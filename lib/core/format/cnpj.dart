/// Formata 14 dígitos de CNPJ para exibição: "12.345.678/0001-99".
///
/// Puramente apresentacional — não valida dígito verificador (isso não
/// é necessário aqui: o CNPJ já veio de dentro de uma chave de acesso
/// fiscal validada pelo mm_fiscal).
String formatCnpj(String digits14) {
  if (digits14.length != 14) return digits14;
  return '${digits14.substring(0, 2)}.${digits14.substring(2, 5)}.'
      '${digits14.substring(5, 8)}/${digits14.substring(8, 12)}-'
      '${digits14.substring(12, 14)}';
}
