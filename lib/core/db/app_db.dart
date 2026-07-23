import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_db.g.dart';

/// Listas de compras. O objeto de uso diário do produto.
class ShoppingLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Itens da lista. `name` é texto livre: a lista funciona antes de qualquer
/// catálogo ou scan (princípio: útil no minuto 1).
class ShoppingListItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId =>
      integer().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Quantidade pode ser fracionária (0,5 kg).
  RealColumn get quantity => real().withDefault(const Constant(1))();

  /// Unidade livre e curta: 'un', 'kg', 'g', 'L', 'ml', 'pct', 'cx'…
  TextColumn get unit => text().nullable()();

  /// Dinheiro SEMPRE em centavos inteiros — nunca float.
  IntColumn get estimatedPriceCents => integer().nullable()();

  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cupons fiscais escaneados (identidade, não itens).
///
/// O QR só entrega chave, UF, CNPJ do emitente e — em contingência
/// offline — o valor total. Itens exigem foto do cupom, XML, ou uma
/// integração paga que ainda não existe (Fase 3). Este pacote existe
/// para: (a) nunca escanear a mesma nota duas vezes, (b) guardar a
/// identidade para quando a busca de itens for ligada.
class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Chave de 44 dígitos, só para exibição/depuração.
  TextColumn get accessKey => text().withLength(min: 44, max: 44)();

  /// Chave NATURAL de dedupe (uf|cnpj|modelo|serie|numero|tpEmis) — não
  /// a chave de 44 dígitos inteira, que carrega um código aleatório
  /// frágil para casar o mesmo documento vindo de origens diferentes.
  TextColumn get naturalKey => text().unique()();

  TextColumn get cuf => text().withLength(min: 2, max: 2)();
  TextColumn get issuerId => text().withLength(min: 14, max: 14)();

  /// '55' NF-e | '59' CF-e-SAT | '65' NFC-e.
  TextColumn get docModel => text().withLength(min: 2, max: 2)();

  /// Só preenchido quando o próprio QR traz o total (contingência
  /// offline, v1 legado, ou CF-e-SAT) — nunca inventado.
  IntColumn get totalCents => integer().nullable()();

  /// Formato do QR reconhecido (v1Legacy|v2Online|v2Offline|v3Online|
  /// v3Offline|cfeSat|unknown), guardado como texto livre por
  /// simplicidade — não é FK para outra tabela.
  TextColumn get qrFormat => text()();

  TextColumn get rawQr => text()();
  DateTimeColumn get scannedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [ShoppingLists, ShoppingListItems, Receipts])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  /// Para testes: injete um executor em memória
  /// (`NativeDatabase.memory()`).
  AppDb.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(receipts);
    },
    beforeOpen: (details) async {
      // Necessário para o ON DELETE CASCADE dos itens.
      await customStatement('PRAGMA foreign_keys = ON');

      // Semente: o app abre já com uma lista — zero fricção no dia 1.
      final any = await (select(shoppingLists)..limit(1)).get();
      if (any.isEmpty) {
        await into(
          shoppingLists,
        ).insert(ShoppingListsCompanion.insert(name: 'Minhas compras'));
      }
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(
    name: 'melhor_mercado',
    native: const DriftNativeOptions(
      // Fora de Documents: não aparece em backups/file pickers.
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
