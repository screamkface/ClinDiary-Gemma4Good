import 'package:flutter/material.dart';

String documentTypeLabel(String type) {
  switch (type) {
    case 'lab_report':
      return 'Referto laboratorio';
    case 'imaging_report':
      return 'Referto imaging';
    case 'discharge_letter':
      return 'Lettera di dimissione';
    case 'specialist_visit':
      return 'Visita specialistica';
    case 'prescription':
      return 'Prescrizione';
    case 'medical_certificate':
      return 'Certificato medico';
    default:
      return 'Documento generico';
  }
}

String documentStatusLabel(String status) {
  switch (status) {
    case 'local_only':
      return 'Solo locale';
    case 'pending':
      return 'In attesa';
    case 'processing':
      return 'In lavorazione';
    case 'parsed':
      return 'Processato';
    case 'ocr_pending':
      return 'OCR futuro';
    case 'review_required':
      return 'Da rivedere';
    case 'reviewed':
      return 'Revisionato';
    case 'failed':
      return 'Errore';
    default:
      return status;
  }
}

String documentContextStatusLabel(String status) {
  switch (status) {
    case 'old':
      return 'Vecchio';
    case 'active':
    default:
      return 'Attivo';
  }
}

Color documentContextStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'old':
      return Colors.blueGrey.shade700;
    case 'active':
    default:
      return Theme.of(context).colorScheme.secondary;
  }
}

Color documentStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'local_only':
      return Colors.teal.shade700;
    case 'parsed':
    case 'reviewed':
      return Colors.green.shade700;
    case 'processing':
      return Colors.orange.shade700;
    case 'ocr_pending':
      return Colors.blueGrey.shade700;
    case 'failed':
      return Theme.of(context).colorScheme.error;
    case 'review_required':
      return Colors.deepOrange.shade700;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

String documentStorageLabel(String storageLocation) {
  switch (storageLocation) {
    case 'local':
      return 'Sul dispositivo';
    case 'cloud':
    default:
      return 'Cloud';
  }
}

IconData documentIcon({
  required String documentType,
  required String mimeType,
}) {
  switch (documentType) {
    case 'lab_report':
      return Icons.science_outlined;
    case 'imaging_report':
      return Icons.image_search_outlined;
    default:
      return mimeType == 'application/pdf'
          ? Icons.picture_as_pdf_outlined
          : Icons.photo_outlined;
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
