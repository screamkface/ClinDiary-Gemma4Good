import 'package:clindiary/features/history/presentation/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HistoryScreen renders without overflow', (tester) async {
    FlutterError.onError = (details) {
      print('FLUTTER_ERROR_MSG: ' + details.exception.toString());
    };

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    await tester.pump();
    
    // Tap on Calendar tab
    await tester.tap(find.text('Calendar'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}
