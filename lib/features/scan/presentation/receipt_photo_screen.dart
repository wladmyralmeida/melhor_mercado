import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:melhor_mercado/core/format/brl.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/lists/presentation/add_item_sheet.dart';
import 'package:melhor_mercado/features/lists/state/list_providers.dart';
import 'package:melhor_mercado/features/scan/domain/receipt_ocr_parser.dart';
import 'package:melhor_mercado/features/scan/state/scan_providers.dart';

/// Foto do cupom -> itens: tira/escolhe foto, lê com ML Kit (on-device),
/// interpreta com [parseReceiptText] e deixa o usuário revisar/corrigir
/// antes de somar tudo à lista. A revisão é a rede de segurança — nada
/// é gravado sem passar por ela.
class ReceiptPhotoScreen extends ConsumerStatefulWidget {
  const ReceiptPhotoScreen({super.key, required this.listId});

  final int listId;

  @override
  ConsumerState<ReceiptPhotoScreen> createState() => _ReceiptPhotoScreenState();
}

sealed class _PhotoUiState {
  const _PhotoUiState();
}

class _Initial extends _PhotoUiState {
  const _Initial();
}

class _Processing extends _PhotoUiState {
  const _Processing();
}

class _Reviewing extends _PhotoUiState {
  const _Reviewing(this.drafts);
  final List<_EditableDraft> drafts;
}

class _NoItemsFound extends _PhotoUiState {
  const _NoItemsFound();
}

class _Failed extends _PhotoUiState {
  const _Failed(this.message);
  final String message;
}

class _ReceiptPhotoScreenState extends ConsumerState<ReceiptPhotoScreen> {
  _PhotoUiState _state = const _Initial();
  var _saving = false;

  @override
  void dispose() {
    _disposeDrafts(_state);
    super.dispose();
  }

  void _disposeDrafts(_PhotoUiState state) {
    if (state case _Reviewing(:final drafts)) {
      for (final draft in drafts) {
        draft.dispose();
      }
    }
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _state = const _Processing());
    try {
      final text = await ref
          .read(receiptScanSourceProvider)
          .captureText(source);
      if (!mounted) return;
      if (text == null) {
        // Usuário cancelou o seletor — não é erro, só volta ao início.
        setState(() => _state = const _Initial());
        return;
      }
      final items = parseReceiptText(text);
      setState(() {
        _state = items.isEmpty
            ? const _NoItemsFound()
            : _Reviewing(items.map(_EditableDraft.new).toList());
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _state = _Failed(_messageFor(e)));
    } on Exception {
      // Falhas que não chegam como PlatformException (ex.:
      // MissingPluginException) — sem isto a tela ficava presa em
      // "Lendo o cupom..." pra sempre, sem chance de tentar de novo.
      if (!mounted) return;
      setState(() => _state = const _Failed('Não foi possível ler o cupom.'));
    }
  }

  String _messageFor(PlatformException e) {
    if (e.code.contains('camera') || e.code.contains('access_denied')) {
      return 'Precisamos de acesso à câmera ou às fotos para ler o cupom. '
          'Permita o acesso nas configurações do aparelho.';
    }
    return 'Não foi possível abrir a câmera ou a galeria.';
  }

  void _retry() {
    _disposeDrafts(_state);
    setState(() => _state = const _Initial());
  }

