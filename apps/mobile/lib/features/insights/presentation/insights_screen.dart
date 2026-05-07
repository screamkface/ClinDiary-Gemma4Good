import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/local_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/presentation/on_device_model_screen.dart';
import 'package:clindiary/shared/widgets/generation_phase_label.dart';
import 'package:clindiary/shared/widgets/compact_segmented_control.dart';
import 'package:clindiary/shared/widgets/clinical_scope_notice.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({
    super.key,
    this.initialSummaryType = 'daily',
    this.initialSummaryMode = InsightSummaryMode.standard,
  });

  final String initialSummaryType;
  final InsightSummaryMode initialSummaryMode;

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  late String _summaryType;
  late InsightSummaryMode _summaryMode;
  DateTime _referenceDate = DateUtils.dateOnly(DateTime.now());
  late DateTime _focusedMonth;
  bool _isRegenerating = false;
  DateTime? _regenerationStartedAt;
  bool _isInstallingOnDeviceModel = false;

  @override
  void initState() {
    super.initState();
    _summaryType = widget.initialSummaryType;
    _summaryMode = widget.initialSummaryType == 'daily'
        ? widget.initialSummaryMode
        : InsightSummaryMode.standard;
    _focusedMonth = DateTime(_referenceDate.year, _referenceDate.month, 1);
  }

  Future<void> _pickReferenceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('en', 'US'),
    );
    if (picked != null) {
      setState(() {
        _referenceDate = DateUtils.dateOnly(picked);
        _focusedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _regenerateSummary() async {
    final query = InsightSummaryQuery(
      summaryType: _summaryType,
      referenceDate: _referenceDate,
      mode: _summaryMode,
    );
    final startedAt = DateTime.now();
    setState(() {
      _isRegenerating = true;
      _regenerationStartedAt = startedAt;
    });
    try {
      await ref.read(insightsRepositoryProvider).regenerateSummary(query);
      ref.invalidate(insightSummaryProvider(query));
      if (_isPrivateLocalMode) {
        ref.invalidate(localAiStatusProvider);
      }
      if (_isOnDeviceMode) {
        ref.invalidate(onDeviceAiStatusProvider);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report regenerated.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Regeneration failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
          _regenerationStartedAt = null;
        });
      }
    }
  }

  Future<void> _installOnDeviceModel() async {
    if (_isInstallingOnDeviceModel) {
      return;
    }

    setState(() => _isInstallingOnDeviceModel = true);
    try {
      final installedPath = await ref
          .read(onDeviceAiServiceProvider)
          .importModelFromPicker();
      ref.invalidate(onDeviceAiStatusProvider);
      if (_isOnDeviceMode) {
        final query = InsightSummaryQuery(
          summaryType: _summaryType,
          referenceDate: _referenceDate,
          mode: _summaryMode,
        );
        ref.invalidate(insightSummaryProvider(query));
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            installedPath == null
                ? 'Model import canceled.'
                : 'Model copied to $installedPath',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Model import failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isInstallingOnDeviceModel = false);
      }
    }
  }

  Future<void> _copySummary(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard.')),
    );
  }

  bool get _isPrivateLocalMode =>
      _summaryType == 'daily' &&
      _summaryMode == InsightSummaryMode.privateLocal;

  bool get _isOnDeviceMode =>
      _summaryType == 'daily' && _summaryMode == InsightSummaryMode.onDevice;

  void _setSummaryType(String value) {
    setState(() {
      _summaryType = value;
      if (value != 'daily') {
        _summaryMode = InsightSummaryMode.standard;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = InsightSummaryQuery(
      summaryType: _summaryType,
      referenceDate: _referenceDate,
      mode: _summaryMode,
    );
    final summaryAsync = ref.watch(insightSummaryProvider(query));
    final currentSummary = summaryAsync.asData?.value;
    final showLocalProof =
        _isPrivateLocalMode || currentSummary?.providerName == 'local_gemma4';
    final showOnDeviceProof =
        _isOnDeviceMode || currentSummary?.providerName == 'on_device_litertlm';
    final localStatusAsync = showLocalProof
        ? ref.watch(localAiStatusProvider)
        : null;
    final onDeviceStatusAsync = showOnDeviceProof
        ? ref.watch(onDeviceAiStatusProvider)
        : null;
    final activityDatesAsync = ref.watch(
      historyActivityDatesProvider(_focusedMonth),
    );
    final activityDates =
        activityDatesAsync.asData?.value ?? const <DateTime>[];
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');
    final dayFormat = DateFormat('dd MMM yyyy', 'en_US');
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI recap'),
        actions: [
          if (currentSummary != null)
            IconButton(
              tooltip: 'Copy report',
              onPressed: () => _copySummary(currentSummary.content),
              icon: const Icon(Icons.content_copy_outlined),
            ),
          if (currentSummary != null)
            TextButton.icon(
              onPressed: _isRegenerating ? null : _regenerateSummary,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: GenerationPhaseLabel(
                isActive: _isRegenerating,
                startedAt: _regenerationStartedAt,
                idleLabel: 'Regenerate',
                showProgress: true,
              ),
            ),
          IconButton(
            onPressed: _pickReferenceDate,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            onPressed: () => ref.invalidate(insightSummaryProvider(query)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a period and a date.',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TypeButton(
                      label: 'Day',
                      selected: _summaryType == 'daily',
                      onPressed: () => _setSummaryType('daily'),
                    ),
                    _TypeButton(
                      label: 'Week',
                      selected: _summaryType == 'weekly',
                      onPressed: () => _setSummaryType('weekly'),
                    ),
                    _TypeButton(
                      label: 'Month',
                      selected: _summaryType == 'monthly',
                      onPressed: () => _setSummaryType('monthly'),
                    ),
                    _TypeButton(
                      label: 'Pre-visit',
                      selected: _summaryType == 'pre_visit',
                      onPressed: () => _setSummaryType('pre_visit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickReferenceDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(dayFormat.format(_referenceDate)),
                    ),
                  ],
                ),
                if (_summaryType == 'daily') ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recap mode',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CompactSegmentedControl<InsightSummaryMode>(
                    options: const [
                      CompactSegmentOption<InsightSummaryMode>(
                        value: InsightSummaryMode.standard,
                        label: 'Standard',
                        icon: Icons.cloud_outlined,
                      ),
                      CompactSegmentOption<InsightSummaryMode>(
                        value: InsightSummaryMode.privateLocal,
                        label: 'Local private',
                        icon: Icons.shield_outlined,
                      ),
                      CompactSegmentOption<InsightSummaryMode>(
                        value: InsightSummaryMode.onDevice,
                        label: 'On device',
                        icon: Icons.smartphone_outlined,
                      ),
                    ],
                    selectedValue: _summaryMode,
                    onChanged: (value) {
                      setState(() {
                        _summaryMode = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _InsightsCalendar(
                  focusedMonth: _focusedMonth,
                  selectedDate: _referenceDate,
                  activityDates: activityDates,
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _referenceDate = DateUtils.dateOnly(selected);
                      _focusedMonth = DateTime(focused.year, focused.month, 1);
                    });
                  },
                  onPageChanged: (focused) {
                    setState(() {
                      _focusedMonth = DateTime(focused.year, focused.month, 1);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const ClinicalScopeNotice(
            title: 'Cautious use',
            message:
                'The AI recap reorganizes diary and recent document data, but it does not replace a clinician, diagnosis, or prescription.',
            icon: Icons.health_and_safety_outlined,
          ),
          if (showLocalProof) ...[
            const SizedBox(height: 12),
            const _LocalModeNote(),
            const SizedBox(height: 12),
            _LocalStatusSection(statusAsync: localStatusAsync!),
          ],
          if (showOnDeviceProof) ...[
            const SizedBox(height: 12),
            const _OnDeviceModeNote(),
            const SizedBox(height: 12),
            _OnDeviceStatusSection(
              statusAsync: onDeviceStatusAsync!,
              onInstallModel: _installOnDeviceModel,
              isInstallingModel: _isInstallingOnDeviceModel,
            ),
          ],
          const SizedBox(height: 12),
          summaryAsync.when(
            data: (summary) => Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: _PromptBubble(
                      summaryType: _summaryType,
                      referenceDate: _referenceDate,
                      dateFormat: dayFormat,
                      summaryMode: _summaryMode,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AnswerBubble(
                  summary: summary,
                  dateFormat: dateFormat,
                  providerLabelOverride: summary.providerName == 'local_gemma4'
                      ? localStatusAsync?.asData?.value.activeProviderLabel ??
                            'Local private mode'
                      : summary.providerName == 'on_device_litertlm'
                      ? onDeviceStatusAsync
                                ?.asData
                                ?.value
                                .activeProviderLabel ??
                            'On-device local'
                      : null,
                ),
              ],
            ),
            loading: () => _LoadingState(
              isActive: _isRegenerating,
              startedAt: _regenerationStartedAt,
            ),
            error: (error, _) => _ErrorState(error: error.toString()),
          ),
        ],
      ),
    );
  }
}

class _InsightsCalendar extends StatelessWidget {
  const _InsightsCalendar({
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
          daysOfWeekHeight: 20,
          rowHeight: 40,
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
        const SizedBox(height: 6),
        Text(
          'Dot = day with activity',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PromptBubble extends StatelessWidget {
  const _PromptBubble({
    required this.summaryType,
    required this.referenceDate,
    required this.dateFormat,
    required this.summaryMode,
  });

  final String summaryType;
  final DateTime referenceDate;
  final DateFormat dateFormat;
  final InsightSummaryMode summaryMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_titleFor(summaryType)} del ${dateFormat.format(referenceDate)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            if (summaryMode == InsightSummaryMode.privateLocal) ...[
              const SizedBox(height: 8),
              Text(
                'Local private path active',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (summaryMode == InsightSummaryMode.onDevice) ...[
              const SizedBox(height: 8),
              Text(
                'On-device inference active',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerBubble extends StatelessWidget {
  const _AnswerBubble({
    required this.summary,
    required this.dateFormat,
    this.providerLabelOverride,
  });

  final InsightSummary summary;
  final DateFormat dateFormat;
  final String? providerLabelOverride;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final providerLabel =
        providerLabelOverride ?? _providerLabel(summary.providerName);
    final providerAccent = _providerAccent(colorScheme, summary.providerName);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.85),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: providerAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: providerAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleFor(summary.summaryType),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(
                                label:
                                    '${summary.periodStart.toIso8601String().split('T').first} → ${summary.periodEnd.toIso8601String().split('T').first}',
                              ),
                              _MetaChip(
                                label: dateFormat.format(
                                  summary.generatedAt.toLocal(),
                                ),
                              ),
                              _MetaChip(
                                label: providerLabel,
                                accent: providerAccent,
                              ),
                              if (summary.modelName != null &&
                                  summary.modelName!.trim().isNotEmpty)
                                _MetaChip(label: summary.modelName!),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SummaryContentView(
                  content: summary.content,
                  constrainHeight: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalModeNote extends StatelessWidget {
  const _LocalModeNote();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The local private mode uses a local/private runtime for the daily recap. The text is intentionally shorter and stays on the device.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalStatusSection extends StatelessWidget {
  const _LocalStatusSection({required this.statusAsync});

  final AsyncValue<LocalAiStatus> statusAsync;

  @override
  Widget build(BuildContext context) {
    return statusAsync.when(
      data: (status) => LocalProofCard(status: status),
      loading: () => const _LocalProofCardLoading(),
      error: (error, _) => _LocalProofCardError(error: error.toString()),
    );
  }
}

class _OnDeviceStatusSection extends StatelessWidget {
  const _OnDeviceStatusSection({
    required this.statusAsync,
    required this.onInstallModel,
    required this.isInstallingModel,
  });

  final AsyncValue<OnDeviceAiStatus> statusAsync;
  final Future<void> Function() onInstallModel;
  final bool isInstallingModel;

  @override
  Widget build(BuildContext context) {
    return statusAsync.when(
      data: (status) => OnDeviceProofCard(
        status: status,
        onInstallModel: onInstallModel,
        isInstallingModel: isInstallingModel,
      ),
      loading: () => const _LocalProofCardLoading(
        message: 'Checking on-device inference...',
      ),
      error: (error, _) =>
          _LocalProofCardError(error: 'On-device proof not available: $error'),
    );
  }
}

class LocalProofCard extends StatelessWidget {
  const LocalProofCard({required this.status, super.key});

  final LocalAiStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Local proof',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                label: 'Active provider: ${status.activeProviderLabel}',
              ),
              _MetaChip(label: 'Runtime: ${status.runtimeMode}'),
              _MetaChip(label: 'Backend: ${status.backend ?? '-'}'),
              _MetaChip(label: 'Model: ${status.modelName ?? '-'}'),
              _MetaChip(
                label:
                    'External cloud used: ${status.isCloudBypassedForThisRequest ? 'No' : 'Yes'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalProofCardLoading extends StatelessWidget {
  const _LocalProofCardLoading({this.message = 'Checking local runtime...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LocalProofCardError extends StatelessWidget {
  const _LocalProofCardError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Text('Local proof not available: $error'),
    );
  }
}

class _OnDeviceModeNote extends StatelessWidget {
  const _OnDeviceModeNote();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.smartphone_outlined, color: colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'On-device mode runs the daily recap directly on Android with LiteRT-LM. It reuses the cautious ClinDiary prompt but does not send the text to the cloud AI provider.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class OnDeviceProofCard extends StatelessWidget {
  const OnDeviceProofCard({
    required this.status,
    required this.onInstallModel,
    required this.isInstallingModel,
    super.key,
  });

  final OnDeviceAiStatus status;
  final Future<void> Function() onInstallModel;
  final bool isInstallingModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final readiness = status.isReady ? 'Ready' : 'Not ready';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proof on-device',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                label: 'Active provider: ${status.activeProviderLabel}',
              ),
              _MetaChip(label: 'Runtime: ${status.runtime}'),
              _MetaChip(
                label: 'Preferred backend: ${status.backendPreference}',
              ),
              _MetaChip(
                label: 'Backend used: ${status.backendResolved ?? '-'}',
              ),
              _MetaChip(label: 'Model: ${status.modelName ?? '-'}'),
              _MetaChip(label: 'Model status: $readiness'),
              _MetaChip(
                label:
                    'External cloud used: ${status.isCloudBypassedForThisRequest ? 'No' : 'Yes'}',
              ),
            ],
          ),
          if (status.defaultModelDirectory != null) ...[
            const SizedBox(height: 12),
            Text(
              'Expected model directory: ${status.defaultModelDirectory}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (status.modelPath != null) ...[
            const SizedBox(height: 6),
            Text(
              'Detected model: ${status.modelPath}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (status.lastError != null &&
              status.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              status.lastError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: isInstallingModel ? null : () => onInstallModel(),
            icon: isInstallingModel
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    status.isReady
                        ? Icons.sync_alt_outlined
                        : Icons.upload_file_outlined,
                  ),
            label: Text(
              isInstallingModel
                  ? 'Importing model...'
                  : status.isReady
                  ? 'Replace model'
                  : 'Import .litertlm model',
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OnDeviceModelScreen(),
                ),
              );
            },
            icon: const Icon(Icons.tune_outlined),
            label: const Text('Manage model'),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.accent});

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipAccent = accent ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: chipAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.isActive, this.startedAt});

  final bool isActive;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GenerationPhaseLabel(
              isActive: isActive,
              startedAt: startedAt,
              idleLabel: 'Loading report...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(error, textAlign: TextAlign.center),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

String _titleFor(String summaryType) {
  switch (summaryType) {
    case 'weekly':
      return 'Weekly summary';
    case 'monthly':
      return 'Monthly summary';
    case 'pre_visit':
      return 'Pre-visit summary';
    default:
      return 'Daily summary';
  }
}

String _providerLabel(String? providerName) {
  switch ((providerName ?? '').trim()) {
    case 'on_device_litertlm':
      return 'Local on-device';
    case 'local_gemma4':
      return 'Local private mode';
    case 'regolo_ai':
      return 'Regolo AI';
    case 'gemini_ai_studio':
      return 'Gemini AI Studio';
    case 'openai_compatible':
      return 'Compatible provider';
    case 'rule_based':
      return 'Cautious fallback';
    default:
      return 'Recap AI';
  }
}

Color _providerAccent(ColorScheme colorScheme, String? providerName) {
  switch ((providerName ?? '').trim()) {
    case 'on_device_litertlm':
      return colorScheme.secondary;
    case 'local_gemma4':
      return colorScheme.primary;
    case 'rule_based':
      return colorScheme.tertiary;
    case 'regolo_ai':
      return colorScheme.primary;
    case 'gemini_ai_studio':
      return colorScheme.secondary;
    default:
      return colorScheme.primary;
  }
}
