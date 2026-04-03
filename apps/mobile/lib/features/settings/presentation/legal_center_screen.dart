import 'package:clindiary/features/settings/presentation/legal_document_screen.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centro legale')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionCard(
            title: 'Documenti beta',
            subtitle: 'Testi interni in-app per privacy, AI e portabilità.',
            child: Text(
              'Questi documenti servono per rendere trasparente il comportamento attuale dell app. Prima del go-live vanno sostituiti con le versioni finali validate legalmente.',
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
                  child: const Text('Apri'),
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
