import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/core/format/brl.dart';
import 'package:melhor_mercado/core/format/cnpj.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/scan/presentation/format_fiscal.dart';
import 'package:melhor_mercado/features/scan/state/scan_providers.dart';

/// Lista dos cupons já escaneados — identidade apenas (chave, UF, CNPJ,
/// valor quando o QR traz), nunca itens, porque o QR não os contém e o
/// app ainda não tem uma fonte para buscá-los (Fase 3).
class ReceiptsHistoryScreen extends ConsumerWidget {
  const ReceiptsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(recentReceiptsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cupons escaneados')),
      body: switch (receiptsAsync) {
        AsyncError(:final error) => _ErrorState(error: error),
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ReceiptCard(receipt: value[i]),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.tintaSuave,
            ),
            const SizedBox(height: 16),
            Text(
              'Você ainda não escaneou nenhum cupom',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque no ícone de câmera na sua lista para escanear o QR '
              'do próximo cupom fiscal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.tintaSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar seus cupons.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ModelBadge(code: receipt.docModel),
                const Spacer(),
                Text(
                  _formatDateTime(receipt.scannedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.tintaSuave,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatCnpj(receipt.issuerId),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (receipt.totalCents case final cents?) ...[
              const SizedBox(height: 4),
              Text(
                formatCents(cents),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: priceFontFeatures,
                  color: AppColors.precoBom,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dt);
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        fiscalDocModelLabelFromCode(code),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
