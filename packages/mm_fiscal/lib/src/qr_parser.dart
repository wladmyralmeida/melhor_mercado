import 'access_key.dart';

/// Formato do QR Code reconhecido. A versão é determinada pelo CAMPO 2
/// do split por `|`, nunca pelo domínio da URL — hosts de consulta
/// mudaram várias vezes por UF nos últimos anos.
enum FiscalQrFormat {
  /// Legado, query string com `chNFe=`. Desativado desde 01/10/2018 mas
  /// ainda aparece em cupons de arquivo — o parser aceita.
  v1Legacy,

  /// `?p=chave|2|tpAmb|idCSC|hash` (5 campos). Sem valor total.
  v2Online,

  /// `?p=chave|2|tpAmb|DD|vNF|digVal|idCSC|hash` (8 campos).
  v2Offline,

  /// `?p=chave|3|tpAmb` (3 campos). Sem valor total.
  v3Online,

  /// `?p=chave|3|tpAmb|DD|vNF|tpIdDest|idDest|assinatura` (8 campos).
  v3Offline,

  /// CF-e-SAT (mod 59, SP/CE): não é URL, `chave|dhEmi|vCFe|doc|assinatura`.
  cfeSat,

  /// A chave foi recuperada por regex de última instância — o layout ao
  /// redor dela não bateu com nenhum formato conhecido.
  unknown,
}

enum FiscalQrParseError {
  /// Nada que lembre um documento fiscal foi encontrado no texto.
  notFiscalDocument,

  /// Havia uma chave de 44 dígitos na posição esperada, mas ela é
  /// inválida (dígito verificador ou modelo).
  invalidAccessKey,
}

sealed class FiscalQrResult {
  const FiscalQrResult();
}

final class RecognizedFiscalDocument extends FiscalQrResult {
  const RecognizedFiscalDocument({
    required this.accessKey,
    required this.format,
    required this.totalCents,
    required this.rawQr,
  });

  final AccessKey accessKey;
  final FiscalQrFormat format;

  /// Valor total (vNF/vCFe) em centavos — só vem preenchido nos
  /// formatos que carregam o total (contingência offline, v1, SAT).
  /// `null` no caminho online v2/v3, que não traz nenhum valor
  /// monetário no próprio QR.
  final int? totalCents;

  final String rawQr;
}

final class UnrecognizedFiscalQr extends FiscalQrResult {
  const UnrecognizedFiscalQr(this.reason, this.rawQr);
  final FiscalQrParseError reason;
  final String rawQr;
}

final _bareKeyPattern = RegExp(r'(?<!\d)\d{44}(?!\d)');

/// Interpreta o conteúdo bruto de um QR Code escaneado e identifica o
/// documento fiscal, se houver um.
///
/// O QR nunca é fonte de ITENS — apenas de identidade (chave, UF, CNPJ
/// emitente, e o total quando o formato o traz). Ler os itens exige o
/// documento em si (foto do cupom, XML, ou consulta que este pacote não
/// faz).
FiscalQrResult parseFiscalQr(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return UnrecognizedFiscalQr(FiscalQrParseError.notFiscalDocument, raw);
  }

  final pIndex = trimmed.indexOf('?p=');
  if (pIndex != -1) {
    final value = trimmed.substring(pIndex + 3);
    final decoded = (value.contains('%7C') || value.contains('%7c'))
        ? Uri.decodeComponent(value)
        : value;
    final result = _fromNfceFields(decoded.split('|'), raw);
    if (result != null) return result;
  }

  if (trimmed.contains('chNFe=')) {
    final result = _fromLegacyQueryString(trimmed, raw);
    if (result != null) return result;
  }

  if (!trimmed.startsWith('http') && trimmed.contains('|')) {
    final result = _fromCfeSatFields(trimmed.split('|'), raw);
    if (result != null) return result;
  }

  final bareMatch = _bareKeyPattern.firstMatch(trimmed);
  if (bareMatch != null) {
    final keyResult = AccessKey.parse(bareMatch.group(0)!);
    if (keyResult case AccessKeyOk(:final key)) {
      return RecognizedFiscalDocument(
        accessKey: key,
        format: FiscalQrFormat.unknown,
        totalCents: null,
        rawQr: raw,
      );
    }
  }

  return UnrecognizedFiscalQr(FiscalQrParseError.notFiscalDocument, raw);
}

