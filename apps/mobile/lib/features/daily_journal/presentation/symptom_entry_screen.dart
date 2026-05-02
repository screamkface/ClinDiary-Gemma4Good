import 'package:clindiary/app/providers.dart';
import 'package:clindiary/shared/widgets/metric_slider.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SymptomEntryScreen extends ConsumerStatefulWidget {
  const SymptomEntryScreen({required this.entryId, super.key});

  final String entryId;

  @override
  ConsumerState<SymptomEntryScreen> createState() => _SymptomEntryScreenState();
}

enum _SymptomInputMode { suggested, custom }

class _SymptomEntryScreenState extends ConsumerState<SymptomEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _bodyLocationController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _headacheNotesController = TextEditingController();
  final _associatedSymptomsController = TextEditingController();
  final _customSymptomController = TextEditingController();
  final _customNotesController = TextEditingController();

  _SymptomInputMode _inputMode = _SymptomInputMode.suggested;
  String _selectedSymptomCode = 'headache';
  double _severity = 4;
  bool _withNausea = false;
  bool _withAura = false;
  bool _vomiting = false;
  bool _saving = false;

  @override
  void dispose() {
    _durationController.dispose();
    _bodyLocationController.dispose();
    _temperatureController.dispose();
    _headacheNotesController.dispose();
    _associatedSymptomsController.dispose();
    _customSymptomController.dispose();
    _customNotesController.dispose();
    super.dispose();
  }

  String get _resolvedSymptomCode {
    if (_inputMode == _SymptomInputMode.custom) {
      return _customSymptomController.text.trim();
    }
    return _selectedSymptomCode;
  }

  Map<String, dynamic> _metadata() {
    final metadata = switch (_inputMode) {
      _SymptomInputMode.custom => {
        'entry_mode': 'custom',
        'notes': _customNotesController.text.trim(),
      },
      _SymptomInputMode.suggested => switch (_selectedSymptomCode) {
        'headache' => {
          'entry_mode': 'suggested',
          'with_nausea': _withNausea,
          'with_aura': _withAura,
          'notes': _headacheNotesController.text.trim(),
        },
        'fever' => {
          'entry_mode': 'suggested',
          'temperature_c': double.tryParse(_temperatureController.text.trim()),
          'duration_days': int.tryParse(_durationController.text.trim()),
        },
        'nausea' => {
          'entry_mode': 'suggested',
          'vomiting': _vomiting,
          'associated_symptoms': _associatedSymptomsController.text.trim(),
        },
        _ => {'entry_mode': 'suggested'},
      },
    };

    metadata.removeWhere(
      (_, value) => value == null || (value is String && value.trim().isEmpty),
    );
    return metadata;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(dailyJournalRepositoryProvider)
          .addSymptom(
            entryId: widget.entryId,
            payload: {
              'symptom_code': _resolvedSymptomCode,
              'severity': _severity.round(),
              'duration_minutes': int.tryParse(_durationController.text.trim()),
              'body_location': _bodyLocationController.text.trim().isEmpty
                  ? null
                  : _bodyLocationController.text.trim(),
              'metadata_json': _metadata(),
            },
          );
      ref.invalidate(dailyEntriesProvider);
      ref.invalidate(timelineEventsProvider);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Main symptom',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_SymptomInputMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _SymptomInputMode.suggested,
                        icon: Icon(Icons.list_alt_outlined),
                        label: Text('List'),
                      ),
                      ButtonSegment(
                        value: _SymptomInputMode.custom,
                        icon: Icon(Icons.edit_note_outlined),
                        label: Text('Write your own'),
                      ),
                    ],
                    selected: {_inputMode},
                    onSelectionChanged: (selection) {
                      setState(() => _inputMode = selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_inputMode == _SymptomInputMode.suggested)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSymptomCode,
                      decoration: const InputDecoration(labelText: 'Symptom'),
                      items: _suggestedSymptoms
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.code,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _selectedSymptomCode = value ?? 'headache',
                      ),
                    )
                  else
                    TextFormField(
                      controller: _customSymptomController,
                      decoration: const InputDecoration(
                        labelText: 'Describe the symptom',
                        hintText: 'E.g. abdominal pain after meals',
                      ),
                      validator: (value) {
                        if (_inputMode != _SymptomInputMode.custom) {
                          return null;
                        }
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the symptom';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration in minutes',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Body location',
                    ),
                  ),
                  const SizedBox(height: 8),
                  MetricSlider(
                    label: 'Intensity',
                    value: _severity,
                    onChanged: (value) => setState(() => _severity = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Details',
              child: _inputMode == _SymptomInputMode.custom
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'If you prefer to describe the symptom in words, ClinDiary saves the free text so you can find it later in the history and recaps.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customNotesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Additional details',
                            hintText:
                                'E.g. it appears after lunch and improves when lying down',
                          ),
                        ),
                      ],
                    )
                  : _AdaptiveSymptomFields(
                      symptomCode: _selectedSymptomCode,
                      withNausea: _withNausea,
                      withAura: _withAura,
                      vomiting: _vomiting,
                      temperatureController: _temperatureController,
                      headacheNotesController: _headacheNotesController,
                      associatedSymptomsController:
                          _associatedSymptomsController,
                      onWithNauseaChanged: (value) =>
                          setState(() => _withNausea = value),
                      onWithAuraChanged: (value) =>
                          setState(() => _withAura = value),
                      onVomitingChanged: (value) =>
                          setState(() => _vomiting = value),
                    ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving...' : 'Save symptom'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdaptiveSymptomFields extends StatelessWidget {
  const _AdaptiveSymptomFields({
    required this.symptomCode,
    required this.withNausea,
    required this.withAura,
    required this.vomiting,
    required this.temperatureController,
    required this.headacheNotesController,
    required this.associatedSymptomsController,
    required this.onWithNauseaChanged,
    required this.onWithAuraChanged,
    required this.onVomitingChanged,
  });

  final String symptomCode;
  final bool withNausea;
  final bool withAura;
  final bool vomiting;
  final TextEditingController temperatureController;
  final TextEditingController headacheNotesController;
  final TextEditingController associatedSymptomsController;
  final ValueChanged<bool> onWithNauseaChanged;
  final ValueChanged<bool> onWithAuraChanged;
  final ValueChanged<bool> onVomitingChanged;

  @override
  Widget build(BuildContext context) {
    switch (symptomCode) {
      case 'headache':
        return Column(
          children: [
            SwitchListTile.adaptive(
              value: withNausea,
              onChanged: onWithNauseaChanged,
              contentPadding: EdgeInsets.zero,
              title: const Text('Associated with nausea'),
            ),
            SwitchListTile.adaptive(
              value: withAura,
              onChanged: onWithAuraChanged,
              contentPadding: EdgeInsets.zero,
              title: const Text('Aura present'),
            ),
            TextFormField(
              controller: headacheNotesController,
              decoration: const InputDecoration(
                labelText: 'Additional details',
              ),
            ),
          ],
        );
      case 'fever':
        return TextFormField(
          controller: temperatureController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Maximum temperature (°C)',
          ),
        );
      case 'nausea':
        return Column(
          children: [
            SwitchListTile.adaptive(
              value: vomiting,
              onChanged: onVomitingChanged,
              contentPadding: EdgeInsets.zero,
              title: const Text('Vomiting present'),
            ),
            TextFormField(
              controller: associatedSymptomsController,
              decoration: const InputDecoration(
                labelText: 'Associated symptoms',
              ),
            ),
          ],
        );
      default:
        return const Text(
          'For this symptom you can use duration, intensity and location.',
        );
    }
  }
}

class _SuggestedSymptomOption {
  const _SuggestedSymptomOption({required this.code, required this.label});

  final String code;
  final String label;
}

const _suggestedSymptoms = [
  _SuggestedSymptomOption(code: 'headache', label: 'Headache'),
  _SuggestedSymptomOption(code: 'fever', label: 'Fever'),
  _SuggestedSymptomOption(code: 'nausea', label: 'Nausea'),
  _SuggestedSymptomOption(code: 'cough', label: 'Cough'),
  _SuggestedSymptomOption(code: 'fatigue', label: 'Fatigue'),
];
