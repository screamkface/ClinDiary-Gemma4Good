import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WearableDaySummary.toDiagnosticText descrive metriche e fonte', () {
    final summary = WearableDaySummary(
      summaryDate: DateTime.utc(2026, 3, 20),
      sourcePlatform: 'android',
      sourceName: 'Health Connect',
      sourceDeviceModel: 'Mi 10',
      stepsCount: 8021,
      sleepMinutes: 435,
      heartRateAvgBpm: 74,
      restingHeartRateBpm: 61,
      bloodOxygenAvgPct: 98,
      exerciseMinutes: 42,
      activeEnergyKcal: 320,
      recordCount: 14,
    );

    final text = summary.toDiagnosticText();

    expect(text, contains('2026-03-20'));
    expect(text, contains('Health Connect'));
    expect(text, contains('Mi 10'));
    expect(text, contains('8021 passi'));
    expect(text, contains('sonno 7.3h'));
    expect(text, contains('FC media 74 bpm'));
    expect(text, contains('record 14'));
  });

  test('WearableSyncStatus.toDiagnosticText include stato e riepiloghi', () {
    final status = WearableSyncStatus(
      isSupported: true,
      platformLabel: 'android',
      providerName: 'Health Connect',
      isAvailable: true,
      permissionGranted: true,
      canInstallProvider: false,
      historyAccessGranted: true,
      healthPermissionsGranted: true,
      activityRecognitionGranted: true,
    );
    final summaries = [
      WearableDaySummary(
        summaryDate: DateTime.utc(2026, 3, 20),
        sourcePlatform: 'android',
        sourceName: 'Health Connect',
        stepsCount: 8021,
        sleepMinutes: 435,
        heartRateAvgBpm: 74,
        recordCount: 14,
      ),
    ];

    final text = status.toDiagnosticText(recentSummaries: summaries);

    expect(text, contains('Diagnostica wearable'));
    expect(text, contains('Piattaforma: android'));
    expect(text, contains('Provider: Health Connect'));
    expect(text, contains('Permesso lettura: sì'));
    expect(text, contains('Permessi Health Connect: sì'));
    expect(text, contains('Permesso Attività fisica: sì'));
    expect(text, contains('Sincronizzazione wearable: 1 giornate recenti.'));
    expect(text, contains('8021 passi'));
    expect(text, contains('Controlli consigliati:'));
  });
}
