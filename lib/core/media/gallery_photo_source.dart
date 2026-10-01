import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Opens the platform photo picker and hands back the picture the student
/// chose — null when they cancelled.
Future<Uint8List?> pickFromGalleryPhoto() async {
  final XFile? file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 90,
  );
  if (file == null) return null;
  return file.readAsBytes();
}
