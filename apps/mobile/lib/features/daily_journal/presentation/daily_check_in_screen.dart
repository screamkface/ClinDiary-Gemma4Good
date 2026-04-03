import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/shared/widgets/metric_slider.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DailyCheckInScreen extends ConsumerStatefulWidget {
  const DailyCheckInScreen({super.key});

  @override
  ConsumerState<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends ConsumerState<DailyCheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _sleepHoursController = TextEditingController(text: '7');
  final _notesController = TextEditingController();

  double _sleepQuality = 7;
  double _energy = 6;
  double _mood = 6;
  double _stress = 4;
  double _appetite = 6;
  double _hydration = 6;
  double _pain = 2;
  bool _saving = false;

  @override
  void dispose() {
    _dateController.dispose();
    _sleepHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final entry = await ref.read(dailyJournalRepositoryProvider).createEntry({
        'entry_date': _dateController.text.trim(),
        'sleep_hours': double.tryParse(_sleepHoursController.text.trim()),
        'sleep_quality': _sleepQuality.round(),
        'energy_level': _energy.round(),
        'mood_level': _mood.round(),
        'stress_level': _stress.round(),
        'appetite_level': _appetite.round(),
        'hydration_level': _hydration.round(),
        'general_pain': _pain.round(),
        'general_notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      });
      ref.invalidate(dailyEntriesProvider);
      ref.invalidate(timelineEventsProvider);
      if (!mounted) return;
      final addSymptom = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check-up salvato'),
          content: const Text('Aggiungere un sintomo adesso?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Più tardi'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aggiungi ora'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (addSymptom == true) {
        context.pushReplacement('/app/diary/${entry.id}/symptom');
      } else {
        context.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo check-up')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Base del check-up',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Data (YYYY-MM-DD)',
                      ),
                      validator: (value) {
                        if (value == null || DateTime.tryParse(value) == null) {
                          return 'Data non valida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sleepHoursController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Ore di sonno',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note generali',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Metriche rapide',
                child: Column(
                  children: [
                    MetricSlider(
                      label: 'Qualità del sonno',
                      value: _sleepQuality,
                      onChanged: (v) => setState(() => _sleepQuality = v),
                    ),
                    MetricSlider(
                      label: 'Energia',
                      value: _energy,
                      onChanged: (v) => setState(() => _energy = v),
                    ),
                    MetricSlider(
                      label: 'Umore',
                      value: _mood,
                      onChanged: (v) => setState(() => _mood = v),
                    ),
                    MetricSlider(
                      label: 'Stress',
                      value: _stress,
                      onChanged: (v) => setState(() => _stress = v),
                    ),
                    MetricSlider(
                      label: 'Appetito',
                      value: _appetite,
                      onChanged: (v) => setState(() => _appetite = v),
                    ),
                    MetricSlider(
                      label: 'Idratazione',
                      value: _hydration,
                      onChanged: (v) => setState(() => _hydration = v),
                    ),
                    MetricSlider(
                      label: 'Dolore generale',
                      value: _pain,
                      onChanged: (v) => setState(() => _pain = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Salvataggio...' : 'Salva check-up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
