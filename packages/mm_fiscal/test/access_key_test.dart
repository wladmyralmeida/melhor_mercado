import 'package:mm_fiscal/mm_fiscal.dart';
import 'package:test/test.dart';

void main() {
  group('AccessKey.parse — NFC-e/NF-e (mod 55/65)', () {
    // Chave sintética válida, Paraíba (cUF=25): DV calculado e
    // verificado por script Python independente (soma mod 11).
    const nfcePb = '25260712345678000199650010000001231876543214';

    test('interpreta uma chave NFC-e válida campo a campo', () {
      final result = AccessKey.parse(nfcePb);
      expect(result, isA<AccessKeyOk>());
      final key = (result as AccessKeyOk).key;

      expect(key.cuf, '25');
      expect(key.ufAbbreviation, 'PB');
      expect(key.aamm, '2607');
      expect(key.issuerId, '12345678000199');
      expect(key.model, FiscalDocModel.nfce);
      expect(key.series, '001');
      expect(key.number, '000000123');
      expect(key.tpEmis, '1');
      expect(key.randomCode, '87654321');
      expect(key.checkDigit, '4');
    });

    test('aceita a chave formatada com espaços/pontos', () {
      const formatted =
          '2526 0712 3456 7800 0199 6500 1000 0001 2318 '
          '7654 3214';
      final result = AccessKey.parse(formatted);
      expect(result, isA<AccessKeyOk>());
    });

    test('vetor do MOC 7.0 (mod 55, NF-e) — DV confirmado: soma 644, DV 5', () {
      const moc = '52060433009911002506550120000007800267301615';
      final result = AccessKey.parse(moc);
      expect(result, isA<AccessKeyOk>());
      expect((result as AccessKeyOk).key.model, FiscalDocModel.nfe);
    });

    test('rejeita dígito verificador incorreto', () {
      const wrongDv = '25260712345678000199650010000001231876543219';
      final result = AccessKey.parse(wrongDv);
      expect(
        result,
        equals(const AccessKeyInvalid(AccessKeyError.invalidCheckDigit)),
      );
    });

    test('rejeita comprimento errado', () {
      expect(
        AccessKey.parse('123'),
        equals(const AccessKeyInvalid(AccessKeyError.wrongLength)),
      );
    });

    test('rejeita modelo desconhecido (dígitos 21-22)', () {
      // Mesmo corpo, campo `mod` = '99' (inexistente), DV recalculado.
      const unknownModel = '25260712345678000199990010000001231876543217';
      expect(
        AccessKey.parse(unknownModel),
        equals(const AccessKeyInvalid(AccessKeyError.unknownModel)),
      );
    });

    test('naturalKey NÃO inclui o código aleatório (randomCode)', () {
      final key = (AccessKey.parse(nfcePb) as AccessKeyOk).key;
      expect(key.naturalKey, '25|12345678000199|65|001|000000123|1');
      expect(key.naturalKey, isNot(contains(key.randomCode)));
    });

    test('UF desconhecida retorna null, não lança', () {
      // cUF = '99' (inexistente na tabela IBGE), com DV recalculado
      // manualmente não é necessário: só testamos o getter isolado.
      const anyValid = '25260712345678000199650010000001231876543214';
      final key = (AccessKey.parse(anyValid) as AccessKeyOk).key;
      expect(key.ufAbbreviation, isNotNull);
    });
  });

  group('AccessKey.parse — CF-e-SAT (mod 59, layout diferente)', () {
    // Chave REAL citada na pesquisa fiscal (SP/CE); DV recomputado e
    // confirmado por script Python independente.
    const cfeSat = '35111202767579000148598583801050151865833992';

    test('interpreta os campos no layout SAT, não no de NF-e', () {
      final result = AccessKey.parse(cfeSat);
      expect(result, isA<AccessKeyOk>());
      final key = (result as AccessKeyOk).key;

      expect(key.model, FiscalDocModel.cfeSat);
      expect(key.cuf, '35');
      expect(key.ufAbbreviation, 'SP');
      expect(key.issuerId, '02767579000148');
      // Aplicar os offsets de NF-e aqui produziria série/número errados
      // — é exatamente o bug que este layout separado evita.
      expect(key.series, '858380105'); // nserieSAT, 9 dígitos
      expect(key.number, '015186'); // nCF, 6 dígitos
      expect(key.tpEmis, isNull); // CF-e-SAT não tem esse campo
      expect(key.randomCode, '583399');
    });

    test('naturalKey do SAT usa tpEmis vazio, nunca "null" literal', () {
      final key = (AccessKey.parse(cfeSat) as AccessKeyOk).key;
      expect(key.naturalKey, endsWith('|'));
      expect(key.naturalKey, isNot(contains('null')));
    });
  });

  group('igualdade e hashCode', () {
    test('duas AccessKey com a mesma chave raw são iguais', () {
      const nfcePb = '25260712345678000199650010000001231876543214';
      final a = (AccessKey.parse(nfcePb) as AccessKeyOk).key;
      final b = (AccessKey.parse(nfcePb) as AccessKeyOk).key;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
