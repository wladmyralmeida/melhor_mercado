enum GtinError { wrongLength, invalidCheckDigit }

sealed class GtinResult {
  const GtinResult();
}

final class GtinOk extends GtinResult {
  const GtinOk(this.gtin);
  final Gtin gtin;
}

final class GtinInvalid extends GtinResult {
  const GtinInvalid(this.error);
  final GtinError error;
}

/// GTIN (código de barras de produto) validado e normalizado.
///
/// Sempre guardado na forma CANÔNICA de 14 dígitos (zero-preenchida à
/// esquerda), para que GTIN-8/12/13/14 do mesmo produto sejam
/// comparáveis como a mesma chave.
class Gtin {
  const Gtin._(this.canonical14);

  /// Sempre 14 dígitos.
  final String canonical14;

  static int _checkDigit(String body) {
    var sum = 0;
    var weight = 3;
    for (var i = body.length - 1; i >= 0; i--) {
      sum += (body.codeUnitAt(i) - 0x30) * weight;
      weight = weight == 3 ? 1 : 3;
    }
    return (10 - (sum % 10)) % 10;
  }

  /// Valida o dígito verificador (módulo 10, pesos alternados 3/1 da
  /// direita para a esquerda) e normaliza para 14 dígitos. Aceita
  /// GTIN-8, GTIN-12, GTIN-13 e GTIN-14.
  static GtinResult parse(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (![8, 12, 13, 14].contains(digits.length)) {
      return const GtinInvalid(GtinError.wrongLength);
    }
    final body = digits.substring(0, digits.length - 1);
    final actual = digits.codeUnitAt(digits.length - 1) - 0x30;
    if (_checkDigit(body) != actual) {
      return const GtinInvalid(GtinError.invalidCheckDigit);
    }
    return GtinOk(Gtin._(digits.padLeft(14, '0')));
  }

  /// RCN (Restricted Circulation Number) — código interno de
  /// loja/balança, não um identificador global de produto. Colide
  /// entre redes: o MESMO código pode significar produtos diferentes
  /// em supermercados diferentes.
  ///
  /// Testado SEMPRE sobre a forma canônica de 14 dígitos: um GTIN-13
  /// '2001234500008' vira '02001234500008' depois do zero-padding, e
  /// testar `g[0]=='2'` diretamente erraria o caso mais comum de RCN.
  bool get isRcn {
    final g = canonical14;
    return g[0] == '9' || // GTIN-14, indicador de medida variável
        g[1] == '2' || // GTIN-13 de prefixo restrito 200-299
        const ['000', '002', '004'].contains(g.substring(0, 3));
  }

  @override
  String toString() => 'Gtin($canonical14)';

  @override
  bool operator ==(Object other) =>
      other is Gtin && other.canonical14 == canonical14;

  @override
  int get hashCode => canonical14.hashCode;
}
