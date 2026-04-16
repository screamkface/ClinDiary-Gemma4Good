import 'package:clindiary/features/history/data/history_repository.dart';
import 'package:clindiary/features/history/domain/models/history_day.dart';
import 'package:clindiary/features/history/presentation/history_screen.dart';
import 'package:clindiary/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HistoryScreen mock data test', (tester) async {
    FlutterError.onError = (details) {
      print('FLUTTER_ERROR_MSG: ' + details.exception.toString());
      print(details.stack);
    };

    final mockDate = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyDayProvider(mockDate).overrideWith((ref) => HistoryDay(
            targetDate: mockDate,
            timelineEvents: [],
          )),
          historyActivityDatesProvider(DateTime(mockDate.year, mockDate.month, 1)).overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Calendar'), warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Now switch back
    await tester.tap(find.text('Day'), warnIfMissed: false);
    await tester.pumpAndSettle();
  });
}
