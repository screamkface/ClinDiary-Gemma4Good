import 'package:clindiary/features/daily_journal/domain/voice_check_in_draft.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';

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

  Future<VoiceCheckInDraft> buildDraftFromTranscript({
    required String transcript,
    required DateTime referenceDate,
  }) async {
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
Transform a voice transcript into pure JSON to fill in a daily check-up.

Rules:
- return only JSON, without markdown or extra text
- do not invent data
- if a field is missing, use null
- use integers from 0 to 10 for sleep_quality, energy_level, mood_level, stress_level, appetite_level, hydration_level, and general_pain
- sleep_hours must be a number between 0 and 24
- general_notes must be a short note in English, not the full transcript
- symptoms must be a list of objects
- each symptom must contain symptom_code, severity, duration_minutes, body_location, and metadata_json
- use these codes if they fit: headache, fever, nausea, cough, fatigue
- if needed, use a free snake_case code
- if the user describes multiple symptoms, include them all
- if the symptom is not clear, leave the field empty instead of guessing
- if useful details are missing or the text is ambiguous, add follow_up_questions with short questions in English
- follow_up_questions must be an empty list if no clarification is needed
- if the user reports symptoms but type is unclear, include one symptom with symptom_code "unspecified_symptom"
- for unclear symptoms, place the short user detail in metadata_json.notes

Required schema:
{
  "entry_date": "YYYY-MM-DD or null",
  "sleep_hours": 7.5,
  "sleep_quality": 7,
  "energy_level": 6,
  "mood_level": 6,
  "stress_level": 4,
  "appetite_level": 6,
  "hydration_level": 6,
  "general_pain": 2,
  "general_notes": "stringa breve oppure null",
  "follow_up_questions": ["Hai febbre?"],
  "symptoms": [
    {
      "symptom_code": "headache",
      "severity": 4,
      "duration_minutes": 30,
      "body_location": "head",
      "metadata_json": {"notes": "short note"}
    }
  ]
}
''';
}
