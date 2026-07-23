/// Modelo do documento fiscal, identificado pelos dígitos 21-22 (0-based
/// [20:22]) da chave de acesso.
enum FiscalDocModel {
  nfe('55'),
  cfeSat('59'),
  nfce('65');

  const FiscalDocModel(this.code);

  final String code;

  static FiscalDocModel? fromCode(String code) => switch (code) {
    '55' => FiscalDocModel.nfe,
    '59' => FiscalDocModel.cfeSat,
    '65' => FiscalDocModel.nfce,
    _ => null,
  };
}

/// Código IBGE da UF (2 dígitos, posições [0:2] da chave) -> sigla.
///
/// Usado só para exibição; nunca para decidir URL de consulta (isso
/// mudou de UF em UF nos últimos anos e não faz parte deste pacote).
const _ufByCuf = <String, String>{
  '11': 'RO',
  '12': 'AC',
  '13': 'AM',
  '14': 'RR',
  '15': 'PA',
  '16': 'AP',
  '17': 'TO',
  '21': 'MA',
  '22': 'PI',
  '23': 'CE',
  '24': 'RN',
  '25': 'PB',
  '26': 'PE',
  '27': 'AL',
  '28': 'SE',
  '29': 'BA',
  '31': 'MG',
  '32': 'ES',
  '33': 'RJ',
  '35': 'SP',
  '41': 'PR',
  '42': 'SC',
  '43': 'RS',
  '50': 'MS',
  '51': 'MT',
  '52': 'GO',
  '53': 'DF',
};

/// Motivo pelo qual uma chave de acesso não pôde ser interpretada.
enum AccessKeyError {
  /// Depois de remover não-dígitos, não sobraram exatamente 44.
  wrongLength,

  /// Os dígitos [20:22] não correspondem a nenhum modelo conhecido
  /// (55 NF-e, 59 CF-e-SAT, 65 NFC-e).
  unknownModel,

  /// O dígito verificador (módulo 11) não bate com os 43 primeiros.
  invalidCheckDigit,
}

/// Resultado de [AccessKey.parse] — nunca lança para entrada inválida
/// (chave de usuário/QR pode vir errada; isso não é bug de programação).
sealed class AccessKeyResult {
  const AccessKeyResult();
}

final class AccessKeyOk extends AccessKeyResult {
  const AccessKeyOk(this.key);
  final AccessKey key;
}

final class AccessKeyInvalid extends AccessKeyResult {
  const AccessKeyInvalid(this.error);
  final AccessKeyError error;
}

/// Chave de acesso de 44 dígitos de um documento fiscal brasileiro.
///
/// NF-e (mod 55) e NFC-e (mod 65) compartilham o mesmo layout de campos.
/// CF-e-SAT (mod 59) tem um layout DIFERENTE a partir da posição 23 —
/// aplicar os offsets de NF-e a uma chave SAT produz lixo silencioso
/// (série e número errados), por isso os dois são tratados em branches
/// separados aqui, nunca com o mesmo fatiamento.
class AccessKey {
  const AccessKey._({
    required this.raw,
    required this.cuf,
    required this.aamm,
    required this.issuerId,
    required this.model,
    required this.series,
    required this.number,
    required this.tpEmis,
    required this.randomCode,
    required this.checkDigit,
  });

  /// Os 44 dígitos, sem formatação.
  final String raw;

  /// Código IBGE da UF do emitente (2 dígitos).
  final String cuf;

  /// Ano+mês de emissão, formato AAMM (4 dígitos).
  final String aamm;

  /// CNPJ do emitente (14 dígitos, zero-preenchido se for CPF).
  final String issuerId;

  final FiscalDocModel model;

  /// Série do documento. Para CF-e-SAT, é o número de série do
  /// equipamento SAT (nserieSAT, 9 dígitos) — não é "série" no sentido
  /// de NF-e/NFC-e.
  final String series;

  /// Número do documento (nNF para NF-e/NFC-e; nCF para CF-e-SAT).
  final String number;

  /// Tipo de emissão. `null` para CF-e-SAT, que não tem esse campo.
  final String? tpEmis;

  /// Código numérico aleatório (cNF) — NÃO usar para deduplicação:
  /// varia entre origens do mesmo documento (QR vs. reprocessamento).
  final String randomCode;

  final String checkDigit;

  /// Sigla da UF, ou `null` se o código IBGE não for reconhecido.
  String? get ufAbbreviation => _ufByCuf[cuf];

  /// Chave NATURAL de deduplicação de documento — não a chave de 44
  /// dígitos inteira, que carrega o código aleatório `randomCode` e é
  /// frágil para casar o mesmo documento vindo de origens diferentes
  /// (QR vs. OCR com um dígito de leitura errado).
  String get naturalKey =>
      '$cuf|$issuerId|${model.code}|$series|$number|${tpEmis ?? ''}';

  static int _computeCheckDigit(String digits43) {
    var sum = 0;
    var weight = 2;
    for (var i = digits43.length - 1; i >= 0; i--) {
      sum += (digits43.codeUnitAt(i) - 0x30) * weight;
      weight = weight == 9 ? 2 : weight + 1;
    }
    final r = sum % 11;
    return r < 2 ? 0 : 11 - r;
  }

  /// Interpreta uma chave de acesso. Aceita entrada com ou sem
  /// formatação (espaços, pontos) — remove tudo que não for dígito
  /// antes de validar.
  static AccessKeyResult parse(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 44) {
      return const AccessKeyInvalid(AccessKeyError.wrongLength);
    }

    final model = FiscalDocModel.fromCode(digits.substring(20, 22));
    if (model == null) {
      return const AccessKeyInvalid(AccessKeyError.unknownModel);
    }

    final expectedDv = _computeCheckDigit(digits.substring(0, 43));
    if (expectedDv != digits.codeUnitAt(43) - 0x30) {
      return const AccessKeyInvalid(AccessKeyError.invalidCheckDigit);
    }

    if (model == FiscalDocModel.cfeSat) {
      return AccessKeyOk(
        AccessKey._(
          raw: digits,
          cuf: digits.substring(0, 2),
          aamm: digits.substring(2, 6),
          issuerId: digits.substring(6, 20),
          model: model,
          series: digits.substring(22, 31), // nserieSAT
          number: digits.substring(31, 37), // nCF
          tpEmis: null,
          randomCode: digits.substring(37, 43),
          checkDigit: digits.substring(43, 44),
        ),
      );
    }

    return AccessKeyOk(
      AccessKey._(
        raw: digits,
        cuf: digits.substring(0, 2),
        aamm: digits.substring(2, 6),
        issuerId: digits.substring(6, 20),
        model: model,
        series: digits.substring(22, 25),
        number: digits.substring(25, 34),
        tpEmis: digits.substring(34, 35),
        randomCode: digits.substring(35, 43),
        checkDigit: digits.substring(43, 44),
      ),
    );
  }

  @override
  String toString() => 'AccessKey($raw, ${model.name})';

  @override
  bool operator ==(Object other) => other is AccessKey && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}
