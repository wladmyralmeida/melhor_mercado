import 'package:flutter_test/flutter_test.dart';
import 'package:melhor_mercado/core/format/brl.dart';

void main() {
  group('parseBrlToCents', () {
    test('aceita vírgula decimal brasileira', () {
      expect(parseBrlToCents('4,99'), 499);
      expect(parseBrlToCents('0,50'), 50);
      expect(parseBrlToCents('12,3'), 1230);
    });

    test('aceita símbolo e espaços', () {
      expect(parseBrlToCents(r'R$ 4,99'), 499);
      expect(parseBrlToCents(r'  R$12,00 '), 1200);
    });

    test('aceita milhar com ponto e decimal com vírgula', () {
      expect(parseBrlToCents('1.234,56'), 123456);
    });

    test('aceita ponto decimal único (teclado numérico)', () {
      expect(parseBrlToCents('4.99'), 499);
      expect(parseBrlToCents('12.5'), 1250);
    });

    test('ponto com 3 dígitos é MILHAR, nunca decimal — '
        '"1.500" jamais vira R\$ 1,50', () {
      expect(parseBrlToCents('1.500'), 150000);
      expect(parseBrlToCents('4.999'), 499900);
    });

    test('ponto com mais de 3 dígitos é inválido (ambíguo demais)', () {
      expect(parseBrlToCents('1.5000'), isNull);
    });

    test('inteiro sem decimal', () {
      expect(parseBrlToCents('5'), 500);
    });

    test('retorna null para vazio e inválido — nunca lança', () {
      expect(parseBrlToCents(''), isNull);
      expect(parseBrlToCents('   '), isNull);
      expect(parseBrlToCents('abc'), isNull);
      expect(parseBrlToCents('-1'), isNull);
      expect(parseBrlToCents('inf'), isNull);
      expect(parseBrlToCents('nan'), isNull);
    });

    test('não sofre erro de float binário no meio centavo', () {
      // float('1.005')*100 = 100.49999... — round() resolve.
      expect(parseBrlToCents('1,005'), 101);
    });
  });

  group('formatCents', () {
    test('formata em pt-BR', () {
      expect(formatCents(499), contains('4,99'));
      expect(formatCents(123456), contains('1.234,56'));
      expect(formatCents(0), contains('0,00'));
    });
  });

  group('centsToEditableText', () {
    test('para campo de edição: vírgula, sem símbolo, sem milhar', () {
      expect(centsToEditableText(549), '5,49');
      expect(centsToEditableText(100000), '1000,00');
      expect(centsToEditableText(5), '0,05');
    });

    test('ida e volta com o parser', () {
      for (final cents in [1, 99, 100, 549, 2599, 100000]) {
        expect(parseBrlToCents(centsToEditableText(cents)), cents);
      }
    });
  });

  group('formatQty / parseQty', () {
    test('inteiros sem casa decimal', () {
      expect(formatQty(1), '1');
      expect(formatQty(12), '12');
    });

    test('fracionários com vírgula', () {
      expect(formatQty(0.5), '0,5');
      expect(formatQty(1.25), '1,25');
    });

    test('parse aceita vírgula e ponto', () {
      expect(parseQty('0,5'), 0.5);
      expect(parseQty('0.5'), 0.5);
      expect(parseQty('2'), 2);
    });

    test('parse rejeita inválido e não-positivo', () {
      expect(parseQty(''), isNull);
      expect(parseQty('0'), isNull);
      expect(parseQty('-1'), isNull);
      expect(parseQty('x'), isNull);
    });
  });
}
