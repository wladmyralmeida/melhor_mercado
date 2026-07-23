import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/lists/presentation/add_item_sheet.dart';
import 'package:melhor_mercado/features/lists/presentation/widgets/item_tile.dart';
import 'package:melhor_mercado/features/lists/presentation/widgets/totals_bar.dart';
import 'package:melhor_mercado/features/lists/state/list_providers.dart';
import 'package:melhor_mercado/features/scan/presentation/receipt_photo_screen.dart';
import 'package:melhor_mercado/features/scan/presentation/receipts_history_screen.dart';
import 'package:melhor_mercado/features/scan/presentation/scan_screen.dart';

/// Home = a lista. O produto abre no objeto de uso diário,
/// não em estatística de gasto.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(allListsProvider);
    final activeList = ref.watch(activeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: listsAsync.when(
          data: (lists) => _ListSwitcher(lists: lists, active: activeList),
          loading: () => const Text('melhor mercado'),
          error: (_, _) => const Text('melhor mercado'),
        ),
        actions: [
          if (activeList != null) _PhotoScanButton(listId: activeList.id),
          if (activeList != null) _ScanButton(listId: activeList.id),
          if (activeList != null) _ListMenu(list: activeList),
        ],
      ),
      body: switch ((listsAsync, activeList)) {
        (AsyncError(:final error), _) => _ErrorState(error: error),
        // Carregado porém SEM nenhuma lista (ex.: usuário apagou a
        // última): estado próprio com saída — nunca spinner infinito.
        (AsyncData(:final value), null) when value.isEmpty =>
          const _NoListsState(),
        (_, null) => const Center(child: CircularProgressIndicator()),
        (_, final ShoppingList list) => _ListBody(list: list),
      },
      floatingActionButton: activeList == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showItemSheet(context, listId: activeList.id),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar item'),
            ),
      bottomNavigationBar: activeList == null
          ? null
          : Consumer(
              builder: (context, ref, _) {
                final totals = ref.watch(totalsProvider(activeList.id));
                return TotalsBar(totals: totals);
              },
            ),
    );
  }
}

/// Entrada do scanner. Ação secundária e explícita — a lista continua
/// sendo o produto; o scan é enriquecimento opcional (nunca obrigatório
/// para usar o app).
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.listId});

  final int listId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Escanear cupom fiscal',
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () async {
        final addItems = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => const ScanScreen()));
        if (addItems == true && context.mounted) {
          showItemSheet(context, listId: listId);
        }
      },
    );
  }
}

/// Entrada da leitura de itens por foto (OCR on-device). Ação separada
/// do QR: ali a gente só identifica a nota; aqui a gente já lê e soma
/// os itens à lista, que é o valor real do recurso.
class _PhotoScanButton extends StatelessWidget {
  const _PhotoScanButton({required this.listId});

  final int listId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ler itens do cupom por foto',
      icon: const Icon(Icons.document_scanner_outlined),
      onPressed: () async {
        final added = await Navigator.of(context).push<int>(
          MaterialPageRoute(builder: (_) => ReceiptPhotoScreen(listId: listId)),
        );
        if (added != null && added > 0 && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  added == 1 ? '1 item adicionado' : '$added itens adicionados',
                ),
              ),
            );
        }
      },
    );
  }
}

// ---- Corpo da lista -------------------------------------------------------

