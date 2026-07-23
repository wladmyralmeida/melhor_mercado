import 'dart:io' show Platform;

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
  /// usuário tem que tentar de novo sem entender por quê.
  ///
  /// `retrieveLostData()` só existe no Android — nas outras plataformas
  /// (iOS incluído) a implementação nem existe e a chamada lança
  /// `UnimplementedError` na hora, antes mesmo de abrir a câmera. Por
  /// isso o `Platform.isAndroid` aqui não é só otimização, é obrigatório.
  Future<XFile?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    if (Platform.isAndroid) {
      final lost = await picker.retrieveLostData();
      if (!lost.isEmpty) {
        if (lost.exception != null) throw lost.exception!;
        if (lost.file != null) return lost.file;
      }
    }
    // Sem limitar a largura, a foto vem na resolução total da câmera
    // (12MP+ em qualquer aparelho atual) e o ML Kit decodifica esse
    // bitmap inteiro na memória — risco real de OutOfMemoryError (que
    // derruba o app, sem chance de captura/mensagem) em aparelhos com
    // pouca RAM, exatamente o público deste app. 1600px de largura
    // sobra pra OCR ler o texto de um cupom.
    return picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
  }
}
