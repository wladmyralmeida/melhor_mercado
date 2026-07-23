import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/lists/state/list_providers.dart';
import 'package:melhor_mercado/features/scan/presentation/receipts_history_screen.dart';
import 'package:melhor_mercado/features/scan/state/scan_providers.dart';

/// Providers sobrescritos com dados fixos — mesma técnica de
/// home_screen_test.dart: sem IO real de banco sob o relógio falso do
/// flutter_test.
void main() {
  late AppDb db;

  Receipt receipt({required int id, String docModel = '65', int? totalCents}) {
    return Receipt(
      id: id,
      accessKey: '2526071234567800019965001000000123187654321$id',
      naturalKey: 'natural-$id',
      cuf: '25',
      issuerId: '12345678000199',
      docModel: docModel,
      totalCents: totalCents,
      qrFormat: 'v2Online',
      rawQr: 'raw-$id',
      scannedAt: DateTime(2026, 7, 22, 18, 0),
    );
  }

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(List<Receipt> receipts) {
    return ProviderScope(
      overrides: [
        appDbProvider.overrideWithValue(db),
        recentReceiptsProvider.overrideWith((ref) => Stream.value(receipts)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const ReceiptsHistoryScreen(),
      ),
    );
  }

  testWidgets('estado vazio quando não há cupons escaneados', (tester) async {
    await tester.pumpWidget(buildApp(const []));
    await tester.pumpAndSettle();

    expect(find.text('Cupons escaneados'), findsOneWidget);
    expect(find.text('Você ainda não escaneou nenhum cupom'), findsOneWidget);
  });

  testWidgets('lista cupons com CNPJ formatado e badge do modelo', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp([
        receipt(id: 1, docModel: '65', totalCents: 15000),
        receipt(id: 2, docModel: '59'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('NFC-e'), findsOneWidget);
    expect(find.text('CF-e-SAT'), findsOneWidget);
    expect(find.text('12.345.678/0001-99'), findsNWidgets(2));
    // Só o primeiro cupom tem total conhecido.
    expect(find.textContaining('150,00'), findsOneWidget);
  });
}
