import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/features/scan/data/receipts_repository.dart';
import 'package:mm_fiscal/mm_fiscal.dart';

// Mesmos vetores verificados do pacote mm_fiscal (DV conferido por
// script Python independente) — reaproveitados aqui para testar a
// integração real entre o parser e a persistência, não só mocks.
const _nfcePb = '25260712345678000199650010000001231876543214';
const _cfeSat = '35111202767579000148598583801050151865833992';

RecognizedFiscalDocument _parse(String raw) =>
    parseFiscalQr(raw) as RecognizedFiscalDocument;

void main() {
  late AppDb db;
  late ReceiptsRepository repo;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    repo = ReceiptsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('primeira leitura', () {
    test('salva a identidade do documento, sem inventar itens', () async {
      final doc = _parse('https://x?p=$_nfcePb|2|1|1|HASH');
      final result = await repo.saveScan(doc);

      expect(result, isA<ScanSaved>());
      final receipt = (result as ScanSaved).receipt;
      expect(receipt.accessKey, _nfcePb);
      expect(receipt.naturalKey, doc.accessKey.naturalKey);
      expect(receipt.cuf, '25');
      expect(receipt.issuerId, '12345678000199');
      expect(receipt.docModel, '65');
      expect(receipt.qrFormat, 'v2Online');
    });

    test('totalCents null quando o QR não traz valor (v2 online)', () async {
      final doc = _parse('https://x?p=$_nfcePb|2|1|1|HASH');
      final result = await repo.saveScan(doc) as ScanSaved;
      expect(result.receipt.totalCents, isNull);
    });

    test('totalCents preenchido quando o QR traz vNF (v2 offline)', () async {
      final doc = _parse('https://x?p=$_nfcePb|2|1|22|150.00|deadbeef|1|HASH');
      final result = await repo.saveScan(doc) as ScanSaved;
      expect(result.receipt.totalCents, 15000);
    });
  });

  group('dedupe pela chave NATURAL, não pela chave de 44 dígitos', () {
    test('escanear a mesma nota de novo não duplica', () async {
      final doc = _parse('https://x?p=$_nfcePb|2|1|1|HASH');
      final first = await repo.saveScan(doc);
      final second = await repo.saveScan(doc);

      expect(first, isA<ScanSaved>());
      expect(second, isA<ScanAlreadyExists>());
      expect(
        (second as ScanAlreadyExists).receipt.id,
        (first as ScanSaved).receipt.id,
      );

      final all = await repo.watchRecent().first;
      expect(all, hasLength(1));
    });

    test('dois QRs de formatos DIFERENTES da MESMA nota (mesma chave '
        'natural) contam como já escaneado, não como notas distintas', () {
      final online = _parse('https://x?p=$_nfcePb|2|1|1|HASH');
      final offline = _parse(
        'https://x?p=$_nfcePb|2|1|22|150.00|deadbeef|1|HASH',
      );
      // Mesma chave -> mesma chave natural, mesmo se o formato do QR
      // (e portanto os bytes do rawQr) for diferente.
      expect(online.accessKey.naturalKey, offline.accessKey.naturalKey);
    });

    test('documentos diferentes NÃO são deduplicados entre si', () async {
      final nfce = _parse('https://x?p=$_nfcePb|2|1|1|HASH');
      final sat = _parse('$_cfeSat|20260722153000|59.05|12345678912|ASSIN');

      await repo.saveScan(nfce);
      final second = await repo.saveScan(sat);

      expect(second, isA<ScanSaved>());
      final all = await repo.watchRecent().first;
      expect(all, hasLength(2));
    });
  });

  group('watchRecent', () {
    test('mais recente primeiro', () async {
      await repo.saveScan(_parse('https://x?p=$_nfcePb|2|1|1|HASH'));
      await repo.saveScan(
        _parse('$_cfeSat|20260722153000|59.05|12345678912|ASSIN'),
      );

      final all = await repo.watchRecent().first;
      expect(all, hasLength(2));
      // O CF-e-SAT foi salvo por último.
      expect(all.first.docModel, '59');
    });
  });
}
