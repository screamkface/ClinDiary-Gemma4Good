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
    expect(text, contains('8021 steps'));
    expect(text, contains('sleep 7.3h'));
    expect(text, contains('avg HR 74 bpm'));
    expect(text, contains('records 14'));
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

    expect(text, contains('Wearable diagnostics'));
    expect(text, contains('Platform: android'));
    expect(text, contains('Provider: Health Connect'));
    expect(text, contains('Read permission: yes'));
    expect(text, contains('Health Connect permissions: yes'));
    expect(text, contains('Activity recognition permission: yes'));
    expect(text, contains('Wearable sync: 1 recent days.'));
    expect(text, contains('8021 steps'));
    expect(text, contains('Recommended checks:'));
  });
}
