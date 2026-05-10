import 'dart:async';

import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/generation_phase_label.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GemmaCenterScreen extends ConsumerStatefulWidget {
  const GemmaCenterScreen({super.key, this.initialQuestion, this.documentId});

  final String? initialQuestion;
  final String? documentId;

  @override
  ConsumerState<GemmaCenterScreen> createState() => _GemmaCenterScreenState();
}

AppLocalizations _l10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

class _GemmaCenterScreenState extends ConsumerState<GemmaCenterScreen> {
  final _questionController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _pageScrollController = ScrollController(keepScrollOffset: false);
  DateTime _referenceDate = DateUtils.dateOnly(DateTime.now());
  bool _isAskingQuestion = false;
  bool _isGeneratingTrend = false;
  bool _isGeneratingPreVisit = false;
  bool _isGeneratingDocument = false;
  DateTime? _questionGenerationStartedAt;
  DateTime? _trendGenerationStartedAt;
  DateTime? _preVisitGenerationStartedAt;
  DateTime? _documentGenerationStartedAt;
  String? _trendResult;
  String? _preVisitResult;
  String? _documentResult;
  String? _questionError;
  String? _trendError;
  String? _preVisitError;
  String? _documentError;
  String? _observedActiveProfileId;
  bool _hasCompletedInitialProfileSync = false;
  List<_GemmaChatMessage> _chatMessages = const <_GemmaChatMessage>[];
  Timer? _questionStreamingTimer;
  bool _chatAutoSnapEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _snapPageToChat());
    if (widget.initialQuestion != null &&
        widget.initialQuestion!.trim().isNotEmpty) {
      _questionController.text = widget.initialQuestion!.trim();
    }
  }

  @override
  void dispose() {
    _questionStreamingTimer?.cancel();
    _pageScrollController.dispose();
    _chatScrollController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  void _snapPageToChat() {
    if (!_pageScrollController.hasClients) {
      return;
    }
    _pageScrollController.jumpTo(0);
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
        _trendResult = null;
        _preVisitResult = null;
        _documentResult = null;
        _chatMessages = const <_GemmaChatMessage>[];
        _chatAutoSnapEnabled = true;
        _questionError = null;
        _trendError = null;
        _preVisitError = null;
        _documentError = null;
        _isAskingQuestion = false;
        _isGeneratingTrend = false;
        _isGeneratingPreVisit = false;
        _isGeneratingDocument = false;
        _questionGenerationStartedAt = null;
        _trendGenerationStartedAt = null;
        _preVisitGenerationStartedAt = null;
        _documentGenerationStartedAt = null;
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
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        _referenceDate = DateUtils.dateOnly(picked);
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
      await ref
          .read(gemmaCenterHistoryStoreProvider)
          .appendEntry(entry, profileScope: profileScopeAtStart);
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      ref.invalidate(gemmaCenterHistoryProvider);
    } catch (_) {
      // History persistence is best effort; keep the generated answer visible.
    }
  }

  Future<void> _askQuestion() async {
    final l10n = _l10nOf(context);
    final languageCode = appLanguageCodeFromLocale(
      Localizations.localeOf(context),
    );
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(
        () => _questionError = l10n.insightsWriteAQuestionBeforeAskingGemma,
      );
      return;
    }

    final profileScopeAtStart = _observedActiveProfileId;

    final startedAt = DateTime.now();
    _questionStreamingTimer?.cancel();
    setState(() {
      _isAskingQuestion = true;
      _questionError = null;
      _questionGenerationStartedAt = startedAt;
      _questionController.clear();
      _chatMessages = [
        ..._chatMessages,
        _GemmaChatMessage.user(question),
        const _GemmaChatMessage.assistant('', isStreaming: true),
      ];
    });
    _scrollChatToBottom();
    var streamingStarted = false;
    try {
      final answer = await ref
          .read(gemmaCoachServiceProvider)
          .answerQuestion(question: question, referenceDate: _referenceDate);
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      streamingStarted = true;
      _streamAssistantAnswer(answer);
      await _recordHistoryEntry(
        GemmaCenterHistoryEntry.question(
          question: question,
          response: answer,
          referenceDate: _referenceDate,
          languageCode: languageCode,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() {
        _questionError = error.toString().replaceFirst('Exception: ', '');
        _replaceLastAssistantMessage(
          l10n.insightsCouldNotAnswerThisTime(_questionError!),
          isStreaming: false,
        );
      });
    } finally {
      if (mounted &&
          profileScopeAtStart == _observedActiveProfileId &&
          !streamingStarted) {
        setState(() {
          _isAskingQuestion = false;
          _questionGenerationStartedAt = null;
        });
      }
    }
  }

  void _streamAssistantAnswer(String answer) {
    _questionStreamingTimer?.cancel();
    var index = 0;
    final chunkSize = answer.length > 900 ? 10 : 5;
    _questionStreamingTimer = Timer.periodic(const Duration(milliseconds: 24), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      index = (index + chunkSize).clamp(0, answer.length);
      final completed = index >= answer.length;
      setState(() {
        _replaceLastAssistantMessage(
          answer.substring(0, index),
          isStreaming: !completed,
        );
        if (completed) {
          _isAskingQuestion = false;
          _questionGenerationStartedAt = null;
        }
      });
      _scrollChatToBottom();
      if (completed) {
        timer.cancel();
      }
    });
  }

  void _replaceLastAssistantMessage(String text, {required bool isStreaming}) {
    final messages = [..._chatMessages];
    for (var index = messages.length - 1; index >= 0; index--) {
      if (!messages[index].isUser) {
        messages[index] = _GemmaChatMessage.assistant(
          text,
          isStreaming: isStreaming,
        );
        _chatMessages = messages;
        return;
      }
    }
    _chatMessages = [
      ...messages,
      _GemmaChatMessage.assistant(text, isStreaming: isStreaming),
    ];
  }

  void _scrollChatToBottom() {
    if (!_chatAutoSnapEnabled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) {
        return;
      }
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _generateTrend() async {
    final languageCode = appLanguageCodeFromLocale(
      Localizations.localeOf(context),
    );
    final profileScopeAtStart = _observedActiveProfileId;
    final startedAt = DateTime.now();
    setState(() {
      _isGeneratingTrend = true;
      _trendError = null;
      _trendGenerationStartedAt = startedAt;
    });
    try {
      final answer = await ref
          .read(gemmaCoachServiceProvider)
          .explainTrend(referenceDate: _referenceDate);
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _trendResult = answer);
      await _recordHistoryEntry(
        GemmaCenterHistoryEntry.trend(
          response: answer,
          referenceDate: _referenceDate,
          languageCode: languageCode,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(
        () => _trendError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted && profileScopeAtStart == _observedActiveProfileId) {
        setState(() {
          _isGeneratingTrend = false;
          _trendGenerationStartedAt = null;
        });
      }
    }
  }

  Future<void> _generatePreVisit() async {
    final languageCode = appLanguageCodeFromLocale(
      Localizations.localeOf(context),
    );
    final profileScopeAtStart = _observedActiveProfileId;
    final startedAt = DateTime.now();
    setState(() {
      _isGeneratingPreVisit = true;
      _preVisitError = null;
      _preVisitGenerationStartedAt = startedAt;
    });
    try {
      final answer = await ref
          .read(gemmaCoachServiceProvider)
          .buildPreVisitBrief(referenceDate: _referenceDate);
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(() => _preVisitResult = answer);
      await _recordHistoryEntry(
        GemmaCenterHistoryEntry.preVisit(
          response: answer,
          referenceDate: _referenceDate,
          languageCode: languageCode,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(
        () => _preVisitError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted && profileScopeAtStart == _observedActiveProfileId) {
        setState(() {
          _isGeneratingPreVisit = false;
          _preVisitGenerationStartedAt = null;
        });
      }
    }
  }

  Future<void> _generateDocumentSummary(ClinicalDocumentDetail detail) async {
    final languageCode = appLanguageCodeFromLocale(
      Localizations.localeOf(context),
    );
    final profileScopeAtStart = _observedActiveProfileId;
    final startedAt = DateTime.now();
    setState(() {
      _isGeneratingDocument = true;
      _documentError = null;
      _documentGenerationStartedAt = startedAt;
    });
    try {
      final answer = await ref
          .read(gemmaCoachServiceProvider)
          .summarizeDocument(detail: detail);
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
          languageCode: languageCode,
        ),
        profileScopeAtStart,
      );
    } catch (error) {
      if (!mounted || profileScopeAtStart != _observedActiveProfileId) {
        return;
      }
      setState(
        () => _documentError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted && profileScopeAtStart == _observedActiveProfileId) {
        setState(() {
          _isGeneratingDocument = false;
          _documentGenerationStartedAt = null;
        });
      }
    }
  }

  Widget _buildQuestionSection() {
    final l10n = _l10nOf(context);
    final questionSuggestions = <String>[
      l10n.insightsHowHasMyClinicalPictureBeen,
      l10n.insightsWhatChangesShouldIBringTo,
      l10n.insightsAreThereAnyImportantTrendsOr,
      l10n.insightsWhatAmIMissingToGet,
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final chatHeight = _snappedChatHeight(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF202544), Color(0xFF15192B)]
              : const [Color(0xFFF0F2FF), Color(0xFFFFF4EF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.insightsTalkWithGemma,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.insightsCalmPlace,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GemmaSafetyPill(
                icon: Icons.lock_outline,
                label: l10n.insightsLocalFirst,
              ),
              _GemmaSafetyPill(
                icon: Icons.health_and_safety_outlined,
                label: l10n.insightsNoDiagnosis,
              ),
              _GemmaSafetyPill(
                icon: Icons.fact_check_outlined,
                label: l10n.insightsSafetyChecksStaySeparate,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: chatHeight,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: isDark ? 0.62 : 0.78),
              borderRadius: BorderRadius.circular(24),
            ),
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle &&
                    _chatAutoSnapEnabled) {
                  setState(() => _chatAutoSnapEnabled = false);
                }
                return false;
              },
              child: _chatMessages.isEmpty
                  ? const _GemmaWelcomePanel()
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        return _GemmaChatBubble(message: _chatMessages[index]);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: questionSuggestions
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(item),
                        onPressed: _isAskingQuestion
                            ? null
                            : () => setState(
                                () => _questionController.text = item,
                              ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: l10n.insightsAskAnythingAboutYourDiary,
                    hintText: l10n.insightsAskDiaryExample,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _isAskingQuestion ? null : _askQuestion,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isAskingQuestion
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
          if (_isAskingQuestion) ...[
            const SizedBox(height: 8),
            GenerationPhaseLabel(
              isActive: true,
              startedAt: _questionGenerationStartedAt,
              idleLabel: l10n.insightsGemmaThinking,
              showProgress: true,
            ),
          ],
        ],
      ),
    );
  }

  double _snappedChatHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final pageHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        kToolbarHeight -
        40 -
        32;
    final compactWidth = media.size.width < 380;
    final fixedChrome = compactWidth ? 280.0 : 252.0;
    return (pageHeight - fixedChrome).clamp(170.0, 360.0);
  }

  Widget _buildTrendSection() {
    final l10n = _l10nOf(context);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    return _GemmaToolCard(
      title: l10n.insightsSpotPatterns,
      subtitle: l10n.insightsSpotPatternsSubtitle,
      icon: Icons.trending_up_rounded,
      color: const Color(0xFF18A999),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.insightsPickADay,
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
                label: Text(
                  DateFormat('dd MMM yyyy', localeName).format(_referenceDate),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _isGeneratingTrend ? null : _generateTrend,
                icon: const Icon(Icons.trending_up_outlined),
                label: GenerationPhaseLabel(
                  isActive: _isGeneratingTrend,
                  startedAt: _trendGenerationStartedAt,
                  idleLabel: l10n.insightsExplainTrend,
                  showProgress: true,
                ),
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
    final l10n = _l10nOf(context);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    return _GemmaToolCard(
      title: l10n.insightsPrepareYourVisit,
      subtitle: l10n.insightsPrepareVisitSubtitle,
      icon: Icons.assignment_rounded,
      color: const Color(0xFFFF7A59),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.insightsGemmaCreatesSummary,
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
                label: Text(
                  l10n.insightsDateLabel(
                    DateFormat(
                      'dd MMM yyyy',
                      localeName,
                    ).format(_referenceDate),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _isGeneratingPreVisit ? null : _generatePreVisit,
                icon: const Icon(Icons.assignment_outlined),
                label: GenerationPhaseLabel(
                  isActive: _isGeneratingPreVisit,
                  startedAt: _preVisitGenerationStartedAt,
                  idleLabel: l10n.insightsPrepareNote,
                  showProgress: true,
                ),
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
            SummaryContentView(
              content: _preVisitResult!,
              constrainHeight: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
    final l10n = _l10nOf(context);
    final documentId = widget.documentId;
    final documentAsync = documentId == null
        ? null
        : ref.watch(documentDetailProvider(documentId));

    return _GemmaToolCard(
      title: l10n.insightsExplainAFile,
      subtitle: documentId == null
          ? l10n.insightsExplainFileSubtitle
          : l10n.insightsGemmaCanSummarizeSelectedFile,
      icon: Icons.description_rounded,
      color: const Color(0xFF23A6D5),
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
                      Chip(
                        label: Text(
                          documentStorageLabel(detail.storageLocation),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail.ocrText != null && detail.ocrText!.trim().isNotEmpty
                        ? l10n.insightsDocumentHasOcr
                        : l10n.insightsDocumentStructuredSummary,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _isGeneratingDocument
                        ? null
                        : () => _generateDocumentSummary(detail),
                    icon: const Icon(Icons.description_outlined),
                    label: GenerationPhaseLabel(
                      isActive: _isGeneratingDocument,
                      startedAt: _documentGenerationStartedAt,
                      idleLabel: l10n.insightsSummarizeDocument,
                      showProgress: true,
                    ),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
            )
          else
            Text(
              l10n.insightsOpenAnyFileFromDocuments,
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
            SummaryContentView(
              content: _documentResult!,
              constrainHeight: false,
            ),
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
      await ref
          .read(gemmaCenterHistoryStoreProvider)
          .clearEntries(profileScope: profileScope);
      if (!mounted || profileScope != _observedActiveProfileId) {
        return;
      }
      ref.invalidate(gemmaCenterHistoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10nOf(context).insightsProfileHistoryCleared)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _l10nOf(context).insightsUnableToClearHistory(error.toString()),
          ),
        ),
      );
    }
  }

  Widget _buildHistorySection(
    AsyncValue<List<GemmaCenterHistoryEntry>> historyAsync,
  ) {
    final l10n = _l10nOf(context);
    return _GemmaToolCard(
      title: l10n.insightsPastAnswers,
      subtitle: l10n.insightsPastAnswersSubtitle,
      icon: Icons.history_rounded,
      color: const Color(0xFF8E5CF7),
      action: TextButton.icon(
        onPressed: _observedActiveProfileId == null
            ? null
            : _clearHistoryForActiveProfile,
        icon: const Icon(Icons.delete_outline),
        label: Text(l10n.insightsClear),
      ),
      child: historyAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Text(l10n.insightsNoAnswersSaved);
          }

          return Column(
            children: [
              for (
                var index = 0;
                index < entries.length && index < 6;
                index++
              ) ...[
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
    final l10n = _l10nOf(context);
    final activeProfileId = ref.watch(activeProfileIdProvider).asData?.value;
    final historyAsync = ref.watch(gemmaCenterHistoryProvider);
    _syncProfileScope(activeProfileId);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.insightsGemmaCenter),
        bottom: activeProfileId == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    l10n.insightsActiveProfile(
                      activeProfileId.trim().isEmpty
                          ? 'not selected'
                          : activeProfileId.trim(),
                    ),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
        actions: [
          IconButton(
            tooltip: l10n.insightsRefresh,
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
        controller: _pageScrollController,
        padding: const EdgeInsets.all(16),
        children: [
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

class _GemmaToolCard extends StatelessWidget {
  const _GemmaToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _GemmaChatMessage {
  const _GemmaChatMessage._({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  const _GemmaChatMessage.user(String text) : this._(text: text, isUser: true);

  const _GemmaChatMessage.assistant(String text, {bool isStreaming = false})
    : this._(text: text, isUser: false, isStreaming: isStreaming);

  final String text;
  final bool isUser;
  final bool isStreaming;
}

class _GemmaWelcomePanel extends StatelessWidget {
  const _GemmaWelcomePanel();

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.insightsAskOneQuestionAtATime,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.insightsGemmaWelcome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GemmaChatBubble extends StatelessWidget {
  const _GemmaChatBubble({required this.message});

  final _GemmaChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final foreground = isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 20),
            ),
          ),
          child: message.isStreaming && message.text.isEmpty
              ? const _GemmaTypingDots()
              : SelectableText(
                  message.isStreaming ? '${message.text}|' : message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    height: 1.42,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GemmaTypingDots extends StatefulWidget {
  const _GemmaTypingDots();

  @override
  State<_GemmaTypingDots> createState() => _GemmaTypingDotsState();
}

class _GemmaTypingDotsState extends State<_GemmaTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = (_controller.value * 3).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final isActive = index == active;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: isActive ? 8 : 6,
              height: isActive ? 8 : 6,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: isActive ? 0.9 : 0.35),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _GemmaSafetyPill extends StatelessWidget {
  const _GemmaSafetyPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
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
    final l10n = _l10nOf(context);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          entry.title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            entry.kindLabel,
            DateFormat(
              'dd MMM yyyy, HH:mm',
              localeName,
            ).format(entry.createdAt.toLocal()),
            if (entry.referenceDate != null)
              l10n.insightsReferenceDate(
                DateFormat(
                  'dd MMM yyyy',
                  localeName,
                ).format(entry.referenceDate!.toLocal()),
              ),
          ].join(' • '),
        ),
        children: [
          if (entry.prompt != null && entry.prompt!.trim().isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.insightsPrompt,
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
              l10n.insightsAnswer,
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
