import 'dart:io';

Future<File> cropImage(String path) async {
  // Webではクロップなし、Fileをそのまま返す
  return File(path);
} 