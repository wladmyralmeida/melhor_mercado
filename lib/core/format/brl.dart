import 'package:intl/intl.dart';

/// Formatação e parsing de dinheiro em pt-BR.
///
/// Regra do projeto: dinheiro vive como CENTAVOS INTEIROS em todo o app.
/// `double` nunca representa um valor monetário armazenado — apenas o
/// trânsito de parsing controlado aqui dentro.
final NumberFormat _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// 1234 -> "R$ 12,34"
String formatCents(int cents) => _brl.format(cents / 100);

/// "4,99" | "R$ 4,99" | "1.234,56" | "4.99" -> centavos.
///
/// Retorna null para entrada vazia ou inválida (nunca lança para input de
/// usuário). Valores negativos são inválidos.
///
/// Aritmética 100% em string/int — `double` NUNCA entra no caminho do
/// dinheiro ("1,005" via float daria 100.4999… e arredondaria errado).
int? parseBrlToCents(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll('R\$', '').replaceAll(' ', '');
  if (s.isEmpty) return null;

  final hasComma = s.contains(',');
  if (hasComma) {
    // Convenção brasileira: ponto = milhar, vírgula = decimal.
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    // Sem vírgula, ponto é ambíguo. Regra: 1-2 dígitos após o único
    // ponto = decimal ("4.99", teclado numérico); exatamente 3 = MILHAR
    // ("1.500" é mil e quinhentos, nunca R$ 1,50); mais de um ponto =
    // milhar. Qualquer outra coisa é inválida — corromper dinheiro em
    // silêncio é pior que pedir de novo.
    final dots = '.'.allMatches(s).length;
    if (dots > 1) {
      s = s.replaceAll('.', '');
    } else if (dots == 1) {
      final fracLen = s.length - s.indexOf('.') - 1;
      if (fracLen == 3) {
        s = s.replaceAll('.', '');
      } else if (fracLen > 3) {
        return null;
      }
    }
  }

  // Apenas dígitos com no máximo um ponto decimal.
  if (!RegExp(r'^\d+(\.\d*)?$').hasMatch(s)) return null;

  final parts = s.split('.');
  // Teto sane: acima de R$ 9.999.999 é erro de digitação, não preço.
  if (parts[0].length > 7) return null;

  var cents = int.parse(parts[0]) * 100;
  if (parts.length == 2 && parts[1].isNotEmpty) {
    final frac = parts[1];
    final d1 = frac.codeUnitAt(0) - 0x30;
    final d2 = frac.length > 1 ? frac.codeUnitAt(1) - 0x30 : 0;
    cents += d1 * 10 + d2;
    // Meio-para-cima pelo 3º dígito decimal ("1,005" -> 101).
    if (frac.length > 2 && frac.codeUnitAt(2) - 0x30 >= 5) cents += 1;
  }
  return cents;
}

/// Centavos -> texto editável de campo ("549" -> "5,49").
///
/// Sem símbolo e sem milhar (é para dentro de um TextField, não para
/// exibição) e 100% em aritmética de int — nada de dividir por 100.0.
String centsToEditableText(int cents) {
  final reais = cents ~/ 100;
  final resto = cents % 100;
  return '$reais,${resto.toString().padLeft(2, '0')}';
}

/// Quantidade: 1.0 -> "1"; 0.5 -> "0,5"; 1.25 -> "1,25".
String formatQty(double qty) {
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  var s = qty.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s.replaceAll('.', ',');
}

/// "0,5" | "0.5" | "2" -> double. Null para inválido/não-positivo.
double? parseQty(String input) {
  final s = input.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  final value = double.tryParse(s);
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return null;
  }
  return value;
}
