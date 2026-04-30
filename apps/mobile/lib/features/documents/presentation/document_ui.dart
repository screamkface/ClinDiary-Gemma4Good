import 'package:flutter/material.dart';

String documentTypeLabel(String type) {
  switch (type) {
    case 'lab_report':
      return 'Lab report';
    case 'imaging_report':
      return 'Imaging report';
    case 'discharge_letter':
      return 'Discharge summary';
    case 'specialist_visit':
      return 'Specialist visit';
    case 'prescription':
      return 'Prescription';
    case 'medical_certificate':
      return 'Medical certificate';
    default:
      return 'General document';
  }
}

String documentStatusLabel(String status) {
  switch (status) {
    case 'local_only':
      return 'Local only';
    case 'pending':
      return 'Pending';
    case 'processing':
      return 'Processing';
    case 'parsed':
      return 'Parsed';
    case 'ocr_pending':
      return 'OCR pending';
    case 'review_required':
      return 'Needs review';
    case 'reviewed':
      return 'Reviewed';
    case 'failed':
      return 'Error';
    default:
      return status;
  }
}

String documentContextStatusLabel(String status) {
  switch (status) {
    case 'old':
      return 'Old';
    case 'active':
    default:
      return 'Active';
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
      return 'On device';
    case 'cloud':
    default:
      return 'Archived';
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
