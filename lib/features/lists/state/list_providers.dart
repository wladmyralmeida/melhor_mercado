import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/features/lists/data/lists_repository.dart';

/// Banco local. Sobrescrito nos testes com `AppDb.forTesting(...)`.
final appDbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
});

final listsRepositoryProvider = Provider<ListsRepository>(
  (ref) => ListsRepository(ref.watch(appDbProvider)),
);

/// Todas as listas não arquivadas (a semente garante ao menos uma).
final allListsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(listsRepositoryProvider).watchLists(),
);

/// Seleção manual de lista; null = usa a primeira.
class ActiveListId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int id) => state = id;
  void clear() => state = null;
}

final activeListIdProvider = NotifierProvider<ActiveListId, int?>(
  ActiveListId.new,
);

/// A lista efetivamente ativa: a selecionada, ou a primeira existente.
final activeListProvider = Provider<ShoppingList?>((ref) {
  final lists = ref.watch(allListsProvider).value ?? const <ShoppingList>[];
  if (lists.isEmpty) return null;
  final selectedId = ref.watch(activeListIdProvider);
  for (final list in lists) {
    if (list.id == selectedId) return list;
  }
  return lists.first;
});

/// Itens da lista ativa (a comprar primeiro, carrinho depois).
///
/// `autoDispose`: sem ele, cada listId já visitado manteria a query
/// reativa do Drift assinada para sempre — inclusive de listas apagadas.
final itemsProvider = StreamProvider.autoDispose
    .family<List<ShoppingListItem>, int>(
      (ref, listId) => ref.watch(listsRepositoryProvider).watchItems(listId),
    );

/// Totais derivados — recalculados a cada mudança dos itens.
final totalsProvider = Provider.autoDispose.family<ListTotals, int>((
  ref,
  listId,
) {
  final items =
      ref.watch(itemsProvider(listId)).value ?? const <ShoppingListItem>[];
  return ListTotals.fromItems(items);
});
