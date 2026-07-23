import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:melhor_mercado/core/format/brl.dart';
import 'package:melhor_mercado/core/format/cnpj.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/scan/data/receipts_repository.dart';
import 'package:melhor_mercado/features/scan/presentation/format_fiscal.dart';
import 'package:melhor_mercado/features/scan/state/scan_providers.dart';
import 'package:mm_fiscal/mm_fiscal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Escaneia o QR do cupom fiscal e identifica o documento — chave, UF,
/// CNPJ do emitente e, quando o QR traz, o valor total.
///
/// O QR NÃO contém os itens da compra (nenhuma versão de NFC-e nem o
/// CF-e-SAT carregam isso). Buscar os itens exige uma integração paga
/// que este app ainda não tem — a tela é honesta sobre isso e oferece
/// o caminho manual (adicionar à lista).
///
/// Retorna `true` via `Navigator.pop` quando o usuário escolhe
/// "Adicionar o que comprei" (sinal para a Home abrir a folha de
/// adicionar item); `false`/`null` nos demais casos.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

sealed class _ScanUiState {
  const _ScanUiState();
}

class _Scanning extends _ScanUiState {
  const _Scanning();
}

class _Saving extends _ScanUiState {
  const _Saving();
}

class _Recognized extends _ScanUiState {
  const _Recognized(this.doc, this.result);
  final RecognizedFiscalDocument doc;
  final ScanSaveResult result;
}

class _NotRecognized extends _ScanUiState {
  const _NotRecognized(this.reason);
  final FiscalQrParseError reason;
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  _ScanUiState _state = const _Scanning();

  /// Trava contra detecções repetidas entre o primeiro `onDetect` e o
  /// `stop()` do controller (o mesmo frame pode disparar mais de uma
  /// vez antes da câmera realmente parar).
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Controller explícito (não o default do widget): precisamos de
    // start()/stop() imperativos ao detectar um QR. Isso desliga o
    // `useAppLifecycleState` automático do MobileScanner — por isso
    // observamos o ciclo de vida nós mesmos, abaixo.
    //
    // `autoStart: false` é obrigatório aqui: por padrão o WIDGET
    // `MobileScanner` já chama `controller.start()` sozinho assim que
    // monta (mobile_scanner.dart:208-209). Sem desligar isso, essa
    // chamada automática corria com a nossa logo abaixo e uma das duas
    // lançava `MobileScannerException(controllerInitializing)` — achado
    // em aparelho real, não hipotético.
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoStart: false,
    );
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_detected) unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_detected) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    _detected = true;
    await _controller.stop();

    switch (parseFiscalQr(raw)) {
      case RecognizedFiscalDocument doc:
        if (!mounted) return;
        setState(() => _state = const _Saving());
        final result = await ref.read(receiptsRepositoryProvider).saveScan(doc);
        if (!mounted) return;
        setState(() => _state = _Recognized(doc, result));
      case UnrecognizedFiscalQr(:final reason):
        if (!mounted) return;
        setState(() => _state = _NotRecognized(reason));
    }
  }

  void _retry() {
    setState(() {
      _detected = false;
      _state = const _Scanning();
    });
    unawaited(_controller.start());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear cupom fiscal')),
      body: switch (_state) {
        _Scanning() => _CameraView(
          controller: _controller,
          onDetect: _onDetect,
        ),
        _Saving() => _CameraView(
          controller: _controller,
          onDetect: _onDetect,
          saving: true,
        ),
        _Recognized(:final doc, :final result) => _RecognizedView(
          doc: doc,
          result: result,
        ),
        _NotRecognized(:final reason) => _NotRecognizedView(
          reason: reason,
          onRetry: _retry,
        ),
      },
    );
  }
}

// ---- Câmera ---------------------------------------------------------------

class _CameraView extends StatelessWidget {
  const _CameraView({
    required this.controller,
    required this.onDetect,
    this.saving = false,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
          errorBuilder: (context, error) => _CameraErrorView(error: error),
        ),
        const _ScanFrameOverlay(),
        if (saving)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text('Identificando…', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          const Expanded(child: Center(child: _FrameBox())),
          Padding(
            padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
            child: Text(
              'Aponte para o QR Code do cupom fiscal',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameBox extends StatelessWidget {
  const _FrameBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 56,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                isPermission
                    ? 'Precisamos da câmera para ler o QR Code'
                    : 'Não foi possível abrir a câmera',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPermission
                    ? 'Permita o acesso à câmera nas configurações do '
                          'aparelho para escanear cupons fiscais.'
                    : error.errorCode.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Resultado --------------------------------------------------------------

class _RecognizedView extends StatelessWidget {
  const _RecognizedView({required this.doc, required this.result});

  final RecognizedFiscalDocument doc;
  final ScanSaveResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = doc.accessKey;
    final alreadyExisted = result is ScanAlreadyExists;
    final receipt = switch (result) {
      ScanSaved(:final receipt) => receipt,
      ScanAlreadyExists(:final receipt) => receipt,
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              alreadyExisted ? Icons.history : Icons.check_circle,
              color: alreadyExisted ? AppColors.tintaSuave : AppColors.precoBom,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              alreadyExisted
                  ? 'Você já tinha escaneado esta nota'
                  : 'Nota identificada',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'Documento',
                      value: fiscalDocModelLabel(key.model),
                    ),
                    _InfoRow(
                      label: 'CNPJ do estabelecimento',
                      value: formatCnpj(key.issuerId),
                    ),
                    if (key.ufAbbreviation case final uf?)
                      _InfoRow(label: 'UF', value: uf),
                    if (doc.totalCents case final cents?)
                      _InfoRow(label: 'Valor total', value: formatCents(cents)),
                    _InfoRow(
                      label: 'Escaneado em',
                      value: _formatDateTime(receipt.scannedAt),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Ainda não conseguimos buscar os itens desta nota '
                'automaticamente. Você pode adicionar o que comprou na '
                'sua lista.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar o que comprei'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar à lista'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dt);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.tintaSuave,
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotRecognizedView extends StatelessWidget {
  const _NotRecognizedView({required this.reason, required this.onRetry});

  final FiscalQrParseError reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (reason) {
      FiscalQrParseError.notFiscalDocument =>
        'Isso não parece ser o QR Code de um cupom fiscal '
            '(NFC-e, NF-e ou CF-e-SAT).',
      FiscalQrParseError.invalidAccessKey =>
        'Encontramos uma chave de acesso, mas ela não é válida. Tente '
            'escanear de novo com mais luz e menos distância.',
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(
              Icons.qr_code_scanner,
              size: 56,
              color: AppColors.tintaSuave,
            ),
            const SizedBox(height: 16),
            Text(
              'Não conseguimos reconhecer este QR Code',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
