import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';
import 'package:clindiary/features/wearables/presentation/wearables_screen.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('wearables screen mostra stato e giornate sincronizzate', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wearableSyncStatusProvider.overrideWith(
            (ref) async => const WearableSyncStatus(
              isSupported: true,
              platformLabel: 'android',
              providerName: 'Health Connect',
              isAvailable: true,
              permissionGranted: true,
              canInstallProvider: false,
              historyAccessGranted: true,
              healthPermissionsGranted: true,
              activityRecognitionGranted: true,
            ),
          ),
          wearableDailySummariesProvider.overrideWith(
            (ref) async => [
              WearableDaySummary(
                summaryDate: DateTime.utc(2026, 3, 20),
                sourcePlatform: 'android',
                sourceName: 'com.google.android.apps.fitness',
                stepsCount: 8021,
                distanceMeters: 2100,
                recordCount: 14,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: WearablesScreen(),
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

    expect(find.text('Health connection'), findsWidgets);
    expect(find.text('Wearable diagnostics'), findsOneWidget);
    expect(find.text('Quick check'), findsOneWidget);
    expect(find.text('Copy diagnostics'), findsOneWidget);
    expect(find.textContaining('Last sync:'), findsOneWidget);
    expect(find.text('Health Connect'), findsOneWidget);
    expect(find.text('Google Fit'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(
      find.textContaining(
        'Health Connect is exposing only activity data from Google Fit to ClinDiary',
      ),
      findsOneWidget,
    );
  });
}
