import 'package:clindiary/features/daily_journal/domain/voice_check_in_draft.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';

class VoiceCheckInAssistant {
  VoiceCheckInAssistant({required OnDeviceAiService onDeviceAiService})
    : _onDeviceAiService = onDeviceAiService;

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
    return VoiceCheckInDraft.fromAiResponse(response);
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

Fill out the check-up in JSON following the required schema.
''';
  }

  static const String _systemPrompt = '''
You are Gemma 4 inside ClinDiary.
Transform a voice transcript into pure JSON for a daily check-up.

Rules:
- return JSON only, without markdown or extra text
- do not invent data
- if a field is missing, use null
- use integers from 0 to 10 for sleep_quality, energy_level, mood_level, stress_level, appetite_level, hydration_level, and general_pain
- sleep_hours must be a number between 0 and 24
- general_notes must be a short note in English, not the full transcript
- symptoms must be a list of objects
- each symptom must contain symptom_code, severity, duration_minutes, body_location, and metadata_json
- use these codes if they fit: headache, fever, nausea, cough, fatigue
- if needed, use a free-form snake_case code
- if the user describes multiple symptoms, include them all
- if a symptom is unclear, leave the field blank instead of guessing
- if useful details are missing or the text is ambiguous, add follow_up_questions with short questions in English
- follow_up_questions must be an empty list if no clarification is needed

Required schema:
{
  "entry_date": "YYYY-MM-DD oppure null",
  "sleep_hours": 7.5,
  "sleep_quality": 7,
  "energy_level": 6,
  "mood_level": 6,
  "stress_level": 4,
  "appetite_level": 6,
  "hydration_level": 6,
  "general_pain": 2,
  "general_notes": "short string or null",
  "follow_up_questions": ["Do you have a fever?"],
  "symptoms": [
    {
      "symptom_code": "headache",
      "severity": 4,
      "duration_minutes": 30,
      "body_location": "head",
      "metadata_json": {"notes": "short string"}
    }
  ]
}
''';
}
