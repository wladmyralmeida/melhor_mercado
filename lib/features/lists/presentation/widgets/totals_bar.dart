import 'package:flutter/material.dart';
import 'package:melhor_mercado/core/format/brl.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';
import 'package:melhor_mercado/features/lists/data/lists_repository.dart';

/// Barra de totais no rodapé.
///
/// Honestidade embutida: o total diz de quantos itens veio o número
/// ("3 de 8 itens com preço") — nunca finge que item sem preço custa zero.
class TotalsBar extends StatelessWidget {
  const TotalsBar({super.key, required this.totals});

  final ListTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!totals.hasAnyPrice) return const SizedBox.shrink();

    final coverage = totals.itemsWithPrice == totals.totalItems
        ? 'todos os itens'
        : '${totals.itemsWithPrice} de ${totals.totalItems} itens com preço';

    return Material(
      color: AppColors.cardBg,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borda)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total estimado · $coverage',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.tintaSuave,
                      ),
                    ),
                    Text(
                      formatCents(totals.estimatedTotalCents),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFeatures: priceFontFeatures,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (totals.inCartCents > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No carrinho',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.tintaSuave,
                      ),
                    ),
                    Text(
                      formatCents(totals.inCartCents),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: priceFontFeatures,
                        fontWeight: FontWeight.w700,
                        color: AppColors.precoBom,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
