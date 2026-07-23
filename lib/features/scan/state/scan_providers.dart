import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/features/lists/state/list_providers.dart';
import 'package:melhor_mercado/features/scan/data/receipt_scan_source.dart';
import 'package:melhor_mercado/features/scan/data/receipts_repository.dart';

final receiptsRepositoryProvider = Provider<ReceiptsRepository>(
  (ref) => ReceiptsRepository(ref.watch(appDbProvider)),
);

/// Overridden nos testes com um fake — a implementação real chama
/// ImagePicker + ML Kit, que não rodam sob flutter_test.
final receiptScanSourceProvider = Provider<ReceiptScanSource>(
  (ref) => const MlKitReceiptScanSource(),
);

/// Cupons escaneados, mais recente primeiro. `autoDispose`: a tela de
/// histórico não fica sempre montada, então a assinatura do stream não
/// precisa sobreviver a ela.
final recentReceiptsProvider = StreamProvider.autoDispose<List<Receipt>>(
  (ref) => ref.watch(receiptsRepositoryProvider).watchRecent(),
);
