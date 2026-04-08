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
Data di riferimento: $day

Trascrizione vocale dell'utente:
"""
$transcript
"""

Compila il check-up in JSON seguendo lo schema richiesto.
''';
  }

  static const String _systemPrompt = '''
Sei Gemma 4 dentro ClinDiary.
Trasforma una trascrizione vocale in un JSON puro per compilare un check-up giornaliero.

Regole:
- restituisci solo JSON, senza markdown o testo extra
- non inventare dati
- se un campo non e presente, usa null
- usa numeri interi da 0 a 10 per sleep_quality, energy_level, mood_level, stress_level, appetite_level, hydration_level e general_pain
- sleep_hours deve essere un numero tra 0 e 24
- general_notes deve essere una nota breve in italiano, non la trascrizione completa
- symptoms deve essere una lista di oggetti
- ogni sintomo deve contenere symptom_code, severity, duration_minutes, body_location e metadata_json
- usa questi codici se sono adatti: headache, fever, nausea, cough, fatigue
- se serve, usa un codice libero in snake_case
- se l'utente descrive piu sintomi, inseriscili tutti
- se il sintomo non e chiaro, lascia il campo vuoto invece di indovinare
- se mancano dettagli utili o il testo e ambiguo, aggiungi follow_up_questions con domande brevi in italiano
- follow_up_questions deve essere una lista vuota se non serve alcun chiarimento

Schema richiesto:
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
  "general_notes": "stringa breve oppure null",
  "follow_up_questions": ["Hai febbre?"],
  "symptoms": [
    {
      "symptom_code": "headache",
      "severity": 4,
      "duration_minutes": 30,
      "body_location": "testa",
      "metadata_json": {"notes": "stringa breve"}
    }
  ]
}
''';
}
