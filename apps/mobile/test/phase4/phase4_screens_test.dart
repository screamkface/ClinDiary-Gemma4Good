import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/medications/presentation/medications_screen.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/notifications/presentation/notifications_screen.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/screenings/domain/screening.dart';
import 'package:clindiary/features/screenings/presentation/screenings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en_US');
  });

  testWidgets('screenings screen shows screenings and catalog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myScreeningsProvider.overrideWith(
            (ref) async => [
              PatientScreeningStatusItem(
                id: 'screen-annual',
                screeningProgramId: 'program-annual',
                screeningCode: 'preventive_annual_visit',
                screeningName: 'Annual preventive visit',
                screeningCategory: 'general_prevention',
                carePathway: 'annual_visit',
                recommendationLevel: 'routine',
                cadenceLabel: 'Annual',
                publicCoverageFlag: false,
                recommendationReason: 'Useful for reviewing prevention status.',
                nextDueDate: DateTime.utc(2026, 3, 20),
                completedThisYear: false,
                status: 'recommended',
                regionalAvailability: const [],
              ),
              PatientScreeningStatusItem(
                id: 'screen-1',
                screeningProgramId: 'program-1',
                screeningCode: 'cervical_cancer_it',
                screeningName: 'Cervical cancer screening',
                screeningCategory: 'oncologia',
                carePathway: 'discuss_with_doctor',
                recommendationLevel: 'routine',
                cadenceLabel: 'Public program',
                publicCoverageFlag: true,
                recommendationReason: 'Recommended based on profile.',
                nextDueDate: DateTime.utc(2026, 3, 20),
                completedThisYear: false,
                status: 'recommended',
                regionalAvailability: const [
                  RegionalScreeningAvailability(
                    regionCode: 'IT',
                    regionName: 'Italia',
                    active: true,
                  ),
                ],
              ),
            ],
          ),
          screeningCatalogProvider.overrideWith(
            (ref) async => [
              const ScreeningCatalogItem(
                id: 'program-annual',
                code: 'preventive_annual_visit',
                name: 'Annual preventive visit',
                description: 'General check-up',
                minAge: 18,
                publicCoverageFlag: false,
                category: 'general_prevention',
                carePathway: 'annual_visit',
                recommendationLevel: 'routine',
                cadenceLabel: 'Annual',
                catalogOnly: false,
                active: true,
                regionalAvailability: [],
              ),
              const ScreeningCatalogItem(
                id: 'program-1',
                code: 'cervical_cancer_it',
                name: 'Cervical cancer screening',
                description: 'Periodic screening',
                minAge: 25,
                maxAge: 64,
                publicCoverageFlag: true,
                category: 'oncologia',
                carePathway: 'discuss_with_doctor',
                recommendationLevel: 'routine',
                cadenceLabel: 'Public program',
                catalogOnly: false,
                active: true,
                regionalAvailability: [],
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: ScreeningsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Prevention catalog'), findsOneWidget);
    expect(find.textContaining('For your profile'), findsWidgets);
    expect(find.text('Recommended annual visit'), findsWidgets);
    expect(
      find.text('Tests and checks to discuss with the doctor'),
      findsWidgets,
    );
    expect(find.text('Cervical cancer screening'), findsNWidgets(2));
    expect(find.text('Annual preventive visit'), findsNWidgets(2));
    expect(find.text('Public program'), findsWidgets);
    expect(find.text('Mark completed'), findsNWidgets(2));
  });

  testWidgets('medications screen shows therapy and adherence history', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
              medications: const [
                MedicationItem(
                  id: 'med-1',
                  name: 'Atorvastatina',
                  dosage: '20 mg',
                  frequency: '1/day',
                  active: true,
                  schedules: [
                    MedicationScheduleItem(
                      id: 'sched-1',
                      scheduledTime: '08:00:00',
                      daysOfWeek: [1, 3, 5],
                      instructions: 'After breakfast',
                      active: true,
                    ),
                  ],
                ),
              ],
              familyHistory: const [],
            ),
          ),
          medicationLogsProvider.overrideWith(
            (ref) async => [
              MedicationLogItem(
                id: 'log-1',
                medicationId: 'med-1',
                medicationName: 'Atorvastatina',
                medicationDosage: '20 mg',
                scheduledAt: DateTime.utc(2026, 3, 20, 8),
                takenAt: DateTime.utc(2026, 3, 20, 8, 5),
                status: 'taken',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: MedicationsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Medications'), findsOneWidget);
    expect(find.text('Atorvastatina'), findsNWidgets(2));
    expect(find.text('Mark as taken'), findsOneWidget);
  });

  testWidgets('notifications screen shows notifications and read action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) async => [
              AppNotificationItem(
                id: 'notif-1',
                notificationType: 'screening_reminder',
                title: 'Screening to schedule',
                body: 'Book the preventive check-up.',
                priority: 'high',
                readStatus: false,
                createdAt: DateTime.utc(2026, 3, 20, 10),
              ),
            ],
          ),
          notificationPreferencesProvider.overrideWith(
            (ref) async => const NotificationPreferences(
              inAppEnabled: true,
              dailyCheckinEnabled: true,
              medicationRemindersEnabled: true,
              screeningRemindersEnabled: true,
              documentFollowUpEnabled: true,
              reportReadyEnabled: true,
              clinicalAlertsEnabled: true,
              preventionTipsEnabled: true,
              pushEnabled: false,
              emailEnabled: false,
            ),
          ),
          localMedicationReminderStatusProvider.overrideWith(
            (ref) async => const LocalMedicationReminderStatus(
              isSupported: true,
              permissionGranted: true,
              scheduledCount: 4,
              lastSyncedAt: null,
            ),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reminder preferences'), findsOneWidget);
    expect(find.byTooltip('Send test notifications'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Local medication reminders'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Local medication reminders'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Screening to schedule'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Screening to schedule'), findsOneWidget);
    expect(find.text('Mark as read'), findsOneWidget);
  });
}
