import 'package:flutter_test/flutter_test.dart';
import 'package:melhor_mercado/features/scan/domain/receipt_ocr_parser.dart';

// A maioria dos textos abaixo segue os padrões de layout DE DANFE
// NFC-e documentados (código/descrição/qtde/un/vl.unit/vl.total,
// decimal por vírgula), mas são inventados à mão — não provam nada
// sobre acurácia contra foto real. O último grupo ("cupom real") é
// exceção: transcrito de uma foto de cupom de verdade (Varejão do
// Preço, João Pessoa-PB) enviada pelo usuário, que revelou bugs reais
// que nenhum teste inventado tinha pego. Ainda é UMA rede/PDV só —
// outras redes podem imprimir diferente e continuam sem cobertura.
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

  group('cupom real (foto enviada pelo usuário — Varejão do Preço, JP-PB)', () {
    // Transcrito de uma foto real de cupom, não hipotético. Revelou dois
    // bugs que os testes sintéticos acima não cobriam: (1) esta rede
    // imprime "UNIDADE QUANTIDADE" em vez de "QUANTIDADE UNIDADE" (ex.
    // "330ML UN 1 X 6,79", não "330ML 1 UN X 6,79"); (2) cada linha
    // começa com número da linha + código de barras antes da descrição.
    const raw =
        'VAREJAO DO PRECO\n'
        'CNPJ: 11.352.290/0003-10 SUPERMERCADO VAREJAO DO PRECO LTDA\n'
        'R EUCLIDES FERREIRA DE CARVALHO, 31 JARDIM CIDADE UNIVERSITARIA\n'
        'JOAO PESSOA-PB 58052-236\n'
        'Fone:3206-0947 I.E.:16443404-6\n'
        'Documento Auxiliar da Nota Fiscal do Consumidor Eletronica\n'
        'EMITIDA EM CONTINGENCIA\n'
        'Pendente de autorizacao\n'
        '# Codigo Descricao Qtde Un. Valor unit. Valor total\n'
        '001 7891991299619 MICHELOB ULTRA N LONG NECK 330ML UN 1 X 6,79 6,79\n'
        '002 7898034920790 IOG ISIS FRUTAS VERMELHAS 900G UN 1 X 11,89 11,89\n'
        '009 3000000000500 PAO FRANCES 12H KG 0,360 X 13,99 5,04\n'
        '022 0000000000290 TOMATE KG 1,365 X 2,99 4,08\n';

    test('nome vem limpo: sem número de linha, código de barras nem '
        '"UN"/"X" soltos — o bug original que motivou este grupo', () {
      final items = parseReceiptText(raw);

      expect(items, hasLength(4));
      expect(items.map((i) => i.name), [
        'MICHELOB ULTRA N LONG NECK 330ML',
        'IOG ISIS FRUTAS VERMELHAS 900G',
        'PAO FRANCES 12H',
        'TOMATE',
      ]);
    });

    test('quantidade e preço por unidade batem certo mesmo com a unidade '
        'impressa antes da quantidade', () {
      final items = parseReceiptText(raw);

      final michelob = items[0];
      expect(michelob.quantity, 1);
      expect(michelob.unit, 'UN');
      expect(michelob.unitPriceCents, 679);
      expect(michelob.totalPriceCents, 679);

      final pao = items[2];
      expect(pao.quantity, 0.360);
      expect(pao.unit, 'KG');
      expect(pao.unitPriceCents, 1399);
      expect(pao.totalPriceCents, 504);

      final tomate = items[3];
      expect(tomate.quantity, 1.365);
      expect(tomate.unitPriceCents, 299);
      expect(tomate.totalPriceCents, 408);
    });

    test('cabeçalho da loja (nome/endereço/telefone) não vaza pro nome '
        'do primeiro item — cortado pela linha de cabeçalho da tabela', () {
      final items = parseReceiptText(raw);
      expect(items.first.name, isNot(contains('VAREJAO')));
      expect(items.first.name, isNot(contains('EUCLIDES')));
    });

    test('"KG" dentro do NOME (produto vendido por peso) não é confundido '
        'com a unidade de verdade — regressão que a normalização causou '
        'e foi corrigida', () {
      final items = parseReceiptText('TOMATE SALADA KG 0,732 KG 6,99 5,12');
      expect(items, hasLength(1));
      expect(items.single.quantity, 0.732);
      expect(items.single.name, 'TOMATE SALADA KG');
    });
  });
}
