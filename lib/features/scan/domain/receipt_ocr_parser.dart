/// Parser heurístico de itens de cupom fiscal a partir de texto de OCR.
///
/// Dart puro, sem Flutter/ML Kit — recebe só texto, testável sem câmera.
///
/// HONESTIDADE SOBRE O LIMITE DESTA ABORDAGEM: ao contrário do
/// `mm_fiscal` (que interpreta campos com especificação oficial e
/// dígito verificador), aqui não existe layout único de cupom — cada
/// rede/PDV imprime de um jeito. Isto é heurística de melhor esforço
/// sobre texto ruidoso de OCR de bobina térmica, não uma leitura exata.
/// A revisão do usuário é a rede de segurança, não um passo descartável.
library;

/// Um item candidato extraído de uma ou duas linhas de OCR.
class DraftReceiptItem {
  const DraftReceiptItem({
    required this.rawText,
    required this.name,
    required this.quantity,
    this.unit,
    this.unitPriceCents,
    this.totalPriceCents,
    required this.confidence,
  });

  /// O texto original de onde o item veio (para o usuário conferir).
  final String rawText;

  final String name;

  /// Pode ser fracionária (peso, ex.: 0,732 kg). Não é dinheiro —
  /// `double` aqui é aceitável (mesma convenção de `ShoppingListItems`).
  final double quantity;

  final String? unit;

  /// Sempre em centavos inteiros. `null` quando não foi possível
  /// separar unitário de total.
  final int? unitPriceCents;

  final int? totalPriceCents;

  /// 0.0-1.0. Alto quando qty × unitário reconcilia com o total
  /// (mesmo princípio do `mm_fiscal`/pipeline de extração: aritmética
  /// como sinal de confiança, não achismo).
  final double confidence;
}

const _units = {
  'UN',
  'UND',
  'UNID',
  'KG',
  'G',
  'GR',
  'MG',
  'ML',
  'L',
  'LT',
  'LTS',
  'DZ',
  'PCT',
  'PC',
  'CX',
  'FD',
  'BDJ',
  'PT',
};

/// Linhas que são cabeçalho/rodapé do cupom, nunca item. Ao encontrar
/// uma, a descrição pendente é ZERADA (não só a linha é ignorada) —
/// achado contra foto de cupom real: texto de cabeçalho que não bate
/// em nenhum marcador (nome/endereço da loja, por exemplo) vazava pra
/// dentro do nome do primeiro item de verdade sem esse corte.
final _nonItemMarkers = RegExp(
  r'CNPJ|CPF|TOTAL|SUBTOTAL|DESCONTO|ACR[ÉE]SCIMO|TROCO|FORMA DE PAGAMENTO|'
  r'DINHEIRO|CART[ÃA]O|PIX|CONSULTE|PROTOCOLO|CHAVE DE ACESSO|DANFE|NFC-E|'
  r'CUPOM FISCAL|EXTRATO|CONSUMIDOR|VALOR PAGO|QTDE\.? TOTAL DE ITENS|'
  r'TRIBUTOS|LEI 12\.741|CONTING[ÊE]NCIA|AUTORIZA[ÇC][ÃA]O',
  caseSensitive: false,
);

// Dinheiro impresso no cupom: vírgula decimal é o padrão oficial (NF-e).
// Fallback com ponto cobre ruído de OCR que achata a vírgula.
//
// `(?<!\d)`/`(?!\d)`: sem essas guardas, o backtracking do `.+?` da
// descrição consegue "cortar" um número mais longo ao meio pra fechar
// o casamento — ex. em "2UN X 6,50 = 13,00", sem a guarda o motor
// aceita qty="1" + preço="3,00", fatiando "13,00" no meio (achado por
// teste, não hipotético). Não uso `\b` aqui porque letra colada em
// dígito é o caso comum ("1UN", "2KG") e `\b` bloquearia isso também;
// a guarda tem que ser especificamente "não veio nem vai dígito".
const _moneyPattern = r'(?<!\d)(?:\d{1,3}(?:\.\d{3})*,\d{2}|\d+\.\d{2})(?!\d)';
const _qtyPattern = r'(?<!\d)\d+(?:[.,]\d{1,4})?(?!\d)';
final _unitAlt = _units.join('|');

/// Monta uma fonte de regex concatenando trechos crus (`r'...'`, onde
/// `\s`/`\d` etc. não precisam de escape) com os pedaços de vocabulário
/// definidos acima. Junção por lista evita a armadilha de misturar
/// string crua com interpolação (o `$` de uma raw string não interpola).
String _buildPattern(List<String> parts) => parts.join();

// Linha completa: descrição (preguiçoso) + quantidade + unidade
// opcional + "x"/"*" opcional + preço unitário + "="/preço total
// opcionais, ancorada no fim da linha. O `$` no fim é o que faz o
// `.+?` preguiçoso parar exatamente onde a cauda numérica começa —
// sem isso, "500G" dentro do NOME (ex. "CAFE 500G") seria confundido
// com a coluna de quantidade.
final _fullLineItem = RegExp(
  _buildPattern([
    r'^(?<desc>.+?)\s+',
    r'(?<qty>',
    _qtyPattern,
    r')\s*',
    r'(?<unit>',
    _unitAlt,
    r')?\s*',
    r'(?:[xX*])?\s*',
    r'(?<price1>',
    _moneyPattern,
    r')',
    r'(?:\s*=?\s*(?<price2>',
    _moneyPattern,
    r'))?\s*$',
  ]),
);

