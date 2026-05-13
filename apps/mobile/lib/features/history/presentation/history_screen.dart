import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/history/domain/history_day.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/compact_segmented_control.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

AppLocalizations _l10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

DateFormat _safeDateFormat(String pattern, String localeName) {
  try {
    return DateFormat(pattern, localeName);
  } catch (_) {
    return DateFormat(pattern);
  }
}

String _historyEventCountLabel(BuildContext context, int count) {
  return _l10nOf(context).historyEventsCount(count);
}

String _historyDocumentCountLabel(BuildContext context, int count) {
  return _l10nOf(context).historyDocumentsCount(count);
}

String _historyRegeneratedLabel(BuildContext context, DateTime targetDate) {
  final localeName = appDateFormattingLocaleName(
    appLanguageCodeFromLocale(Localizations.localeOf(context)),
  );
  final formatted = _safeDateFormat(
    'dd/MM/yyyy',
    localeName,
  ).format(targetDate);
  return _l10nOf(context).historyDailyReportRegeneratedFor(formatted);
}

String _historyRegenerationFailedLabel(BuildContext context, Object error) {
  return _l10nOf(context).historyRegenerationFailedError(error.toString());
}

String _historyCheckUpLabel(BuildContext context, bool hasEntry) {
  if (hasEntry) {
    return _l10nOf(context).checkUp;
  }
  return _l10nOf(context).historyNoCheckUp;
}

String _historyEnergyLabel(BuildContext context, int value) {
  return _l10nOf(context).historyEnergyValue(value);
}

String _historyMoodLabel(BuildContext context, int value) {
  return _l10nOf(context).historyMoodValue(value);
}

String _historyStressLabel(BuildContext context, int value) {
  return _l10nOf(context).historyStressValue(value);
}

String _historyPainLabel(BuildContext context, int value) {
  return _l10nOf(context).historyPainValue(value);
}

String _historyStepsLabel(BuildContext context, int value) {
  return _l10nOf(context).historyStepsValue(value);
}

String _historySleepLabel(BuildContext context, double hours) {
  return _l10nOf(context).historySleepValue(hours.toStringAsFixed(1));
}

String _historyRestingLabel(BuildContext context, String value) {
  return _l10nOf(context).historyRestingValue(value);
}

String _historyHeartRateLabel(BuildContext context, String value) {
  return _l10nOf(context).historyHeartRateValue(value);
}

