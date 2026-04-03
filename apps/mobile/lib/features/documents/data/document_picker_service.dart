import 'dart:io';

import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:file_picker/file_picker.dart';

class DocumentPickerService {
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

    final mimeType = _inferMimeType(file);
    return SelectedUploadDocument(
      name: file.name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  String _inferMimeType(PlatformFile file) {
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    return 'image/jpeg';
  }
}
