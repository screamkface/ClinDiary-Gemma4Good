import 'dart:async';

import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';
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
  DateTime? _questionGenerationStartedAt;
  DateTime? _trendGenerationStartedAt;
  DateTime? _preVisitGenerationStartedAt;
  String? _trendResult;
  String? _preVisitResult;
  String? _questionError;
  String? _trendError;
  String? _preVisitError;
  String? _observedActiveProfileId;
  bool _hasCompletedInitialProfileSync = false;
  List<_GemmaChatMessage> _chatMessages = const <_GemmaChatMessage>[];
  StreamSubscription<String>? _questionStreamSub;
  StreamSubscription<String>? _trendStreamSub;
  StreamSubscription<String>? _preVisitStreamSub;
  String _trendStreamBuffer = '';
  String _preVisitStreamBuffer = '';
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
    _questionStreamSub?.cancel();
    _trendStreamSub?.cancel();
    _preVisitStreamSub?.cancel();
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
        _chatMessages = const <_GemmaChatMessage>[];
        _chatAutoSnapEnabled = true;
        _questionError = null;
        _trendError = null;
        _preVisitError = null;
        _isAskingQuestion = false;
        _isGeneratingTrend = false;
        _isGeneratingPreVisit = false;
        _questionGenerationStartedAt = null;
        _trendGenerationStartedAt = null;
        _preVisitGenerationStartedAt = null;
      });
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

    _questionStreamSub?.cancel();
    final startedAt = DateTime.now();
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

    var fullAnswer = '';
    var thinkingContent = '';

    final stream = ref
        .read(gemmaCoachServiceProvider)
        .answerQuestionStream(
          question: question,
          referenceDate: _referenceDate,
        );

    _questionStreamSub = stream.listen(
      (token) {
        if (!mounted) return;
        if (token.startsWith('[thinking]')) {
          thinkingContent += token.replaceFirst('[thinking]', '');
          return;
        }
        if (token.endsWith('[/thinking]')) {
          thinkingContent += token.replaceFirst('[/thinking]', '');
          return;
        }
        fullAnswer += token;
        setState(() {
          _replaceLastAssistantMessage(fullAnswer, isStreaming: true);
        });
        _scrollChatToBottom();
      },
      onDone: () async {
        if (!mounted || profileScopeAtStart != _observedActiveProfileId) return;
        setState(() {
          _replaceLastAssistantMessage(
            fullAnswer,
            isStreaming: false,
            thinking: thinkingContent.isEmpty ? null : thinkingContent,
          );
          _isAskingQuestion = false;
          _questionGenerationStartedAt = null;
        });
        await _recordHistoryEntry(
          GemmaCenterHistoryEntry.question(
            question: question,
            response: fullAnswer,
            referenceDate: _referenceDate,
            languageCode: languageCode,
          ),
          profileScopeAtStart,
        );
      },
      onError: (error) {
        if (!mounted || profileScopeAtStart != _observedActiveProfileId) return;
        setState(() {
          _questionError = error.toString().replaceFirst('Exception: ', '');
          _replaceLastAssistantMessage(
            l10n.insightsCouldNotAnswerThisTime(_questionError!),
            isStreaming: false,
          );
          _isAskingQuestion = false;
          _questionGenerationStartedAt = null;
        });
      },
    );
  }

  void _replaceLastAssistantMessage(
    String text, {
    required bool isStreaming,
    String? thinking,
  }) {
    final messages = [..._chatMessages];
    for (var index = messages.length - 1; index >= 0; index--) {
      if (!messages[index].isUser) {
        messages[index] = _GemmaChatMessage.assistant(
          text,
          isStreaming: isStreaming,
          thinking: thinking,
        );
        _chatMessages = messages;
        return;
      }
    }
    _chatMessages = [
      ...messages,
      _GemmaChatMessage.assistant(
        text,
        isStreaming: isStreaming,
        thinking: thinking,
      ),
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
    _trendStreamSub?.cancel();
    final startedAt = DateTime.now();
    setState(() {
      _isGeneratingTrend = true;
      _trendError = null;
      _trendGenerationStartedAt = startedAt;
      _trendStreamBuffer = '';
      _trendResult = null;
    });

    final stream = ref
        .read(gemmaCoachServiceProvider)
        .explainTrendStream(referenceDate: _referenceDate);

    _trendStreamSub = stream.listen(
      (token) {
        if (!mounted) return;
        setState(() => _trendStreamBuffer += token);
      },
      onDone: () async {
        if (!mounted || profileScopeAtStart != _observedActiveProfileId) return;
        setState(() {
          _trendResult = _trendStreamBuffer;
          _isGeneratingTrend = false;
          _trendGenerationStartedAt = null;
        });
        await _recordHistoryEntry(
          GemmaCenterHistoryEntry.trend(
            response: _trendStreamBuffer,
            referenceDate: _referenceDate,
            languageCode: languageCode,
          ),
          profileScopeAtStart,
        );
      },
      onError: (error) {
        if (!mounted || profileScopeAtStart != _observedActiveProfileId) return;
        setState(() {
          _trendError = error.toString().replaceFirst('Exception: ', '');
          _isGeneratingTrend = false;
          _trendGenerationStartedAt = null;
        });
      },
    );
  }

  Future<void> _generatePreVisit() async {
    final languageCode = appLanguageCodeFromLocale(
      Localizations.localeOf(context),
    );
    final profileScopeAtStart = _observedActiveProfileId;
    _preVisitStreamSub?.cancel();
    final startedAt = DateTime.now();
    setState(() {
      _isGeneratingPreVisit = true;
      _preVisitError = null;
      _preVisitGenerationStartedAt = startedAt;
      _preVisitStreamBuffer = '';
      _preVisitResult = null;
    });

    final stream = ref
        .read(gemmaCoachServiceProvider)
        .buildPreVisitBriefStream(referenceDate: _referenceDate);

    _preVisitStreamSub = stream.listen(
      (token) {
        if (!mounted) return;
        setState(() => _preVisitStreamBuffer += token);
      },
      onDone: () async {
        if (!mounted || profileScopeAtStart != _observedActiveProfileId) return;
        setState(() {
          _preVisitResult = _preVisitStreamBuffer;
          _isGeneratingPreVisit = false;
          _preVisitGenerationStartedAt = null;
        });
        await _recordHistoryEntry(
          GemmaCenterHistoryEntry.preVisit(
            response: _preVisitStreamBuffer,
            referenceDate: _referenceDate,
            languageCode: languageCode,
          ),
          profileScopeAtStart,
        );
      },
      onError: (error) {
        if (!mounted || profileScopeAtStart != _observedActiveProfileId) return;
        setState(() {
          _preVisitError = error.toString().replaceFirst('Exception: ', '');
          _isGeneratingPreVisit = false;
          _preVisitGenerationStartedAt = null;
        });
      },
    );
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
                onPressed: _isAskingQuestion
                    ? () {
                        _questionStreamSub?.cancel();
                        _questionStreamSub = null;
                        setState(() {
                          _replaceLastAssistantMessage(
                            _chatMessages.lastWhere((m) => !m.isUser).text,
                            isStreaming: false,
                          );
                          _isAskingQuestion = false;
                          _questionGenerationStartedAt = null;
                        });
                      }
                    : _askQuestion,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isAskingQuestion
                    ? const Icon(Icons.stop_rounded)
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
                onPressed: _isGeneratingTrend
                    ? () {
                        _trendStreamSub?.cancel();
                        _trendStreamSub = null;
                        setState(() {
                          if (_trendStreamBuffer.isNotEmpty) {
                            _trendResult = _trendStreamBuffer;
                          }
                          _isGeneratingTrend = false;
                          _trendGenerationStartedAt = null;
                        });
                      }
                    : _generateTrend,
                icon: Icon(
                  _isGeneratingTrend
                      ? Icons.stop_rounded
                      : Icons.trending_up_outlined,
                ),
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
                onPressed: _isGeneratingPreVisit
                    ? () {
                        _preVisitStreamSub?.cancel();
                        _preVisitStreamSub = null;
                        setState(() {
                          if (_preVisitStreamBuffer.isNotEmpty) {
                            _preVisitResult = _preVisitStreamBuffer;
                          }
                          _isGeneratingPreVisit = false;
                          _preVisitGenerationStartedAt = null;
                        });
                      }
                    : _generatePreVisit,
                icon: Icon(
                  _isGeneratingPreVisit
                      ? Icons.stop_rounded
                      : Icons.assignment_outlined,
                ),
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
            onPressed: () => ref.invalidate(onDeviceAiStatusProvider),
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
    this.thinking,
  });

  const _GemmaChatMessage.user(String text) : this._(text: text, isUser: true);

  const _GemmaChatMessage.assistant(
    String text, {
    bool isStreaming = false,
    String? thinking,
  }) : this._(
         text: text,
         isUser: false,
         isStreaming: isStreaming,
         thinking: thinking,
       );

  final String text;
  final bool isUser;
  final bool isStreaming;
  final String? thinking;
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
    final textTheme = Theme.of(context).textTheme;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.thinking != null)
                _GemmaThinkingTile(thinking: message.thinking!),
              if (message.isStreaming && message.text.isEmpty)
                const _GemmaTypingDots()
              else if (message.isStreaming || message.isUser)
                SelectableText(
                  message.isStreaming ? '${message.text}|' : message.text,
                  style: textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    height: 1.42,
                  ),
                )
              else
                _MarkdownBubbleText(text: message.text, foreground: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _GemmaThinkingTile extends StatefulWidget {
  const _GemmaThinkingTile({required this.thinking});

  final String thinking;

  @override
  State<_GemmaThinkingTile> createState() => _GemmaThinkingTileState();
}

class _GemmaThinkingTileState extends State<_GemmaThinkingTile> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ragionamento',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                if (_expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      widget.thinking,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownBubbleText extends StatelessWidget {
  const _MarkdownBubbleText({required this.text, required this.foreground});

  final String text;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle =
        Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: foreground, height: 1.42) ??
        const TextStyle();

    return SelectableText.rich(
      TextSpan(
        style: baseStyle,
        children: _bubbleInlineSpans(text, baseStyle, colorScheme),
      ),
    );
  }
}

List<InlineSpan> _bubbleInlineSpans(
  String text,
  TextStyle baseStyle,
  ColorScheme colorScheme,
) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    r'(\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`)',
  );
  var lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }

    final boldItalic = match.group(2);
    final bold = match.group(3);
    final italic = match.group(4);
    final code = match.group(5);

    if (boldItalic != null) {
      spans.add(
        TextSpan(
          text: boldItalic,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
    } else if (italic != null) {
      spans.add(
        TextSpan(
          text: italic,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (code != null) {
      spans.add(
        TextSpan(
          text: code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! - 1 : 12,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return spans;
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
