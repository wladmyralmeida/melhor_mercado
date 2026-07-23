import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/lists/data/lists_repository.dart';
import 'package:melhor_mercado/features/lists/state/list_providers.dart';
import 'package:melhor_mercado/features/scan/data/receipt_scan_source.dart';
import 'package:melhor_mercado/features/scan/presentation/receipt_photo_screen.dart';
import 'package:melhor_mercado/features/scan/state/scan_providers.dart';

class _FakeReceiptScanSource implements ReceiptScanSource {
  _FakeReceiptScanSource(this._text);

  final String? _text;
  ImageSource? lastSource;
  var callCount = 0;

  @override
  Future<String?> captureText(ImageSource source) async {
    callCount++;
    lastSource = source;
    return _text;
  }
}

class _ThrowingReceiptScanSource implements ReceiptScanSource {
  const _ThrowingReceiptScanSource();

  @override
  Future<String?> captureText(ImageSource source) {
    throw PlatformException(code: 'camera_access_denied');
  }
}

// Linhas já cobertas (com valores esperados calculados) por
// receipt_ocr_parser_test.dart — reaproveitadas aqui pra não recalcular
// aritmética de OCR na mão dentro de um teste de widget.
const _sampleReceiptText =
    'CAFE PILAO TRAD 500G 1 UN 8,99 8,99\n'
    'PAO FRANCES 6,50\n'
    'LEITE INTEGRAL 1L 2 UN 4,50 10,00'; // não reconcilia -> confiança baixa

