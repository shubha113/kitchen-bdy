import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extracts and returns all raw text from [imageFile].
  /// The returned string preserves line breaks so the parser can work line-by-line.
  static Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognised = await _recognizer.processImage(inputImage);
    return recognised.text;
  }

  /// Call once when the app is disposed.
  static void dispose() => _recognizer.close();
}
