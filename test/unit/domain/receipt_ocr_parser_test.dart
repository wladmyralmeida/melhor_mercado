import 'package:flutter_test/flutter_test.dart';
import 'package:melhor_mercado/features/scan/domain/receipt_ocr_parser.dart';

// Os textos abaixo seguem os padrões de layout DE DANFE NFC-e
// documentados (código/descrição/qtde/un/vl.unit/vl.total, decimal por
// vírgula) — NÃO são transcrição de um cupom real. A acurácia real
// contra fotos verdadeiras de cupons da Paraíba ainda não foi medida;
// isso é o que os testes abaixo NÃO provam.
void main() {
  group('linha completa (descrição + qty + unidade + preços)', () {
    test('qty inteira, unitário e total presentes, reconciliando', () {
      final items = parseReceiptText('CAFE PILAO TRAD 500G 1 UN 8,99 8,99');
      expect(items, hasLength(1));
      final item = items.single;
      expect(item.name, 'CAFE PILAO TRAD 500G');
      expect(item.quantity, 1);
      expect(item.unit, 'UN');
      expect(item.unitPriceCents, 899);
      expect(item.totalPriceCents, 899);
      expect(item.confidence, greaterThanOrEqualTo(0.9));
    });

    test('"500G" no nome não é confundido com a coluna de quantidade', () {
      final items = parseReceiptText(
        'ARROZ TIO JOAO TIPO 1 5KG 2 UN 25,90 51,80',
      );
      expect(items, hasLength(1));
      expect(items.single.name, 'ARROZ TIO JOAO TIPO 1 5KG');
      expect(items.single.quantity, 2);
    });

    test('quantidade fracionária (peso) com vírgula', () {
      final items = parseReceiptText('TOMATE SALADA KG 0,732 KG 6,99 5,12');
      expect(items, hasLength(1));
      expect(items.single.quantity, 0.732);
    });

    test('conector "x" entre unidade e preço unitário', () {
      final items = parseReceiptText('IOGURTE NATURAL 170G 3 UN X 2,50 7,50');
      expect(items, hasLength(1));
      expect(items.single.unitPriceCents, 250);
      expect(items.single.totalPriceCents, 750);
    });

    test('aritmética que NÃO reconcilia gera confiança baixa, '
        'mas o valor bruto é preservado (nunca ajustado)', () {
      final items = parseReceiptText('LEITE INTEGRAL 1L 2 UN 4,50 10,00');
      expect(items, hasLength(1));
      final item = items.single;
      expect(item.unitPriceCents, 450);
      expect(item.totalPriceCents, 1000); // preservado, não "corrigido"
      expect(item.confidence, lessThan(0.5));
    });

    test('qty > 1 com só o total (sem coluna de unitário separada) '
        'deixa unitPriceCents nulo — quem deriva é a tela, não o parser', () {
      final items = parseReceiptText('ARROZ 2KG 6,00');
      expect(items, hasLength(1));
      final item = items.single;
      expect(item.quantity, 2);
      expect(item.unitPriceCents, isNull);
      expect(item.totalPriceCents, 600);
    });
  });

  group('só descrição + um preço (quantidade 1 implícita)', () {
    test('sem coluna de quantidade nem unidade', () {
      final items = parseReceiptText('PAO FRANCES 8,99');
      expect(items, hasLength(1));
      expect(items.single.quantity, 1);
      expect(items.single.totalPriceCents, 899);
    });
  });

  group('linha órfã (descrição e valores em linhas separadas)', () {
    test('cupom estreito: descrição numa linha, qty/preço na próxima', () {
      final items = parseReceiptText(
        'CAFE PILAO TRADICIONAL 500G\n1UN X 8,99 = 8,99',
      );
      expect(items, hasLength(1));
      final item = items.single;
      expect(item.name, 'CAFE PILAO TRADICIONAL 500G');
      expect(item.quantity, 1);
      expect(item.totalPriceCents, 899);
    });

    test('duas notas seguidas no formato órfão', () {
      final items = parseReceiptText(
        'CAFE PILAO 500G\n1UN X 8,99 = 8,99\n'
        'ACHOCOLATADO NESCAU 400G\n2UN X 6,50 = 13,00',
      );
      expect(items, hasLength(2));
      expect(items[0].name, 'CAFE PILAO 500G');
      expect(items[1].name, 'ACHOCOLATADO NESCAU 400G');
      expect(items[1].totalPriceCents, 1300);
    });
  });

  group('ruído de cabeçalho/rodapé — nunca vira item', () {
    test('linhas de CNPJ, total, forma de pagamento são ignoradas', () {
      final items = parseReceiptText(
        'SUPERMERCADO EXEMPLO LTDA\n'
        'CNPJ: 12.345.678/0001-99\n'
        'CAFE PILAO TRAD 500G 1 UN 8,99 8,99\n'
        'VALOR TOTAL R\$ 8,99\n'
        'FORMA DE PAGAMENTO: DINHEIRO\n'
        'CONSULTE PELA CHAVE DE ACESSO EM...\n',
      );
      expect(items, hasLength(1));
      expect(items.single.name, 'CAFE PILAO TRAD 500G');
    });
  });

  group('robustez contra texto vazio/lixo', () {
    test('texto vazio não lança e devolve lista vazia', () {
      expect(parseReceiptText(''), isEmpty);
    });

    test('texto sem nenhum padrão reconhecível devolve lista vazia', () {
      expect(parseReceiptText('blablabla sem nenhum numero'), isEmpty);
    });

    test('preço com formato quebrado (3+ decimais) não gera item falso', () {
      final items = parseReceiptText('ITEM ESTRANHO 1 UN 8,999');
      expect(items, isEmpty);
    });
  });

  group('OCR mais fiel a um recorte real (várias linhas de uma vez)', () {
    test('cupom com múltiplos itens em formatos mistos', () {
      final raw =
          'MERCADO BOM PRECO LTDA\n'
          'CNPJ 11.222.333/0001-44\n'
          'CAFE PILAO TRAD 500G 1 UN 8,99 8,99\n'
          'ARROZ TIO JOAO 5KG 1 UN 24,90 24,90\n'
          'FEIJAO CARIOCA 1KG\n'
          '2UN X 7,50 = 15,00\n'
          'PAO FRANCES 6,50\n'
          'QTDE. TOTAL DE ITENS 4\n'
          'VALOR TOTAL R\$ 55,39\n';
      final items = parseReceiptText(raw);

      expect(items, hasLength(4));
      expect(items.map((i) => i.name), [
        'CAFE PILAO TRAD 500G',
        'ARROZ TIO JOAO 5KG',
        'FEIJAO CARIOCA 1KG',
        'PAO FRANCES',
      ]);
      expect(items.map((i) => i.totalPriceCents), [899, 2490, 1500, 650]);
    });
  });
}
