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

/// Linhas que são cabeçalho/rodapé do cupom, nunca item — ignoradas
/// antes de qualquer tentativa de parse.
final _nonItemMarkers = RegExp(
  r'CNPJ|CPF|TOTAL|SUBTOTAL|DESCONTO|ACR[ÉE]SCIMO|TROCO|FORMA DE PAGAMENTO|'
  r'DINHEIRO|CART[ÃA]O|PIX|CONSULTE|PROTOCOLO|CHAVE DE ACESSO|DANFE|NFC-E|'
  r'CUPOM FISCAL|EXTRATO|CONSUMIDOR|VALOR PAGO|QTDE\.? TOTAL DE ITENS|'
  r'TRIBUTOS|LEI 12\.741',
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

// Linha "órfã" de quantidade/preço, sem descrição — o item pertence à
// linha anterior (cupom estreito, descrição não coube na mesma linha).
final _orphanQtyPrice = RegExp(
  _buildPattern([
    r'^\s*(?<qty>',
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

String _cleanDesc(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();

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

DraftReceiptItem? _fromFullLineMatch(RegExpMatch m, String rawLine) {
  final qty = _qtyToDouble(m.namedGroup('qty')!);
  if (qty == null || qty <= 0) return null;

  final price1 = _moneyToCents(m.namedGroup('price1'));
  final price2 = _moneyToCents(m.namedGroup('price2'));
  // Só um preço na linha: é o total (o comum quando não há coluna de
  // unitário separada); derivamos o unitário, nunca o contrário.
  final unitPriceCents = price2 != null ? price1 : null;
  final totalPriceCents = price2 ?? price1;

  return DraftReceiptItem(
    rawText: rawLine,
    name: _cleanDesc(m.namedGroup('desc')!),
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
List<DraftReceiptItem> parseReceiptText(String rawText) {
  final lines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .where((l) => !_nonItemMarkers.hasMatch(l))
      .toList();

  final items = <DraftReceiptItem>[];
  String? pendingDesc;
  String? pendingRaw;

  for (final line in lines) {
    final fullMatch = _fullLineItem.firstMatch(line);
    if (fullMatch != null) {
      final item = _fromFullLineMatch(fullMatch, line);
      if (item != null) {
        items.add(item);
        pendingDesc = null;
        pendingRaw = null;
        continue;
      }
    }

    final orphanMatch = _orphanQtyPrice.firstMatch(line);
    if (orphanMatch != null && pendingDesc != null) {
      final qty = _qtyToDouble(orphanMatch.namedGroup('qty')!);
      final price1 = _moneyToCents(orphanMatch.namedGroup('price1'));
      final price2 = _moneyToCents(orphanMatch.namedGroup('price2'));
      if (qty != null && qty > 0 && price1 != null) {
        final unitPriceCents = price2 != null ? price1 : null;
        final totalPriceCents = price2 ?? price1;
        items.add(
          DraftReceiptItem(
            rawText: '$pendingRaw\n$line',
            name: pendingDesc,
            quantity: qty,
            unit: orphanMatch.namedGroup('unit'),
            unitPriceCents: unitPriceCents,
            totalPriceCents: totalPriceCents,
            confidence: _confidenceFor(
              quantity: qty,
              unitPriceCents: unitPriceCents,
              totalPriceCents: totalPriceCents,
            ),
          ),
        );
        pendingDesc = null;
        pendingRaw = null;
        continue;
      }
    }

    final simpleMatch = _descAndPriceOnly.firstMatch(line);
    if (simpleMatch != null) {
      final price = _moneyToCents(simpleMatch.namedGroup('price'));
      if (price != null) {
        items.add(
          DraftReceiptItem(
            rawText: line,
            name: _cleanDesc(simpleMatch.namedGroup('desc')!),
            quantity: 1,
            totalPriceCents: price,
            confidence: _confidenceFor(quantity: 1, totalPriceCents: price),
          ),
        );
        pendingDesc = null;
        pendingRaw = null;
        continue;
      }
    }

    // Não bateu em nada: pode ser a descrição de um item cuja
    // qty/preço vem na PRÓXIMA linha (cupom estreito).
    pendingDesc = _cleanDesc(line);
    pendingRaw = line;
  }

  return items;
}
