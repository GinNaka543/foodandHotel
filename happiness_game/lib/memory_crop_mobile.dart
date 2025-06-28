// このファイルはモバイル専用です。Webではimportしないでください。
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';

Future<File?> cropImage(String path) async {
  CroppedFile? cropped = await ImageCropper().cropImage(
    sourcePath: path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    cropStyle: CropStyle.circle,
  );
  if (cropped == null) return null;
  return File(cropped.path);
} 