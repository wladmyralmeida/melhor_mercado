import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/lists/presentation/home_screen.dart';
import 'package:melhor_mercado/features/lists/state/list_providers.dart';

/// Widget tests de RENDERIZAÇÃO: os providers de stream são sobrescritos
/// com valores fixos (fakes). O Drift real fica nos testes de unidade —
/// streams de IO real sob o relógio falso do flutter_test deixam o
/// spinner girando e o pumpAndSettle preso por 10 minutos.
void main() {
  final lista = ShoppingList(
    id: 1,
    name: 'Minhas compras',
    isArchived: false,
    createdAt: DateTime(2026, 7, 22),
  );

  ShoppingListItem item({
    required int id,
    required String name,
    int? priceCents,
    bool checked = false,
    double quantity = 1,
    String? unit = 'un',
  }) {
    return ShoppingListItem(
      id: id,
      listId: 1,
      name: name,
      quantity: quantity,
      unit: unit,
      estimatedPriceCents: priceCents,
      isChecked: checked,
      position: 0,
      createdAt: DateTime(2026, 7, 22),
    );
  }

  late AppDb db;

  setUp(() {
    // Nunca consultado (streams sobrescritos), mas impede o provider
    // default de abrir um banco de arquivo via path_provider no teste.
    db = AppDb.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(List<ShoppingListItem> items) {
    return ProviderScope(
      overrides: [
        appDbProvider.overrideWithValue(db),
        allListsProvider.overrideWith((ref) => Stream.value([lista])),
        itemsProvider.overrideWith((ref, listId) => Stream.value(items)),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
    );
  }

  testWidgets('mostra estado vazio com a lista padrão', (tester) async {
    await tester.pumpWidget(buildApp(const []));
    await tester.pumpAndSettle();

    expect(find.text('Minhas compras'), findsOneWidget);
    expect(find.text('Sua lista está vazia'), findsOneWidget);
    expect(find.text('Adicionar item'), findsOneWidget);
  });

  testWidgets('exibe itens com seções e total honesto', (tester) async {
    await tester.pumpWidget(
      buildApp([
        item(id: 1, name: 'Arroz 5kg', priceCents: 2599),
        item(id: 2, name: 'Feijão'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('A comprar (2)'), findsOneWidget);
    expect(find.text('Arroz 5kg'), findsOneWidget);
    expect(find.text('Feijão'), findsOneWidget);
    // Total honesto: 1 de 2 itens com preço — nunca finge que o item
    // sem preço custa zero.
    expect(find.textContaining('1 de 2 itens com preço'), findsOneWidget);
    expect(find.textContaining('25,99'), findsWidgets);
  });

  testWidgets('item marcado aparece em "No carrinho" com subtotal', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp([
        item(id: 1, name: 'Leite', priceCents: 549, checked: true),
        item(id: 2, name: 'Café', priceCents: 1899),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('No carrinho (1)'), findsOneWidget);
    expect(find.text('A comprar (1)'), findsOneWidget);
    // Subtotal do carrinho: só o item marcado (R$ 5,49).
    expect(find.text('No carrinho'), findsOneWidget);
    expect(find.textContaining('5,49'), findsWidgets);
  });

  testWidgets('sem nenhuma lista: estado próprio com saída, nunca spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDbProvider.overrideWithValue(db),
          // Carregado e VAZIO — o cenário de apagar a última lista.
          allListsProvider.overrideWith(
            (ref) => Stream.value(const <ShoppingList>[]),
          ),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Nenhuma lista por aqui'), findsOneWidget);
    expect(find.text('Criar lista'), findsOneWidget);
  });

  testWidgets('quantidade fracionária com unidade aparece no item', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp([
        item(
          id: 1,
          name: 'Carne moída',
          quantity: 0.5,
          unit: 'kg',
          priceCents: 3999,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('0,5 kg'), findsOneWidget);
    // Linha = 0,5 × 39,99 = R$ 20,00 (arredondado por linha).
    expect(find.textContaining('20,00'), findsWidgets);
  });
}
