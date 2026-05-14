import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/history/domain/history_day.dart';
import 'package:clindiary/features/history/presentation/history_screen.dart';
import 'package:clindiary/features/alerts/presentation/alerts_screen.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/insights/data/insights_repository.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/local_ai_status.dart';
import 'package:clindiary/features/insights/presentation/insights_screen.dart';
import 'package:clindiary/features/reports/data/reports_repository.dart';
import 'package:clindiary/features/reports/domain/clinical_report.dart';
import 'package:clindiary/features/reports/presentation/reports_screen.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

class MockInsightsRepository extends Mock implements InsightsRepository {}

class FakeInsightSummaryQuery extends Fake implements InsightSummaryQuery {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboardText;

  setUpAll(() async {
    await initializeDateFormatting('en_US');
    registerFallbackValue(FakeInsightSummaryQuery());
  });

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          switch (methodCall.method) {
            case 'Clipboard.setData':
              clipboardText = (methodCall.arguments as Map)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              if (clipboardText == null) {
                return null;
              }
              return <String, dynamic>{'text': clipboardText};
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('insights screen shows the cautious summary', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightSummaryProvider.overrideWith(
            (ref, query) async => InsightSummary(
              id: 'sum-1',
              summaryType: query.summaryType,
              periodStart: DateTime.utc(2026, 3, 14),
              periodEnd: DateTime.utc(2026, 3, 20),
              content:
                  'Analyzed period: from 2026-03-14 to 2026-03-20.\nA stable average energy level is observed.',
              generatedAt: DateTime.utc(2026, 3, 20, 9),
            ),
          ),
        ],
        child: const MaterialApp(
          home: InsightsScreen(
            initialSummaryMode: InsightSummaryMode.privateLocal,
          ),
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

    expect(find.text('AI Recap'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Private local'), findsOneWidget);
  });

  test('insight summary query distinguishes local private mode', () {
    const standard = InsightSummaryQuery(summaryType: 'daily');
    const privateLocal = InsightSummaryQuery(
      summaryType: 'daily',
      mode: InsightSummaryMode.privateLocal,
    );

    expect(standard, isNot(privateLocal));
    expect(standard.hashCode, isNot(privateLocal.hashCode));
  });

  testWidgets('insights screen shows proof card in local private mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocalProofCard(
            status: LocalAiStatus(
              enabled: true,
              provider: 'local_gemma4',
              activeProviderLabel: 'Gemma 4 Local',
              runtimeMode: 'local',
              backend: 'ollama',
              modelName: 'gemma-4-e2b',
              configuredBaseUrlPresent: true,
              fallbackProvider: 'rule_based',
              isCloudBypassedForThisRequest: true,
            ),
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

    expect(find.text('Local proof'), findsOneWidget);
    expect(
      find.textContaining('Active provider: Gemma 4 Local'),
      findsOneWidget,
    );
    expect(find.textContaining('Cloud esterno usato: No'), findsOneWidget);
  });

  testWidgets('insights screen opens date picker without crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightSummaryProvider.overrideWith(
            (ref, query) async => InsightSummary(
              id: 'sum-calendar',
              summaryType: query.summaryType,
              periodStart: DateTime.utc(2026, 3, 20),
              periodEnd: DateTime.utc(2026, 3, 20),
              content: 'Blocco 1.\n\nBlocco 2.',
              generatedAt: DateTime.utc(2026, 3, 20, 21),
            ),
          ),
        ],
        child: const MaterialApp(
          home: InsightsScreen(),
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
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('insights screen regenerates the report only on request', (
    tester,
  ) async {
    final repository = MockInsightsRepository();
    when(() => repository.regenerateSummary(any())).thenAnswer(
      (_) async => InsightSummary(
        id: 'sum-regenerated',
        summaryType: 'daily',
        periodStart: DateTime.utc(2026, 3, 20),
        periodEnd: DateTime.utc(2026, 3, 20),
        content: 'Report regenerated manually.',
        generatedAt: DateTime.utc(2026, 3, 20, 22),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsRepositoryProvider.overrideWith((ref) => repository),
          insightSummaryProvider.overrideWith(
            (ref, query) async => InsightSummary(
              id: 'sum-existing',
              summaryType: query.summaryType,
              periodStart: DateTime.utc(2026, 3, 20),
              periodEnd: DateTime.utc(2026, 3, 20),
              content: 'Report already available.',
              generatedAt: DateTime.utc(2026, 3, 20, 21),
            ),
          ),
        ],
        child: const MaterialApp(
          home: InsightsScreen(),
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
    await tester.tap(find.text('Regenerate').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => repository.regenerateSummary(any())).called(1);
    expect(find.text('Report regenerated.'), findsOneWidget);
  });

  testWidgets('insights screen copies the report to clipboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightSummaryProvider.overrideWith(
            (ref, query) async => InsightSummary(
              id: 'sum-copy',
              summaryType: query.summaryType,
              periodStart: DateTime.utc(2026, 3, 20),
              periodEnd: DateTime.utc(2026, 3, 20),
              content: 'Report to copy.',
              generatedAt: DateTime.utc(2026, 3, 20, 21),
            ),
          ),
        ],
        child: const MaterialApp(
          home: InsightsScreen(),
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
    await tester.tap(find.byIcon(Icons.content_copy_outlined).first);
    await tester.pump();

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'Report to copy.');
    expect(find.text('Report copied to clipboard.'), findsOneWidget);
  });

