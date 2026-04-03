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
    await initializeDateFormatting('it_IT');
  });

  testWidgets('screenings screen mostra screening e catalogo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myScreeningsProvider.overrideWith(
            (ref) async => [
              PatientScreeningStatusItem(
                id: 'screen-annual',
                screeningProgramId: 'program-annual',
                screeningCode: 'preventive_annual_visit',
                screeningName: 'Visita preventiva annuale',
                screeningCategory: 'prevenzione_generale',
                carePathway: 'annual_visit',
                recommendationLevel: 'routine',
                cadenceLabel: 'Annuale',
                publicCoverageFlag: false,
                recommendationReason:
                    'Utile per fare il punto sulla prevenzione.',
                nextDueDate: DateTime.utc(2026, 3, 20),
                completedThisYear: false,
                status: 'recommended',
                regionalAvailability: const [],
              ),
              PatientScreeningStatusItem(
                id: 'screen-1',
                screeningProgramId: 'program-1',
                screeningCode: 'cervical_cancer_it',
                screeningName: 'Screening cervice uterina',
                screeningCategory: 'oncologia',
                carePathway: 'discuss_with_doctor',
                recommendationLevel: 'routine',
                cadenceLabel: 'Programma pubblico',
                publicCoverageFlag: true,
                recommendationReason: 'Consigliato in base al profilo.',
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
                name: 'Visita preventiva annuale',
                description: 'Controllo generale',
                minAge: 18,
                publicCoverageFlag: false,
                category: 'prevenzione_generale',
                carePathway: 'annual_visit',
                recommendationLevel: 'routine',
                cadenceLabel: 'Annuale',
                catalogOnly: false,
                active: true,
                regionalAvailability: [],
              ),
              const ScreeningCatalogItem(
                id: 'program-1',
                code: 'cervical_cancer_it',
                name: 'Screening cervice uterina',
                description: 'Screening periodico',
                minAge: 25,
                maxAge: 64,
                publicCoverageFlag: true,
                category: 'oncologia',
                carePathway: 'discuss_with_doctor',
                recommendationLevel: 'routine',
                cadenceLabel: 'Programma pubblico',
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

    expect(find.text('Catalogo prevenzione'), findsOneWidget);
    expect(find.textContaining('Checklist personale'), findsOneWidget);
    expect(find.text('Visita annuale consigliata'), findsWidgets);
    expect(
      find.text('Esami e controlli da discutere col medico'),
      findsWidgets,
    );
    expect(find.text('Screening cervice uterina'), findsNWidgets(2));
    expect(find.text('Visita preventiva annuale'), findsNWidgets(2));
    expect(find.text('Programma pubblico'), findsWidgets);
    expect(find.text('Segna completato'), findsNWidgets(2));
  });

  testWidgets('medications screen mostra terapia e storico aderenza', (
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
                  frequency: '1/die',
                  active: true,
                  schedules: [
                    MedicationScheduleItem(
                      id: 'sched-1',
                      scheduledTime: '08:00:00',
                      daysOfWeek: [1, 3, 5],
                      instructions: 'Dopo colazione',
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

    expect(find.text('Farmaci'), findsOneWidget);
    expect(find.text('Atorvastatina'), findsNWidgets(2));
    expect(find.text('Segna assunta'), findsOneWidget);
  });

  testWidgets('notifications screen mostra notifiche e azione letta', (
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
                title: 'Screening da programmare',
                body: 'Prenota il controllo preventivo.',
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

    expect(find.text('Preferenze reminder'), findsOneWidget);
    expect(find.byTooltip('Invia test notifiche'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Promemoria locali farmaci'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Promemoria locali farmaci'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Screening da programmare'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Screening da programmare'), findsOneWidget);
    expect(find.text('Segna letta'), findsOneWidget);
  });
}
