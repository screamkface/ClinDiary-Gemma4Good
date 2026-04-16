import 'package:clindiary/features/settings/presentation/legal_document_screen.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionCard(
            title: 'Beta documents',
            subtitle: 'In-app internal texts for privacy, AI, and portability.',
            child: Text(
              'These documents make the current app behavior transparent. Before go-live they must be replaced with the legally validated final versions.',
            ),
          ),
          const SizedBox(height: 12),
          ...LegalDocumentType.values.map(
            (document) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                title: document.title,
                subtitle: document.description,
                action: FilledButton.tonal(
                  onPressed: () => context.push('/legal/${document.slug}'),
                  child: const Text('Open'),
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
