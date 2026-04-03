import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
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
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String _summaryType = 'daily';
  DateTime _referenceDate = DateUtils.dateOnly(DateTime.now());
  late DateTime _focusedMonth;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(_referenceDate.year, _referenceDate.month, 1);
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
        _focusedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _regenerateSummary() async {
    final query = InsightSummaryQuery(
      summaryType: _summaryType,
      referenceDate: _referenceDate,
    );
    setState(() => _isRegenerating = true);
    try {
      await ref.read(insightsRepositoryProvider).regenerateSummary(query);
      ref.invalidate(insightSummaryProvider(query));
      ref.invalidate(billingStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report rigenerato.')));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isFeatureLocked) {
        _openBilling(error.featureCode ?? _featureCodeForType(_summaryType));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rigenerazione non riuscita: $error')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rigenerazione non riuscita: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
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
      const SnackBar(content: Text('Report copiato negli appunti.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = InsightSummaryQuery(
      summaryType: _summaryType,
      referenceDate: _referenceDate,
    );
    final summaryAsync = ref.watch(insightSummaryProvider(query));
    final billingStatusAsync = ref.watch(billingStatusProvider);
    final activityDatesAsync = ref.watch(
      historyActivityDatesProvider(_focusedMonth),
    );
    final activityDates =
        activityDatesAsync.asData?.value ?? const <DateTime>[];
    final currentSummary = summaryAsync.asData?.value;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'it_IT');
    final dayFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final colorScheme = Theme.of(context).colorScheme;
    final requiredFeatureCode = _featureCodeForType(_summaryType);
    final proactiveLock =
        billingStatusAsync.asData?.value?.hasFeature(requiredFeatureCode) ==
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recap AI'),
        actions: [
          if (currentSummary != null)
            IconButton(
              tooltip: 'Copia report',
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
              label: Text(_isRegenerating ? 'Rigenero...' : 'Rigenera'),
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
                  'Scegli periodo e data.',
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
                      label: 'Giorno',
                      selected: _summaryType == 'daily',
                      onPressed: () => setState(() => _summaryType = 'daily'),
                    ),
                    _TypeButton(
                      label: 'Settimana',
                      selected: _summaryType == 'weekly',
                      onPressed: () => setState(() => _summaryType = 'weekly'),
                    ),
                    _TypeButton(
                      label: 'Mese',
                      selected: _summaryType == 'monthly',
                      onPressed: () => setState(() => _summaryType = 'monthly'),
                    ),
                    _TypeButton(
                      label: 'Pre-visita',
                      selected: _summaryType == 'pre_visit',
                      onPressed: () =>
                          setState(() => _summaryType = 'pre_visit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickReferenceDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(dayFormat.format(_referenceDate)),
                    ),
                  ],
                ),
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
            title: 'Uso prudente',
            message:
                'Il recap AI riordina i dati del diario e dei documenti recenti, ma non sostituisce medico, diagnosi o prescrizione.',
            icon: Icons.health_and_safety_outlined,
          ),
          const SizedBox(height: 12),
          if (proactiveLock)
            FeatureLockCard(
              title: 'AI Plus richiesto',
              featureLabel: _featureLabel(requiredFeatureCode),
              message:
                  'I recap AI di questo periodo fanno parte di ClinDiary AI Plus. Il diario e lo storico restano accessibili anche senza piano.',
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AnswerBubble(summary: summary, dateFormat: dateFormat),
                ],
              ),
              loading: () => const _LoadingState(),
              error: (error, _) {
                final apiError = error is ApiException ? error : null;
                if (apiError != null && apiError.isFeatureLocked) {
                  return FeatureLockCard(
                    title: 'AI Plus richiesto',
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
      return 'Recap giornaliero';
    case 'ai_periodic_summaries':
      return 'Recap settimana e mese';
    default:
      return 'Recap pre-visita';
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
          locale: 'it_IT',
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
          'Pallino = giorno con attività',
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
  });

  final String summaryType;
  final DateTime referenceDate;
  final DateFormat dateFormat;

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
              'Richiesta',
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
          ],
        ),
      ),
    );
  }
}

class _AnswerBubble extends StatelessWidget {
  const _AnswerBubble({required this.summary, required this.dateFormat});

  final InsightSummary summary;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final providerLabel = _providerLabel(summary.providerName);
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
      return 'Riassunto settimanale';
    case 'monthly':
      return 'Riassunto mensile';
    case 'pre_visit':
      return 'Riassunto pre-visita';
    default:
      return 'Riassunto giornaliero';
  }
}

String _providerLabel(String? providerName) {
  switch ((providerName ?? '').trim()) {
    case 'regolo_ai':
      return 'Regolo AI';
    case 'gemini_ai_studio':
      return 'Gemini AI Studio';
    case 'openai_compatible':
      return 'Provider compatibile';
    case 'rule_based':
      return 'Fallback prudente';
    default:
      return 'Recap AI';
  }
}

Color _providerAccent(ColorScheme colorScheme, String? providerName) {
  switch ((providerName ?? '').trim()) {
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
