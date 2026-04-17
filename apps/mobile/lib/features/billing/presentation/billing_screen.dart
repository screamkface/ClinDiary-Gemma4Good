import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({this.featureCode, super.key});

  final String? featureCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing removed for hackathon')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Local-first build',
            subtitle: 'This hackathon build runs without billing gates.',
            child: const Text(
              'Billing and plan activation flows are disabled. Features are driven by local-only mode and on-device capabilities.',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/app/home/privacy'),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Open Privacy and AI settings'),
          ),
        ],
      ),
    );
  }
}
