import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/shared/widgets/clinical_scope_notice.dart';
import 'package:clindiary/shared/widgets/feature_lock_card.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DocumentQueryScreen extends ConsumerStatefulWidget {
  const DocumentQueryScreen({
    this.initialFolderId,
    this.initialFolderName,
    super.key,
  });

  final String? initialFolderId;
  final String? initialFolderName;

  @override
  ConsumerState<DocumentQueryScreen> createState() =>
      _DocumentQueryScreenState();
}

class _DocumentQueryScreenState extends ConsumerState<DocumentQueryScreen> {
  static const _questionSuggestions = <String>[
    'Which recent tests mention creatinine or kidney function?',
    'Are there documents with out-of-range values in the last few months?',
    'Summarize the recent reports to bring to the doctor.',
  ];

  late final TextEditingController _questionController;
  DocumentQueryResult? _result;
  bool _isSubmitting = false;
  bool _isReindexing = false;
  String? _errorMessage;

  String? get _folderId => widget.initialFolderId;
  String? get _folderName => widget.initialFolderName;

  void _openBilling() {
    context.push('/app/home/billing?feature=ai_document_query');
  }

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionController.text.trim();
    if (question.length < 3) {
      setState(() => _errorMessage = 'Write a slightly more specific question.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(documentsRepositoryProvider)
          .queryDocuments(question: question, folderId: _folderId);
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (error.isFeatureLocked) {
        if (mounted) {
          _openBilling();
        }
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _reindex() async {
    setState(() => _isReindexing = true);
    try {
      final queued = await ref
          .read(documentsRepositoryProvider)
          .reindexDocuments();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued == 1
                ? 'Indexing started for 1 document.'
                : 'Indexing started for $queued documents.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isReindexing = false);
      }
    }
  }

  void _openCitation(DocumentQueryCitation citation) {
    context.push('/app/documents/${citation.documentId}');
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');
    final billingStatusAsync = ref.watch(billingStatusProvider);
    final proactiveLock =
        billingStatusAsync.asData?.value?.hasFeature('ai_document_query') ==
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask files'),
        actions: [
          TextButton.icon(
            onPressed: _isReindexing ? null : _reindex,
            icon: _isReindexing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_outlined),
            label: Text(_isReindexing ? 'Updating...' : 'Refresh index'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ClinicalScopeNotice(
            title: 'Citation search',
            message:
                'Document answers summarize only the retrieved and cited files. They help you navigate reports, not make diagnoses.',
            icon: Icons.manage_search_outlined,
          ),
          const SizedBox(height: 12),
          if (proactiveLock)
            FeatureLockCard(
              title: 'Ask files',
              featureLabel: 'Document questions',
              message:
                  'Conversational search with citations is part of ClinDiary AI Plus. Archive, folders, and classic search stay available.',
              onOpenBilling: _openBilling,
            )
          else ...[
            SectionCard(
              title: 'Search scope',
              subtitle: _folderName == null
                  ? 'The question searches the entire archive for the active profile.'
                  : 'The question is limited to the current folder.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.folder_open_outlined, size: 18),
                    label: Text(_folderName ?? 'Entire archive'),
                  ),
                  const Chip(
                    avatar: Icon(Icons.link_outlined, size: 18),
                    label: Text('Citations required'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Ask a question',
              subtitle:
                  'Use practical questions: recent tests, out-of-range values, documents to bring to the visit.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _questionController,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      hintText:
                          'E.g. Are there recent reports with high creatinine?',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _questionSuggestions
                        .map(
                          (item) => ActionChip(
                            label: Text(item),
                            onPressed: () => _questionController.text = item,
                          ),
                        )
                        .toList(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        _isSubmitting
                            ? 'Searching...'
                            : 'Search files',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isSubmitting)
              const SectionCard(
                title: 'Preparing answer',
                child: LinearProgressIndicator(),
              )
            else if (_result == null)
              const SectionCard(
                title: 'No answer yet',
                child: Text(
                  'Send a question to get a summary with citations to the documents used.',
                ),
              )
            else ...[
              SectionCard(
                title: 'Answer',
                subtitle: _result!.usedFallback
                    ? 'Conservative fallback active.'
                    : 'Answer generated from the retrieved passages.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(_result!.searchScopeLabel)),
                        Chip(label: Text('Provider: ${_result!.providerName}')),
                        Chip(label: Text('Model: ${_result!.modelName}')),
                        if (_result!.embeddingModelName != null)
                          Chip(
                            label: Text(
                              'Embedding: ${_result!.embeddingModelName}',
                            ),
                          ),
                        if (_result!.rerankerModelName != null)
                          Chip(
                            label: Text(
                              'Reranker: ${_result!.rerankerModelName}',
                            ),
                          ),
                        Chip(
                          label: Text(
                            '${_result!.retrievedDocuments} documents',
                          ),
                        ),
                        Chip(
                          label: Text('${_result!.retrievedChunks} passages'),
                        ),
                      ],
                    ),
                    if ((_result!.coverageNote ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _result!.coverageNote!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    SummaryContentView(
                      content: _result!.answer,
                      constrainHeight: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Sources used',
                subtitle:
                    'Open the document to check the passage directly.',
                child: Column(
                  children: _result!.citations.isEmpty
                      ? const [
                          Text(
                            'No citations available. Try refreshing the index or rephrasing the question.',
                          ),
                        ]
                      : _result!.citations
                            .map(
                              (citation) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Card.outlined(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    onTap: () => _openCitation(citation),
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: CircleAvatar(
                                      child: Icon(
                                        documentIcon(
                                          documentType: citation.documentType,
                                          mimeType: 'application/pdf',
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      citation.documentTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            documentTypeLabel(
                                              citation.documentType,
                                            ),
                                            if (citation.folderName != null)
                                              citation.folderName!,
                                            if (citation.examDate != null)
                                              dateFormat.format(
                                                citation.examDate!.toLocal(),
                                              ),
                                          ].join(' • '),
                                        ),
                                        if (citation.chunkLabel != null &&
                                            citation.chunkLabel!
                                                .trim()
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              citation.chunkLabel!,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium,
                                            ),
                                          ),
                                        if (citation.score != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Chip(
                                              label: Text(
                                                'Score ${citation.score!.toStringAsFixed(2)}',
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            citation.excerpt,
                                            maxLines: 5,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
