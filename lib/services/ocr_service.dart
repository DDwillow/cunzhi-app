import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 本地 OCR 文字识别服务（基于 Google ML Kit）。
///
/// 使用 bundled 模型（模型打包进 App），离线可用、免费，不依赖 Google Play 服务。
class OcrService {
  // 懒加载：只在真正调用 OCR 时才初始化识别器，避免 App 启动/类加载时
  // 就加载模型（也避免静态字段初始化时机导致的崩溃）。
  static TextRecognizer? _recognizer;

  static TextRecognizer _getRecognizer() {
    return _recognizer ??=
        TextRecognizer(script: TextRecognitionScript.chinese);
  }

  /// 识别图片里的所有文字，按「从上到下」顺序拼接成纯文本返回。
  ///
  /// [imagePath] 图片本地路径。
  /// 返回识别出的完整文字（按行拼接）；识别失败或没有文字时抛异常/返回空串。
  static Future<String> recognize(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw Exception('图片文件不存在');
    }
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText result = await _getRecognizer().processImage(inputImage);

    final lines = <String>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) lines.add(text);
      }
    }
    return lines.join('\n');
  }

  /// 释放资源。
  static Future<void> close() async {
    final r = _recognizer;
    _recognizer = null;
    if (r != null) {
      await r.close();
    }
  }
}
