import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/devices/domain/device_hub.dart';
import 'package:clindiary/features/devices/presentation/devices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('devices screen mostra provider, connessioni e misure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceOverviewProvider.overrideWith(
            (ref) async => DeviceOverview(
              providers: const [
                DeviceProviderItem(
                  code: 'omron',
                  displayName: 'OMRON Connect',
                  summary: 'Monitor pressione e peso.',
                  category: 'clinical_device',
                  integrationKind: 'partner_platform',
                  connectionFlow: 'partner_setup',
                  docsUrl: 'https://example.com/omron',
                  capabilities: ['Pressione', 'Peso'],
                  setupNotes: ['Nota 1'],
                  isWaveOne: true,
                  requiresVendorContract: false,
                  providerConfigured: true,
                  supportsLiveSync: false,
                  supportsManualIngest: true,
                  priority: 10,
                ),
                DeviceProviderItem(
                  code: 'dexcom',
                  displayName: 'Dexcom',
                  summary: 'CGM partner API.',
                  category: 'diabetes',
                  integrationKind: 'cloud_api',
                  connectionFlow: 'oauth2',
                  docsUrl: 'https://example.com/dexcom',
                  capabilities: ['CGM'],
                  setupNotes: ['Nota 2'],
                  isWaveOne: true,
                  requiresVendorContract: true,
                  providerConfigured: false,
                  supportsLiveSync: false,
                  supportsManualIngest: false,
                  priority: 50,
                ),
              ],
              connections: [
                DeviceConnectionItem(
                  id: 'conn-1',
                  providerCode: 'omron',
                  providerName: 'OMRON Connect',
                  integrationKind: 'partner_platform',
                  connectionFlow: 'partner_setup',
                  status: 'connected',
                  accountLabel: 'Misuratore casa',
                  measurementCount: 1,
                  latestMeasurement: DeviceMeasurementItem(
                    id: 'meas-1',
                    providerCode: 'omron',
                    metricType: 'blood_pressure',
                    measuredAt: DateTime.utc(2026, 4, 1, 8, 30),
                    displayTitle: 'Pressione arteriosa',
                    displayValue: '122/78 mmHg · FC 66 bpm',
                  ),
                  supportsLiveSync: false,
                  supportsManualIngest: true,
                ),
              ],
              recentMeasurements: [
                DeviceMeasurementItem(
                  id: 'meas-1',
                  providerCode: 'omron',
                  metricType: 'blood_pressure',
                  measuredAt: DateTime.utc(2026, 4, 1, 8, 30),
                  displayTitle: 'Pressione arteriosa',
                  displayValue: '122/78 mmHg · FC 66 bpm',
                ),
              ],
              recentJobs: const [],
            ),
          ),
        ],
        child: const MaterialApp(home: DevicesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dispositivi'), findsOneWidget);
    expect(find.text('OMRON Connect'), findsAtLeastNWidgets(1));
    expect(find.text('Wave 1 clinica'), findsOneWidget);
    await tester.tap(find.text('Connessi'));
    await tester.pumpAndSettle();
    expect(find.text('Misuratore casa'), findsOneWidget);
    expect(find.text('122/78 mmHg · FC 66 bpm'), findsOneWidget);
    expect(find.text('Registra misura'), findsOneWidget);
    await tester.tap(find.text('Misure'));
    await tester.pumpAndSettle();
    expect(find.text('Pressione arteriosa'), findsOneWidget);
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Nessun import recente'), findsOneWidget);
  });
}