// Fallback: só descrição + um preço (quantidade 1 implícita).
final _descAndPriceOnly = RegExp(
  _buildPattern([r'^(?<desc>.+?)\s+(?<price>', _moneyPattern, r')\s*$']),
);

// Achado contra foto de cupom real (rede "Varejão do Preço", JP-PB):
// a unidade pode vir ANTES da quantidade na mesma célula impressa
// (ex.: "...330ML UN 1 X 6,79 6,79", não "...330ML 1 UN X 6,79 6,79"
// como os padrões acima assumem). Em vez de duplicar cada regex pras
// duas ordens possíveis, normaliza a linha pra ordem esperada antes de
// tentar casar. `\b` nos dois lados evita casar "UN" colado dentro de
// uma palavra maior.
//
// `(?<!\d\s)` é essencial: sem essa guarda, "500G 1 UN 8,99 8,99" (que
// JÁ está na ordem certa) casava "UN 8,99" achando que "8,99" era a
// quantidade — o "1" sobrava dentro do nome (achado por teste, não
// hipotético). A guarda bloqueia especificamente quando a unidade vem
// logo depois de um dígito+espaço, ou seja, quando ela já está no
// lugar certo (depois da quantidade, não antes).
//
// O lookahead final (`x`/`*` ou preço logo em seguida) é a segunda
// guarda necessária: sem ele, "TOMATE SALADA KG 0,732 KG 6,99 5,12"
// (onde o PRIMEIRO "KG" é parte do NOME — produto vendido por kg — e
// o segundo é a unidade de verdade) casava errado no primeiro "KG",
// interpretando a quantidade real como se fosse preço (achado por
// teste, não hipotético). Só troca a ordem quando o que vem logo
// depois da quantidade é claramente o conector/preço, nunca outra
// unidade.
final _unitBeforeQty = RegExp(
  _buildPattern([
    r'(?<!\d\s)\b(',
    _unitAlt,
    r')\b\s+(',
    _qtyPattern,
    r')(?=\s*(?:[xX*]|',
    _moneyPattern,
    r'))',
  ]),
);

// Grupos posicionais (não nomeados) de propósito: `replaceAllMapped`
// devolve `Match` puro, sem `namedGroup` — só `RegExpMatch` tem isso, e
// o cast seria mais barulho do que os dois `group()` abaixo.
String _normalizeUnitOrder(String line) =>
    line.replaceAllMapped(_unitBeforeQty, (m) => '${m.group(2)} ${m.group(1)}');

int? _moneyToCents(String? raw) {
  if (raw == null) return null;
  final hasComma = raw.contains(',');
  final normalized = hasComma
      ? raw.replaceAll('.', '').replaceAll(',', '.')
      : raw;
  final parts = normalized.split('.');
  if (parts.length != 2 || parts[1].length != 2) return null;
  final reais = int.tryParse(parts[0]);
  final centavos = int.tryParse(parts[1]);
  if (reais == null || centavos == null) return null;
  return reais * 100 + centavos;
}

double? _qtyToDouble(String raw) => double.tryParse(raw.replaceAll(',', '.'));

String _cleanDesc(String raw) => _stripTrailingConnector(
  _stripLeadingCodes(raw.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase()),
);

/// Cupons reais prefixam a descrição com número da linha e/ou código
/// de barras (ex.: "001 7891991299619 MICHELOB ULTRA..."). Sem isso, o
/// nome salvo começava com uma sequência de dígitos sem significado
/// nenhum pro usuário. Corta tokens 100% numéricos do INÍCIO, um a um,
/// enquanto sobrar pelo menos um token depois (nunca esvazia o nome).
String _stripLeadingCodes(String desc) {
  final tokens = desc.split(' ');
  var start = 0;
  while (start < tokens.length - 1 &&
      RegExp(r'^\d+$').hasMatch(tokens[start])) {
    start++;
  }
  return tokens.sublist(start).join(' ');
}

/// Quando o fallback "só descrição + preço" casa contra um buffer
/// acumulado, o conector "x"/"*" às vezes sobra colado no final da
/// descrição (ex.: "MICHELOB ULTRA... 330ML X" em vez de só o nome) —
/// corta, um token por vez, do FIM.
String _stripTrailingConnector(String desc) {
  final tokens = desc.split(' ');
  var end = tokens.length;
  while (end > 1 && (tokens[end - 1] == 'X' || tokens[end - 1] == '*')) {
    end--;
  }
  return tokens.sublist(0, end).join(' ');
}

