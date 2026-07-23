import 'package:drift/drift.dart';
import 'package:melhor_mercado/core/db/app_db.dart';

/// Acesso a listas e itens. Toda a persistência é local (Drift/SQLite):
/// a lista funciona offline, sem conta — princípio do produto.
class ListsRepository {
  const ListsRepository(this._db);

  final AppDb _db;

  // ---- Listas -------------------------------------------------------------

  Stream<List<ShoppingList>> watchLists() {
    final q = _db.select(_db.shoppingLists)
      ..where((l) => l.isArchived.equals(false))
      ..orderBy([(l) => OrderingTerm.asc(l.id)]);
    return q.watch();
  }

  Future<int> createList(String name) => _db
      .into(_db.shoppingLists)
      .insert(ShoppingListsCompanion.insert(name: name.trim()));

  Future<void> renameList(int id, String name) =>
      (_db.update(_db.shoppingLists)..where((l) => l.id.equals(id))).write(
        ShoppingListsCompanion(name: Value(name.trim())),
      );

  /// Apaga a lista e, por cascade, os itens.
  Future<void> deleteList(int id) =>
      (_db.delete(_db.shoppingLists)..where((l) => l.id.equals(id))).go();

  /// "Repetir lista": desmarca tudo — a lista da semana renasce.
  Future<void> uncheckAll(int listId) =>
      (_db.update(_db.shoppingListItems)..where((i) => i.listId.equals(listId)))
          .write(const ShoppingListItemsCompanion(isChecked: Value(false)));

  /// Duplica a lista com os mesmos itens, todos desmarcados.
  Future<int> duplicateList(int listId, {String? newName}) =>
      _db.transaction(() async {
        final source = await (_db.select(
          _db.shoppingLists,
        )..where((l) => l.id.equals(listId))).getSingle();
        // Mesmo ORDER BY de watchItems: sem ele o SQLite não garante
        // ordem e a cópia poderia sair embaralhada.
        final items =
            await (_db.select(_db.shoppingListItems)
                  ..where((i) => i.listId.equals(listId))
                  ..orderBy([
                    (i) => OrderingTerm.asc(i.isChecked),
                    (i) => OrderingTerm.asc(i.position),
                    (i) => OrderingTerm.asc(i.id),
                  ]))
                .get();

        final newId = await _db
            .into(_db.shoppingLists)
            .insert(
              ShoppingListsCompanion.insert(
                name: newName ?? '${source.name} (cópia)',
              ),
            );
        for (final item in items) {
          await _db
              .into(_db.shoppingListItems)
              .insert(
                ShoppingListItemsCompanion.insert(
                  listId: newId,
                  name: item.name,
                  quantity: Value(item.quantity),
                  unit: Value(item.unit),
                  estimatedPriceCents: Value(item.estimatedPriceCents),
                  position: Value(item.position),
                ),
              );
        }
        return newId;
      });

  // ---- Itens --------------------------------------------------------------

  /// Itens ordenados: a comprar primeiro, depois no carrinho.
  Stream<List<ShoppingListItem>> watchItems(int listId) {
    final q = _db.select(_db.shoppingListItems)
      ..where((i) => i.listId.equals(listId))
      ..orderBy([
        (i) => OrderingTerm.asc(i.isChecked),
        (i) => OrderingTerm.asc(i.position),
        (i) => OrderingTerm.asc(i.id),
      ]);
    return q.watch();
  }

  Future<int> addItem({
    required int listId,
    required String name,
    double quantity = 1,
    String? unit,
    int? estimatedPriceCents,
  }) => _db
      .into(_db.shoppingListItems)
      .insert(
        ShoppingListItemsCompanion.insert(
          listId: listId,
          name: name.trim(),
          quantity: Value(quantity),
          unit: Value(unit),
          estimatedPriceCents: Value(estimatedPriceCents),
        ),
      );

  /// Adiciona vários itens de uma vez (ex.: revisão pós-OCR do cupom) —
  /// uma transação só, para não deixar a lista pela metade se algo
  /// falhar no meio do lote.
  Future<void> addItems(
    int listId,
    List<({String name, double quantity, String? unit, int? priceCents})> items,
  ) => _db.transaction(() async {
    for (final item in items) {
      await _db
          .into(_db.shoppingListItems)
          .insert(
            ShoppingListItemsCompanion.insert(
              listId: listId,
              name: item.name.trim(),
              quantity: Value(item.quantity),
              unit: Value(item.unit),
              estimatedPriceCents: Value(item.priceCents),
            ),
          );
    }
  });

  Future<void> updateItem({
    required int id,
    required String name,
    required double quantity,
    String? unit,
    int? estimatedPriceCents,
  }) =>
      (_db.update(_db.shoppingListItems)..where((i) => i.id.equals(id))).write(
        ShoppingListItemsCompanion(
          name: Value(name.trim()),
          quantity: Value(quantity),
          unit: Value(unit),
          estimatedPriceCents: Value(estimatedPriceCents),
        ),
      );

  Future<void> setChecked(int id, {required bool checked}) =>
      (_db.update(_db.shoppingListItems)..where((i) => i.id.equals(id))).write(
        ShoppingListItemsCompanion(isChecked: Value(checked)),
      );

  Future<void> deleteItem(int id) =>
      (_db.delete(_db.shoppingListItems)..where((i) => i.id.equals(id))).go();

  /// Restaura um item apagado (undo do swipe).
  ///
  /// Honestidade: o item volta com id novo e reaparece no FIM da sua
  /// seção (position não é rastreada nesta fase), não no lugar exato.
  Future<int> restoreItem(ShoppingListItem item) => _db
      .into(_db.shoppingListItems)
      .insert(
        ShoppingListItemsCompanion.insert(
          listId: item.listId,
          name: item.name,
          quantity: Value(item.quantity),
          unit: Value(item.unit),
          estimatedPriceCents: Value(item.estimatedPriceCents),
          isChecked: Value(item.isChecked),
          position: Value(item.position),
        ),
      );
}

/// Totais derivados dos itens — calculados em Dart (listas são pequenas).
///
/// Honestidade embutida: o total estimado diz de quantos itens ele veio;
/// nunca finge que itens sem preço custam zero.
class ListTotals {
  const ListTotals({
    required this.totalItems,
    required this.itemsWithPrice,
    required this.estimatedTotalCents,
    required this.inCartCents,
    required this.checkedCount,
  });

  factory ListTotals.fromItems(List<ShoppingListItem> items) {
    var estimated = 0;
    var inCart = 0;
    var withPrice = 0;
    var checked = 0;
    for (final item in items) {
      final price = item.estimatedPriceCents;
      if (item.isChecked) checked++;
      if (price == null) continue;
      withPrice++;
      final line = (price * item.quantity).round();
      estimated += line;
      if (item.isChecked) inCart += line;
    }
    return ListTotals(
      totalItems: items.length,
      itemsWithPrice: withPrice,
      estimatedTotalCents: estimated,
      inCartCents: inCart,
      checkedCount: checked,
    );
  }

  final int totalItems;
  final int itemsWithPrice;
  final int estimatedTotalCents;

  /// Soma do que já está marcado — o "quanto já tem no carrinho" durante
  /// a compra.
  final int inCartCents;
  final int checkedCount;

  bool get hasAnyPrice => itemsWithPrice > 0;
  bool get isComplete => totalItems > 0 && checkedCount == totalItems;
}