String _historySpo2Label(BuildContext context, String value) {
  return _l10nOf(context).historySpo2Value(value);
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  bool _isRegeneratingDailyReport = false;
  InsightSummary? _overrideDailySummary;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _selectedDate = today;
    _focusedMonth = DateTime(today.year, today.month, 1);
  }

  Future<void> _regenerateDailyReport() async {
    final targetDate = _selectedDate;
    final query = InsightSummaryQuery(
      summaryType: 'daily',
      referenceDate: targetDate,
    );
    setState(() => _isRegeneratingDailyReport = true);
    try {
      final summary = await ref
          .read(insightsRepositoryProvider)
          .regenerateSummary(query);
      if (!mounted) {
        return;
      }

      setState(() => _overrideDailySummary = summary);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_historyRegeneratedLabel(context, targetDate))),
      );

      // Salva il recap nel Gemma Center History
      try {
        final activeProfileId = ref
            .read(activeProfileIdProvider)
            .asData
            ?.value
            ?.trim();
        if (activeProfileId != null && activeProfileId.isNotEmpty) {
          final languageCode = appLanguageCodeFromLocale(
            Localizations.localeOf(context),
          );
          await ref
              .read(gemmaCenterHistoryStoreProvider)
              .appendEntry(
                GemmaCenterHistoryEntry.dailyRecap(
                  response: summary.content,
                  referenceDate: targetDate,
                  languageCode: languageCode,
                  createdAt: summary.generatedAt,
                ),
                profileScope: activeProfileId,
              );
          ref.invalidate(gemmaCenterHistoryProvider);
        }
      } catch (_) {
        // Il salvataggio nel Gemma Center è best-effort
      }

      // Invalida il cache locale della history per quella data
      // così il prossimo fetchDay recupererà i dati aggiornati dal backend
      try {
        await ref.read(historyRepositoryProvider).evictDayCache(targetDate);
      } catch (_) {
        // best-effort
      }

      // Aggiorna i provider di history e insights
      ref.invalidate(historyDayProvider(targetDate));
      ref.invalidate(insightSummaryProvider(query));

      if (!mounted) return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_historyRegenerationFailedLabel(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRegeneratingDailyReport = false);
      }
    }
  }

  Future<void> _copyDailyReport(String content) async {
    final l10n = _l10nOf(context);
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.historyReportCopiedToClipboard)),
    );
  }

  void _goToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _selectedDate = today;
      _focusedMonth = DateTime(today.year, today.month, 1);
      _overrideDailySummary = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    final historyAsync = ref.watch(historyDayProvider(_selectedDate));
    final activityDatesAsync = ref.watch(
      historyActivityDatesProvider(_focusedMonth),
    );
    // Watch the daily summary separately
    final dailySummaryQuery = InsightSummaryQuery(
      summaryType: 'daily',
      referenceDate: _selectedDate,
    );
    final dailySummaryAsync = ref.watch(
      insightSummaryProvider(dailySummaryQuery),
    );

    final dateFormat = _safeDateFormat('dd MMM yyyy', localeName);
    Future<void> refreshHistory() async {
      ref.invalidate(historyDayProvider(_selectedDate));
      ref.invalidate(historyActivityDatesProvider(_focusedMonth));
      ref.invalidate(insightSummaryProvider(dailySummaryQuery));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.history3),
          actions: [
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today_outlined),
              label: Text(l10n.todayTitle),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            IconButton(
              onPressed: refreshHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            tabAlignment: TabAlignment.fill,
            tabs: [
              Tab(text: l10n.historyDay),
              Tab(text: l10n.historyCalendar),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HistoryTabList(
              onRefresh: refreshHistory,
              children: [
                historyAsync.when(
                  data: (history) => _HistoryContent(
                    history: history,
                    dailySummaryAsync: dailySummaryAsync,
                    dateFormat: dateFormat,
                    isRegeneratingDailyReport: _isRegeneratingDailyReport,
                    overrideDailySummary: _overrideDailySummary,
                    onCopyDailyReport:
                        (_overrideDailySummary ??
                                dailySummaryAsync.asData?.value ??
                                history.dailySummary) ==
                            null
                        ? null
                        : () => _copyDailyReport(
                            (_overrideDailySummary ??
                                    dailySummaryAsync.asData?.value ??
                                    history.dailySummary)!
                                .content,
                          ),
                    onRegenerateDailyReport: _regenerateDailyReport,
                  ),
                  loading: () => SectionCard(
                    title: l10n.historyDay2,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SectionCard(
                    title: l10n.historyDay3,
                    child: Text(error.toString()),
                  ),
                ),
              ],
            ),
            _HistoryTabList(
              onRefresh: refreshHistory,
              children: [
                SectionCard(
                  title: l10n.historyCalendar2,
                  subtitle: l10n.historyChooseADay,
                  child: activityDatesAsync.when(
                    data: (activityDates) => _HistoryCalendar(
                      focusedMonth: _focusedMonth,
                      selectedDate: _selectedDate,
                      activityDates: activityDates,
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDate = DateUtils.dateOnly(selected);
                          _focusedMonth = DateTime(
                            focused.year,
                            focused.month,
                            1,
                          );
                          _overrideDailySummary = null;
                        });
                      },
                      onPageChanged: (focused) {
                        setState(() {
                          _focusedMonth = DateTime(
                            focused.year,
                            focused.month,
                            1,
                          );
                        });
                      },
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text(error.toString()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTabList extends StatelessWidget {
  const _HistoryTabList({required this.children, required this.onRefresh});

  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}

class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.activityDates,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<DateTime> activityDates;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    final normalizedActivityDates = activityDates
        .map(DateUtils.dateOnly)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TableCalendar<String>(
          locale: localeName,
          firstDay: DateTime(2020),
          lastDay: DateTime.now().add(const Duration(days: 1)),
          focusedDay: focusedMonth,
          startingDayOfWeek: StartingDayOfWeek.monday,
          availableGestures: AvailableGestures.horizontalSwipe,
          rowHeight: 48,
          selectedDayPredicate: (day) => isSameDay(day, selectedDate),
          eventLoader: (day) =>
              normalizedActivityDates.contains(DateUtils.dateOnly(day))
              ? const ['activity']
              : const [],
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
          headerStyle: const HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            markerDecoration: const BoxDecoration(),
            markersMaxCount: 1,
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.historyDotRecordedActivity,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.history,
    required this.dailySummaryAsync,
    required this.dateFormat,
    required this.isRegeneratingDailyReport,
    required this.overrideDailySummary,
    required this.onCopyDailyReport,
    required this.onRegenerateDailyReport,
  });

  final HistoryDay history;
  final AsyncValue<InsightSummary> dailySummaryAsync;
  final DateFormat dateFormat;
  final bool isRegeneratingDailyReport;
  final InsightSummary? overrideDailySummary;
  final VoidCallback? onCopyDailyReport;
  final VoidCallback onRegenerateDailyReport;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final entry = history.dailyEntry;
    final dailySummary =
        overrideDailySummary ??
        dailySummaryAsync.asData?.value ??
        history.dailySummary;

    return Column(
      children: [
        SectionCard(
          title: l10n.historySelectedDay,
          subtitle: l10n.historyQuickOverview,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(label: dateFormat.format(history.targetDate)),
              _SummaryChip(label: _historyCheckUpLabel(context, entry != null)),
              _SummaryChip(
                label: _historyEventCountLabel(
                  context,
                  history.timelineEvents.length,
                ),
              ),
              _SummaryChip(
                label: _historyDocumentCountLabel(
                  context,
                  history.documents.length,
                ),
              ),
              if (dailySummary != null)
                _SummaryChip(label: l10n.historyRecapAvailable),
              if (history.wearableSummary != null)
                _SummaryChip(label: l10n.historyWearable),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HistoryDetailSwitcher(
          history: history,
          dailySummary: dailySummary,
          entry: entry,
          isRegeneratingDailyReport: isRegeneratingDailyReport,
          onCopyDailyReport: onCopyDailyReport,
          onRegenerateDailyReport: onRegenerateDailyReport,
        ),
      ],
    );
  }
}

enum _HistoryDetailTab { recap, checkup, events, documents, wearable }

class _HistoryDetailSwitcher extends StatefulWidget {
  const _HistoryDetailSwitcher({
    required this.history,
    required this.dailySummary,
    required this.entry,
    required this.isRegeneratingDailyReport,
    required this.onCopyDailyReport,
    required this.onRegenerateDailyReport,
  });

  final HistoryDay history;
  final InsightSummary? dailySummary;
  final DailyEntry? entry;
  final bool isRegeneratingDailyReport;
  final VoidCallback? onCopyDailyReport;
  final VoidCallback onRegenerateDailyReport;

  @override
  State<_HistoryDetailSwitcher> createState() => _HistoryDetailSwitcherState();
}

class _HistoryDetailSwitcherState extends State<_HistoryDetailSwitcher> {
  _HistoryDetailTab _selected = _HistoryDetailTab.recap;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final entry = widget.entry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: l10n.historyDayDetails,
          subtitle: l10n.historyOpenOnlyTheSectionYouNeed,
          child: CompactSegmentedControl<_HistoryDetailTab>(
            options: [
              CompactSegmentOption(
                value: _HistoryDetailTab.recap,
                label: l10n.historyRecap,
                icon: Icons.auto_awesome_outlined,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.checkup,
                label: l10n.checkUp,
                icon: Icons.favorite_outline,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.events,
                label: l10n.historyEvents,
                icon: Icons.timeline_outlined,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.documents,
                label: l10n.documents,
                icon: Icons.description_outlined,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.wearable,
                label: l10n.historyWearable2,
                icon: Icons.watch_outlined,
              ),
            ],
            selectedValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
          ),
        ),
        const SizedBox(height: 12),
        switch (_selected) {
          _HistoryDetailTab.recap => SectionCard(
            title: l10n.historyDailyRecap,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onCopyDailyReport != null)
                  IconButton(
                    tooltip: l10n.historyCopyReport,
                    onPressed: widget.onCopyDailyReport,
                    icon: const Icon(Icons.content_copy_outlined),
                  ),
                TextButton.icon(
                  onPressed: widget.isRegeneratingDailyReport
                      ? null
                      : widget.onRegenerateDailyReport,
                  icon: widget.isRegeneratingDailyReport
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    widget.isRegeneratingDailyReport
                        ? l10n.historyRegenerating
                        : l10n.historyRegenerate,
                  ),
                ),
              ],
            ),
            child: widget.dailySummary == null
                ? Text(l10n.historyNoRecapAvailable)
                : SummaryContentView(
                    content: widget.dailySummary!.content,
                    maxHeightFactor: 0.48,
                  ),
          ),
          _HistoryDetailTab.checkup => SectionCard(
            title: l10n.checkUp,
            subtitle: l10n.historyDataRecordedOnTheDay,
            child: entry == null
                ? Text(l10n.historyNoCheckUpRecordedForThis)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (entry.energyLevel != null)
                            _SummaryChip(
                              label: _historyEnergyLabel(
                                context,
                                entry.energyLevel!,
                              ),
                            ),
                          if (entry.moodLevel != null)
                            _SummaryChip(
                              label: _historyMoodLabel(
                                context,
                                entry.moodLevel!,
                              ),
                            ),
                          if (entry.stressLevel != null)
                            _SummaryChip(
                              label: _historyStressLabel(
                                context,
                                entry.stressLevel!,
                              ),
                            ),
                          if (entry.generalPain != null)
                            _SummaryChip(
                              label: _historyPainLabel(
                                context,
                                entry.generalPain!,
                              ),
                            ),
                        ],
                      ),
                      if (entry.generalNotes != null &&
                          entry.generalNotes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card.outlined(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(entry.generalNotes!),
                          ),
                        ),
                      ],
                      if (entry.symptoms.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _MiniSection(
                          title: l10n.historySymptoms,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.symptoms
                                .map(
                                  (item) => _SummaryChip(
                                    label: item.severity == null
                                        ? item.symptomCode
                                        : '${item.symptomCode} ${item.severity}/10',
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      if (entry.vitals.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _MiniSection(
                          title: l10n.historyVitals,
                          child: Column(
                            children: entry.vitals
                                .map(
                                  (item) => Card.outlined(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      dense: true,
                                      title: Text(item.type),
                                      subtitle: Text(
                                        item.measuredAt
                                            .toLocal()
                                            .toString()
                                            .substring(11, 16),
                                      ),
                                      trailing: Text(
                                        '${item.value}${item.unit == null ? '' : ' ${item.unit}'}',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          _HistoryDetailTab.events => SectionCard(
            title: l10n.historyEvents2,
            subtitle: l10n.historyDayTimeline,
            child: widget.history.timelineEvents.isEmpty
                ? Text(l10n.historyNoEventsRecordedForThisDay)
                : Column(
                    children: widget.history.timelineEvents
                        .map((event) => _HistoryEventCard(event: event))
                        .toList(),
                  ),
          ),
          _HistoryDetailTab.documents => SectionCard(
            title: l10n.historyDayDocuments,
            subtitle: l10n.historyUploadedOrLinkedToThisDate,
            child: widget.history.documents.isEmpty
                ? Text(l10n.historyNoDocumentsLinkedToThisDay)
                : Column(
                    children: widget.history.documents
                        .map(
                          (document) => Card.outlined(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              title: Text(document.title),
                              subtitle: Text(document.documentType),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  context.push('/app/documents/${document.id}'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          _HistoryDetailTab.wearable => SectionCard(
            title: l10n.historyWearableData,
            subtitle: l10n.historyDaySummary,
            child: widget.history.wearableSummary == null
                ? Text(l10n.historyNoWearableDataForThisDay)
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.history.wearableSummary!.stepsCount != null)
                        _SummaryChip(
                          label: _historyStepsLabel(
                            context,
                            widget.history.wearableSummary!.stepsCount!,
                          ),
                        ),
                      if (widget.history.wearableSummary!.sleepMinutes != null)
                        _SummaryChip(
                          label: _historySleepLabel(
                            context,
                            widget.history.wearableSummary!.sleepMinutes! / 60,
                          ),
                        ),
                      if (widget.history.wearableSummary!.heartRateAvgBpm !=
                          null)
                        _SummaryChip(
                          label: _historyHeartRateLabel(
                            context,
                            '${widget.history.wearableSummary!.heartRateAvgBpm!.toStringAsFixed(0)} bpm',
                          ),
                        ),
                      if (widget.history.wearableSummary!.restingHeartRateBpm !=
                          null)
                        _SummaryChip(
                          label: _historyRestingLabel(
                            context,
                            '${widget.history.wearableSummary!.restingHeartRateBpm!.toStringAsFixed(0)} bpm',
                          ),
                        ),
                      if (widget.history.wearableSummary!.bloodOxygenAvgPct !=
                          null)
                        _SummaryChip(
                          label: _historySpo2Label(
                            context,
                            '${widget.history.wearableSummary!.bloodOxygenAvgPct!.toStringAsFixed(0)}%',
                          ),
                        ),
                    ],
                  ),
          ),
        },
      ],
    );
  }
}

class _HistoryEventCard extends StatelessWidget {
  const _HistoryEventCard({required this.event});

  final TimelineEventItem event;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    final dateFormat = _safeDateFormat(l10n.historyHhMm, localeName);

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                _iconForEvent(event.eventType),
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        dateFormat.format(event.eventDate.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(event.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForEvent(String eventType) {
    switch (eventType) {
      case 'document_uploaded':
      case 'lab_result_summary':
      case 'imaging_summary':
        return Icons.description_outlined;
      case 'medication_logged':
        return Icons.medication_outlined;
      case 'daily_entry_created':
      case 'daily_entry':
        return Icons.edit_note_outlined;
      case 'ai_alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.bolt_outlined;
    }
  }
}

class _MiniSection extends StatelessWidget {
  const _MiniSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
