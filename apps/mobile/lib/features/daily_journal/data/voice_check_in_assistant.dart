import 'package:clindiary/features/daily_journal/domain/voice_check_in_draft.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class VoiceCheckInAssistant {
  VoiceCheckInAssistant({required OnDeviceAiService onDeviceAiService})
    : _onDeviceAiService = onDeviceAiService;

  static final RegExp _symptomSignalPattern = RegExp(
    r'\b(symptom|symptoms|sintomo|sintomi|pain|dolore|headache|cefalea|fever|febbre|nausea|cough|tosse|fatigue|stanchezza|dizziness|vertigini)\b',
    caseSensitive: false,
  );
  static final RegExp _noSymptomPattern = RegExp(
    r'\b(no|without|nessun|nessuna|senza)\s+(symptom|symptoms|sintomo|sintomi|pain|dolore)\b',
    caseSensitive: false,
  );

  final OnDeviceAiService _onDeviceAiService;

  static final Tool _fillCheckInTool = Tool(
    name: 'fill_check_in',
    description: 'Fill in a daily check-in from a voice transcript',
    parameters: {
      'type': 'object',
      'properties': {
        'entry_date': {
          'type': 'string',
          'description': 'Date in YYYY-MM-DD format or null',
        },
        'sleep_hours': {
          'type': 'number',
          'description': 'Hours of sleep (0-24) or null',
        },
        'sleep_quality': {
          'type': 'integer',
          'description': 'Sleep quality 0-10 or null',
        },
        'energy_level': {
          'type': 'integer',
          'description': 'Energy level 0-10 or null',
        },
        'mood_level': {
          'type': 'integer',
          'description': 'Mood level 0-10 or null',
        },
        'stress_level': {
          'type': 'integer',
          'description': 'Stress level 0-10 or null',
        },
        'appetite_level': {
          'type': 'integer',
          'description': 'Appetite level 0-10 or null',
        },
        'hydration_level': {
          'type': 'integer',
          'description': 'Hydration level 0-10 or null',
        },
        'general_pain': {
          'type': 'integer',
          'description': 'General pain 0-10 or null',
        },
        'general_notes': {
          'type': 'string',
          'description': 'Short note in English, not the full transcript',
        },
        'follow_up_questions': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Questions to clarify if details are missing',
        },
        'symptoms': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'symptom_code': {
                'type': 'string',
                'description':
                    'Use: headache, fever, nausea, cough, fatigue, or snake_case',
              },
              'severity': {
                'type': 'integer',
                'description': 'Severity 0-10 or null',
              },
              'duration_minutes': {
                'type': 'integer',
                'description': 'Duration in minutes or null',
              },
              'body_location': {
                'type': 'string',
                'description': 'Body location or null',
              },
              'metadata_json': {
                'type': 'object',
                'description': 'Additional notes and flags',
              },
            },
          },
        },
      },
    },
  );

  Future<VoiceCheckInDraft> buildDraftFromTranscript({
    required String transcript,
    required DateTime referenceDate,
  }) async {
    try {
      final args = await _onDeviceAiService.callFunction(
        systemPrompt: _systemPrompt,
        userMessage: _buildUserMessage(transcript, referenceDate),
        tools: [_fillCheckInTool],
      );
      final draft = VoiceCheckInDraft.fromJson(args);
      return _ensureSymptomCoverage(draft: draft, transcript: transcript);
    } on Exception {
      final response = await _onDeviceAiService.generateText(
        systemPrompt: _systemPrompt,
        userPrompt: _buildUserPrompt(
          transcript: transcript,
          referenceDate: referenceDate,
        ),
      );
      final parsedDraft = VoiceCheckInDraft.fromAiResponse(response);
      return _ensureSymptomCoverage(draft: parsedDraft, transcript: transcript);
    }
  }

  VoiceCheckInDraft _ensureSymptomCoverage({
    required VoiceCheckInDraft draft,
    required String transcript,
  }) {
    if (draft.symptoms.isNotEmpty ||
        !_symptomSignalPattern.hasMatch(transcript) ||
        _noSymptomPattern.hasMatch(transcript)) {
      return draft;
    }

    final fallbackNotes = _resolveFallbackNotes(draft.generalNotes, transcript);
    final followUpQuestions = <String>[
      ...draft.followUpQuestions,
      if (!draft.followUpQuestions.any(
        (question) => question.toLowerCase().contains('symptom'),
      ))
        'Which symptom did you feel exactly?',
    ];

    return draft.copyWith(
      generalNotes: fallbackNotes,
      followUpQuestions: followUpQuestions,
      symptoms: <VoiceCheckInSymptomDraft>[
        VoiceCheckInSymptomDraft(
          symptomCode: 'unspecified_symptom',
          metadataJson: fallbackNotes == null || fallbackNotes.isEmpty
              ? const <String, dynamic>{}
              : <String, dynamic>{'notes': fallbackNotes},
        ),
      ],
    );
  }

  String? _resolveFallbackNotes(String? generalNotes, String transcript) {
    final existingNotes = generalNotes?.trim();
    if (existingNotes != null && existingNotes.isNotEmpty) {
      return existingNotes;
    }

    final normalizedTranscript = transcript
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalizedTranscript.isEmpty) {
      return null;
    }

    if (normalizedTranscript.length <= 180) {
      return normalizedTranscript;
    }

    return '${normalizedTranscript.substring(0, 177)}...';
  }

  String _buildUserMessage(String transcript, DateTime referenceDate) {
    final day = referenceDate.toIso8601String().split('T').first;
    return 'Reference date: $day\n\nUser voice transcript:\n"""\n$transcript\n"""';
  }

  String _buildUserPrompt({
    required String transcript,
    required DateTime referenceDate,
  }) {
    final day = referenceDate.toIso8601String().split('T').first;
    return '''
Reference date: $day

User voice transcript:
"""
$transcript
"""

Fill in the check-up as JSON using the required schema.
''';
  }

  static const String _systemPrompt = '''
You are Gemma 4 inside ClinDiary.
Transform a voice transcript into structured check-in data.
Do not invent data. If a field is missing, use null.
For unclear symptoms, use symptom_code "unspecified_symptom" and place any short user detail in metadata_json.notes.
''';
}
