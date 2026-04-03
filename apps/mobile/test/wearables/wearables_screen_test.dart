import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';
import 'package:clindiary/features/wearables/presentation/wearables_screen.dart';
import 'package:flutter/material.dart';
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
        child: const MaterialApp(home: WearablesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Connessione salute'), findsOneWidget);
    expect(find.text('Diagnostica wearable'), findsOneWidget);
    expect(find.text('Verifica rapida'), findsOneWidget);
    expect(find.text('Copia diagnostica'), findsOneWidget);
    expect(find.textContaining('Ultimo sync:'), findsOneWidget);
    expect(find.text('Health Connect'), findsOneWidget);
    expect(find.text('Google Fit'), findsOneWidget);
    expect(find.text('Passi'), findsOneWidget);
    expect(find.textContaining('Health Connect sta esponendo a ClinDiary solo dati attività da Google Fit'), findsOneWidget);
  });
}
