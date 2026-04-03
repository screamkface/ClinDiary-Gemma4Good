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
    'Quali esami recenti parlano di creatinina o funzionalita renale?',
    'Ci sono documenti con valori fuori range negli ultimi mesi?',
    'Riassumi i referti recenti da portare dal medico.',
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
      setState(() => _errorMessage = 'Scrivi una domanda un po piu precisa.');
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
                ? 'Indicizzazione avviata per 1 documento.'
                : 'Indicizzazione avviata per $queued documenti.',
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
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final billingStatusAsync = ref.watch(billingStatusProvider);
    final proactiveLock =
        billingStatusAsync.asData?.value?.hasFeature('ai_document_query') ==
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chiedi ai documenti'),
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
            label: Text(_isReindexing ? 'Aggiorno...' : 'Aggiorna indice'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ClinicalScopeNotice(
            title: 'Ricerca con citazioni',
            message:
                'Le risposte sui documenti riassumono solo i file recuperati e citati. Servono per orientarsi nei referti, non per fare diagnosi.',
            icon: Icons.manage_search_outlined,
          ),
          const SizedBox(height: 12),
          if (proactiveLock)
            FeatureLockCard(
              title: 'Chiedi ai documenti',
              featureLabel: 'Domande ai documenti',
              message:
                  'La ricerca conversazionale con citazioni fa parte di ClinDiary AI Plus. Archivio, cartelle e ricerca classica restano disponibili.',
              onOpenBilling: _openBilling,
            )
          else ...[
            SectionCard(
              title: 'Ambito della ricerca',
              subtitle: _folderName == null
                  ? 'La domanda usa tutto l archivio del profilo attivo.'
                  : 'La domanda e limitata alla cartella corrente.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.folder_open_outlined, size: 18),
                    label: Text(_folderName ?? 'Tutto l archivio'),
                  ),
                  const Chip(
                    avatar: Icon(Icons.link_outlined, size: 18),
                    label: Text('Citazioni obbligatorie'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Fai una domanda',
              subtitle:
                  'Usa domande pratiche: esami recenti, valori fuori range, documenti da portare in visita.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _questionController,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Domanda',
                      hintText:
                          'Es. Ci sono referti recenti con creatinina alta?',
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
                            ? 'Sto cercando...'
                            : 'Cerca nei documenti',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isSubmitting)
              const SectionCard(
                title: 'Risposta in preparazione',
                child: LinearProgressIndicator(),
              )
            else if (_result == null)
              const SectionCard(
                title: 'Nessuna risposta ancora',
                child: Text(
                  'Invia una domanda per ottenere un riepilogo con citazioni ai documenti usati.',
                ),
              )
            else ...[
              SectionCard(
                title: 'Risposta',
                subtitle: _result!.usedFallback
                    ? 'Fallback prudente attivo.'
                    : 'Risposta generata sui passaggi trovati.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(_result!.searchScopeLabel)),
                        Chip(label: Text('Provider: ${_result!.providerName}')),
                        Chip(label: Text('Modello: ${_result!.modelName}')),
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
                            '${_result!.retrievedDocuments} documenti',
                          ),
                        ),
                        Chip(
                          label: Text('${_result!.retrievedChunks} passaggi'),
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
                title: 'Fonti usate',
                subtitle:
                    'Apri il documento per controllare direttamente il passaggio.',
                child: Column(
                  children: _result!.citations.isEmpty
                      ? const [
                          Text(
                            'Nessuna citazione disponibile. Prova ad aggiornare l indice o a riformulare la domanda.',
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
