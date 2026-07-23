import 'package:mm_fiscal/mm_fiscal.dart';
import 'package:test/test.dart';

void main() {
  group('Gtin.parse — dígito verificador', () {
    test('exemplo oficial GS1 (GTIN-12): 614141000036', () {
      final result = Gtin.parse('614141000036');
      expect(result, isA<GtinOk>());
      final gtin = (result as GtinOk).gtin;
      expect(gtin.canonical14, '00614141000036');
    });

    test('rejeita dígito verificador incorreto', () {
      expect(
        Gtin.parse('614141000037'),
        equals(const GtinInvalid(GtinError.invalidCheckDigit)),
      );
    });

    test('rejeita comprimento fora de {8, 12, 13, 14}', () {
      expect(
        Gtin.parse('12345'),
        equals(const GtinInvalid(GtinError.wrongLength)),
      );
    });

    test('normaliza GTIN-13 para 14 dígitos com zero à esquerda', () {
      final gtin = (Gtin.parse('7891234567895') as GtinOk).gtin;
      expect(gtin.canonical14, '07891234567895');
    });
  });

  group('Gtin.isRcn — SEMPRE sobre a forma canônica de 14 dígitos', () {
    test('GTIN-13 de prefixo restrito 200-299 é RCN', () {
      final gtin = (Gtin.parse('2001234500005') as GtinOk).gtin;
      // Depois do padding: '02001234500005' — testar g[0]=='2' aqui
      // erraria; a regra certa mira g[1] na forma canônica.
      expect(gtin.canonical14, '02001234500005');
      expect(gtin.isRcn, isTrue);
    });

    test('GTIN-13 de prefixo comercial normal (789, Brasil) não é RCN', () {
      final gtin = (Gtin.parse('7891234567895') as GtinOk).gtin;
      expect(gtin.isRcn, isFalse);
    });

    test('GTIN-8 iniciado em 0 é RCN-8', () {
      final gtin = (Gtin.parse('01234565') as GtinOk).gtin;
      expect(gtin.isRcn, isTrue);
    });

    test('GTIN-14 com indicador 9 (medida variável) é RCN', () {
      final gtin = (Gtin.parse('90012345678908') as GtinOk).gtin;
      expect(gtin.isRcn, isTrue);
    });

    test('GTIN-14 com indicador comum (1-8) não é RCN por si só', () {
      // Mesmo corpo do caso Brasil acima, com indicador '1' (agrupamento
      // fixo) em vez de medida variável.
      final gtin = (Gtin.parse('17891234567892') as GtinOk).gtin;
      expect(gtin.canonical14[0], '1');
      expect(gtin.isRcn, isFalse);
    });
  });

  group('igualdade', () {
    test('dois Gtin com o mesmo canonical14 são iguais', () {
      final a = (Gtin.parse('614141000036') as GtinOk).gtin;
      final b = (Gtin.parse('00614141000036') as GtinOk).gtin;
      expect(a, equals(b));
    });
  });
}
