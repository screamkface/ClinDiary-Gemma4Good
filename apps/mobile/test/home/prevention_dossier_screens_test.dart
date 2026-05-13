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
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en_US');
  });

  testWidgets('prevention center screen shows main sections', (tester) async {
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
                title: 'Annual preventive visit',
                subtitle: 'General check-up',
                status: 'recommended',
                priority: 'normal',
                category: 'general_prevention',
                kind: 'screening',
              ),
              visitsAndControls: const [
                PreventionRecommendationItem(
                  code: 'blood_pressure_adults',
                  title: 'Blood pressure check',
                  subtitle: 'To discuss with your doctor',
                  status: 'recommended',
                  priority: 'normal',
                  category: 'cardiometabolic',
                  kind: 'screening',
                ),
              ],
              vaccines: const [
                PreventionRecommendationItem(
                  code: 'influenza_annual_review',
                  title: 'Influenza vaccine',
                  status: 'recommended',
                  priority: 'normal',
                  category: 'vaccines',
                  kind: 'vaccine',
                ),
              ],
              seasonalChecks: const [
                PreventionRecommendationItem(
                  code: 'spring_allergy_review',
                  title: 'Seasonal allergy review',
                  status: 'seasonal',
                  priority: 'normal',
                  category: 'seasonal',
                  kind: 'seasonal_check',
                ),
              ],
              followUpReminders: const [
                PreventionRecommendationItem(
                  code: 'report_ready',
                  title: 'Report ready: Weekly summary',
                  status: 'ready',
                  priority: 'low',
                  category: 'follow_up',
                  kind: 'follow_up',
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(
          home: PreventionCenterScreen(),
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Prevention center'), findsOneWidget);
    expect(find.text('Recommended annual visit'), findsOneWidget);
    await tester.tap(find.text('Vaccines'));
    await tester.pumpAndSettle();
    expect(find.text('Recommended vaccines'), findsOneWidget);
    expect(find.text('Influenza vaccine'), findsOneWidget);
    await tester.tap(find.text('Follow-up'));
    await tester.pumpAndSettle();
    expect(find.text('Seasonal checks'), findsOneWidget);
    expect(find.text('Follow-up reminders'), findsOneWidget);
    await tester.tap(find.text('Checks'));
    await tester.pumpAndSettle();
    expect(find.text('Visits and checks for your profile'), findsOneWidget);
  });

  testWidgets('health dossier screen shows ordered sections', (tester) async {
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
                DossierProfileFact(label: 'Smoker', value: 'No'),
              ],
              provenanceFacts: const [
                DossierProvenanceFact(
                  label: 'Profile',
                  value: 'Updated on 24/03/2026 09:00',
                ),
              ],
              emergencySummary: DossierEmergencySummary(
                generatedAt: DateTime.utc(2026, 3, 24, 9),
                headline: 'ClinDiary emergency card',
                keyPoints: const ['Last check-up on 2026-03-23.'],
                activeProblems: const ['Asthma'],
                activeMedications: const ['Cetirizina'],
                allergies: const ['Pollini'],
                conditions: const ['Asthma'],
                openAlerts: const ['attention: Alert follow-up'],
              ),
              allergies: const [AllergyItem(id: 'all-1', allergen: 'Pollen')],
              medicalConditions: const [
                MedicalConditionItem(
                  id: 'cond-1',
                  name: 'Asthma',
                  status: 'active',
                ),
              ],
              medications: const [
                MedicationItem(
                  id: 'med-1',
                  name: 'Cetirizina',
                  dosage: '10 mg',
                  frequency: '1/day',
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
                  relation: 'mother',
                  conditionName: 'hypertension',
                ),
              ],
              vaccinations: const [],
              recentDailyEntries: [
                DailyEntry(
                  id: 'entry-1',
                  entryDate: DateTime.utc(2026, 3, 23),
                  generalNotes: 'Stable day.',
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
                  title: 'Annual blood tests',
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
                  documentTitle: 'Annual blood tests',
                  panelName: 'Blood tests',
                  abnormalResultsCount: 1,
                  keyResults: ['Creatinine: 1.4 mg/dL'],
                ),
              ],
              recentImagingReports: const [],
              deviceMeasurementSummaries: [
                DossierDeviceMeasurementSummary(
                  providerCode: 'ad_medical',
                  providerName: 'A&D Medical',
                  metricType: 'blood_pressure',
                  metricLabel: 'Blood pressure',
                  measurementCount: 2,
                  latestMeasuredAt: DateTime.utc(2026, 3, 24, 20, 5),
                  latestValue: '128/80 mmHg · FC 68 bpm',
                  trendLabel: 'Average 127/80 mmHg',
                  concernLevel: null,
                  concernNote: null,
                  summary:
                      'A&D Medical: 2 measurements, average 127/80 mmHg, latest 128/80 mmHg · HR 68 bpm.',
                ),
              ],
              recentInsights: [
                InsightSummary(
                  id: 'ins-1',
                  summaryType: 'daily',
                  periodStart: DateTime.utc(2026, 3, 23),
                  periodEnd: DateTime.utc(2026, 3, 23),
                  content: 'Cautious summary of the day.',
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
                  description: 'A follow-up check is needed.',
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
        child: const MaterialApp(
          home: HealthDossierScreen(),
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Health dossier'), findsOneWidget);
    expect(find.byKey(const ValueKey('dossier-emergency-nfc')), findsOneWidget);
    await tester.tap(find.text('Clinical'));
    await tester.pumpAndSettle();
    expect(find.text('Current medications'), findsOneWidget);
    expect(find.text('Clinical devices'), findsOneWidget);
    expect(find.text('Blood pressure'), findsOneWidget);
    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    expect(find.text('Recent diary'), findsOneWidget);
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Documents and reports'), findsOneWidget);
    expect(find.text('Annual blood tests'), findsWidgets);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Secure shares'), findsOneWidget);
  });
}
