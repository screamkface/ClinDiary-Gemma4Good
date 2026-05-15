import 'dart:convert';

import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}

void main() {
  test(
    'on-device prompt builder uses the local cache when available',
    () async {
      final database = MockLocalDatabase();

      when(
        () => database.readCache(activeProfileIdCacheKey),
      ).thenAnswer((_) async => 'profile-1');
      when(
        () => database.readCache('app_display_settings'),
      ).thenAnswer((_) async => null);
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
            {'id': 'allergy-1', 'allergen': 'Penicillin'},
          ],
          'medical_conditions': [
            {'id': 'cond-1', 'name': 'Asthma'},
          ],
          'medications': [
            {
              'id': 'med-1',
              'name': 'Salbutamolo',
              'dosage': '100 mcg',
              'frequency': 'as needed',
              'active': true,
              'schedules': [],
            },
          ],
          'family_history': [
            {
              'id': 'fh-1',
              'relation': 'mother',
              'condition_name': 'hypertension',
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
            'general_notes': 'Mild cough in the morning.',
            'symptoms': [
              {
                'id': 'sym-1',
                'symptom_code': 'cough',
                'severity': 5,
                'metadata_json': {'notes': 'Worse with work stress'},
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
      when(
        () => database.readCache('wearables_recent_30::profile-1'),
      ).thenAnswer(
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
            'title': 'Daily check-up',
            'description': 'Diary updated with symptoms and measurements.',
            'event_date': '2026-04-05T08:15:00Z',
          },
        ]),
      );
      when(
        () => database.readCache('alerts_list::profile-1'),
      ).thenAnswer((_) async => jsonEncode([]));
      when(() => database.readCache('health_dossier::profile-1')).thenAnswer(
        (_) async => jsonEncode({
          'generated_at': '2026-04-05T09:00:00Z',
          'display_name': 'Giulia Rossi',
          'age': 36,
          'biological_sex': 'female',
          'profile_facts': [
            {'label': 'weight', 'value': '62 kg'},
          ],
          'provenance_facts': [],
          'emergency_summary': null,
          'allergies': [
            {'id': 'allergy-1', 'allergen': 'Penicillin'},
          ],
          'medical_conditions': [
            {'id': 'cond-1', 'name': 'Asthma'},
          ],
          'medications': [
            {
              'id': 'med-1',
              'name': 'Salbutamolo',
              'dosage': '100 mcg',
              'frequency': 'as needed',
              'active': true,
              'schedules': [],
            },
          ],
          'family_history': [
            {
              'id': 'fh-1',
              'relation': 'mother',
              'condition_name': 'hypertension',
            },
          ],
          'vaccinations': [],
          'clinical_episodes': [],
          'recent_daily_entries': [],
          'recent_documents': [
            {
              'id': 'doc-1',
              'title': 'Chest X-ray',
              'document_type': 'imaging_report',
              'upload_date': '2026-04-04T12:00:00Z',
              'exam_date': '2026-04-04T10:00:00Z',
              'source': 'Clinica Demo',
              'parsed_status': 'parsed',
              'context_status': 'linked',
            },
          ],
          'recent_lab_panels': [
            {
              'document_id': 'lab-doc-1',
              'document_title': 'Complete blood count',
              'panel_name': 'Complete blood count',
              'panel_date': '2026-04-04T07:30:00Z',
              'abnormal_results_count': 1,
              'key_results': ['PCR 12 mg/L', 'GB 10.8'],
            },
          ],
          'recent_imaging_reports': [
            {
              'document_id': 'img-doc-1',
              'document_title': 'Chest X-ray',
              'exam_date': '2026-04-04T10:00:00Z',
              'exam_type': 'RX',
              'body_part': 'Chest',
              'impression': 'No focal consolidation',
            },
          ],
          'device_measurement_summaries': [
            {
              'provider_code': 'omron',
              'provider_name': 'Omron',
              'metric_type': 'blood_pressure',
              'metric_label': 'Blood pressure',
              'measurement_count': 3,
              'latest_measured_at': '2026-04-05T07:20:00Z',
              'latest_value': '128/82 mmHg',
              'trend_label': 'stable',
              'concern_level': null,
              'concern_note': null,
              'summary': 'Blood pressure: recent average 128/82 mmHg, stable.',
            },
          ],
          'recent_insights': [
            {
              'id': 'insight-1',
              'summary_type': 'daily',
              'period_start': '2026-04-04',
              'period_end': '2026-04-04',
              'content': 'Stable compared to previous days with mild cough.',
              'provider_name': 'local_gemma4',
              'model_name': 'gemma-4-e2b',
              'generated_at': '2026-04-04T20:00:00Z',
            },
          ],
          'recent_reports': [],
          'alerts': [],
          'wearable_summaries': [],
        }),
      );
      when(
        () => database.readCache('wearables_recent_14::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_7::profile-1'),
      ).thenAnswer((_) async => null);

      final builder = OnDevicePromptBuilder(localDatabase: database);
      final prompt = await builder.buildDailyRecapPrompt(
        referenceDate: DateTime(2026, 4, 5),
      );

      expect(prompt, isNotNull);
      expect(prompt!.suggestedModelFamily, 'Gemma 4');
      expect(prompt.systemPrompt, contains('Use only the data present'));
      expect(prompt.userPrompt, contains('Giulia Rossi'));
      expect(prompt.userPrompt, contains('Salbutamolo'));
      expect(prompt.userPrompt, contains('4200 steps'));
      expect(prompt.userPrompt, contains('"general_note_tags":["cough"]'));
      expect(prompt.userPrompt, contains('"general_notes":"tags: cough"'));
      expect(prompt.userPrompt, contains('"note_tags":["work_stress"]'));
      expect(prompt.userPrompt, isNot(contains('Mild cough in the morning.')));
      expect(
        prompt.userPrompt,
        contains('Blood pressure: recent average 128/82 mmHg, stable.'),
      );
      expect(prompt.userPrompt, contains('Complete blood count'));
      expect(prompt.userPrompt, contains('RX - Chest'));
      expect(prompt.userPrompt, contains('Chest X-ray'));
      expect(prompt.userPrompt, contains('Stable compared to previous days'));
    },
  );

  test(
    'on-device prompt builder uses local dossier as fallback when other caches are missing',
    () async {
      final database = MockLocalDatabase();

      when(
        () => database.readCache(activeProfileIdCacheKey),
      ).thenAnswer((_) async => 'profile-1');
      when(
        () => database.readCache('app_display_settings'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('profile_bundle::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('daily_entries::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('medication_logs::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_30::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_14::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_7::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('timeline_events::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('alerts_list::profile-1'),
      ).thenAnswer((_) async => null);
      when(() => database.readCache('health_dossier::profile-1')).thenAnswer(
        (_) async => jsonEncode({
          'generated_at': '2026-04-05T09:00:00Z',
          'display_name': 'Maria Bianchi',
          'age': 68,
          'biological_sex': 'female',
          'profile_facts': [
            {'label': 'profile', 'value': 'hypertension in follow-up'},
          ],
          'provenance_facts': [],
          'emergency_summary': null,
          'allergies': [],
          'medical_conditions': [
            {'id': 'cond-1', 'name': 'Hypertension'},
          ],
          'medications': [
            {
              'id': 'med-1',
              'name': 'Ramipril',
              'dosage': '5 mg',
              'frequency': 'morning',
              'active': true,
              'schedules': [],
            },
          ],
          'family_history': [],
          'vaccinations': [],
          'clinical_episodes': [],
          'recent_daily_entries': [
            {
              'id': 'entry-1',
              'entry_date': '2026-04-05T07:30:00Z',
              'sleep_hours': 6.0,
              'energy_level': 5,
              'stress_level': 3,
              'general_notes': 'Feeling tired on waking.',
              'symptoms': [],
              'vitals': [],
            },
          ],
          'recent_documents': [],
          'recent_lab_panels': [
            {
              'document_id': 'lab-doc-1',
              'document_title': 'Blood tests',
              'panel_name': 'Fasting glucose',
              'panel_date': '2026-04-03T07:30:00Z',
              'abnormal_results_count': 0,
              'key_results': ['96 mg/dL'],
            },
          ],
          'recent_imaging_reports': [],
          'device_measurement_summaries': [
            {
              'provider_code': 'omron',
              'provider_name': 'Omron',
              'metric_type': 'blood_pressure',
              'metric_label': 'Blood pressure',
              'measurement_count': 4,
              'latest_measured_at': '2026-04-05T07:15:00Z',
              'latest_value': '134/84 mmHg',
              'trend_label': 'stable',
              'concern_level': null,
              'concern_note': null,
              'summary': 'Blood pressure: latest value 134/84 mmHg.',
            },
          ],
          'recent_insights': [],
          'recent_reports': [],
          'alerts': [
            {
              'id': 'alert-1',
              'title': 'Blood pressure to recheck',
              'severity': 'medium',
              'alert_type': 'monitoring',
              'description': 'Check blood pressure again in upcoming readings.',
              'status': 'open',
              'triggered_at': '2026-04-05T07:25:00Z',
            },
          ],
          'wearable_summaries': [
            {
              'summary_date': '2026-04-05',
              'source_platform': 'android',
              'source_name': 'Xiaomi 15T Pro',
              'steps_count': 3100,
              'sleep_minutes': 360,
              'record_count': 8,
            },
          ],
        }),
      );

      final builder = OnDevicePromptBuilder(localDatabase: database);
      final prompt = await builder.buildDailyRecapPrompt(
        referenceDate: DateTime(2026, 4, 5),
      );

      expect(prompt, isNotNull);
      expect(prompt!.userPrompt, contains('Maria Bianchi'));
      expect(prompt.userPrompt, contains('Ramipril'));
      expect(
        prompt.userPrompt,
        contains('Blood pressure: latest value 134/84 mmHg.'),
      );
      expect(prompt.userPrompt, contains('Fasting glucose'));
      expect(prompt.userPrompt, contains('3100 steps'));
    },
  );

  test(
    'on-device prompt builder skips local prompt when cache is too sparse',
    () async {
      final database = MockLocalDatabase();

      when(
        () => database.readCache(activeProfileIdCacheKey),
      ).thenAnswer((_) async => 'profile-1');
      when(
        () => database.readCache('app_display_settings'),
      ).thenAnswer((_) async => null);
      when(() => database.readCache('profile_bundle::profile-1')).thenAnswer(
        (_) async => jsonEncode({
          'profile': {
            'id': 'profile-1',
            'user_id': 'user-1',
            'is_primary': true,
            'first_name': 'Elena',
            'last_name': 'Rossi',
            'birth_date': '1988-11-02',
            'biological_sex': 'female',
            'smoker': false,
          },
          'onboarding': {'health_data_consent': true},
          'allergies': [],
          'medical_conditions': [
            {'id': 'cond-1', 'name': 'Recurring rhinitis'},
          ],
          'medications': [
            {
              'id': 'med-1',
              'name': 'Saline nasal spray',
              'dosage': '2 puff',
              'frequency': '2/day',
              'active': true,
              'schedules': [],
            },
          ],
          'family_history': [],
          'managed_profiles': [],
          'vaccinations': [],
          'clinical_episodes': [],
        }),
      );
      when(
        () => database.readCache('daily_entries::profile-1'),
      ).thenAnswer((_) async => null);
      when(() => database.readCache('medication_logs::profile-1')).thenAnswer(
        (_) async => jsonEncode([
          {
            'id': 'log-1',
            'medication_id': 'med-1',
            'medication_name': 'Saline nasal spray',
            'medication_dosage': '2 puff',
            'scheduled_at': '2026-04-05T09:00:00Z',
            'status': 'taken',
          },
        ]),
      );
      when(
        () => database.readCache('wearables_recent_30::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_14::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_7::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('timeline_events::profile-1'),
      ).thenAnswer((_) async => null);
      when(() => database.readCache('alerts_list::profile-1')).thenAnswer(
        (_) async => jsonEncode([
          {
            'id': 'alert-1',
            'severity': 'attention',
            'alert_type': 'sleep_decline',
            'title': 'Reduced sleep in recent days',
            'description': 'Poor sleep pattern to contextualize in the recap.',
            'status': 'open',
            'triggered_at': '2026-04-05T07:30:00Z',
          },
        ]),
      );
      when(
        () => database.readCache('health_dossier::profile-1'),
      ).thenAnswer((_) async => null);

      final builder = OnDevicePromptBuilder(localDatabase: database);
      final prompt = await builder.buildDailyRecapPrompt(
        referenceDate: DateTime(2026, 4, 5),
      );

      expect(prompt, isNull);
    },
  );

  test(
    'on-device prompt builder accepts a focused document even without other cached context',
    () async {
      final database = MockLocalDatabase();

      when(
        () => database.readCache(activeProfileIdCacheKey),
      ).thenAnswer((_) async => 'profile-1');
      when(
        () => database.readCache('app_display_settings'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('profile_bundle::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('daily_entries::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('medication_logs::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_30::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_14::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('wearables_recent_7::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('timeline_events::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('alerts_list::profile-1'),
      ).thenAnswer((_) async => null);
      when(
        () => database.readCache('health_dossier::profile-1'),
      ).thenAnswer((_) async => null);

      final builder = OnDevicePromptBuilder(localDatabase: database);
      final prompt = await builder.buildClinicalQuestionPrompt(
        question: 'Explain this lab report simply',
        referenceDate: DateTime(2026, 4, 5),
        focusedDocument: ClinicalDocumentDetail(
          id: 'doc-1',
          title: 'April labs',
          documentType: 'lab_report',
          uploadDate: DateTime(2026, 4, 5),
          examDate: DateTime(2026, 4, 4),
          originalFilename: 'image.png',
          mimeType: 'image/png',
          fileSizeBytes: 2048,
          parsedStatus: 'reviewed',
          fileUrl: '/tmp/image.png',
          ocrText: 'Hemoglobin 14.5 g/dL 13.5 - 17.5',
          labPanels: const [
            LabPanelItem(
              id: 'panel-1',
              panelName: 'Complete blood count',
              results: [
                LabResultItem(
                  id: 'result-1',
                  analyteName: 'Hemoglobin',
                  value: '14.5',
                  unit: 'g/dL',
                  refMin: 13.5,
                  refMax: 17.5,
                ),
              ],
            ),
          ],
          imagingReports: const [],
          storageLocation: 'local',
        ),
      );

      expect(prompt, isNotNull);
      expect(prompt!.contextType, 'clinical_question');
      expect(prompt.periodStart, DateTime(2026, 4, 4));
      expect(prompt.periodEnd, DateTime(2026, 4, 4));
      expect(prompt.userPrompt, contains('Explain this lab report simply'));
      expect(prompt.userPrompt, contains('April labs'));
      expect(prompt.userPrompt, contains('Hemoglobin'));
      expect(prompt.userPrompt, contains('14.5'));
      expect(prompt.userPrompt, isNot(contains('/tmp/image.png')));
    },
  );
}
