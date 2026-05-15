import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/data/gemma_coach_service.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';
import 'package:clindiary/features/insights/presentation/gemma_center_screen.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockGemmaCoachService extends Mock implements GemmaCoachService {}

class FakeOnDeviceAiService extends OnDeviceAiService {
  FakeOnDeviceAiService({
    this.backend = PreferredBackend.gpu,
    this.speculativeDecoding = true,
    this.npuStatus,
    this.npuError,
  });

  PreferredBackend backend;
  bool speculativeDecoding;
  bool? npuStatus;
  String? npuError;

  @override
  PreferredBackend get preferredBackend => backend;

  @override
  bool get enableSpeculativeDecoding => speculativeDecoding;

  @override
  bool? get npuAvailable => npuStatus;

  @override
  String? get lastNpuCheckError => npuError;

  @override
  Future<void> setPreferredBackend(PreferredBackend backend) async {
    this.backend = backend;
  }

  @override
  Future<void> setEnableSpeculativeDecoding(bool value) async {
    speculativeDecoding = value;
  }

  @override
  Future<bool> checkNpuAvailability() async {
    return npuStatus ?? false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en_US');
    registerFallbackValue(DateTime.utc(2026, 4, 5));
  });

  testWidgets(
    'Gemma Center hides suggestions after sending a question on compact screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final service = MockGemmaCoachService();
      final streamController = StreamController<String>();
      addTearDown(streamController.close);

      when(
        () => service.answerQuestionStream(
          question: any(named: 'question'),
          referenceDate: any(named: 'referenceDate'),
          documentId: any(named: 'documentId'),
        ),
      ).thenAnswer((_) => streamController.stream);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gemmaCoachServiceProvider.overrideWithValue(service),
            activeProfileIdProvider.overrideWith(
              (ref) async => 'pending-profile',
            ),
            gemmaCenterHistoryProvider.overrideWith(
              (ref) async => const <GemmaCenterHistoryEntry>[],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GemmaCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNWidgets(4));

      await tester.enterText(find.byType(TextField), 'How am I doing lately?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(find.byType(ActionChip), findsNothing);
      expect(find.text('How am I doing lately?'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Gemma Center does not leave an empty bubble for empty responses',
    (tester) async {
      final service = MockGemmaCoachService();
      final streamController = StreamController<String>();
      addTearDown(() {
        if (!streamController.isClosed) {
          streamController.close();
        }
      });

      when(
        () => service.answerQuestionStream(
          question: any(named: 'question'),
          referenceDate: any(named: 'referenceDate'),
          documentId: any(named: 'documentId'),
        ),
      ).thenAnswer((_) => streamController.stream);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gemmaCoachServiceProvider.overrideWithValue(service),
            activeProfileIdProvider.overrideWith(
              (ref) async => 'pending-profile',
            ),
            gemmaCenterHistoryProvider.overrideWith(
              (ref) async => const <GemmaCenterHistoryEntry>[],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GemmaCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Can Gemma answer?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      await streamController.close();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.textContaining('empty response'), findsOneWidget);
    },
  );

  testWidgets(
    'Gemma Center NPU copy explains runtime support instead of hardware absence',
    (tester) async {
      final coachService = MockGemmaCoachService();
      final aiService = FakeOnDeviceAiService(
        npuStatus: false,
        npuError: 'engine_create failed: missing dispatch library',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gemmaCoachServiceProvider.overrideWithValue(coachService),
            onDeviceAiServiceProvider.overrideWithValue(aiService),
            activeProfileIdProvider.overrideWith(
              (ref) async => 'pending-profile',
            ),
            gemmaCenterHistoryProvider.overrideWith(
              (ref) async => const <GemmaCenterHistoryEntry>[],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GemmaCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text('Gemma cannot open the NPU backend on this device'),
        findsOneWidget,
      );
      expect(find.textContaining('may still include an NPU'), findsOneWidget);
      expect(
        find.text('engine_create failed: missing dispatch library'),
        findsOneWidget,
      );
    },
  );
}
