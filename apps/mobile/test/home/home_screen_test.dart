import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/features/home/presentation/home_screen.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('home screen mostra badge per notifiche non lette e farmaci', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertsProvider.overrideWith(
            (ref) async => [
              ClinicalAlert(
                id: 'alert-1',
                severity: 'high',
                alertType: 'follow_up',
                title: 'Alert di prova',
                description: 'Controllo necessario.',
                status: 'open',
                triggeredAt: DateTime.utc(2026, 3, 20, 10),
              ),
            ],
          ),
          notificationsProvider.overrideWith(
            (ref) async => [
              AppNotificationItem(
                id: 'notif-1',
                notificationType: 'clinical_alert',
                title: 'Alert clinico',
                body: 'Promemoria da leggere.',
                priority: 'high',
                readStatus: false,
                createdAt: DateTime.utc(2026, 3, 20, 9),
              ),
            ],
          ),
          unreadNotificationsProvider.overrideWith((ref) async => true),
          pendingMedicationDosesProvider.overrideWith((ref) async => true),
          activeProfileIdProvider.overrideWith((ref) async => 'profile-1'),
          profileBundleProvider.overrideWith(
            (ref) async => ProfileBundle(
              profile: const PatientProfile(
                id: 'profile-1',
                userId: 'user-1',
                isPrimary: true,
                firstName: 'Anna',
                lastName: 'Bianchi',
                smoker: false,
              ),
              onboarding: const OnboardingStatus(healthDataConsent: true),
              allergies: const [],
              medicalConditions: const [],
              medications: const [],
              familyHistory: const [],
              managedProfiles: const [
                PatientProfile(
                  id: 'profile-1',
                  userId: 'user-1',
                  isPrimary: true,
                  firstName: 'Anna',
                  lastName: 'Bianchi',
                  smoker: false,
                ),
                PatientProfile(
                  id: 'profile-2',
                  userId: 'user-1',
                  isPrimary: false,
                  firstName: 'Luca',
                  lastName: 'Bianchi',
                  smoker: false,
                  relationshipLabel: 'figlio',
                ),
              ],
            ),
          ),
          dailyEntriesProvider.overrideWith(
            (ref) async => [
              DailyEntry(
                id: 'entry-1',
                entryDate: DateTime.utc(2026, 3, 20),
                generalNotes: 'Tutto ok.',
                symptoms: const [],
                vitals: const [],
              ),
            ],
          ),
          preventionCenterProvider.overrideWith(
            (ref) async => PreventionCenterData(
              generatedAt: DateTime.utc(2026, 3, 20, 12),
              displayName: 'Anna Bianchi',
              age: 33,
              biologicalSex: 'female',
              overview: const PreventionCenterOverview(
                actionableScreenings: 1,
                vaccineReviews: 2,
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
              visitsAndControls: const [],
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
              seasonalChecks: const [],
              followUpReminders: const [],
            ),
          ),
          healthDossierProvider.overrideWith(
            (ref) async => HealthDossier(
              generatedAt: DateTime.utc(2026, 3, 20, 12),
              displayName: 'Anna Bianchi',
              age: 33,
              biologicalSex: 'female',
              profileFacts: const [
                DossierProfileFact(label: 'BMI', value: '22.1'),
              ],
              provenanceFacts: const [],
              emergencySummary: DossierEmergencySummary(
                generatedAt: DateTime.utc(2026, 3, 20, 12),
                headline: 'Scheda emergenza ClinDiary',
                keyPoints: const [
                  'Nessun dato critico aggiuntivo disponibile al momento.',
                ],
                activeProblems: const ['Asma allergica'],
                activeMedications: const [],
                allergies: const [],
                conditions: const [],
                openAlerts: const [],
              ),
              allergies: const [],
              medicalConditions: const [],
              medications: const [],
              familyHistory: const [],
              vaccinations: const [],
              recentDailyEntries: const [],
              recentDocuments: [
                DossierDocumentItem(
                  id: 'doc-1',
                  title: 'Esami marzo',
                  documentType: 'lab_report',
                  uploadDate: DateTime.utc(2026, 3, 20),
                  parsedStatus: 'parsed',
                  contextStatus: 'active',
                ),
              ],
              recentLabPanels: const [],
              recentImagingReports: const [],
              deviceMeasurementSummaries: const [],
              recentInsights: const [],
              recentReports: const [],
              alerts: const [],
              wearableSummaries: const [],
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Oggi'), findsWidgets);
    expect(find.text('Recap AI'), findsOneWidget);
    expect(find.text('Check-up'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Profili'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Profili'), findsWidgets);
    expect(find.text('Gestisci'), findsOneWidget);
    expect(find.text('Aggiungi'), findsOneWidget);
    expect(find.text('Anna Bianchi · principale'), findsOneWidget);
    expect(find.textContaining('Luca'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Vai a'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Vai a'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Altro'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Altro'), findsOneWidget);
    expect(find.text('Documenti'), findsOneWidget);
    expect(find.text('Notifiche'), findsOneWidget);
    expect(find.text('Prevenzione'), findsOneWidget);
    expect(find.text('Dossier'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-notifications-badge')), findsOne);
    expect(find.byKey(const ValueKey('home-medications-badge')), findsOne);
  });
}
