import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/profile/presentation/vaccination_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vaccination form closes with back without Flutter errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileBundleProvider.overrideWith((ref) async => _profileBundle),
          preventionCenterProvider.overrideWith((ref) async => _prevention),
        ],
        child: const MaterialApp(home: VaccinationHistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Add vaccine'));
    await tester.pumpAndSettle();

    expect(find.text('Vaccine name'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Vaccine name'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _profileBundle = ProfileBundle(
  profile: PatientProfile(
    id: 'profile-1',
    userId: 'user-1',
    isPrimary: true,
    firstName: 'Anna',
    lastName: 'Bianchi',
    smoker: false,
  ),
  onboarding: OnboardingStatus(healthDataConsent: true),
  allergies: [],
  medicalConditions: [],
  medications: [],
  familyHistory: [],
  vaccinations: [],
);

final _prevention = PreventionCenterData(
  generatedAt: DateTime.utc(2026, 5, 8),
  displayName: 'Anna Bianchi',
  overview: const PreventionCenterOverview(
    actionableScreenings: 0,
    vaccineReviews: 0,
    seasonalChecks: 0,
    followUpItems: 0,
  ),
  visitsAndControls: const [],
  vaccines: const [],
  vaccineRegistry: const [],
  seasonalChecks: const [],
  followUpReminders: const [],
);
