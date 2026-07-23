import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/core/format/brl.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/lists/state/list_providers.dart';

const _units = ['un', 'kg', 'g', 'L', 'ml', 'pct', 'cx'];

/// Abre a folha de adicionar (item == null) ou editar (item != null).
Future<void> showItemSheet(
  BuildContext context, {
  required int listId,
  ShoppingListItem? item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ItemSheet(listId: listId, item: item),
  );
}

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.listId, this.item});

  final int listId;
  final ShoppingListItem? item;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  String? _unit;
  String? _error;

  /// Trava de duplo-submit: no modo rajada, dois toques rápidos em
  /// "Adicionar" inseririam o mesmo item duas vezes.
  bool _saving = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _qty = TextEditingController(
      text: item == null ? '1' : formatQty(item.quantity),
    );
    final cents = item?.estimatedPriceCents;
    _price = TextEditingController(
      text: cents == null ? '' : centsToEditableText(cents),
    );
    _unit = item?.unit ?? 'un';
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dê um nome ao item.');
      return;
    }
    final qty = parseQty(_qty.text) ?? 1;
    final priceText = _price.text.trim();
    final cents = priceText.isEmpty ? null : parseBrlToCents(priceText);
    if (priceText.isNotEmpty && cents == null) {
      setState(() => _error = 'Preço inválido. Use por exemplo 4,99.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(listsRepositoryProvider);
      if (_isEditing) {
        await repo.updateItem(
          id: widget.item!.id,
          name: name,
          quantity: qty,
          unit: _unit,
          estimatedPriceCents: cents,
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await repo.addItem(
        listId: widget.listId,
        name: name,
        quantity: qty,
        unit: _unit,
        estimatedPriceCents: cents,
      );
      // Modo adicionar: a folha fica aberta para o próximo item —
      // montar a lista da semana é uma rajada, não um item por vez.
      if (!mounted) return;
      setState(() {
        _error = null;
        _name.clear();
        _price.clear();
        _qty.text = '1';
        _unit = 'un';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Só o teclado interessa aqui — não inscrever em todo o MediaQuery.
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Editar item' : 'Adicionar item',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Item',
                hintText: 'ex.: Arroz 5kg',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Qtde',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final unit in _units)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(unit),
                              selected: _unit == unit,
                              onSelected: (_) => setState(() => _unit = unit),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Preço estimado (opcional)',
                hintText: '4,99',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
                helperText:
                    'Depois o app preenche sozinho com o que você pagou.',
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? 'Salvar' : 'Adicionar'),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 8),
              Text(
                'A folha fica aberta para adicionar vários itens. '
                'Toque fora quando terminar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.tintaSuave,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
