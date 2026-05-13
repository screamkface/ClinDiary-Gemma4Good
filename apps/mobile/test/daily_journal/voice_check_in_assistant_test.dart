import 'package:clindiary/features/daily_journal/data/voice_check_in_assistant.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubOnDeviceAiService extends OnDeviceAiService {
  _StubOnDeviceAiService(this._response);

  final String _response;

  @override
  Future<Map<String, dynamic>> callFunction({
    required String systemPrompt,
    required String userMessage,
    required List<Tool> tools,
  }) async {
    throw Exception('Fallback to prompt-based generation');
  }

  @override
  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
    String? modelPath,
  }) async {
    return _response;
  }
}

void main() {
  test(
    'adds fallback symptom when transcript mentions symptoms but model omits them',
    () async {
      final assistant = VoiceCheckInAssistant(
        onDeviceAiService: _StubOnDeviceAiService('''
{
  "entry_date": "2026-03-22",
  "general_notes": null,
  "follow_up_questions": [],
  "symptoms": []
}
'''),
      );

      final draft = await assistant.buildDraftFromTranscript(
        transcript: 'Today I had nausea and headache since morning.',
        referenceDate: DateTime.utc(2026, 3, 22),
      );

      expect(draft.symptoms, hasLength(1));
      expect(draft.symptoms.first.symptomCode, 'unspecified_symptom');
      expect(draft.symptoms.first.metadataJson['notes'], isA<String>());
      expect(
        draft.followUpQuestions,
        contains('Which symptom did you feel exactly?'),
      );
    },
  );

  test(
    'buildDraftFromTranscript uses function calling and falls back to text generation',
    () async {
      final stub = _StubOnDeviceAiService(
        '{"entry_date": "2026-03-22", "general_notes": null, "follow_up_questions": [], "symptoms": []}',
      );

      final assistant = VoiceCheckInAssistant(onDeviceAiService: stub);

      final draft = await assistant.buildDraftFromTranscript(
        transcript: 'Feeling fine today.',
        referenceDate: DateTime.utc(2026, 3, 22),
      );

      expect(draft.generalNotes, isNull);
      expect(draft.entryDate, DateTime(2026, 3, 22));
    },
  );

  test(
    'does not force symptoms when transcript has no symptom hints',
    () async {
      final assistant = VoiceCheckInAssistant(
        onDeviceAiService: _StubOnDeviceAiService('''
{
  "entry_date": "2026-03-22",
  "general_notes": "Slept better today",
  "follow_up_questions": [],
  "symptoms": []
}
'''),
      );

      final draft = await assistant.buildDraftFromTranscript(
        transcript: 'I slept well and walked for 30 minutes.',
        referenceDate: DateTime.utc(2026, 3, 22),
      );

      expect(draft.symptoms, isEmpty);
    },
  );
}
