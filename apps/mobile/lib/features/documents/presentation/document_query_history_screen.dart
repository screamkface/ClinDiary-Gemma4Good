import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DocumentQueryHistoryScreen extends ConsumerStatefulWidget {
  const DocumentQueryHistoryScreen({super.key});

  @override
  ConsumerState<DocumentQueryHistoryScreen> createState() =>
      _DocumentQueryHistoryScreenState();
}

AppLocalizations _l10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

class _DocumentQueryHistoryScreenState
    extends ConsumerState<DocumentQueryHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    final dateFormat = DateFormat('dd MMM yyyy HH:mm', localeName);
    final historyAsync = ref.watch(documentQueryHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.documentsAskFiles),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _showClearDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'clear',
                child: Text(l10n.documentsClearAllHistory),
              ),
            ],
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.documentsNoAskFilesHistoryYet,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.documentsYourDocumentQuestionsWillAppearHere,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  title: '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.question,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormat.format(entry.createdAt.toLocal()),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            iconSize: 20,
                            icon: const Icon(Icons.clear),
                            onPressed: () => _deleteEntry(entry.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(entry.searchScopeLabel)),
                          Chip(
                            label: Text(
                              entry.retrievedDocuments == 1
                                  ? l10n.documentsFileSingular
                                  : l10n.documentsFilesCount(
                                      entry.retrievedDocuments.toString(),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SummaryContentView(
                        content: entry.answer,
                        constrainHeight: true,
                      ),
                      if (entry.citations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.documentsSourcesCount(
                            entry.citations.length.toString(),
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: entry.citations.length,
                            itemBuilder: (context, citationIndex) {
                              final citation = entry.citations[citationIndex];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Card.outlined(
                                  child: InkWell(
                                    onTap: () =>
                                        _openDocument(citation.documentId),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 140,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              documentIcon(
                                                documentType:
                                                    citation.documentType,
                                                mimeType: 'application/pdf',
                                              ),
                                              size: 20,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              citation.documentTitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              documentTypeLabel(
                                                citation.documentType,
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDocument(String documentId) {
    context.push('/app/documents/$documentId');
  }

  Future<void> _deleteEntry(String entryId) async {
    final l10n = _l10nOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10nOf(context).documentsDeleteHistoryEntry),
        content: Text(_l10nOf(context).documentsDeleteHistoryEntryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_l10nOf(context).documentsCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_l10nOf(context).documentsDelete),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(documentQueryHistoryStoreProvider).deleteEntry(entryId);

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.documentsHistoryEntryDeleted)),
      );
    }
  }

  void _showClearDialog(BuildContext context) {
    final l10n = _l10nOf(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.documentsClearAllHistoryTitle),
        content: Text(l10n.documentsClearAllHistoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.documentsCancel),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(this.context);
              Navigator.pop(context);
              await ref.read(documentQueryHistoryStoreProvider).clearEntries();
              if (mounted) {
                setState(() {});
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.documentsHistoryCleared)),
                );
              }
            },
            child: Text(l10n.documentsClear),
          ),
        ],
      ),
    );
  }
}
