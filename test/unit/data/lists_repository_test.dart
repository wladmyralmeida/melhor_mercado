import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/features/lists/data/lists_repository.dart';

void main() {
  late AppDb db;
  late ListsRepository repo;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    repo = ListsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('semente', () {
    test('o banco abre com a lista padrão criada', () async {
      final lists = await repo.watchLists().first;
      expect(lists, hasLength(1));
      expect(lists.single.name, 'Minhas compras');
    });
  });

  group('itens', () {
    test('adiciona, marca e ordena: a comprar antes do carrinho', () async {
      final lists = await repo.watchLists().first;
      final listId = lists.single.id;

      final arrozId = await repo.addItem(
        listId: listId,
        name: 'Arroz 5kg',
        estimatedPriceCents: 2599,
      );
      await repo.addItem(listId: listId, name: 'Feijão');
      await repo.setChecked(arrozId, checked: true);

      final items = await repo.watchItems(listId).first;
      expect(items, hasLength(2));
      // Desmarcado (Feijão) vem antes do marcado (Arroz).
      expect(items.first.name, 'Feijão');
      expect(items.last.name, 'Arroz 5kg');
      expect(items.last.isChecked, isTrue);
    });

    test('atualiza item preservando os campos', () async {
      final listId = (await repo.watchLists().first).single.id;
      final id = await repo.addItem(listId: listId, name: 'Leite');

      await repo.updateItem(
        id: id,
        name: 'Leite integral',
        quantity: 12,
        unit: 'un',
        estimatedPriceCents: 549,
      );

      final item = (await repo.watchItems(listId).first).single;
      expect(item.name, 'Leite integral');
      expect(item.quantity, 12);
      expect(item.estimatedPriceCents, 549);
    });

    test('addItems insere vários itens de uma vez (lote pós-OCR)', () async {
      final listId = (await repo.watchLists().first).single.id;

      await repo.addItems(listId, [
        (name: 'Café', quantity: 1.0, unit: 'UN', priceCents: 899),
        (name: 'Arroz ', quantity: 2.0, unit: 'KG', priceCents: 2490),
        (name: 'Sem preço', quantity: 1.0, unit: null, priceCents: null),
      ]);

      final items = await repo.watchItems(listId).first;
      expect(items, hasLength(3));
      final arroz = items.firstWhere((i) => i.name == 'Arroz');
      expect(arroz.quantity, 2.0);
      expect(arroz.unit, 'KG');
      expect(arroz.estimatedPriceCents, 2490);
      final semPreco = items.firstWhere((i) => i.name == 'Sem preço');
      expect(semPreco.estimatedPriceCents, isNull);
    });

    test('apaga e restaura (undo)', () async {
      final listId = (await repo.watchLists().first).single.id;
      await repo.addItem(listId: listId, name: 'Café', unit: 'pct');

      final item = (await repo.watchItems(listId).first).single;
      await repo.deleteItem(item.id);
      expect(await repo.watchItems(listId).first, isEmpty);

      await repo.restoreItem(item);
      final restored = (await repo.watchItems(listId).first).single;
      expect(restored.name, 'Café');
      expect(restored.unit, 'pct');
    });
  });

  group('listas', () {
    test('repetir lista desmarca todos os itens', () async {
      final listId = (await repo.watchLists().first).single.id;
      final a = await repo.addItem(listId: listId, name: 'A');
      final b = await repo.addItem(listId: listId, name: 'B');
      await repo.setChecked(a, checked: true);
      await repo.setChecked(b, checked: true);

      await repo.uncheckAll(listId);

      final items = await repo.watchItems(listId).first;
      expect(items.every((i) => !i.isChecked), isTrue);
    });

    test('duplicar copia itens desmarcados', () async {
      final listId = (await repo.watchLists().first).single.id;
      final a = await repo.addItem(
        listId: listId,
        name: 'Arroz',
        estimatedPriceCents: 2599,
      );
      await repo.setChecked(a, checked: true);

      final copyId = await repo.duplicateList(listId);
      final copied = await repo.watchItems(copyId).first;

      expect(copied, hasLength(1));
      expect(copied.single.name, 'Arroz');
      expect(copied.single.estimatedPriceCents, 2599);
      expect(copied.single.isChecked, isFalse);
    });

    test('excluir lista apaga os itens em cascata', () async {
      final listId = (await repo.watchLists().first).single.id;
      await repo.addItem(listId: listId, name: 'X');

      await repo.deleteList(listId);

      final orphans = await db.select(db.shoppingListItems).get();
      expect(orphans, isEmpty);
    });
  });

  group('ListTotals', () {
    test(
      'total honesto: conta só itens com preço e reporta cobertura',
      () async {
        final listId = (await repo.watchLists().first).single.id;
        final comPreco = await repo.addItem(
          listId: listId,
          name: 'Arroz',
          quantity: 2,
          estimatedPriceCents: 1000, // 2 x R$10 = R$20
        );
        await repo.addItem(listId: listId, name: 'Sem preço');
        await repo.setChecked(comPreco, checked: true);

        final items = await repo.watchItems(listId).first;
        final totals = ListTotals.fromItems(items);

        expect(totals.totalItems, 2);
        expect(totals.itemsWithPrice, 1);
        expect(totals.estimatedTotalCents, 2000);
        expect(totals.inCartCents, 2000);
        expect(totals.checkedCount, 1);
        expect(totals.isComplete, isFalse);
      },
    );

    test('quantidade fracionária arredonda por linha (0,5 kg)', () {
      final totals = ListTotals.fromItems([
        ShoppingListItem(
          id: 1,
          listId: 1,
          name: 'Carne',
          quantity: 0.5,
          unit: 'kg',
          estimatedPriceCents: 3999, // 0,5 x 39,99 = 20,00 (round)
          isChecked: false,
          position: 0,
          createdAt: DateTime(2026),
        ),
      ]);
      expect(totals.estimatedTotalCents, 2000);
    });

    test('lista vazia não tem preço nem está completa', () {
      final totals = ListTotals.fromItems(const []);
      expect(totals.hasAnyPrice, isFalse);
      expect(totals.isComplete, isFalse);
    });
  });
}
