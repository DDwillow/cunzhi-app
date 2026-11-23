import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 负责把用户选择的图片复制到应用私有目录，保证数据自包含。
class ImageStorage {
  static Future<Directory> _getImageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(join(dir.path, 'images'));
    if (!imageDir.existsSync()) {
      imageDir.createSync(recursive: true);
    }
    return imageDir;
  }

  /// 把图片字节保存到应用私有目录，返回绝对路径。
  static Future<String> saveImageBytes(Uint8List bytes, {String? ext}) async {
    final dir = await _getImageDir();
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${bytes.hashCode.abs()}.${ext ?? 'jpg'}';
    final file = File(join(dir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// 把图片文件复制到应用私有目录，返回绝对路径。
  static Future<String> saveImageFile(File source, {String? ext}) async {
    final bytes = await source.readAsBytes();
    final e = ext ?? extension(source.path).replaceAll('.', '');
    return saveImageBytes(bytes, ext: e.isEmpty ? 'jpg' : e);
  }

  static Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  static Future<void> deleteMany(List<String> paths) async {
    for (final p in paths) {
      await delete(p);
    }
  }
}
