import 'dart:io';

import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class DocumentPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<SelectedUploadDocument?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      return null;
    }

    final mimeType = _inferMimeTypeFromName(file.name);
    return SelectedUploadDocument(
      name: file.name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  Future<SelectedUploadDocument?> pickPhotoFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (image == null) {
      return null;
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }

    final filename = path.basename(image.path).trim().isEmpty
        ? 'camera-${DateTime.now().millisecondsSinceEpoch}.jpg'
        : path.basename(image.path);

    return SelectedUploadDocument(
      name: filename,
      bytes: bytes,
      mimeType: _inferMimeTypeFromName(filename),
    );
  }

  String _inferMimeTypeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    return 'image/jpeg';
  }
}