/// `null` = "não parecia deste formato, tente o próximo" — diferente de
/// [UnrecognizedFiscalQr], que é "era deste formato e falhou".
FiscalQrResult? _fromNfceFields(List<String> fields, String raw) {
  if (fields.isEmpty) return null;

  final keyResult = AccessKey.parse(fields[0]);
  if (keyResult is! AccessKeyOk) {
    if (_looksLikeAccessKey(fields[0])) {
      return UnrecognizedFiscalQr(FiscalQrParseError.invalidAccessKey, raw);
    }
    return null;
  }
  if (fields.length < 2) return null;

  final key = keyResult.key;
  final versao = fields[1];

  return switch ((versao, fields.length)) {
    ('2', 5) => RecognizedFiscalDocument(
      accessKey: key,
      format: FiscalQrFormat.v2Online,
      totalCents: null,
      rawQr: raw,
    ),
    ('2', 8) => RecognizedFiscalDocument(
      accessKey: key,
      format: FiscalQrFormat.v2Offline,
      totalCents: _parseFiscalDecimalToCents(fields[4]),
      rawQr: raw,
    ),
    ('3', 3) => RecognizedFiscalDocument(
      accessKey: key,
      format: FiscalQrFormat.v3Online,
      totalCents: null,
      rawQr: raw,
    ),
    ('3', 8) => RecognizedFiscalDocument(
      accessKey: key,
      format: FiscalQrFormat.v3Offline,
      totalCents: _parseFiscalDecimalToCents(fields[4]),
      rawQr: raw,
    ),
    _ => null,
  };
}

FiscalQrResult? _fromLegacyQueryString(String raw, String original) {
  final chMatch = RegExp(r'chNFe=(\d{44})').firstMatch(raw);
  if (chMatch == null) return null;

  final keyResult = AccessKey.parse(chMatch.group(1)!);
  if (keyResult is! AccessKeyOk) {
    return UnrecognizedFiscalQr(FiscalQrParseError.invalidAccessKey, original);
  }

  final vnfMatch = RegExp(r'vNF=([\d.]+)').firstMatch(raw);
  return RecognizedFiscalDocument(
    accessKey: keyResult.key,
    format: FiscalQrFormat.v1Legacy,
    totalCents: vnfMatch == null
        ? null
        : _parseFiscalDecimalToCents(vnfMatch.group(1)!),
    rawQr: original,
  );
}

FiscalQrResult? _fromCfeSatFields(List<String> fields, String raw) {
  if (fields.length != 5) return null;

  final keyResult = AccessKey.parse(fields[0]);
  if (keyResult is! AccessKeyOk) {
    if (_looksLikeAccessKey(fields[0])) {
      return UnrecognizedFiscalQr(FiscalQrParseError.invalidAccessKey, raw);
    }
    return null;
  }
  // Uma chave de 44 dígitos válida, mas de NFC-e/NF-e, aparecendo num
  // texto com pipes por coincidência não é um CF-e-SAT de verdade.
  if (keyResult.key.model != FiscalDocModel.cfeSat) return null;

  return RecognizedFiscalDocument(
    accessKey: keyResult.key,
    format: FiscalQrFormat.cfeSat,
    totalCents: _parseFiscalDecimalToCents(fields[2]),
    rawQr: raw,
  );
}

bool _looksLikeAccessKey(String field) =>
    field.replaceAll(RegExp(r'\D'), '').length == 44;

/// Converte o valor monetário do JEITO QUE O DOCUMENTO FISCAL O
/// ESCREVE: ponto decimal, sem separador de milhar, 1-2 casas (o
/// padrão do XML/QR da NF-e — NÃO é a convenção brasileira de digitação
/// que `parseBrlToCents` do app resolve). 100% aritmética de string/int;
/// `double` nunca representa dinheiro.
int? _parseFiscalDecimalToCents(String raw) {
  final s = raw.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  if (parts[0].length > 12) return null;
  var cents = int.parse(parts[0]) * 100;
  if (parts.length == 2) {
    cents += int.parse(parts[1].padRight(2, '0'));
  }
  return cents;
}
