import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class FeatureLockCard extends StatelessWidget {
  const FeatureLockCard({
    required this.title,
    required this.message,
    required this.onOpenBilling,
    this.featureLabel,
    this.compact = false,
    super.key,
  });

  final String title;
  final String message;
  final String? featureLabel;
  final VoidCallback onOpenBilling;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featureLabel != null && featureLabel!.trim().isNotEmpty) ...[
          Chip(label: Text(featureLabel!)),
          const SizedBox(height: 12),
        ],
        Text(message),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onOpenBilling,
          icon: const Icon(Icons.workspace_premium_outlined),
          label: Text(l10n.discoverAiPlus),
        ),
      ],
    );

    if (compact) {
      return child;
    }

    return SectionCard(title: title, child: child);
  }
}
