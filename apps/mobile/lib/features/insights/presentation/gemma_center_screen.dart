import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/shared/widgets/clinical_scope_notice.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GemmaCenterScreen extends ConsumerStatefulWidget {
  const GemmaCenterScreen({
    super.key,
    this.initialQuestion,
    this.documentId,
  });

  final String? initialQuestion;
  final String? documentId;

  @override
  ConsumerState<GemmaCenterScreen> createState() => _GemmaCenterScreenState();
}

class _GemmaCenterScreenState extends ConsumerState<GemmaCenterScreen> {
  static const _questionSuggestions = <String>[
    'Come sta andando il mio quadro clinico negli ultimi giorni?',
    'Quali cambiamenti dovrei portare al medico alla prossima visita?',
    'Ci sono trend o associazioni importanti da tenere d occhio?',
    'Cosa mi manca per avere un quadro piu completo?',
  ];

  final _questionController = TextEditingController();
  DateTime _referenceDate = DateUtils.dateOnly(DateTime.now());
  bool _isAskingQuestion = false;
  bool _isGeneratingTrend = false;
  bool _isGeneratingPreVisit = false;
  bool _isGeneratingDocument = false;
  String? _questionResult;
  String? _trendResult;
  String? _preVisitResult;
  String? _documentResult;
  String? _questionError;
  String? _trendError;
  String? _preVisitError;
  String? _documentError;
  String? _observedActiveProfileId;
  bool _hasCompletedInitialProfileSync = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null && widget.initialQuestion!.trim().isNotEmpty) {
      _questionController.text = widget.initialQuestion!.trim();
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _syncProfileScope(String? activeProfileId) {
    final normalizedProfileId = activeProfileId?.trim().isEmpty == true
        ? null
        : activeProfileId?.trim();

    if (!_hasCompletedInitialProfileSync) {
      if (_observedActiveProfileId != normalizedProfileId) {
        _observedActiveProfileId = normalizedProfileId;
      }
      if (normalizedProfileId != null) {
        _hasCompletedInitialProfileSync = true;
      }
      return;
    }

    if (_observedActiveProfileId == normalizedProfileId) {
      return;
    }

    _observedActiveProfileId = normalizedProfileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _observedActiveProfileId != normalizedProfileId) {
        return;
      }
      setState(() {
        _questionController.clear();
        _questionResult = null;
        _trendResult = null;
        _preVisitResult = null;
        _documentResult = null;
        _questionError = null;
        _trendError = null;
        _preVisitError = null;
        _documentError = null;
        _isAskingQuestion = false;
        _isGeneratingTrend = false;
        _isGeneratingPreVisit = false;
        _isGeneratingDocument = false;
      });
      if (widget.documentId != null) {
        ref.invalidate(documentDetailProvider(widget.documentId!));
      }
    });
  }

  Future<void> _pickReferenceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        _referenceDate = DateUtils.dateOnly(picked);
        _questionResult = null;
        _trendResult = null;
        _preVisitResult = null;
      });
    }
  }

  Future<void> _recordHistoryEntry(
    GemmaCenterHistoryEntry entry,
    String? profileScopeAtStart,
  ) async {
    if (profileScopeAtStart == null ||
        profileScopeAtStart != _observedActiveProfileId) {
      return;
    }

    try {
      await ref.read(gemmaCenterHistoryStoreProvider).appendEntry(
        entry,
        profileScope: profileScopeAtStart,
          );
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      ref.invalidate(gemmaCenterHistoryProvider);
    } catch (_) {
      // History persistence is best effort; keep the generated answer visible.
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _questionError = 'Scrivi una domanda prima di chiedere a Gemma.');
      return;
    }

    final profileScopeAtStart = _observedActiveProfileId;

    setState(() {
      _isAskingQuestion = true;
      _questionError = null;
    });
    try {
      final answer = await ref.read(gemmaCoachServiceProvider).answerQuestion(
        question: question,
        referenceDate: _referenceDate,
      );
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _questionResult = answer);
      await _recordHistoryEntry(
        GemmaCenterHistoryEntry.question(
          question: question,
          response: answer,
          referenceDate: _referenceDate,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _questionError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && profileScopeAtStart == _observedActiveProfileId) {
        setState(() => _isAskingQuestion = false);
      }
    }
  }

  Future<void> _generateTrend() async {
    final profileScopeAtStart = _observedActiveProfileId;
    setState(() {
      _isGeneratingTrend = true;
      _trendError = null;
    });
    try {
      final answer = await ref.read(gemmaCoachServiceProvider).explainTrend(
        referenceDate: _referenceDate,
      );
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _trendResult = answer);
      await _recordHistoryEntry(
        GemmaCenterHistoryEntry.trend(
          response: answer,
          referenceDate: _referenceDate,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _trendError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && profileScopeAtStart == _observedActiveProfileId) {
        setState(() => _isGeneratingTrend = false);
      }
    }
  }

  Future<void> _generatePreVisit() async {
    final profileScopeAtStart = _observedActiveProfileId;
    setState(() {
      _isGeneratingPreVisit = true;
      _preVisitError = null;
    });
    try {
      final answer = await ref.read(gemmaCoachServiceProvider).buildPreVisitBrief(
        referenceDate: _referenceDate,
      );
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _preVisitResult = answer);
      await _recordHistoryEntry(
        GemmaCenterHistoryEntry.preVisit(
          response: answer,
          referenceDate: _referenceDate,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _preVisitError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && profileScopeAtStart == _observedActiveProfileId) {
        setState(() => _isGeneratingPreVisit = false);
      }
    }
  }

  Future<void> _generateDocumentSummary(ClinicalDocumentDetail detail) async {
    final profileScopeAtStart = _observedActiveProfileId;
    setState(() {
      _isGeneratingDocument = true;
      _documentError = null;
    });
    try {
      final answer = await ref.read(gemmaCoachServiceProvider).summarizeDocument(
        detail: detail,
      );
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _documentResult = answer);
      await _recordHistoryEntry(
        GemmaCenterHistoryEntry.documentSummary(
          response: answer,
          documentId: detail.id,
          documentTitle: detail.title,
          referenceDate: detail.examDate ?? detail.uploadDate,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _documentError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && profileScopeAtStart == _observedActiveProfileId) {
        setState(() => _isGeneratingDocument = false);
      }
    }
  }

  Widget _buildStatusCard() {
    final statusAsync = ref.watch(onDeviceAiStatusProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    return statusAsync.when(
      data: (status) => SectionCard(
        title: 'Gemma 4 sul dispositivo',
        subtitle: status.isReady
            ? 'Pronta per domande, pre-visita e documenti.'
            : 'Il runtime non e ancora pronto sul dispositivo.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(status.activeProviderLabel)),
            if (status.modelName != null && status.modelName!.trim().isNotEmpty)
              Chip(label: Text(status.modelName!)),
            Chip(label: Text('Backend ${status.backendPreference}')),
            if (status.lastError != null && status.lastError!.trim().isNotEmpty)
              Chip(label: Text(status.lastError!)),
            Chip(label: Text('Aggiornato ${dateFormat.format(DateTime.now())}')),
          ],
        ),
      ),
      loading: () => const SectionCard(
        title: 'Gemma 4 sul dispositivo',
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => SectionCard(
        title: 'Gemma 4 sul dispositivo',
        subtitle: 'Impossibile leggere lo stato del runtime.',
        child: Text(error.toString()),
      ),
    );
  }

  Widget _buildQuestionSection() {
    return SectionCard(
      title: 'Chiedi alla tua storia',
      subtitle: 'Domande libere su sintomi, trend, farmaci e contesto clinico.',
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
              hintText: 'Es. Come sta andando il mio quadro negli ultimi giorni?',
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
                    onPressed: () => setState(() => _questionController.text = item),
                  ),
                )
                .toList(),
          ),
          if (_questionError != null) ...[
            const SizedBox(height: 12),
            Text(
              _questionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isAskingQuestion ? null : _askQuestion,
              icon: _isAskingQuestion
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: Text(_isAskingQuestion ? 'Analizzo...' : 'Chiedi a Gemma'),
            ),
          ),
          if (_questionResult != null) ...[
            const SizedBox(height: 16),
            SummaryContentView(content: _questionResult!, constrainHeight: false),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendSection() {
    return SectionCard(
      title: 'Spiega l andamento',
      subtitle: 'Gemma confronta i dati recenti e mette in evidenza i pattern.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usa la data selezionata come riferimento per il periodo analizzato.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickReferenceDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(DateFormat('dd MMM yyyy', 'it_IT').format(_referenceDate)),
              ),
              FilledButton.tonalIcon(
                onPressed: _isGeneratingTrend ? null : _generateTrend,
                icon: _isGeneratingTrend
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.trending_up_outlined),
                label: Text(_isGeneratingTrend ? 'Genero...' : 'Spiega andamento'),
              ),
            ],
          ),
          if (_trendError != null) ...[
            const SizedBox(height: 12),
            Text(
              _trendError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_trendResult != null) ...[
            const SizedBox(height: 16),
            SummaryContentView(content: _trendResult!, constrainHeight: false),
          ],
        ],
      ),
    );
  }

  Widget _buildPreVisitSection() {
    return SectionCard(
      title: 'Pre-visita assistita',
      subtitle: 'Prepara una scheda da portare al medico con domande e punti chiave.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gemma sintetizza i dati locali in una scheda pratica per la visita.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickReferenceDate,
                icon: const Icon(Icons.event_outlined),
                label: Text('Data: ${DateFormat('dd MMM yyyy', 'it_IT').format(_referenceDate)}'),
              ),
              FilledButton.icon(
                onPressed: _isGeneratingPreVisit ? null : _generatePreVisit,
                icon: _isGeneratingPreVisit
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.assignment_outlined),
                label: Text(_isGeneratingPreVisit ? 'Genero...' : 'Genera scheda'),
              ),
            ],
          ),
          if (_preVisitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _preVisitError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_preVisitResult != null) ...[
            const SizedBox(height: 16),
            SummaryContentView(content: _preVisitResult!, constrainHeight: false),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
    final documentId = widget.documentId;
    final documentAsync = documentId == null
        ? null
        : ref.watch(documentDetailProvider(documentId));

    return SectionCard(
      title: 'Documento corrente',
      subtitle: documentId == null
          ? 'Apri un documento dal dettaglio per sintetizzarlo con Gemma.'
          : 'Gemma legge OCR e strutture estratte del documento selezionato.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (documentAsync != null)
            documentAsync.when(
              data: (detail) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(detail.title)),
                      Chip(label: Text(detail.documentType)),
                      Chip(label: Text(documentStorageLabel(detail.storageLocation))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail.ocrText != null && detail.ocrText!.trim().isNotEmpty
                        ? 'Il documento contiene testo OCR utile per una sintesi di Gemma.'
                        : 'Il documento ha metadati e sezioni strutturate da cui estrarre un riassunto prudente.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _isGeneratingDocument ? null : () => _generateDocumentSummary(detail),
                    icon: _isGeneratingDocument
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: Text(_isGeneratingDocument ? 'Genero...' : 'Riassumi documento'),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
            )
          else
            Text(
              'Da un dettaglio documento puoi aprire questa schermata e chiedere a Gemma di spiegarlo in parole semplici.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (_documentError != null) ...[
            const SizedBox(height: 12),
            Text(
              _documentError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_documentResult != null) ...[
            const SizedBox(height: 16),
            SummaryContentView(content: _documentResult!, constrainHeight: false),
          ],
        ],
      ),
    );
  }

  Future<void> _clearHistoryForActiveProfile() async {
    final profileScope = _observedActiveProfileId;
    if (profileScope == null) {
      return;
    }

    try {
      await ref.read(gemmaCenterHistoryStoreProvider).clearEntries(
        profileScope: profileScope,
          );
      if (!mounted || profileScope != _observedActiveProfileId) {
        return;
      }
      ref.invalidate(gemmaCenterHistoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cronologia di questo profilo svuotata.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile svuotare la cronologia: $error')),
      );
    }
  }

  Widget _buildHistorySection(AsyncValue<List<GemmaCenterHistoryEntry>> historyAsync) {
    return SectionCard(
      title: 'Cronologia di questo profilo',
      subtitle: 'Le risposte restano separate per profilo attivo.',
      action: TextButton.icon(
        onPressed: _observedActiveProfileId == null ? null : _clearHistoryForActiveProfile,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Svuota'),
      ),
      child: historyAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Text('Nessuna risposta salvata per questo profilo.');
          }

          return Column(
            children: [
              for (var index = 0; index < entries.length && index < 6; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                _HistoryEntryCard(entry: entries[index]),
              ],
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text(error.toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeProfileId = ref.watch(activeProfileIdProvider).asData?.value;
    final historyAsync = ref.watch(gemmaCenterHistoryProvider);
    _syncProfileScope(activeProfileId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma Center'),
        bottom: activeProfileId == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Profilo attivo: ${activeProfileId.trim().isEmpty ? 'non selezionato' : activeProfileId.trim()}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: () {
              ref.invalidate(onDeviceAiStatusProvider);
              if (widget.documentId != null) {
                ref.invalidate(documentDetailProvider(widget.documentId!));
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ClinicalScopeNotice(
            title: 'Gemma per supporto e sintesi',
            message:
                'Gemma riordina i dati locali per domande, pre-visita e documenti. Non sostituisce il medico e non sostituisce i controlli deterministici di sicurezza.',
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 12),
          _buildStatusCard(),
          const SizedBox(height: 12),
          _buildQuestionSection(),
          const SizedBox(height: 12),
          _buildTrendSection(),
          const SizedBox(height: 12),
          _buildPreVisitSection(),
          const SizedBox(height: 12),
          _buildDocumentSection(),
          const SizedBox(height: 12),
          _buildHistorySection(historyAsync),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry});

  final GemmaCenterHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          entry.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          [
            entry.kindLabel,
            DateFormat('dd MMM yyyy, HH:mm', 'it_IT').format(entry.createdAt.toLocal()),
            if (entry.referenceDate != null)
              'Rif. ${DateFormat('dd MMM yyyy', 'it_IT').format(entry.referenceDate!.toLocal())}',
          ].join(' • '),
        ),
        children: [
          if (entry.prompt != null && entry.prompt!.trim().isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Prompt',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 6),
            Text(entry.prompt!),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Risposta',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 8),
          SummaryContentView(content: entry.response, constrainHeight: false),
        ],
      ),
    );
  }
}
