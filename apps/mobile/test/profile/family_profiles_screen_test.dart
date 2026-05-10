import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/data/profile_repository.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/profile/presentation/family_profiles_screen.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

Widget _testApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en_US');
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets(
    'family profiles screen creates a profile without using disposed controllers',
    (tester) async {
      final repository = MockProfileRepository();
      const primaryProfile = PatientProfile(
        id: 'profile-1',
        userId: 'user-1',
        isPrimary: true,
        firstName: 'Anna',
        lastName: 'Bianchi',
        smoker: false,
      );
      const managedProfile = PatientProfile(
        id: 'profile-2',
        userId: 'user-1',
        isPrimary: false,
        firstName: 'Luca',
        lastName: 'Bianchi',
        smoker: false,
        relationshipLabel: 'Son',
      );
      final initialBundle = ProfileBundle(
        profile: primaryProfile,
        onboarding: const OnboardingStatus(healthDataConsent: true),
        allergies: const [],
        medicalConditions: const [],
        medications: const [],
        familyHistory: const [],
        managedProfiles: const [primaryProfile],
      );
      final createdBundle = ProfileBundle(
        profile: primaryProfile,
        onboarding: const OnboardingStatus(healthDataConsent: true),
        allergies: const [],
        medicalConditions: const [],
        medications: const [],
        familyHistory: const [],
        managedProfiles: const [primaryProfile, managedProfile],
      );

      when(
        () => repository.createManagedProfile(any()),
      ).thenAnswer((_) async => createdBundle);
      when(() => repository.setActiveProfileId(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWith((ref) => repository),
            profileBundleProvider.overrideWith((ref) async => initialBundle),
            activeProfileIdProvider.overrideWith((ref) async => 'profile-1'),
          ],
          child: _testApp(home: const FamilyProfilesScreen()),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('New profile'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Luca',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Relationship'),
        'Son',
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(() => repository.createManagedProfile(any())).called(1);
      verify(() => repository.setActiveProfileId('profile-2')).called(1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
