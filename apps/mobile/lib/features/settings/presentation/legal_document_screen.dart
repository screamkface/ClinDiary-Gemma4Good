import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LegalDocumentType {
  privacy(
    title: 'Informativa privacy beta',
    assetPath: 'assets/legal/privacy-notice-beta.md',
    description: 'Trattamento dati e struttura del prodotto.',
  ),
  ai(
    title: 'Nota AI beta',
    assetPath: 'assets/legal/ai-notice-beta.md',
    description: 'Uso prudente dell AI e provider esterni.',
  ),
  portability(
    title: 'Portabilità e retention beta',
    assetPath: 'assets/legal/portability-retention-beta.md',
    description: 'Export, account deletion e lifecycle dati.',
  );

  const LegalDocumentType({
    required this.title,
    required this.assetPath,
    required this.description,
  });

  final String title;
  final String assetPath;
  final String description;

  static LegalDocumentType? fromSlug(String slug) {
    switch (slug) {
      case 'privacy':
        return LegalDocumentType.privacy;
      case 'ai':
        return LegalDocumentType.ai;
      case 'portability':
        return LegalDocumentType.portability;
      default:
        return null;
    }
  }

  String get slug {
    switch (this) {
      case LegalDocumentType.privacy:
        return 'privacy';
      case LegalDocumentType.ai:
        return 'ai';
      case LegalDocumentType.portability:
        return 'portability';
    }
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.documentType, super.key});

  final LegalDocumentType documentType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(documentType.title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(documentType.assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: documentType.title,
                subtitle: documentType.description,
                child: SummaryContentView(content: snapshot.data ?? ''),
              ),
            ],
          );
        },
      ),
    );
  }
}
