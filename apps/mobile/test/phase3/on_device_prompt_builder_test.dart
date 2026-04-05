import 'dart:convert';

import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}

void main() {
  test('on-device prompt builder usa la cache locale quando disponibile', () async {
    final database = MockLocalDatabase();

    when(() => database.readCache(activeProfileIdCacheKey)).thenAnswer(
      (_) async => 'profile-1',
    );
    when(() => database.readCache('profile_bundle::profile-1')).thenAnswer(
      (_) async => jsonEncode({
        'profile': {
          'id': 'profile-1',
          'user_id': 'user-1',
          'is_primary': true,
          'first_name': 'Giulia',
          'last_name': 'Rossi',
          'birth_date': '1990-04-01',
          'biological_sex': 'female',
          'smoker': false,
        },
        'onboarding': {'health_data_consent': true},
        'allergies': [
          {'id': 'allergy-1', 'allergen': 'Penicillina'},
        ],
        'medical_conditions': [
          {'id': 'cond-1', 'name': 'Asma'},
        ],
        'medications': [
          {
            'id': 'med-1',
            'name': 'Salbutamolo',
            'dosage': '100 mcg',
            'frequency': 'al bisogno',
            'active': true,
            'schedules': [],
          },
        ],
        'family_history': [
          {
            'id': 'fh-1',
            'relation': 'madre',
            'condition_name': 'ipertensione',
          },
        ],
        'managed_profiles': [],
        'vaccinations': [],
        'clinical_episodes': [],
      }),
    );
    when(() => database.readCache('daily_entries::profile-1')).thenAnswer(
      (_) async => jsonEncode([
        {
          'id': 'entry-1',
          'entry_date': '2026-04-05T08:00:00Z',
          'sleep_hours': 5.5,
          'energy_level': 4,
          'stress_level': 6,
          'general_pain': 2,
          'general_notes': 'Tosse leggera al mattino.',
          'symptoms': [
            {
              'id': 'sym-1',
              'symptom_code': 'cough',
              'severity': 5,
            },
          ],
          'vitals': [
            {
              'id': 'vital-1',
              'type': 'temperature',
              'value': '37.2',
              'unit': 'C',
              'measured_at': '2026-04-05T08:10:00Z',
            },
          ],
        },
      ]),
    );
    when(() => database.readCache('medication_logs::profile-1')).thenAnswer(
      (_) async => jsonEncode([
        {
          'id': 'log-1',
          'medication_id': 'med-1',
          'medication_name': 'Salbutamolo',
          'medication_dosage': '100 mcg',
          'scheduled_at': '2026-04-05T09:00:00Z',
          'status': 'taken',
        },
      ]),
    );
    when(() => database.readCache('wearables_recent_30::profile-1')).thenAnswer(
      (_) async => jsonEncode([
        {
          'summary_date': '2026-04-05',
          'source_platform': 'android',
          'source_name': 'Xiaomi 15T Pro',
          'steps_count': 4200,
          'sleep_minutes': 330,
          'heart_rate_avg_bpm': 72.0,
          'record_count': 10,
        },
      ]),
    );
    when(() => database.readCache('timeline_events::profile-1')).thenAnswer(
      (_) async => jsonEncode([
        {
          'id': 'evt-1',
          'event_type': 'daily_entry',
          'title': 'Check-up giornaliero',
          'description': 'Diario aggiornato con sintomi e parametri.',
          'event_date': '2026-04-05T08:15:00Z',
        },
      ]),
    );
    when(() => database.readCache('alerts_list::profile-1')).thenAnswer(
      (_) async => jsonEncode([]),
    );
    when(() => database.readCache('wearables_recent_14::profile-1')).thenAnswer(
      (_) async => null,
    );
    when(() => database.readCache('wearables_recent_7::profile-1')).thenAnswer(
      (_) async => null,
    );

    final builder = OnDevicePromptBuilder(localDatabase: database);
    final prompt = await builder.buildDailyRecapPrompt(
      referenceDate: DateTime(2026, 4, 5),
    );

    expect(prompt, isNotNull);
    expect(prompt!.suggestedModelFamily, 'Gemma 4');
    expect(prompt.systemPrompt, contains('Usa esclusivamente i dati presenti'));
    expect(prompt.userPrompt, contains('Giulia Rossi'));
    expect(prompt.userPrompt, contains('Salbutamolo'));
    expect(prompt.userPrompt, contains('4200 passi'));
    expect(prompt.userPrompt, contains('Tosse leggera al mattino.'));
  });
}
