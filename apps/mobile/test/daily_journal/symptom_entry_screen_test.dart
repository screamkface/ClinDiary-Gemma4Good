import 'package:clindiary/features/daily_journal/presentation/symptom_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('symptom entry screen supports free text', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SymptomEntryScreen(entryId: 'entry-1')),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Write your own'), findsOneWidget);

    await tester.tap(find.text('Write your own'));
    await tester.pumpAndSettle();

    expect(find.text('Describe the symptom'), findsOneWidget);
    expect(find.text('Associated with nausea'), findsNothing);
  });
}
