import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/shared/widgets/metric_slider.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SymptomFollowUpScreen extends ConsumerStatefulWidget {
  const SymptomFollowUpScreen({
    required this.sourceEntryId,
    required this.sourceSymptomId,
    this.initialResponse,
    super.key,
  });

  final String sourceEntryId;
  final String sourceSymptomId;
  final String? initialResponse;

  @override
  ConsumerState<SymptomFollowUpScreen> createState() =>
      _SymptomFollowUpScreenState();
}

class _SymptomFollowUpScreenState extends ConsumerState<SymptomFollowUpScreen> {
  final _notesController = TextEditingController();
  bool _saving = false;
  double _severity = 4;
  bool _autoHandled = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoHandled) {
      return;
    }
    final response = widget.initialResponse;
    if (response == 'still_present' || response == 'resolved') {
      _autoHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submit(stillPresent: response == 'still_present');
      });
    }
  }

  Future<void> _submit({required bool stillPresent}) async {
    if (_saving) {
      return;
    }

    final entries = await ref.read(dailyEntriesProvider.future);
    final source = _findSource(entries);
    if (source == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original symptom not found anymore.')),
      );
      context.go('/app/diary');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(dailyJournalRepositoryProvider)
          .recordSymptomFollowUp(
            sourceEntryId: source.entry.id,
            sourceEntryDate: source.entry.entryDate,
            sourceSymptom: source.symptom,
            stillPresent: stillPresent,
            severity: stillPresent ? _severity.round() : 0,
            notes: _notesController.text,
          );
      ref.invalidate(dailyEntriesProvider);
      ref.invalidate(timelineEventsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stillPresent
                ? 'Symptom updated for today.'
                : 'Symptom marked as resolved for today.',
          ),
        ),
      );
      context.go('/app/diary');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  _SourceSymptom? _findSource(List<DailyEntry> entries) {
    for (final entry in entries) {
      if (entry.id != widget.sourceEntryId) {
        continue;
      }
      for (final symptom in entry.symptoms) {
        if (symptom.id == widget.sourceSymptomId) {
          return _SourceSymptom(entry: entry, symptom: symptom);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(dailyEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom follow-up')),
      body: entriesAsync.when(
        data: (entries) {
          final source = _findSource(entries);
          if (source == null) {
            return const Center(child: Text('Original symptom not available.'));
          }
          final initialSeverity = (source.symptom.severity ?? 4).toDouble();
          if (!_saving && _severity == 4) {
            _severity = initialSeverity;
          }
          final label = _symptomLabel(source.symptom);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Quick update',
                subtitle: 'A symptom logged yesterday needs a fast check.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Do you still have $label today?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _submit(stillPresent: true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Yes, still present'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _submit(stillPresent: false),
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const Text('No, resolved'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Optional details',
                subtitle: 'Only if you want to be more precise.',
                child: Column(
                  children: [
                    MetricSlider(
                      label: 'Current intensity',
                      value: _severity,
                      onChanged: (value) {
                        if (_saving) {
                          return;
                        }
                        setState(() => _severity = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Quick note',
                        hintText: 'Example: less intense than yesterday',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  String _symptomLabel(SymptomEntry symptom) {
    const labels = <String, String>{
      'headache': 'headache',
      'fever': 'fever',
      'nausea': 'nausea',
      'cough': 'cough',
      'fatigue': 'fatigue',
    };
    final base =
        labels[symptom.symptomCode] ?? symptom.symptomCode.replaceAll('_', ' ');
    final location = symptom.bodyLocation?.trim();
    if (location == null || location.isEmpty) {
      return base;
    }
    return '$base in $location';
  }
}

class _SourceSymptom {
  const _SourceSymptom({required this.entry, required this.symptom});

  final DailyEntry entry;
  final SymptomEntry symptom;
}
