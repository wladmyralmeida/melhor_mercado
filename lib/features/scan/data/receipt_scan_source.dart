import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Fonte de "foto -> texto reconhecido". Abstraída atrás de uma
/// interface (em vez de chamar ImagePicker/ML Kit direto na tela) para
/// que a revisão pós-OCR seja testável com um fake — diferente da
/// ScanScreen (câmera ao vivo via platform view), que não dá pra testar
/// sob flutter_test.
abstract interface class ReceiptScanSource {
  /// `null` quando o usuário cancelou o seletor de imagem — não é erro.
  Future<String?> captureText(ImageSource source);
}

/// Implementação real: ImagePicker (câmera ou galeria) + ML Kit Text
/// Recognition, 100% no aparelho — a foto nunca sai dele.
class MlKitReceiptScanSource implements ReceiptScanSource {
  const MlKitReceiptScanSource();

  @override
  Future<String?> captureText(ImageSource source) async {
    final file = await _pickImage(source);
    if (file == null) return null;

    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// No Android, o sistema pode matar a Activity do app enquanto o app
  /// de câmera está em primeiro plano (mais comum em aparelhos com
  /// pouca RAM — exatamente o público deste app). Sem checar
  /// `retrieveLostData()` primeiro, a foto tirada some em silêncio e o
  /// usuário tem que tentar de novo sem entender por quê. Não tem
  /// efeito nas outras plataformas (sempre volta vazio).
  Future<XFile?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final lost = await picker.retrieveLostData();
    if (!lost.isEmpty) {
      if (lost.exception != null) throw lost.exception!;
      if (lost.file != null) return lost.file;
    }
    return picker.pickImage(source: source);
  }
}
