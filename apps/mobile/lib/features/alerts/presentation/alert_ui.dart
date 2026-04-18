import 'package:flutter/material.dart';

String alertSeverityLabel(String severity) {
  switch (severity) {
    case 'urgency':
      return 'Urgency';
    case 'contact_doctor':
      return 'Contact doctor';
    case 'attention':
      return 'Attention';
    default:
      return 'Info';
  }
}

Color alertSeverityColor(BuildContext context, String severity) {
  switch (severity) {
    case 'urgency':
      return Theme.of(context).colorScheme.error;
    case 'contact_doctor':
      return Colors.deepOrange.shade700;
    case 'attention':
      return Colors.orange.shade700;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

IconData alertSeverityIcon(String severity) {
  switch (severity) {
    case 'urgency':
      return Icons.warning_amber_rounded;
    case 'contact_doctor':
      return Icons.medical_information_outlined;
    case 'attention':
      return Icons.notification_important_outlined;
    default:
      return Icons.info_outline;
  }
}
