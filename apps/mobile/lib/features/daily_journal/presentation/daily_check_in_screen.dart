import 'dart:async';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/voice_check_in_draft.dart';
import 'package:clindiary/shared/widgets/metric_slider.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class DailyCheckInScreen extends ConsumerStatefulWidget {
  const DailyCheckInScreen({super.key});

  @override
  ConsumerState<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends ConsumerState<DailyCheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final SpeechToText _speechToText = SpeechToText();
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
  bool _speechReady = false;
  bool _listening = false;
  bool _parsingVoice = false;
  bool _saving = false;
  String _voiceTranscript = '';
  String? _voiceError;
  VoiceCheckInDraft? _voiceDraft;

  @override
  void dispose() {
    unawaited(_speechToText.stop());
    _dateController.dispose();
    _sleepHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    final text = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    return text.replaceFirst(RegExp(r'\.0$'), '');
  }

  String _formatDate(DateTime dateTime) {
    return dateTime.toIso8601String().split('T').first;
  }

  void _applyVoiceDraft(VoiceCheckInDraft draft) {
    setState(() {
      if (draft.entryDate != null) {
        _dateController.text = _formatDate(draft.entryDate!);
      }
      if (draft.sleepHours != null) {
        _sleepHoursController.text = _formatNumber(draft.sleepHours!);
      }
      if (draft.sleepQuality != null) {
        _sleepQuality = draft.sleepQuality!.toDouble();
      }
      if (draft.energyLevel != null) {
        _energy = draft.energyLevel!.toDouble();
      }
      if (draft.moodLevel != null) {
        _mood = draft.moodLevel!.toDouble();
      }
      if (draft.stressLevel != null) {
        _stress = draft.stressLevel!.toDouble();
      }
      if (draft.appetiteLevel != null) {
        _appetite = draft.appetiteLevel!.toDouble();
      }
      if (draft.hydrationLevel != null) {
        _hydration = draft.hydrationLevel!.toDouble();
      }
      if (draft.generalPain != null) {
        _pain = draft.generalPain!.toDouble();
      }
      if (draft.generalNotes != null && draft.generalNotes!.trim().isNotEmpty) {
        final incomingNotes = draft.generalNotes!.trim();
        final existingNotes = _notesController.text.trim();
        _notesController.text = existingNotes.isEmpty
            ? incomingNotes
            : '$existingNotes\n$incomingNotes';
      }
    });
  }

  void _clearVoiceDraft() {
    unawaited(_speechToText.stop());
    setState(() {
      _voiceTranscript = '';
      _voiceError = null;
      _voiceDraft = null;
      _listening = false;
      _parsingVoice = false;
    });
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechReady) {
      return true;
    }

    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      if (mounted) {
        setState(() {
          _voiceError = 'Permesso microfono negato.';
        });
      }
      return false;
    }

    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        if ((status == 'done' || status == 'notListening') && _listening) {
          unawaited(_finalizeVoiceCapture());
        }
      },
      onError: (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _voiceError = error.errorMsg;
          _listening = false;
        });
      },
    );

    if (!mounted) {
      return false;
    }

    setState(() {
      _speechReady = available;
      if (!available) {
        _voiceError = 'Riconoscimento vocale non disponibile su questo device.';
      }
    });
    return available;
  }

  Future<void> _toggleVoiceCapture() async {
    if (_saving || _parsingVoice) {
      return;
    }

    if (_listening) {
      await _speechToText.stop();
      await _finalizeVoiceCapture();
      return;
    }

    final ready = await _ensureSpeechReady();
    if (!ready || !mounted) {
      return;
    }

    setState(() {
      _voiceTranscript = '';
      _voiceError = null;
      _voiceDraft = null;
      _listening = true;
    });

    await _speechToText.listen(
      localeId: 'it_IT',
      partialResults: true,
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _voiceTranscript = result.recognizedWords;
        });
        if (result.finalResult) {
          unawaited(_finalizeVoiceCapture());
        }
      },
    );
  }

  Future<void> _finalizeVoiceCapture() async {
    if (_parsingVoice) {
      return;
    }

    final transcript = _voiceTranscript.trim();
    if (transcript.isEmpty) {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceError = 'Non ho riconosciuto testo utile.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _parsingVoice = true;
        _listening = false;
        _voiceError = null;
      });
    }

    try {
      final referenceDate =
          DateTime.tryParse(_dateController.text.trim()) ?? DateTime.now();
      final draft = await ref
          .read(voiceCheckInAssistantProvider)
          .buildDraftFromTranscript(
            transcript: transcript,
            referenceDate: referenceDate,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceDraft = draft;
      });
      _applyVoiceDraft(draft);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-up compilato con Gemma 4')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _voiceError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dettatura non compilata: $message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _parsingVoice = false;
        });
      }
    }
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
      final voiceSymptoms =
          _voiceDraft?.symptoms ?? const <VoiceCheckInSymptomDraft>[];
      if (voiceSymptoms.isNotEmpty) {
        for (final symptom in voiceSymptoms) {
          await ref
              .read(dailyJournalRepositoryProvider)
              .addSymptom(
                entryId: entry.id,
                payload: symptom.toRequestPayload(),
              );
        }
        ref.invalidate(dailyEntriesProvider);
        ref.invalidate(timelineEventsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-up e sintomi vocali salvati')),
        );
        context.pop();
        return;
      }

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
                title: 'Dettatura vocale Gemma 4',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parla in italiano: ClinDiary trascrive la voce, Gemma 4 compila il check-up e puo aggiungere sintomi riconosciuti.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving || _parsingVoice
                              ? null
                              : _toggleVoiceCapture,
                          icon: Icon(
                            _listening
                                ? Icons.stop_circle_outlined
                                : Icons.mic_none_outlined,
                          ),
                          label: Text(_listening ? 'Ferma e compila' : 'Parla'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              (_listening ||
                                  _parsingVoice ||
                                  (_voiceTranscript.isEmpty &&
                                      _voiceDraft == null &&
                                      _voiceError == null))
                              ? null
                              : _clearVoiceDraft,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Azzera'),
                        ),
                      ],
                    ),
                    if (_voiceError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _voiceError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (_listening) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Sto ascoltando...'),
                    ],
                    if (_parsingVoice) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Gemma sta compilando i campi...'),
                    ],
                    if (_voiceTranscript.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Trascrizione',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SelectableText(_voiceTranscript),
                      ),
                    ],
                    if (_voiceDraft != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _voiceDraft!.hasSymptoms
                            ? 'Gemma ha compilato i campi e ${_voiceDraft!.symptoms.length} sintomi.'
                            : 'Gemma ha compilato i campi principali.',
                      ),
                      if (_voiceDraft!.hasFollowUpQuestions) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Gemma chiede un chiarimento prima di chiudere il check-up.',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _voiceDraft!.followUpQuestions
                              .map(
                                (question) => Chip(
                                  label: Text(question),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aggiungi un altro messaggio vocale o compila i campi manualmente se serve.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_voiceDraft!.symptoms.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _voiceDraft!.symptoms.map((symptom) {
                            final label = symptom.severity == null
                                ? symptom.symptomCode
                                : '${symptom.symptomCode} • ${symptom.severity}/10';
                            return Chip(label: Text(label));
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
