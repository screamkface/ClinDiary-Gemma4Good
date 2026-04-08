import 'package:clindiary/features/daily_journal/domain/voice_check_in_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice check-in draft parses Gemma JSON and normalizes payloads', () {
    const response = '''
```json
{
  "entry_date": "2026-04-08",
  "sleep_hours": "6.5",
  "sleep_quality": 7,
  "energy_level": 4,
  "mood_level": 5,
  "stress_level": 3,
  "appetite_level": 6,
  "hydration_level": 7,
  "general_pain": 2,
  "general_notes": "Mi sento stanco e ho un po di cefalea.",
  "follow_up_questions": ["Hai anche nausea?"],
  "symptoms": [
    {
      "symptom_code": "headache",
      "severity": "4",
      "duration_minutes": 30,
      "body_location": "testa",
      "metadata_json": {
        "notes": "Peggiora a fine giornata"
      }
    }
  ]
}
```
''';

    final draft = VoiceCheckInDraft.fromAiResponse(response);

    expect(draft.sleepHours, closeTo(6.5, 0.001));
    expect(draft.sleepQuality, 7);
    expect(draft.energyLevel, 4);
    expect(draft.moodLevel, 5);
    expect(draft.stressLevel, 3);
    expect(draft.appetiteLevel, 6);
    expect(draft.hydrationLevel, 7);
    expect(draft.generalPain, 2);
    expect(draft.generalNotes, 'Mi sento stanco e ho un po di cefalea.');
    expect(draft.followUpQuestions, hasLength(1));
    expect(draft.followUpQuestions.first, 'Hai anche nausea?');
    expect(draft.symptoms, hasLength(1));
    expect(draft.symptoms.first.symptomCode, 'headache');
    expect(draft.symptoms.first.severity, 4);
    expect(draft.symptoms.first.durationMinutes, 30);
    expect(draft.symptoms.first.bodyLocation, 'testa');
    expect(
      draft.symptoms.first.toRequestPayload()['metadata_json'],
      isA<Map<String, dynamic>>(),
    );
    expect(draft.toDailyEntryPayload('2026-04-07')['entry_date'], '2026-04-08');
  });
}
