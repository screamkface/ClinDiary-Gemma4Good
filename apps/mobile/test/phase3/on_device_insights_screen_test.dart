import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/presentation/insights_screen.dart';
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

  test('insight summary query distinguishes on-device mode', () {
    const standard = InsightSummaryQuery(summaryType: 'daily');
    const onDevice = InsightSummaryQuery(
      summaryType: 'daily',
      mode: InsightSummaryMode.onDevice,
    );

    expect(standard, isNot(onDevice));
    expect(standard.hashCode, isNot(onDevice.hashCode));
  });

  testWidgets('on-device proof card shows runtime and model', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnDeviceProofCard(
            status: const OnDeviceAiStatus(
              isSupported: true,
              isReady: true,
              runtime: 'LiteRT-LM Android',
              provider: 'on_device_litertlm',
              activeProviderLabel: 'Gemma 4 On-device',
              backendPreference: 'GPU',
              backendResolved: 'GPU',
              modelName: 'gemma-4-E2B-it',
              modelPath:
                  '/data/data/it.clindiary.clindiary/app_flutter/gemma-4-E2B-it.litertlm',
              modelFileSizeBytes: 2684354560,
              modelLastModifiedAt: null,
              defaultModelDirectory:
                  '/data/data/it.clindiary.clindiary/app_flutter',
              isCloudBypassedForThisRequest: true,
            ),
            onInstallModel: _noop,
            isInstallingModel: false,
          ),
        ),
        supportedLocales: [Locale('it', 'IT'), Locale('en', 'US')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('On-device proof'), findsOneWidget);
    expect(
      find.textContaining('Active provider: Gemma 4 On-device'),
      findsOneWidget,
    );
    expect(find.textContaining('Modello: gemma-4-E2B-it'), findsOneWidget);
    expect(find.textContaining('Local-only request: Yes'), findsOneWidget);
    expect(find.text('Verify/reinstall model'), findsOneWidget);
    expect(find.text('Manage model'), findsOneWidget);
  });

  testWidgets('insights screen exposes on-device mode in recap selector', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightSummaryProvider.overrideWith(
            (ref, query) async => InsightSummary(
              id: 'sum-on-device',
              summaryType: query.summaryType,
              periodStart: DateTime.utc(2026, 4, 5),
              periodEnd: DateTime.utc(2026, 4, 5),
              content: 'Observations: regular day with mild symptoms.',
              providerName: 'on_device_litertlm',
              modelName: 'gemma-4-E2B-it',
              generatedAt: DateTime.utc(2026, 4, 5, 9),
            ),
          ),
          onDeviceAiStatusProvider.overrideWith(
            (ref) async => const OnDeviceAiStatus(
              isSupported: true,
              isReady: true,
              runtime: 'LiteRT-LM Android',
              provider: 'on_device_litertlm',
              activeProviderLabel: 'Gemma 4 On-device',
              backendPreference: 'GPU',
              backendResolved: 'GPU',
              modelName: 'gemma-4-E2B-it',
              modelPath:
                  '/data/data/it.clindiary.clindiary/app_flutter/gemma-4-E2B-it.litertlm',
              modelFileSizeBytes: 2684354560,
              modelLastModifiedAt: null,
              defaultModelDirectory:
                  '/data/data/it.clindiary.clindiary/app_flutter',
              isCloudBypassedForThisRequest: true,
            ),
          ),
        ],
        child: const MaterialApp(
          home: InsightsScreen(initialSummaryMode: InsightSummaryMode.onDevice),
          supportedLocales: [Locale('it', 'IT'), Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recap mode'), findsOneWidget);
    expect(find.text('On device'), findsOneWidget);
  });
}

Future<void> _noop() async {}
