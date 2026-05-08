import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/features/home/presentation/home_screen.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
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

  testWidgets(
    'home screen shows badges for unread notifications and medications',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertsProvider.overrideWith(
              (ref) async => [
                ClinicalAlert(
                  id: 'alert-1',
                  severity: 'high',
                  alertType: 'follow_up',
                  title: 'Test alert',
                  description: 'Check required.',
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
                  title: 'Clinical alert',
                  body: 'Reminder to read.',
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
                    relationshipLabel: 'son',
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
                  title: 'Annual preventive visit',
                  subtitle: 'General check-up',
                  status: 'recommended',
                  priority: 'normal',
                  category: 'general_prevention',
                  kind: 'screening',
                ),
                visitsAndControls: const [],
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
                  headline: 'ClinDiary emergency card',
                  keyPoints: const [
                    'No additional critical data currently available.',
                  ],
                  activeProblems: const ['Allergic asthma'],
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
                    title: 'March labs',
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
          child: const MaterialApp(
            home: HomeScreen(),
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

      expect(find.text('Today'), findsWidgets);
      expect(find.text('AI Recap'), findsOneWidget);
      expect(find.text('Check-up'), findsOneWidget);
      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('Vaccines'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Alerts'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-alert-alert-1')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recent check-ups'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent check-ups'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-checkup-entry-1')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Profiles'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Profiles'), findsWidgets);
      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Anna Bianchi · Primary'), findsOneWidget);
      expect(find.textContaining('Luca'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Quick actions'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Quick actions'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Secondary tools'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Secondary tools'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Prevention'), findsOneWidget);
      expect(find.text('Dossier'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-notifications-badge')), findsOne);
      expect(find.byKey(const ValueKey('home-medications-badge')), findsOne);
    },
  );

  testWidgets('home screen shows demo scenarios only in hackathon mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeProfileIdProvider.overrideWith((ref) async => 'profile-1'),
          appConfigProvider.overrideWith(
            (ref) => const AppConfig(hackathonDemoMode: true),
          ),
          profileBundleProvider.overrideWith(
            (ref) async => ProfileBundle(
              profile: const PatientProfile(
                id: 'profile-1',
                userId: 'user-1',
                isPrimary: true,
                firstName: 'Giulia',
                lastName: 'Rossi',
                relationshipLabel: 'Scenario A',
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
                  firstName: 'Giulia',
                  lastName: 'Rossi',
                  relationshipLabel: 'Scenario A',
                  smoker: false,
                ),
                PatientProfile(
                  id: 'profile-2',
                  userId: 'user-1',
                  isPrimary: false,
                  firstName: 'Elena',
                  lastName: 'Rossi',
                  relationshipLabel: 'Scenario B',
                  smoker: false,
                ),
                PatientProfile(
                  id: 'profile-3',
                  userId: 'user-1',
                  isPrimary: false,
                  firstName: 'Paolo',
                  lastName: 'Rossi',
                  relationshipLabel: 'Scenario C',
                  smoker: false,
                ),
              ],
            ),
          ),
          alertsProvider.overrideWith((ref) async => const []),
          dailyEntriesProvider.overrideWith((ref) async => const []),
          unreadNotificationsProvider.overrideWith((ref) async => false),
          pendingMedicationDosesProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
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

    await tester.scrollUntilVisible(
      find.text('Demo Scenarios'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Demo Scenarios'), findsOneWidget);
    expect(find.textContaining('Scenario A'), findsOneWidget);
    expect(find.textContaining('Scenario B'), findsOneWidget);
    expect(find.textContaining('Scenario C'), findsOneWidget);
    expect(find.text('Open AI Recap'), findsOneWidget);
  });
}
