import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// `flutter test` roda esta função automaticamente antes de QUALQUER
/// teste em test/ e subpastas (convenção reconhecida pelo test runner,
/// sem precisar de import em cada arquivo).
///
/// Sem isso, qualquer widget que use `DateFormat(..., 'pt_BR')` lança
/// `LocaleDataException` em teste — o app normal só funciona porque
/// `main.dart` chama `initializeDateFormatting` antes do `runApp`, e
/// testes pulam o `main()`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('pt_BR');
  await testMain();
}