// Fragmento de OCR que virou só conector/unidade solto, sem nome
// nenhum (ex.: "X 6,79", "UN X 6,89") — achado contra foto de cupom
// real: sem essa lista, esse fragmento virava um item com nome "X" ou
// "UN X", DESCARTANDO o nome de verdade que estava acumulado no
// buffer. Melhor perder o item do que salvar um nome sem sentido.
final _connectorOrUnitOnly = {'X', '*', ..._units};

bool _isJunkOnly(String desc) {
  final tokens = desc.split(' ').where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return true;
  return tokens.every(_connectorOrUnitOnly.contains);
}

/// Confiança alta quando qty × unitário reconcilia com o total
/// (tolerância de 2 centavos por arredondamento de peso/embalagem).
double _confidenceFor({
  required double quantity,
  int? unitPriceCents,
  int? totalPriceCents,
}) {
  if (unitPriceCents != null && totalPriceCents != null) {
    final expected = (quantity * unitPriceCents).round();
    final diff = (expected - totalPriceCents).abs();
    return diff <= 2 ? 0.9 : 0.4;
  }
  if (unitPriceCents != null || totalPriceCents != null) return 0.6;
  return 0.5;
}

DraftReceiptItem? _fromFullLineMatch(RegExpMatch m, String rawText) {
  final qty = _qtyToDouble(m.namedGroup('qty')!);
  if (qty == null || qty <= 0) return null;

  final name = _cleanDesc(m.namedGroup('desc')!);
  if (_isJunkOnly(name)) return null;

  final price1 = _moneyToCents(m.namedGroup('price1'));
  final price2 = _moneyToCents(m.namedGroup('price2'));
  // Só um preço na linha: é o total (o comum quando não há coluna de
  // unitário separada); derivamos o unitário, nunca o contrário.
  final unitPriceCents = price2 != null ? price1 : null;
  final totalPriceCents = price2 ?? price1;

  return DraftReceiptItem(
    rawText: rawText,
    name: name,
    quantity: qty,
    unit: m.namedGroup('unit'),
    unitPriceCents: unitPriceCents,
    totalPriceCents: totalPriceCents,
    confidence: _confidenceFor(
      quantity: qty,
      unitPriceCents: unitPriceCents,
      totalPriceCents: totalPriceCents,
    ),
  );
}

/// Interpreta o texto bruto do OCR (uma linha por `\n`) e devolve os
/// itens candidatos encontrados. Nunca lança — texto de OCR é
/// inerentemente ruidoso; linhas que não parseiam são silenciosamente
/// ignoradas (o usuário revisa e adiciona manualmente o que faltar).
///
/// Acumula linhas cruas num buffer e tenta casar o buffer INTEIRO
/// (não só a última linha) a cada nova linha — funciona com qualquer
/// número de fragmentos, porque um cupom fotografado (não digitalizado
/// reto) pode quebrar uma linha larga em 2, 3 ou mais pedaços,
/// dependendo do ângulo/distância da foto (achado contra foto real).
List<DraftReceiptItem> parseReceiptText(String rawText) {
  final rawLines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final items = <DraftReceiptItem>[];
  final buffer = <String>[];

  for (final rawLine in rawLines) {
    if (_nonItemMarkers.hasMatch(rawLine)) {
      // Zera: texto de cabeçalho/rodapé que não virou item nunca deve
      // vazar pro nome do PRÓXIMO item de verdade.
      buffer.clear();
      continue;
    }

    buffer.add(rawLine);
    // Unidade pode vir antes da quantidade no cupom real (ver
    // `_unitBeforeQty`) — normaliza o buffer JUNTO, não linha a linha,
    // porque a quantidade e a unidade podem estar em fragmentos
    // diferentes.
    final joined = _normalizeUnitOrder(buffer.join(' '));

    final fullMatch = _fullLineItem.firstMatch(joined);
    if (fullMatch != null) {
      final item = _fromFullLineMatch(fullMatch, buffer.join('\n'));
      if (item != null) {
        items.add(item);
        buffer.clear();
        continue;
      }
    }

    final simpleMatch = _descAndPriceOnly.firstMatch(joined);
    if (simpleMatch != null) {
      final name = _cleanDesc(simpleMatch.namedGroup('desc')!);
      final price = _moneyToCents(simpleMatch.namedGroup('price'));
      // Guarda contra fragmento tipo "X 6,79"/"UN X 6,89" virando item
      // com nome "X"/"UN X" — sem isso, o nome de verdade acumulado no
      // buffer era descartado (achado real, não hipotético).
      if (price != null && !_isJunkOnly(name)) {
        items.add(
          DraftReceiptItem(
            rawText: buffer.join('\n'),
            name: name,
            quantity: 1,
            totalPriceCents: price,
            confidence: _confidenceFor(quantity: 1, totalPriceCents: price),
          ),
        );
        buffer.clear();
        continue;
      }
    }

    // Não bateu em nada útil: continua acumulando pra próxima linha
    // tentar de novo com mais contexto. Buffer que cresce demais sem
    // nunca casar é provavelmente lixo (cabeçalho não reconhecido) —
    // descarta pra não grudar em itens futuros.
    if (buffer.length > 6) buffer.clear();
  }

  return items;
}
