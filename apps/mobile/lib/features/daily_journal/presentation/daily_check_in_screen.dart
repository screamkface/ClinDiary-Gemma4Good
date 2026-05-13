import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/voice_check_in_draft.dart';
import 'package:clindiary/shared/widgets/metric_picker.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum _GemmaSymptomMenuAction { detectFromNotes, clearDetected }

class DailyCheckInScreen extends ConsumerStatefulWidget {
  const DailyCheckInScreen({super.key});

  @override
  ConsumerState<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends ConsumerState<DailyCheckInScreen> {
  static const _speechListenFor = Duration(seconds: 90);
  static const _speechPauseFor = Duration(seconds: 8);

  final _formKey = GlobalKey<FormState>();
  final SpeechToText _speechToText = SpeechToText();
  final _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _sleepHoursController = TextEditingController(text: '7');
  final _notesController = TextEditingController();
  final _voiceTranscriptController = TextEditingController();

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

  bool _isSpeechTimeout(String? errorMsg) {
    if (errorMsg == null) {
      return false;
    }

    final normalized = errorMsg.toLowerCase();
    return normalized.contains('speech_timeout');
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }

    if (_isSpeechTimeout(error.errorMsg)) {
      final transcript = _voiceTranscript.trim();
      if (transcript.isNotEmpty) {
        setState(() {
          _voiceError = null;
          _listening = false;
        });
        unawaited(_finalizeVoiceCapture());
        return;
      }

      setState(() {
        _voiceError =
            'I did not hear enough speech. Tap Speak and start talking right away.';
        _listening = false;
      });
      return;
    }

    setState(() {
      _voiceError = error.errorMsg;
      _listening = false;
    });
  }

