import 'package:drift/drift.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:mm_fiscal/mm_fiscal.dart';

/// Resultado de salvar um cupom escaneado.
sealed class ScanSaveResult {
  const ScanSaveResult();
}

/// Primeira vez que esta chave natural aparece.
final class ScanSaved extends ScanSaveResult {
  const ScanSaved(this.receipt);
  final Receipt receipt;
}

/// Mesma chave natural já tinha sido escaneada antes — nada foi
/// duplicado. O usuário vê o registro existente, não um erro.
final class ScanAlreadyExists extends ScanSaveResult {
  const ScanAlreadyExists(this.receipt);
  final Receipt receipt;
}

/// Persistência de cupons fiscais escaneados.
///
/// Guarda só IDENTIDADE (chave, UF, CNPJ, total quando disponível) —
/// itens exigem uma fonte que este app ainda não tem (Fase 3). Dedupe
/// é pela CHAVE NATURAL (uf|cnpj|modelo|série|número|tpEmis), não pela
/// chave de 44 dígitos inteira: o código aleatório dela é frágil para
/// casar o mesmo documento vindo de origens diferentes.
class ReceiptsRepository {
  ReceiptsRepository(this._db);

  final AppDb _db;

  Future<ScanSaveResult> saveScan(RecognizedFiscalDocument doc) async {
    final key = doc.accessKey;
    final existing = await (_db.select(
      _db.receipts,
    )..where((r) => r.naturalKey.equals(key.naturalKey))).getSingleOrNull();
    if (existing != null) return ScanAlreadyExists(existing);

    final id = await _db
        .into(_db.receipts)
        .insert(
          ReceiptsCompanion.insert(
            accessKey: key.raw,
            naturalKey: key.naturalKey,
            cuf: key.cuf,
            issuerId: key.issuerId,
            docModel: key.model.code,
            totalCents: Value(doc.totalCents),
            qrFormat: doc.format.name,
            rawQr: doc.rawQr,
          ),
        );
    final saved = await (_db.select(
      _db.receipts,
    )..where((r) => r.id.equals(id))).getSingle();
    return ScanSaved(saved);
  }

  Stream<List<Receipt>> watchRecent({int limit = 20}) =>
      (_db.select(_db.receipts)
            // `id DESC` como desempate: dois cupons escaneados no
            // mesmo segundo empatam em `scannedAt`, e sem uma segunda
            // chave de ordenação o SQLite não garante qual vem
            // primeiro.
            ..orderBy([
              (r) => OrderingTerm.desc(r.scannedAt),
              (r) => OrderingTerm.desc(r.id),
            ])
            ..limit(limit))
          .watch();
}
