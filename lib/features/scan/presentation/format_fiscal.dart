import 'package:mm_fiscal/mm_fiscal.dart';

/// Rótulo curto e reconhecível do modelo de documento fiscal.
String fiscalDocModelLabel(FiscalDocModel model) => switch (model) {
  FiscalDocModel.nfce => 'NFC-e',
  FiscalDocModel.nfe => 'NF-e',
  FiscalDocModel.cfeSat => 'CF-e-SAT',
};

/// O mesmo rótulo, a partir do código de 2 dígitos guardado no banco
/// (`Receipts.docModel`), sem precisar reconstruir um `AccessKey`.
String fiscalDocModelLabelFromCode(String code) =>
    switch (FiscalDocModel.fromCode(code)) {
      null => code,
      final model => fiscalDocModelLabel(model),
    };
