import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/features/dossier/presentation/health_dossier_screen.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/prevention_center/presentation/prevention_center_screen.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('prevention center screen mostra sezioni principali', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preventionCenterProvider.overrideWith(
            (ref) async => PreventionCenterData(
              generatedAt: DateTime.utc(2026, 3, 24, 9),
              displayName: 'Anna Bianchi',
              age: 34,
              biologicalSex: 'female',
              overview: const PreventionCenterOverview(
                actionableScreenings: 2,
                vaccineReviews: 3,
                seasonalChecks: 1,
                followUpItems: 1,
              ),
              annualVisit: const PreventionRecommendationItem(
                code: 'preventive_annual_visit',
                title: 'Visita preventiva annuale',
                subtitle: 'Controllo generale',
                status: 'recommended',
                priority: 'normal',
                category: 'prevenzione_generale',
                kind: 'screening',
              ),
              visitsAndControls: const [
                PreventionRecommendationItem(
                  code: 'blood_pressure_adults',
                  title: 'Controllo pressione arteriosa',
                  subtitle: 'Da discutere col medico',
                  status: 'recommended',
                  priority: 'normal',
                  category: 'cardiometabolico',
                  kind: 'screening',
                ),
              ],
              vaccines: const [
                PreventionRecommendationItem(
                  code: 'influenza_annual_review',
                  title: 'Vaccino antinfluenzale',
                  status: 'recommended',
                  priority: 'normal',
                  category: 'vaccini',
                  kind: 'vaccine',
                ),
              ],
              seasonalChecks: const [
                PreventionRecommendationItem(
                  code: 'spring_allergy_review',
                  title: 'Revisione allergie stagionali',
                  status: 'seasonal',
                  priority: 'normal',
                  category: 'stagionale',
                  kind: 'seasonal_check',
                ),
              ],
              followUpReminders: const [
                PreventionRecommendationItem(
                  code: 'report_ready',
                  title: 'Report pronto: Weekly summary',
                  status: 'ready',
                  priority: 'low',
                  category: 'follow_up',
                  kind: 'follow_up',
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: PreventionCenterScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Centro prevenzione'), findsOneWidget);
    expect(find.text('Visita annuale consigliata'), findsOneWidget);
    await tester.tap(find.text('Vaccini'));
    await tester.pumpAndSettle();
    expect(find.text('Vaccini consigliati'), findsOneWidget);
    expect(find.text('Vaccino antinfluenzale'), findsOneWidget);
    await tester.tap(find.text('Follow-up'));
    await tester.pumpAndSettle();
    expect(find.text('Controlli stagionali'), findsOneWidget);
    expect(find.text('Reminder di follow-up'), findsOneWidget);
    await tester.tap(find.text('Controlli'));
    await tester.pumpAndSettle();
    expect(find.text('Visite e controlli per il tuo profilo'), findsOneWidget);
  });

  testWidgets('health dossier screen mostra sezioni ordinate', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthDossierProvider.overrideWith(
            (ref) async => HealthDossier(
              generatedAt: DateTime.utc(2026, 3, 24, 9),
              displayName: 'Anna Bianchi',
              age: 34,
              biologicalSex: 'female',
              profileFacts: const [
                DossierProfileFact(label: 'BMI', value: '23.1'),
                DossierProfileFact(label: 'Fumo', value: 'No'),
              ],
              provenanceFacts: const [
                DossierProvenanceFact(
                  label: 'Profilo',
                  value: 'Aggiornato il 24/03/2026 09:00',
                ),
              ],
              emergencySummary: DossierEmergencySummary(
                generatedAt: DateTime.utc(2026, 3, 24, 9),
                headline: 'Scheda emergenza ClinDiary',
                keyPoints: const ['Ultimo check-up del 2026-03-23.'],
                activeProblems: const ['Asma'],
                activeMedications: const ['Cetirizina'],
                allergies: const ['Pollini'],
                conditions: const ['Asma'],
                openAlerts: const ['attention: Alert follow-up'],
              ),
              allergies: const [AllergyItem(id: 'all-1', allergen: 'Pollini')],
              medicalConditions: const [
                MedicalConditionItem(
                  id: 'cond-1',
                  name: 'Asma',
                  status: 'active',
                ),
              ],
              medications: const [
                MedicationItem(
                  id: 'med-1',
                  name: 'Cetirizina',
                  dosage: '10 mg',
                  frequency: '1/die',
                  active: true,
                  schedules: [
                    MedicationScheduleItem(
                      id: 'sch-1',
                      scheduledTime: '21:00:00',
                      daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
                      active: true,
                    ),
                  ],
                ),
              ],
              familyHistory: const [
                FamilyHistoryItem(
                  id: 'fam-1',
                  relation: 'madre',
                  conditionName: 'ipertensione',
                ),
              ],
              vaccinations: const [],
              recentDailyEntries: [
                DailyEntry(
                  id: 'entry-1',
                  entryDate: DateTime.utc(2026, 3, 23),
                  generalNotes: 'Giornata stabile.',
                  energyLevel: 7,
                  moodLevel: 7,
                  generalPain: 1,
                  symptoms: const [],
                  vitals: const [],
                ),
              ],
              recentDocuments: [
                DossierDocumentItem(
                  id: 'doc-1',
                  title: 'Esami sangue annuali',
                  documentType: 'lab_report',
                  uploadDate: DateTime.utc(2026, 3, 20),
                  examDate: DateTime.utc(2026, 3, 20),
                  parsedStatus: 'parsed',
                  contextStatus: 'active',
                ),
              ],
              recentLabPanels: const [
                DossierLabPanelItem(
                  documentId: 'doc-1',
                  documentTitle: 'Esami sangue annuali',
                  panelName: 'Esami del sangue',
                  abnormalResultsCount: 1,
                  keyResults: ['Creatinina: 1.4 mg/dL'],
                ),
              ],
              recentImagingReports: const [],
              deviceMeasurementSummaries: [
                DossierDeviceMeasurementSummary(
                  providerCode: 'ad_medical',
                  providerName: 'A&D Medical',
                  metricType: 'blood_pressure',
                  metricLabel: 'Pressione arteriosa',
                  measurementCount: 2,
                  latestMeasuredAt: DateTime.utc(2026, 3, 24, 20, 5),
                  latestValue: '128/80 mmHg · FC 68 bpm',
                  trendLabel: 'Media 127/80 mmHg',
                  concernLevel: null,
                  concernNote: null,
                  summary:
                      'A&D Medical: 2 misure, media 127/80 mmHg, ultima 128/80 mmHg · FC 68 bpm.',
                ),
              ],
              recentInsights: [
                InsightSummary(
                  id: 'ins-1',
                  summaryType: 'daily',
                  periodStart: DateTime.utc(2026, 3, 23),
                  periodEnd: DateTime.utc(2026, 3, 23),
                  content: 'Sintesi prudente della giornata.',
                  providerName: 'gemini_ai_studio',
                  modelName: 'gemini-2.5-flash',
                  generatedAt: DateTime.utc(2026, 3, 23, 20),
                ),
              ],
              recentReports: [
                DossierReportSummary(
                  id: 'rep-1',
                  reportType: 'weekly_summary',
                  title: 'ClinDiary - weekly summary',
                  periodStart: DateTime.utc(2026, 3, 17),
                  periodEnd: DateTime.utc(2026, 3, 23),
                  generatedAt: DateTime.utc(2026, 3, 23, 21),
                ),
              ],
              alerts: [
                ClinicalAlert(
                  id: 'alert-1',
                  severity: 'attention',
                  alertType: 'follow_up',
                  title: 'Alert follow-up',
                  description: 'Serve un controllo.',
                  status: 'open',
                  triggeredAt: DateTime.utc(2026, 3, 23, 10),
                ),
              ],
              wearableSummaries: [
                WearableDaySummary(
                  summaryDate: DateTime.utc(2026, 3, 23),
                  sourcePlatform: 'health_connect',
                  stepsCount: 8200,
                  sleepMinutes: 420,
                  heartRateAvgBpm: 69,
                ),
              ],
            ),
          ),
          dossierShareLinksProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: HealthDossierScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dossier salute'), findsOneWidget);
    expect(find.byKey(const ValueKey('dossier-emergency-nfc')), findsOneWidget);
    await tester.tap(find.text('Clinico'));
    await tester.pumpAndSettle();
    expect(find.text('Farmaci attuali'), findsOneWidget);
    expect(find.text('Dispositivi clinici'), findsOneWidget);
    expect(find.text('Pressione arteriosa'), findsOneWidget);
    await tester.tap(find.text('Diario'));
    await tester.pumpAndSettle();
    expect(find.text('Diario recente'), findsOneWidget);
    await tester.tap(find.text('Referti'));
    await tester.pumpAndSettle();
    expect(find.text('Documenti e referti'), findsOneWidget);
    expect(find.text('Esami sangue annuali'), findsWidgets);
    await tester.tap(find.text('Diario'));
    await tester.pumpAndSettle();
    expect(find.text('Insight, report e alert'), findsOneWidget);
    await tester.tap(find.text('Condividi'));
    await tester.pumpAndSettle();
    expect(find.text('Condivisioni sicure'), findsOneWidget);
  });
}
