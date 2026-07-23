import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:melhor_mercado/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura global: nenhum erro morre em silêncio. Nesta fase é log
  // local; um reporter (Sentry etc.) pluga aqui depois, se entrar.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Erro não tratado: $error\n$stack');
    return true;
  };

  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  runApp(const ProviderScope(child: App()));
}
