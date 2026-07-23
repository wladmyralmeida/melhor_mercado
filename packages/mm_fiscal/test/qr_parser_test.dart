import 'package:mm_fiscal/mm_fiscal.dart';
import 'package:test/test.dart';

const _nfcePb = '25260712345678000199650010000001231876543214';
const _cfeSat = '35111202767579000148598583801050151865833992';
const _hash40 = 'ABCDEF0123456789ABCDEF0123456789ABCDEF01';

void main() {
  group('QR NFC-e v2.00', () {
    test('online (5 campos): sem valor total', () {
      final raw = 'https://www.sefaz.pb.gov.br/nfce?p=$_nfcePb|2|1|1|$_hash40';
      final result = parseFiscalQr(raw);

      expect(result, isA<RecognizedFiscalDocument>());
      final doc = result as RecognizedFiscalDocument;
      expect(doc.accessKey.raw, _nfcePb);
      expect(doc.format, FiscalQrFormat.v2Online);
      expect(doc.totalCents, isNull);
    });

    test('offline (8 campos): total no índice 4', () {
      final raw =
          'https://www.sefaz.pb.gov.br/nfce'
          '?p=$_nfcePb|2|1|22|150.00|deadbeef|1|$_hash40';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.format, FiscalQrFormat.v2Offline);
      expect(doc.totalCents, 15000);
    });

    test('aceita "|" percent-encoded (%7C)', () {
      final raw =
          'https://x?p=$_nfcePb%7C2%7C1%7C1%7C'
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.format, FiscalQrFormat.v2Online);
    });
  });

  group('QR NFC-e v3.00 (sem CSC, produção desde 01/09/2025)', () {
    test('online (3 campos): sem valor total', () {
      final raw = 'https://www.sefaz.pb.gov.br/nfce?p=$_nfcePb|3|1';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.format, FiscalQrFormat.v3Online);
      expect(doc.totalCents, isNull);
    });

    test('offline (8 campos): total no mesmo índice 4 do v2', () {
      final raw =
          'https://www.sefaz.pb.gov.br/nfce'
          '?p=$_nfcePb|3|1|22|150.00|1|12345678000199|BASE64ASSINATURA==';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.format, FiscalQrFormat.v3Offline);
      expect(doc.totalCents, 15000);
    });
  });

  group('QR v1.00 legado (query string, desativado desde 01/10/2018)', () {
    test('extrai chNFe e vNF de dentro da query string', () {
      final raw =
          'https://www.sefaz.rs.gov.br/NFCE/NFCE-COM.aspx'
          '?chNFe=$_nfcePb&nVersao=100&tpAmb=1&cDest='
          '&dhEmi=323032362d30372d3232&vNF=150.00&vICMS=0.00'
          '&digVal=deadbeef&cIdToken=000001'
          '&cHashQRCode=ecc4f0e7e612456f2e3521768bd572b6f0eae240';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.accessKey.raw, _nfcePb);
      expect(doc.format, FiscalQrFormat.v1Legacy);
      expect(doc.totalCents, 15000);
    });
  });

  group('QR CF-e-SAT (mod 59, não é URL)', () {
    test('5 campos pipe-delimited: chave|dhEmi|vCFe|doc|assinatura', () {
      final raw = '$_cfeSat|20260722153000|59.05|12345678912|ASSINATURA';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.accessKey.raw, _cfeSat);
      expect(doc.format, FiscalQrFormat.cfeSat);
      expect(doc.totalCents, 5905);
    });

    test('documento do destinatário vazio (pipe duplo) ainda parseia', () {
      final raw = '$_cfeSat|20260722153000|59.05||ASSINATURA';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.format, FiscalQrFormat.cfeSat);
      expect(doc.totalCents, 5905);
    });
  });

  group('fallback universal (chave de 44 dígitos em texto sem estrutura)', () {
    test('recupera a chave mesmo sem reconhecer o formato ao redor', () {
      final doc =
          parseFiscalQr('Nota fiscal - chave $_nfcePb impressa')
              as RecognizedFiscalDocument;

      expect(doc.accessKey.raw, _nfcePb);
      expect(doc.format, FiscalQrFormat.unknown);
      expect(doc.totalCents, isNull);
    });

    test('chave NFC-e válida num layout pipe de 5 campos '
        '(modelo não bate com CF-e-SAT) cai no fallback, não erra', () {
      final raw = '$_nfcePb|20260722153000|59.05||ASSINATURA';
      final doc = parseFiscalQr(raw) as RecognizedFiscalDocument;

      expect(doc.accessKey.raw, _nfcePb);
      expect(doc.format, FiscalQrFormat.unknown);
    });
  });

  group('rejeição', () {
    test('texto sem nenhuma chave reconhecível', () {
      final result = parseFiscalQr('isso não é um cupom fiscal');
      expect(
        result,
        isA<UnrecognizedFiscalQr>().having(
          (r) => r.reason,
          'reason',
          FiscalQrParseError.notFiscalDocument,
        ),
      );
    });

    test('string vazia', () {
      final result = parseFiscalQr('   ');
      expect(result, isA<UnrecognizedFiscalQr>());
    });

    test('chave na posição certa do v2, mas com DV inválido', () {
      const wrongDv = '25260712345678000199650010000001231876543219';
      final raw = 'https://x?p=$wrongDv|2|1|1|$_hash40';
      final result = parseFiscalQr(raw);

      expect(
        result,
        isA<UnrecognizedFiscalQr>().having(
          (r) => r.reason,
          'reason',
          FiscalQrParseError.invalidAccessKey,
        ),
      );
    });
  });
}
