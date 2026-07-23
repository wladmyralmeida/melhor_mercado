import 'package:flutter/material.dart';
import 'package:melhor_mercado/core/db/app_db.dart';
import 'package:melhor_mercado/core/format/brl.dart';
import 'package:melhor_mercado/core/theme/app_theme.dart';

/// Uma linha da lista: checkbox, nome, quantidade e preço (quando houver).
///
/// O preço usa numerais tabulares para a coluna de dinheiro alinhar.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onTap,
  });

  final ShoppingListItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checked = item.isChecked;

    final qtyLabel = _qtyLabel();
    final price = item.estimatedPriceCents;

    // MergeSemantics: o leitor de tela anuncia a linha inteira como um
    // nó só ("Arroz 5kg, caixa de seleção…") — sem isso o Checkbox é
    // anunciado solto, sem dizer de qual item ele é.
    return MergeSemantics(
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(
          value: checked,
          onChanged: (v) => onToggle(v ?? false),
        ),
        title: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: checked ? TextDecoration.lineThrough : null,
            color: checked ? AppColors.tintaSuave : AppColors.tinta,
          ),
        ),
        subtitle: qtyLabel == null
            ? null
            : Text(
                qtyLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.tintaSuave,
                ),
              ),
        trailing: price == null
            ? null
            : Text(
                formatCents((price * item.quantity).round()),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFeatures: priceFontFeatures,
                  fontWeight: FontWeight.w600,
                  color: checked ? AppColors.tintaSuave : AppColors.tinta,
                ),
              ),
      ),
    );
  }

  String? _qtyLabel() {
    final unit = item.unit;
    final qty = item.quantity;
    final isSingleUnit = qty == 1 && (unit == null || unit == 'un');
    if (isSingleUnit) return null;
    final qtyText = formatQty(qty);
    return unit == null ? qtyText : '$qtyText $unit';
  }
}