  void _toggle(_EditableDraft draft) {
    setState(() => draft.selected = !draft.selected);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addSelected(List<_EditableDraft> drafts) async {
    if (_saving) return;
    final selected = drafts.where((d) => d.selected).toList();
    if (selected.isEmpty) return;

    final toInsert =
        <({String name, double quantity, String? unit, int? priceCents})>[];
    for (final draft in selected) {
      final name = draft.nameCtrl.text.trim();
      if (name.isEmpty) {
        _showMessage('Um dos itens selecionados está sem nome.');
        return;
      }
      // Mesmo limite de ShoppingListItems.name (app_db.dart) — validar
      // aqui evita que um nome longo demais derrube o insert inteiro lá
      // na frente sem nenhuma explicação pro usuário.
      if (name.length > 120) {
        _showMessage('Um item tem nome muito longo (máx. 120 caracteres).');
        return;
      }
      // Assim como o preço, uma quantidade inválida bloqueia o envio em
      // vez de cair silenciosamente para 1 — sem isto, um "1" que devia
      // virar "3" (erro comum de OCR) salvaria "1" sem aviso nenhum.
      final quantity = parseQty(draft.qtyCtrl.text);
      if (quantity == null) {
        _showMessage(
          'Quantidade inválida em "$name". Use, por exemplo, 1 ou 0,5.',
        );
        return;
      }
      final priceText = draft.priceCtrl.text.trim();
      final priceCents = priceText.isEmpty ? null : parseBrlToCents(priceText);
      if (priceText.isNotEmpty && priceCents == null) {
        _showMessage('Preço inválido em "$name". Use, por exemplo, 4,99.');
        return;
      }
      final unitText = draft.unitCtrl.text.trim();
      toInsert.add((
        name: name,
        quantity: quantity,
        unit: unitText.isEmpty ? null : unitText,
        priceCents: priceCents,
      ));
    }

    setState(() => _saving = true);
    try {
      await ref.read(listsRepositoryProvider).addItems(widget.listId, toInsert);
    } on Exception {
      // Sem isto, uma falha aqui (ex.: alguma violação de constraint que
      // escapou da validação acima) deixava "Adicionar" desabilitado pra
      // sempre, sem nenhum jeito de recuperar a revisão já feita.
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('Não foi possível salvar os itens. Tente de novo.');
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(toInsert.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Itens do cupom (foto)')),
      body: switch (_state) {
        _Initial() => _SourcePicker(onPick: _pick),
        _Processing() => const _ProcessingView(),
        _Reviewing(:final drafts) => _ReviewView(
          drafts: drafts,
          saving: _saving,
          onToggle: _toggle,
          onAdd: () => _addSelected(drafts),
        ),
        _NoItemsFound() => _NoItemsFoundView(
          listId: widget.listId,
          onRetry: _retry,
        ),
        _Failed(:final message) => _FailedView(
          message: message,
          onRetry: _retry,
        ),
      },
    );
  }
}

/// Estado editável de um item candidato — controllers próprios porque a
/// revisão é o passo em que o usuário corrige o que o OCR errou.
class _EditableDraft {
  _EditableDraft(DraftReceiptItem draft)
    : selected = true,
      confidence = draft.confidence,
      rawText = draft.rawText,
      _derivedTotalCents = draft.unitPriceCents == null
          ? draft.totalPriceCents
          : null,
      nameCtrl = TextEditingController(text: draft.name),
      qtyCtrl = TextEditingController(text: formatQty(draft.quantity)),
      unitCtrl = TextEditingController(text: draft.unit ?? ''),
      priceCtrl = TextEditingController(
        text: switch (_impliedUnitPriceCents(draft)) {
          final cents? => centsToEditableText(cents),
          null => '',
        },
      ) {
    // Só liga o recálculo quando o preço mostrado foi DERIVADO (total ÷
    // qty) — quando o cupom já trazia o unitário direto, preço e
    // quantidade são de fato independentes, e não tem nada pra recalcular.
    if (_derivedTotalCents != null) {
      qtyCtrl.addListener(_recomputeDerivedPrice);
      priceCtrl.addListener(_markPriceEditedManually);
    }
  }

  /// Total original da linha do cupom — só preenchido quando o preço
  /// exibido foi derivado (total ÷ qty). Usado para recalcular o preço
  /// por unidade se o usuário corrigir a quantidade; sem isso, corrigir
  /// um erro comum de OCR na quantidade (ex.: "1" devia ser "2") deixava
  /// o preço por unidade errado em silêncio, sem nenhum sinal pro
  /// usuário — exatamente o tipo de corrupção de dinheiro que este app
  /// não pode deixar passar.
  final int? _derivedTotalCents;
  var _priceEditedManually = false;
  var _recomputing = false;

  bool selected;
  final double confidence;
  final String rawText;
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;

  void _markPriceEditedManually() {
    if (!_recomputing) _priceEditedManually = true;
  }

  void _recomputeDerivedPrice() {
    if (_priceEditedManually) return;
    final total = _derivedTotalCents;
    if (total == null) return;
    final qty = parseQty(qtyCtrl.text);
    if (qty == null) return;
    _recomputing = true;
    priceCtrl.text = centsToEditableText((total / qty).round());
    _recomputing = false;
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// `estimatedPriceCents` é sempre POR UNIDADE nesse app (quem multiplica
/// pela quantidade é quem exibe/soma — ver ItemTile/ListTotals). Usa o
/// unitário direto quando o OCR separou as colunas; deriva de
/// total ÷ qty quando a linha só trazia um preço (o caso mais comum).
int? _impliedUnitPriceCents(DraftReceiptItem draft) {
  if (draft.unitPriceCents != null) return draft.unitPriceCents;
  final total = draft.totalPriceCents;
  if (total == null || draft.quantity <= 0) return null;
  return (total / draft.quantity).round();
}

// ---- Estados de tela --------------------------------------------------

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.onPick});

  final void Function(ImageSource) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.document_scanner_outlined,
              size: 64,
              color: AppColors.tintaSuave,
            ),
            const SizedBox(height: 16),
            Text(
              'Leia os itens do cupom por foto',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tudo acontece no aparelho: a foto não é enviada a nenhum '
              'servidor. Depois de ler, você revisa e corrige antes de '
              'adicionar à lista.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.tintaSuave,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              key: const Key('ocr-source-camera'),
              onPressed: () => onPick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tirar foto do cupom'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('ocr-source-gallery'),
              onPressed: () => onPick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Escolher da galeria'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Lendo o cupom…'),
        ],
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.drafts,
    required this.saving,
    required this.onToggle,
    required this.onAdd,
  });

  final List<_EditableDraft> drafts;
  final bool saving;
  final void Function(_EditableDraft) onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = drafts.where((d) => d.selected).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${drafts.length} itens encontrados',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.tintaSuave,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: drafts.length,
            itemBuilder: (context, i) => _DraftItemCard(
              index: i,
              draft: drafts[i],
              onToggle: () => onToggle(drafts[i]),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              key: const Key('ocr-add-button'),
              onPressed: selectedCount == 0 || saving ? null : onAdd,
              child: Text(
                selectedCount == 0
                    ? 'Selecione ao menos 1 item'
                    : 'Adicionar $selectedCount '
                          '${selectedCount == 1 ? 'item' : 'itens'}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftItemCard extends StatelessWidget {
  const _DraftItemCard({
    required this.index,
    required this.draft,
    required this.onToggle,
  });

  final int index;
  final _EditableDraft draft;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowConfidence = draft.confidence < 0.6;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  key: Key('ocr-selected-$index'),
                  value: draft.selected,
                  onChanged: (_) => onToggle(),
                ),
                Expanded(
                  child: TextField(
                    key: Key('ocr-name-$index'),
                    controller: draft.nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tooltip(
                  message:
                      'Confiança: ${(draft.confidence * 100).round()}%\n'
                      'Texto lido: "${draft.rawText}"',
                  child: Icon(
                    lowConfidence
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: lowConfidence
                        ? theme.colorScheme.error
                        : AppColors.precoBom,
                    size: 20,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: TextField(
                      key: Key('ocr-qty-$index'),
                      controller: draft.qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Qtde',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      key: Key('ocr-unit-$index'),
                      controller: draft.unitCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Un.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: Key('ocr-price-$index'),
                      controller: draft.priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Preço un.',
                        prefixText: 'R\$ ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (lowConfidence)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Text(
                  'Confira: valores podem estar errados.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoItemsFoundView extends StatelessWidget {
  const _NoItemsFoundView({required this.listId, required this.onRetry});

  final int listId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 56, color: AppColors.tintaSuave),
            const SizedBox(height: 16),
            Text(
              'Não conseguimos reconhecer itens neste cupom',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tente uma foto com mais luz, sem dobras e enquadrando bem '
              'as linhas dos produtos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.tintaSuave,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('ocr-retry-photo'),
              onPressed: onRetry,
              child: const Text('Tentar outra foto'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('ocr-manual-add'),
              onPressed: () => showItemSheet(context, listId: listId),
              child: const Text('Adicionar manualmente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('ocr-retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
