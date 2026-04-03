import 'package:clindiary/features/daily_journal/presentation/symptom_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('symptom entry screen supporta il testo libero', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SymptomEntryScreen(entryId: 'entry-1')),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Lista'), findsOneWidget);
    expect(find.text('Scrivi tu'), findsOneWidget);

    await tester.tap(find.text('Scrivi tu'));
    await tester.pumpAndSettle();

    expect(find.text('Descrivi il sintomo'), findsOneWidget);
    expect(find.text('Associato a nausea'), findsNothing);
  });
}
