import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/history/domain/history_day.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
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

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  bool _isRegeneratingDailyReport = false;

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
      await ref.read(insightsRepositoryProvider).regenerateSummary(query);
      ref.invalidate(historyDayProvider(targetDate));
      ref.invalidate(insightSummaryProvider(query));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Daily report regenerated for ${DateFormat('dd/MM/yyyy').format(targetDate)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regeneration failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRegeneratingDailyReport = false);
      }
    }
  }

  Future<void> _copyDailyReport(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard.')),
    );
  }

  void _goToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _selectedDate = today;
      _focusedMonth = DateTime(today.year, today.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyDayProvider(_selectedDate));
    final activityDatesAsync = ref.watch(
      historyActivityDatesProvider(_focusedMonth),
    );
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');
    Future<void> refreshHistory() async {
      ref.invalidate(historyDayProvider(_selectedDate));
      ref.invalidate(historyActivityDatesProvider(_focusedMonth));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today_outlined),
              label: const Text('Today'),
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Day'),
              Tab(text: 'Calendar'),
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
                    dateFormat: dateFormat,
                    isRegeneratingDailyReport: _isRegeneratingDailyReport,
                    onCopyDailyReport: history.dailySummary == null
                        ? null
                        : () => _copyDailyReport(history.dailySummary!.content),
                    onRegenerateDailyReport: _regenerateDailyReport,
                  ),
                  loading: () => const SectionCard(
                    title: 'Day',
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SectionCard(
                    title: 'Day',
                    child: Text(error.toString()),
                  ),
                ),
              ],
            ),
            _HistoryTabList(
              onRefresh: refreshHistory,
              children: [
                SectionCard(
                  title: 'Calendar',
                  subtitle: 'Choose a day.',
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
    final normalizedActivityDates = activityDates
        .map(DateUtils.dateOnly)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TableCalendar<String>(
          locale: 'en_US',
          firstDay: DateTime(2020),
          lastDay: DateTime.now().add(const Duration(days: 1)),
          focusedDay: focusedMonth,
          startingDayOfWeek: StartingDayOfWeek.monday,
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
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
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
          'Dot = recorded activity',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.history,
    required this.dateFormat,
    required this.isRegeneratingDailyReport,
    required this.onCopyDailyReport,
    required this.onRegenerateDailyReport,
  });

  final HistoryDay history;
  final DateFormat dateFormat;
  final bool isRegeneratingDailyReport;
  final VoidCallback? onCopyDailyReport;
  final VoidCallback onRegenerateDailyReport;

  @override
  Widget build(BuildContext context) {
    final entry = history.dailyEntry;

    return Column(
      children: [
        SectionCard(
          title: 'Selected day',
          subtitle: 'Quick overview.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(label: dateFormat.format(history.targetDate)),
              _SummaryChip(
                label: entry == null ? 'No check-up' : 'Check-up',
              ),
              _SummaryChip(label: '${history.timelineEvents.length} eventi'),
              _SummaryChip(label: '${history.documents.length} documenti'),
              if (history.dailySummary != null)
                const _SummaryChip(label: 'Recap available'),
              if (history.wearableSummary != null)
                const _SummaryChip(label: 'Wearable'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HistoryDetailSwitcher(
          history: history,
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
    required this.entry,
    required this.isRegeneratingDailyReport,
    required this.onCopyDailyReport,
    required this.onRegenerateDailyReport,
  });

  final HistoryDay history;
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
    final entry = widget.entry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Day details',
          subtitle: 'Open only the section you need.',
          child: CompactSegmentedControl<_HistoryDetailTab>(
            options: const [
              CompactSegmentOption(
                value: _HistoryDetailTab.recap,
                label: 'Recap',
                icon: Icons.auto_awesome_outlined,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.checkup,
                label: 'Check-up',
                icon: Icons.favorite_outline,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.events,
                label: 'Events',
                icon: Icons.timeline_outlined,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.documents,
                label: 'Documents',
                icon: Icons.description_outlined,
              ),
              CompactSegmentOption(
                value: _HistoryDetailTab.wearable,
                label: 'Wearable',
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
            title: 'Daily recap',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onCopyDailyReport != null)
                  IconButton(
                    tooltip: 'Copy report',
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
                    widget.isRegeneratingDailyReport ? 'Regenerating...' : 'Regenerate',
                  ),
                ),
              ],
            ),
            child: widget.history.dailySummary == null
                ? const Text('No recap available.')
                : SummaryContentView(
                    content: widget.history.dailySummary!.content,
                    maxHeightFactor: 0.48,
                  ),
          ),
          _HistoryDetailTab.checkup => SectionCard(
            title: 'Check-up',
            subtitle: 'Data recorded on the day.',
            child: entry == null
                ? const Text('No check-up recorded for this day.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (entry.energyLevel != null)
                            _SummaryChip(label: 'Energy ${entry.energyLevel}/10'),
                          if (entry.moodLevel != null)
                            _SummaryChip(label: 'Mood ${entry.moodLevel}/10'),
                          if (entry.stressLevel != null)
                            _SummaryChip(label: 'Stress ${entry.stressLevel}/10'),
                          if (entry.generalPain != null)
                            _SummaryChip(label: 'Pain ${entry.generalPain}/10'),
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
                          title: 'Symptoms',
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
                          title: 'Vitals',
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
            title: 'Events',
            subtitle: 'Day timeline.',
            child: widget.history.timelineEvents.isEmpty
                ? const Text('No events recorded for this day.')
                : Column(
                    children: widget.history.timelineEvents
                        .map((event) => _HistoryEventCard(event: event))
                        .toList(),
                  ),
          ),
          _HistoryDetailTab.documents => SectionCard(
            title: 'Day documents',
            subtitle: 'Uploaded or linked to this date.',
            child: widget.history.documents.isEmpty
                ? const Text('No documents linked to this day.')
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
            title: 'Wearable data',
            subtitle: 'Day summary.',
            child: widget.history.wearableSummary == null
                ? const Text('No wearable data for this day.')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.history.wearableSummary!.stepsCount != null)
                        _SummaryChip(
                          label:
                              '${widget.history.wearableSummary!.stepsCount} steps',
                        ),
                      if (widget.history.wearableSummary!.sleepMinutes != null)
                        _SummaryChip(
                          label:
                              'Sleep ${(widget.history.wearableSummary!.sleepMinutes! / 60).toStringAsFixed(1)} h',
                        ),
                      if (widget.history.wearableSummary!.heartRateAvgBpm !=
                          null)
                        _SummaryChip(
                          label:
                              'HR ${widget.history.wearableSummary!.heartRateAvgBpm!.toStringAsFixed(0)} bpm',
                        ),
                      if (widget.history.wearableSummary!.restingHeartRateBpm !=
                          null)
                        _SummaryChip(
                          label:
                              'Resting ${widget.history.wearableSummary!.restingHeartRateBpm!.toStringAsFixed(0)} bpm',
                        ),
                      if (widget.history.wearableSummary!.bloodOxygenAvgPct !=
                          null)
                        _SummaryChip(
                          label:
                              'SpO2 ${widget.history.wearableSummary!.bloodOxygenAvgPct!.toStringAsFixed(0)}%',
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
    final dateFormat = DateFormat('HH:mm', 'it_IT');

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