  @override
  void dispose() {
    unawaited(_speechToText.stop());
    _dateController.dispose();
    _sleepHoursController.dispose();
    _notesController.dispose();
    _voiceTranscriptController.dispose();
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
      _voiceTranscriptController.text = '';
      _voiceError = null;
      _voiceDraft = null;
      _listening = false;
      _parsingVoice = false;
    });
  }

  String _normalizedQuestion(String question) {
    return question.trim().toLowerCase();
  }

  List<String> _mergeFollowUpQuestions(
    List<String> existing,
    List<String> incoming,
  ) {
    final merged = <String>[];
    final seen = <String>{};
    for (final question in [...existing, ...incoming]) {
      final normalized = question.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (seen.add(_normalizedQuestion(normalized))) {
        merged.add(normalized);
      }
    }
    return merged;
  }

  String _symptomIdentity(VoiceCheckInSymptomDraft symptom) {
    final code = symptom.symptomCode.trim().toLowerCase();
    final location = symptom.bodyLocation?.trim().toLowerCase() ?? '';
    return '$code|$location';
  }

  VoiceCheckInSymptomDraft _mergeSymptomDraft(
    VoiceCheckInSymptomDraft current,
    VoiceCheckInSymptomDraft incoming,
  ) {
    final mergedMetadata = <String, dynamic>{
      ...current.metadataJson,
      ...incoming.metadataJson,
    };
    return current.copyWith(
      symptomCode: incoming.symptomCode,
      severity: incoming.severity ?? current.severity,
      durationMinutes: incoming.durationMinutes ?? current.durationMinutes,
      bodyLocation: incoming.bodyLocation ?? current.bodyLocation,
      metadataJson: mergedMetadata,
    );
  }

  List<VoiceCheckInSymptomDraft> _mergeSymptoms(
    List<VoiceCheckInSymptomDraft> existing,
    List<VoiceCheckInSymptomDraft> incoming,
  ) {
    final byIdentity = <String, VoiceCheckInSymptomDraft>{
      for (final symptom in existing) _symptomIdentity(symptom): symptom,
    };

    for (final symptom in incoming) {
      final identity = _symptomIdentity(symptom);
      final current = byIdentity[identity];
      byIdentity[identity] = current == null
          ? symptom
          : _mergeSymptomDraft(current, symptom);
    }

    return byIdentity.values.toList(growable: false);
  }

  String _buildSymptomExtractionTranscript() {
    final notes = _notesController.text.trim();
    // Prefer the editable transcript controller so user edits are used
    final transcript = _voiceTranscriptController.text.trim().isNotEmpty
        ? _voiceTranscriptController.text.trim()
        : _voiceTranscript.trim();
    if (notes.isEmpty && transcript.isEmpty) {
      return '';
    }
    if (notes.isEmpty) {
      return transcript;
    }
    if (transcript.isEmpty) {
      return notes;
    }
    return '$notes\n$transcript';
  }

  Future<void> _extractSymptomsWithGemma() async {
    if (_saving || _parsingVoice || _listening) {
      return;
    }

    final transcript = _buildSymptomExtractionTranscript();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add notes or record voice before extracting symptoms'),
        ),
      );
      return;
    }

    setState(() {
      _parsingVoice = true;
      _voiceError = null;
    });

    try {
      final referenceDate =
          DateTime.tryParse(_dateController.text.trim()) ?? DateTime.now();
      final extractedDraft = await ref
          .read(voiceCheckInAssistantProvider)
          .buildDraftFromTranscript(
            transcript: transcript,
            referenceDate: referenceDate,
          );

      if (!mounted) {
        return;
      }

      final existingDraft = _voiceDraft ?? const VoiceCheckInDraft();
      final previousSymptoms = existingDraft.symptoms;
      final mergedSymptoms = _mergeSymptoms(
        previousSymptoms,
        extractedDraft.symptoms,
      );
      final mergedQuestions = _mergeFollowUpQuestions(
        existingDraft.followUpQuestions,
        extractedDraft.followUpQuestions,
      );

      setState(() {
        _voiceDraft = existingDraft.copyWith(
          generalNotes: existingDraft.generalNotes?.trim().isNotEmpty == true
              ? existingDraft.generalNotes
              : extractedDraft.generalNotes,
          followUpQuestions: mergedQuestions,
          symptoms: mergedSymptoms,
        );
      });

      final addedSymptomsCount =
          mergedSymptoms.length - previousSymptoms.length;
      final message = mergedSymptoms.isEmpty
          ? 'Gemma did not detect symptoms from the current notes.'
          : addedSymptomsCount > 0
          ? 'Gemma added $addedSymptomsCount symptoms to this check-in.'
          : 'Gemma refreshed detected symptoms.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _voiceError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gemma symptom extraction failed: $message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _parsingVoice = false;
        });
      }
    }
  }

  void _clearDetectedSymptoms() {
    final draft = _voiceDraft;
    if (draft == null || draft.symptoms.isEmpty) {
      return;
    }
    setState(() {
      _voiceDraft = draft.copyWith(
        symptoms: const <VoiceCheckInSymptomDraft>[],
      );
    });
  }

  void _onGemmaSymptomMenuActionSelected(_GemmaSymptomMenuAction action) {
    switch (action) {
      case _GemmaSymptomMenuAction.detectFromNotes:
        unawaited(_extractSymptomsWithGemma());
        break;
      case _GemmaSymptomMenuAction.clearDetected:
        _clearDetectedSymptoms();
        break;
    }
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechReady) {
      return true;
    }

    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      if (mounted) {
        setState(() {
          _voiceError = 'Microphone permission denied.';
        });
      }
      return false;
    }

    final available = await _speechToText.initialize(
      onStatus: (status) {
        // Don't auto-finalize when the runtime stops listening; allow the user
        // to review and explicitly send the transcript to Gemma.
        if (!mounted) return;
        // keep _listening flag in sync if runtime reports notListening/done
        if ((status == 'done' || status == 'notListening') && _listening) {
          setState(() {
            _listening = false;
          });
        }
      },
      onError: _handleSpeechError,
    );

    if (!mounted) {
      return false;
    }

    setState(() {
      _speechReady = available;
      if (!available) {
        _voiceError = 'Speech recognition is not available on this device.';
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
      // Stop listening but do not auto-send; user will review and press "Send to Gemma"
      if (mounted) {
        setState(() {
          _listening = false;
        });
      }
      return;
    }

    final ready = await _ensureSpeechReady();
    if (!ready || !mounted) {
      return;
    }

    setState(() {
      _voiceTranscript = '';
      _voiceTranscriptController.text = '';
      _voiceError = null;
      _voiceDraft = null;
      _listening = true;
    });

    await _speechToText.listen(
      localeId: 'en_US',
      listenFor: _speechListenFor,
      pauseFor: _speechPauseFor,
      listenOptions: SpeechListenOptions(partialResults: true),
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _voiceTranscript = result.recognizedWords;
          _voiceTranscriptController.text = _voiceTranscript;
        });
        // Do not auto-finalize on finalResult; wait for user confirmation
      },
    );
  }

  Future<void> _finalizeVoiceCapture() async {
    if (_parsingVoice) {
      return;
    }

    // Use the (possibly edited) transcript from the controller so user edits are respected
    final transcript = _voiceTranscriptController.text.trim();
    if (transcript.isEmpty) {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceError = 'I did not recognize any useful text.';
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
        const SnackBar(content: Text('Check-in filled in by Gemma 4')),
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
        SnackBar(
          content: Text('Voice dictation could not be completed: $message'),
        ),
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
      if (DateUtils.isSameDay(entry.entryDate, DateTime.now())) {
        await ref
            .read(localMedicationReminderServiceProvider)
            .cancelDailyCheckInRemindersForDate(targetDate: entry.entryDate);
      }
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
        invalidatePatientScopedProviders(ref);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in and voice symptoms saved')),
        );
        context.pop();
        return;
      }

      invalidatePatientScopedProviders(ref);
      if (!mounted) return;
      final addSymptom = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check-in saved'),
          content: const Text('Add a symptom now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add now'),
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
      appBar: AppBar(title: const Text('New check-up')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Gemma 4 voice dictation',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speak in English: ClinDiary transcribes your voice, Gemma 4 fills in the check-in and can add recognized symptoms.',
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
                          label: Text(_listening ? 'Stop' : 'Speak'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              (_listening ||
                                  _parsingVoice ||
                                  (_voiceTranscriptController.text.isEmpty &&
                                      _voiceDraft == null &&
                                      _voiceError == null))
                              ? null
                              : _clearVoiceDraft,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear'),
                        ),
                        FilledButton.icon(
                          onPressed:
                              (_listening ||
                                  _parsingVoice ||
                                  _voiceTranscriptController.text
                                      .trim()
                                      .isEmpty)
                              ? null
                              : () async {
                                  // Explicitly send edited transcript to Gemma
                                  await _finalizeVoiceCapture();
                                },
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Send to Gemma'),
                        ),
                        PopupMenuButton<_GemmaSymptomMenuAction>(
                          enabled: !_saving && !_parsingVoice && !_listening,
                          onSelected: _onGemmaSymptomMenuActionSelected,
                          itemBuilder: (context) => [
                            const PopupMenuItem<_GemmaSymptomMenuAction>(
                              value: _GemmaSymptomMenuAction.detectFromNotes,
                              child: Text('Detect symptoms with Gemma'),
                            ),
                            PopupMenuItem<_GemmaSymptomMenuAction>(
                              value: _GemmaSymptomMenuAction.clearDetected,
                              enabled:
                                  (_voiceDraft?.symptoms.isNotEmpty ?? false),
                              child: const Text('Clear detected symptoms'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: ShapeDecoration(
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.healing_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Symptoms via Gemma'),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, size: 20),
                              ],
                            ),
                          ),
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
                      const Text('Listening...'),
                    ],
                    if (_parsingVoice) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Gemma is filling in the fields...'),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Transcript (edit before sending)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _voiceTranscriptController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText:
                            'Your transcript will appear here after recording. Edit as needed before sending to Gemma.',
                      ),
                      onChanged: (v) => setState(() => _voiceTranscript = v),
                    ),
                    if (_voiceDraft != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _voiceDraft!.hasSymptoms
                            ? 'Gemma filled in the fields and ${_voiceDraft!.symptoms.length} symptoms.'
                            : 'Gemma filled in the main fields. Open "Symptoms via Gemma" to detect symptoms from notes.',
                      ),
                      if (_voiceDraft!.hasFollowUpQuestions) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Gemma asks for clarification before closing the check-in.',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _voiceDraft!.followUpQuestions
                              .map((question) => Chip(label: Text(question)))
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add another voice message or fill in the fields manually if needed.',
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
                title: 'Check-in basics',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date (YYYY-MM-DD)',
                      ),
                      validator: (value) {
                        if (value == null || DateTime.tryParse(value) == null) {
                          return 'Invalid date';
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
                        labelText: 'Sleep hours',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'General notes',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Quick metrics',
                child: Column(
                  children: [
                    MetricPicker(
                      label: 'Sleep quality',
                      value: _sleepQuality,
                      onChanged: (v) => setState(() => _sleepQuality = v),
                    ),
                    MetricPicker(
                      label: 'Energy',
                      value: _energy,
                      onChanged: (v) => setState(() => _energy = v),
                    ),
                    MetricPicker(
                      label: 'Mood',
                      value: _mood,
                      onChanged: (v) => setState(() => _mood = v),
                    ),
                    MetricPicker(
                      label: 'Stress',
                      value: _stress,
                      onChanged: (v) => setState(() => _stress = v),
                    ),
                    MetricPicker(
                      label: 'Appetite',
                      value: _appetite,
                      onChanged: (v) => setState(() => _appetite = v),
                    ),
                    MetricPicker(
                      label: 'Hydration',
                      value: _hydration,
                      onChanged: (v) => setState(() => _hydration = v),
                    ),
                    MetricPicker(
                      label: 'General pain',
                      value: _pain,
                      onChanged: (v) => setState(() => _pain = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Saving...' : 'Save check-in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
