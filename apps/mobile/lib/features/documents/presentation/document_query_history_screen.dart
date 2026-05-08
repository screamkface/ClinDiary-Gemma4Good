import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/domain/document_query_history_entry.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
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

class _DocumentQueryHistoryScreenState
    extends ConsumerState<DocumentQueryHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask files history'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _showClearDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear all history'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<DocumentQueryHistoryEntry>>(
        future: ref.read(documentQueryHistoryStoreProvider).readEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? const [];

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
                    'No ask files history yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your document questions will appear here.',
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
                      // Header with timestamp and delete button
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
                                  dateFormat.format(entry.createdAt),
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
                                  ? '1 file'
                                  : '${entry.retrievedDocuments} files',
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
                          'Sources (${entry.citations.length})',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete history entry?'),
        content: const Text(
          'This will remove the question and answer from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('History entry deleted.')));
    }
  }

  void _showClearDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This will remove all your document questions and answers from history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(this.context);
              Navigator.pop(context);
              await ref.read(documentQueryHistoryStoreProvider).clearEntries();
              if (mounted) {
                setState(() {});
                messenger.showSnackBar(
                  const SnackBar(content: Text('History cleared.')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