void main() {
  late AppDb db;
  late int listId;

  setUp(() async {
    db = AppDb.forTesting(NativeDatabase.memory());
    listId = (await ListsRepository(db).watchLists().first).single.id;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(ReceiptScanSource source) {
    return ProviderScope(
      overrides: [
        appDbProvider.overrideWithValue(db),
        receiptScanSourceProvider.overrideWithValue(source),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: ReceiptPhotoScreen(listId: listId),
      ),
    );
  }

  testWidgets('estado inicial oferece câmera e galeria, sem erro', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(_FakeReceiptScanSource(null)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ocr-source-camera')), findsOneWidget);
    expect(find.byKey(const Key('ocr-source-gallery')), findsOneWidget);
  });

  testWidgets('foto reconhecida mostra os itens para revisão', (tester) async {
    await tester.pumpWidget(
      buildApp(_FakeReceiptScanSource(_sampleReceiptText)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ocr-source-camera')));
    await tester.pumpAndSettle();

    expect(find.text('CAFE PILAO TRAD 500G'), findsOneWidget);
    expect(find.text('PAO FRANCES'), findsOneWidget);
    expect(find.text('LEITE INTEGRAL 1L'), findsOneWidget);
    expect(find.text('3 itens encontrados'), findsOneWidget);
    // Item que não reconcilia (LEITE) mostra aviso de conferência.
    expect(find.textContaining('Confira'), findsOneWidget);
  });

  testWidgets('desmarcar um item exclui ele do lote salvo', (tester) async {
    await tester.pumpWidget(
      buildApp(_FakeReceiptScanSource(_sampleReceiptText)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ocr-source-camera')));
    await tester.pumpAndSettle();

    // Índice 1 = "PAO FRANCES" (ordem de aparição no texto).
    await tester.tap(find.byKey(const Key('ocr-selected-1')));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 2 itens'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ocr-add-button')));
    await tester.pumpAndSettle();

    final items = await ListsRepository(db).watchItems(listId).first;
    expect(items, hasLength(2));
    expect(items.any((i) => i.name == 'PAO FRANCES'), isFalse);
  });

  testWidgets('editar nome e preço antes de adicionar salva o valor editado', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(_FakeReceiptScanSource(_sampleReceiptText)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ocr-source-camera')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ocr-name-0')),
      'CAFE PILAO 500G EDITADO',
    );
    await tester.enterText(find.byKey(const Key('ocr-price-0')), '9,50');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ocr-add-button')));
    await tester.pumpAndSettle();

    final items = await ListsRepository(db).watchItems(listId).first;
    final edited = items.firstWhere((i) => i.name == 'CAFE PILAO 500G EDITADO');
    expect(edited.estimatedPriceCents, 950);
  });

  testWidgets('adicionar fecha a tela após salvar no banco', (tester) async {
    await tester.pumpWidget(
      buildApp(_FakeReceiptScanSource(_sampleReceiptText)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ocr-source-camera')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ocr-add-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ReceiptPhotoScreen), findsNothing);
    final items = await ListsRepository(db).watchItems(listId).first;
    expect(items, hasLength(3));
  });

  testWidgets('nenhum item reconhecido mostra estado honesto com saída', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(_FakeReceiptScanSource('blablabla sem nenhum numero')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ocr-source-camera')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não conseguimos reconhecer itens neste cupom'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ocr-manual-add')), findsOneWidget);
  });

  testWidgets(
    '"tentar outra foto" a partir do estado sem itens volta ao início',
    (tester) async {
      await tester.pumpWidget(
        buildApp(_FakeReceiptScanSource('blablabla sem nenhum numero')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ocr-source-camera')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr-retry-photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ocr-source-camera')), findsOneWidget);
      expect(find.byKey(const Key('ocr-source-gallery')), findsOneWidget);
    },
  );

  group('preço derivado (só total na linha, sem unitário separado)', () {
    testWidgets(
      'preço por unidade fica correto quando a quantidade não é editada',
      (tester) async {
        await tester.pumpWidget(
          buildApp(_FakeReceiptScanSource('ARROZ 2KG 6,00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ocr-source-camera')));
        await tester.pumpAndSettle();

        // 6,00 (total original) / 2 = 3,00 por unidade — conferido no
        // próprio campo antes de tocar em "Adicionar".
        expect(find.text('3,00'), findsOneWidget);

        await tester.tap(find.byKey(const Key('ocr-add-button')));
        await tester.pumpAndSettle();

        final items = await ListsRepository(db).watchItems(listId).first;
        final arroz = items.firstWhere((i) => i.name == 'ARROZ');
        expect(arroz.estimatedPriceCents, 300);
      },
    );

    testWidgets('corrigir a quantidade recalcula o preço derivado', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(_FakeReceiptScanSource('ARROZ 2KG 6,00')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ocr-source-camera')));
      await tester.pumpAndSettle();

      // OCR errou a quantidade (era 3, leu 2). O preço por unidade tem
      // que recalcular a partir do TOTAL original (6,00), não ficar
      // travado no valor derivado pra quantidade antiga (3,00).
      await tester.enterText(find.byKey(const Key('ocr-qty-0')), '3');
      await tester.pumpAndSettle();
      expect(find.text('2,00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ocr-add-button')));
      await tester.pumpAndSettle();

      final items = await ListsRepository(db).watchItems(listId).first;
      final arroz = items.firstWhere((i) => i.name == 'ARROZ');
      expect(arroz.quantity, 3);
      expect(arroz.estimatedPriceCents, 200);
    });

    testWidgets(
      'editar o preço manualmente primeiro trava o recálculo automático',
      (tester) async {
        await tester.pumpWidget(
          buildApp(_FakeReceiptScanSource('ARROZ 2KG 6,00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ocr-source-camera')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('ocr-price-0')), '5,00');
        await tester.enterText(find.byKey(const Key('ocr-qty-0')), '3');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('ocr-add-button')));
        await tester.pumpAndSettle();

        final items = await ListsRepository(db).watchItems(listId).first;
        final arroz = items.firstWhere((i) => i.name == 'ARROZ');
        // Preço editado à mão é preservado — não sobrescrito pelo
        // recálculo automático que a mudança de quantidade dispararia.
        expect(arroz.estimatedPriceCents, 500);
      },
    );
  });

  testWidgets('quantidade inválida bloqueia o envio com mensagem clara', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(_FakeReceiptScanSource(_sampleReceiptText)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ocr-source-camera')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ocr-qty-0')), '0');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ocr-add-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quantidade inválida'), findsOneWidget);
    // Nada foi salvo — a tela de revisão continua aberta.
    expect(find.byType(ReceiptPhotoScreen), findsOneWidget);
    final items = await ListsRepository(db).watchItems(listId).first;
    expect(items, isEmpty);
  });

  testWidgets('usuário cancela o seletor de imagem: volta ao início sem erro', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(_FakeReceiptScanSource(null)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ocr-source-gallery')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ocr-source-camera')), findsOneWidget);
    expect(find.textContaining('erro'), findsNothing);
  });

  testWidgets('erro de permissão da câmera mostra estado de falha com retry', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const _ThrowingReceiptScanSource()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ocr-source-camera')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ocr-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ocr-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ocr-source-camera')), findsOneWidget);
  });
}