  testWidgets('history screen shows check-up and daily recap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyDayProvider.overrideWith(
            (ref, targetDate) async => HistoryDay(
              targetDate: DateTime.utc(2026, 3, 20),
              dailyEntry: DailyEntry(
                id: 'entry-1',
                entryDate: DateTime.utc(2026, 3, 20),
                energyLevel: 4,
                moodLevel: 5,
                generalPain: 6,
                generalNotes: 'Tough but manageable day.',
                symptoms: [
                  const SymptomEntry(
                    id: 'sym-1',
                    symptomCode: 'headache',
                    severity: 6,
                  ),
                ],
                vitals: [
                  VitalSignEntry(
                    id: 'vital-1',
                    type: 'temperature',
                    value: '37.4',
                    unit: 'C',
                    measuredAt: DateTime.utc(2026, 3, 20, 18),
                  ),
                ],
              ),
              dailySummary: InsightSummary(
                id: 'sum-2',
                summaryType: 'daily',
                periodStart: DateTime.utc(2026, 3, 20),
                periodEnd: DateTime.utc(2026, 3, 20),
                content: 'Cautious recap of the day.',
                generatedAt: DateTime.utc(2026, 3, 20, 21),
              ),
              weeklySummary: null,
              monthlySummary: null,
              wearableSummary: WearableDaySummary(
                summaryDate: DateTime.utc(2026, 3, 20),
                sourcePlatform: 'android',
                sourceName: 'Health Connect',
                stepsCount: 6510,
                sleepMinutes: 420,
                heartRateAvgBpm: 76,
                recordCount: 12,
              ),
              documents: [
                ClinicalDocumentSummary(
                  id: 'doc-1',
                  title: 'Complete blood count',
                  documentType: 'lab_report',
                  uploadDate: DateTime.utc(2026, 3, 20, 8),
                  originalFilename: 'cbc.pdf',
                  mimeType: 'application/pdf',
                  fileSizeBytes: 1024,
                  parsedStatus: 'parsed',
                ),
              ],
              timelineEvents: [
                TimelineEventItem(
                  id: 'event-1',
                  eventType: 'daily_entry',
                  title: 'Check-up completed',
                  description: 'Symptoms and notes saved.',
                  eventDate: DateTime.utc(2026, 3, 20, 20),
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(
          home: HistoryScreen(),
          supportedLocales: [Locale('it', 'IT'), Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Daily recap'), findsOneWidget);
    expect(find.textContaining('Cautious recap'), findsOneWidget);
    await tester.tap(find.text('Check-up').last);
    await tester.pumpAndSettle();
    expect(find.text('headache 6/10'), findsOneWidget);
    await tester.tap(find.text('Documents').last);
    await tester.pumpAndSettle();
    expect(find.text('Complete blood count'), findsOneWidget);
  });

  testWidgets('history screen regenerates daily report only with button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = MockInsightsRepository();
    when(() => repository.regenerateSummary(any())).thenAnswer(
      (_) async => InsightSummary(
        id: 'sum-history-regenerated',
        summaryType: 'daily',
        periodStart: DateTime.utc(2026, 3, 20),
        periodEnd: DateTime.utc(2026, 3, 20),
        content: 'Historical report regenerated.',
        generatedAt: DateTime.utc(2026, 3, 20, 22),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsRepositoryProvider.overrideWith((ref) => repository),
          historyActivityDatesProvider.overrideWith(
            (ref, targetDate) async => const [],
          ),
          historyDayProvider.overrideWith(
            (ref, targetDate) async => HistoryDay(
              targetDate: DateTime.utc(2026, 3, 20),
              dailyEntry: null,
              dailySummary: InsightSummary(
                id: 'sum-history',
                summaryType: 'daily',
                periodStart: DateTime.utc(2026, 3, 20),
                periodEnd: DateTime.utc(2026, 3, 20),
                content: 'Existing historical report.',
                generatedAt: DateTime.utc(2026, 3, 20, 21),
              ),
              weeklySummary: null,
              monthlySummary: null,
              wearableSummary: null,
              documents: const [],
              timelineEvents: const [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: HistoryScreen(),
          supportedLocales: [Locale('it', 'IT'), Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Regenerate').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => repository.regenerateSummary(any())).called(1);
    expect(find.textContaining('Daily report regenerated'), findsOneWidget);
  });

  testWidgets('history screen copies daily report to clipboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyActivityDatesProvider.overrideWith(
            (ref, targetDate) async => const [],
          ),
          historyDayProvider.overrideWith(
            (ref, targetDate) async => HistoryDay(
              targetDate: DateTime.utc(2026, 3, 20),
              dailyEntry: null,
              dailySummary: InsightSummary(
                id: 'sum-history-copy',
                summaryType: 'daily',
                periodStart: DateTime.utc(2026, 3, 20),
                periodEnd: DateTime.utc(2026, 3, 20),
                content: 'Historical report to copy.',
                generatedAt: DateTime.utc(2026, 3, 20, 21),
              ),
              weeklySummary: null,
              monthlySummary: null,
              wearableSummary: null,
              documents: const [],
              timelineEvents: const [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: HistoryScreen(),
          supportedLocales: [Locale('it', 'IT'), Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.content_copy_outlined).first);
    await tester.pump();

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, 'Historical report to copy.');
    expect(find.text('Report copied to clipboard.'), findsOneWidget);
  });

  testWidgets('alerts screen shows open alerts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertsProvider.overrideWith(
            (ref) async => [
              ClinicalAlert(
                id: 'alert-1',
                severity: 'urgency',
                alertType: 'chest_pain',
                title: 'Urgency: chest pain reported',
                description: 'Rapid assessment recommended.',
                status: 'open',
                triggeredAt: DateTime.utc(2026, 3, 20, 10),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: AlertsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Urgency: chest pain reported'), findsOneWidget);
    expect(find.textContaining('Rapid assessment'), findsOneWidget);
    expect(find.text('Mark resolved'), findsOneWidget);
  });

  testWidgets('reports screen generates and shows latest report', (
    tester,
  ) async {
    final repository = MockReportsRepository();
    when(
      () => repository.readCachedLatestReport(),
    ).thenAnswer((_) async => null);
    when(
      () => repository.generateReport(
        reportType: 'weekly_summary',
        referenceDate: null,
      ),
    ).thenAnswer(
      (_) async => ClinicalReport(
        id: 'report-1',
        reportType: 'weekly_summary',
        status: 'generated',
        title: 'ClinDiary - weekly summary',
        periodStart: DateTime.utc(2026, 3, 14),
        periodEnd: DateTime.utc(2026, 3, 20),
        contentText: 'Cautious AI summary\nAverage energy 5.0/10.',
        generatedAt: DateTime.utc(2026, 3, 20, 11),
        downloadUrl: '/api/v1/reports/report-1/content?token=abc',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportsRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Regenerate report'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Regenerate report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latest report'));
    await tester.pumpAndSettle();

    expect(find.text('ClinDiary - weekly summary'), findsOneWidget);
    expect(find.textContaining('Cautious AI summary'), findsOneWidget);
  });
}
