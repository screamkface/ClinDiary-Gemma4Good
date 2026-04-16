import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/local_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/presentation/on_device_model_screen.dart';
import 'package:clindiary/shared/widgets/compact_segmented_control.dart';
import 'package:clindiary/shared/widgets/clinical_scope_notice.dart';
import 'package:clindiary/shared/widgets/feature_lock_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    setState(() => _isRegenerating = true);
    try {
      await ref.read(insightsRepositoryProvider).regenerateSummary(query);
      ref.invalidate(insightSummaryProvider(query));
      if (_isPrivateLocalMode) {
        ref.invalidate(localAiStatusProvider);
      }
      if (_isOnDeviceMode) {
        ref.invalidate(onDeviceAiStatusProvider);
      }
      ref.invalidate(billingStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report regenerated.')));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isFeatureLocked) {
        _openBilling(error.featureCode ?? _featureCodeForType(_summaryType));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regeneration failed: $error')),
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
        setState(() => _isRegenerating = false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model import failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isInstallingOnDeviceModel = false);
      }
    }
  }

  void _openBilling(String featureCode) {
    context.push('/app/home/billing?feature=$featureCode');
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
    final billingStatusAsync = ref.watch(billingStatusProvider);
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
    final requiredFeatureCode = _featureCodeForType(_summaryType);
    final proactiveLock =
        billingStatusAsync.asData?.value?.hasFeature(requiredFeatureCode) ==
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recap'),
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
              icon: _isRegenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_isRegenerating ? 'Regenerating...' : 'Regenerate'),
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
                  'Choose period and date.',
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
                        label: 'Private local',
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
              'The AI recap organizes diary and recent document data, but it does not replace a clinician, diagnosis, or prescription.',
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
          if (proactiveLock)
            FeatureLockCard(
              title: 'AI Plus required',
              featureLabel: _featureLabel(requiredFeatureCode),
              message:
                  'AI recaps for this period are part of ClinDiary AI Plus. The diary and history remain accessible even without a plan.',
              onOpenBilling: () => _openBilling(requiredFeatureCode),
            )
          else
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
                    providerLabelOverride:
                        summary.providerName == 'local_gemma4'
                        ? localStatusAsync?.asData?.value.activeProviderLabel ??
                          'Private local mode'
                        : summary.providerName == 'on_device_litertlm'
                        ? onDeviceStatusAsync?.asData?.value.activeProviderLabel ??
                          'Local on-device'
                        : null,
                  ),
                ],
              ),
              loading: () => const _LoadingState(),
              error: (error, _) {
                final apiError = error is ApiException ? error : null;
                if (apiError != null && apiError.isFeatureLocked) {
                  return FeatureLockCard(
                    title: 'AI Plus required',
                    featureLabel: _featureLabel(
                      apiError.featureCode ?? requiredFeatureCode,
                    ),
                    message: apiError.message,
                    onOpenBilling: () => _openBilling(
                      apiError.featureCode ?? requiredFeatureCode,
                    ),
                  );
                }
                return _ErrorState(error: error.toString());
              },
            ),
        ],
      ),
    );
  }
}

String _featureCodeForType(String summaryType) {
  switch (summaryType) {
    case 'daily':
      return 'ai_daily_summary';
    case 'weekly':
    case 'monthly':
      return 'ai_periodic_summaries';
    default:
      return 'ai_previsit_summary';
  }
}

String _featureLabel(String featureCode) {
  switch (featureCode) {
    case 'ai_daily_summary':
      return 'Daily recap';
    case 'ai_periodic_summaries':
      return 'Weekly and monthly recap';
    default:
      return 'Pre-visit recap';
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
          availableGestures: AvailableGestures.horizontalSwipe,
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
                'Private local path active',
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
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The private local mode uses a local/private runtime for the daily recap. The text may be shorter than the cloud mode.',
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
      error: (error, _) => _LocalProofCardError(
        error: 'On-device proof unavailable: $error',
      ),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: 'Active provider: ${status.activeProviderLabel}'),
              _MetaChip(label: 'Runtime: ${status.runtimeMode}'),
              _MetaChip(label: 'Backend: ${status.backend ?? '-'}'),
              _MetaChip(label: 'Modello: ${status.modelName ?? '-'}'),
              _MetaChip(
                label:
                    'Cloud esterno usato: ${status.isCloudBypassedForThisRequest ? 'No' : 'Si'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalProofCardLoading extends StatelessWidget {
  const _LocalProofCardLoading({
    this.message = 'Checking local runtime...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.85,
          ),
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
      child: Text('Local proof unavailable: $error'),
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
              'On-device mode runs the daily recap directly on Android with LiteRT-LM. It reuses ClinDiary\'s cautious prompt but does not send the text to the cloud AI provider.',
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
            'On-device proof',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: 'Active provider: ${status.activeProviderLabel}'),
                _MetaChip(label: 'Runtime: ${status.runtime}'),
                _MetaChip(label: 'Preferred backend: ${status.backendPreference}'),
                _MetaChip(label: 'Backend used: ${status.backendResolved ?? '-'}'),
              _MetaChip(label: 'Modello: ${status.modelName ?? '-'}'),
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
          if (status.lastError != null && status.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              status.lastError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
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
                  : 'Import model .litertlm',
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
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
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
      return 'Weekly recap';
    case 'monthly':
      return 'Monthly recap';
    case 'pre_visit':
      return 'Pre-visit recap';
    default:
      return 'Daily recap';
  }
}

String _providerLabel(String? providerName) {
  switch ((providerName ?? '').trim()) {
    case 'on_device_litertlm':
      return 'On-device local';
    case 'local_gemma4':
      return 'Private local mode';
    case 'regolo_ai':
      return 'Regolo AI';
    case 'gemini_ai_studio':
      return 'Gemini AI Studio';
    case 'openai_compatible':
      return 'Compatible provider';
    case 'rule_based':
      return 'Cautious fallback';
    default:
      return 'AI Recap';
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