class _ListBody extends ConsumerWidget {
  const _ListBody({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsProvider(list.id));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (items) {
        if (items.isEmpty) return const _EmptyState();

        final toBuy = items.where((i) => !i.isChecked).toList();
        final inCart = items.where((i) => i.isChecked).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (toBuy.isNotEmpty)
              _SectionHeader(label: 'A comprar', count: toBuy.length),
            for (final item in toBuy) _dismissible(context, ref, item),
            if (inCart.isNotEmpty)
              _SectionHeader(
                label: 'No carrinho',
                count: inCart.length,
                color: AppColors.precoBom,
              ),
            for (final item in inCart) _dismissible(context, ref, item),
          ],
        );
      },
    );
  }

  Widget _dismissible(
    BuildContext context,
    WidgetRef ref,
    ShoppingListItem item,
  ) {
    final repo = ref.read(listsRepositoryProvider);
    return Dismissible(
      key: ValueKey('item-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) {
        unawaited(repo.deleteItem(item.id));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${item.name}" removido'),
              action: SnackBarAction(
                label: 'Desfazer',
                onPressed: () => unawaited(repo.restoreItem(item)),
              ),
            ),
          );
      },
      child: ItemTile(
        item: item,
        onToggle: (checked) =>
            unawaited(repo.setChecked(item.id, checked: checked)),
        onTap: () => showItemSheet(context, listId: item.listId, item: item),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count, this.color});

  final String label;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$label ($count)',
        style: theme.textTheme.labelLarge?.copyWith(
          color: color ?? AppColors.tintaSuave,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---- Estados --------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 56,
              color: AppColors.tintaSuave,
            ),
            const SizedBox(height: 16),
            Text(
              'Sua lista está vazia',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione o que você precisa comprar.\n'
              'Funciona offline, sem conta.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.tintaSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nenhuma lista existe (a última foi apagada). Sempre com saída.
class _NoListsState extends ConsumerWidget {
  const _NoListsState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.playlist_add,
              size: 56,
              color: AppColors.tintaSuave,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma lista por aqui',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final name = await promptListName(context, 'Nova lista');
                if (name == null || name.isEmpty) return;
                if (!context.mounted) return;
                final id = await ref
                    .read(listsRepositoryProvider)
                    .createList(name);
                if (!context.mounted) return;
                ref.read(activeListIdProvider.notifier).select(id);
              },
              icon: const Icon(Icons.add),
              label: const Text('Criar lista'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Algo deu errado ao abrir sua lista.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.tintaSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Troca de lista e menu ------------------------------------------------

class _ListSwitcher extends ConsumerWidget {
  const _ListSwitcher({required this.lists, required this.active});

  final List<ShoppingList> lists;
  final ShoppingList? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = active?.name ?? 'melhor mercado';
    if (lists.length <= 1) {
      return Text(title, overflow: TextOverflow.ellipsis);
    }
    return PopupMenuButton<int>(
      tooltip: 'Trocar de lista',
      onSelected: (id) => ref.read(activeListIdProvider.notifier).select(id),
      itemBuilder: (_) => [
        for (final list in lists)
          PopupMenuItem(value: list.id, child: Text(list.name)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

enum _ListAction { newList, rename, repeat, duplicate, delete, receiptsHistory }

class _ListMenu extends ConsumerWidget {
  const _ListMenu({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(listsRepositoryProvider);
    return PopupMenuButton<_ListAction>(
      tooltip: 'Opções da lista',
      onSelected: (action) async {
        // Regra: após QUALQUER await de diálogo, checar context.mounted
        // antes de tocar em ref/repo — o menu pode ter saído da árvore.
        switch (action) {
          case _ListAction.newList:
            final name = await promptListName(context, 'Nova lista');
            if (name == null || name.isEmpty || !context.mounted) return;
            final id = await repo.createList(name);
            if (!context.mounted) return;
            ref.read(activeListIdProvider.notifier).select(id);
          case _ListAction.rename:
            final name = await promptListName(
              context,
              'Renomear lista',
              initial: list.name,
            );
            if (name == null || name.isEmpty || !context.mounted) return;
            await repo.renameList(list.id, name);
          case _ListAction.repeat:
            await repo.uncheckAll(list.id);
          case _ListAction.duplicate:
            final id = await repo.duplicateList(list.id);
            if (!context.mounted) return;
            ref.read(activeListIdProvider.notifier).select(id);
          case _ListAction.delete:
            final confirmed = await _confirmDelete(context, list.name);
            if (!confirmed || !context.mounted) return;
            ref.read(activeListIdProvider.notifier).clear();
            await repo.deleteList(list.id);
          case _ListAction.receiptsHistory:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReceiptsHistoryScreen()),
            );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ListAction.newList, child: Text('Nova lista')),
        PopupMenuItem(value: _ListAction.rename, child: Text('Renomear')),
        PopupMenuItem(
          value: _ListAction.repeat,
          child: Text('Repetir lista (desmarcar tudo)'),
        ),
        PopupMenuItem(value: _ListAction.duplicate, child: Text('Duplicar')),
        PopupMenuItem(value: _ListAction.delete, child: Text('Excluir lista')),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _ListAction.receiptsHistory,
          child: Text('Cupons escaneados'),
        ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "$name"?'),
        content: const Text(
          'Os itens desta lista serão apagados. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ---- Diálogo de nome ------------------------------------------------------

/// Pergunta um nome de lista. O diálogo é um StatefulWidget para que o
/// TextEditingController tenha ciclo de vida (dispose) — nada de
/// controller órfão a cada abertura.
Future<String?> promptListName(
  BuildContext context,
  String title, {
  String? initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nome da lista'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
