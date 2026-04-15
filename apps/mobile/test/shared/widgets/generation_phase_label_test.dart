import 'package:clindiary/shared/widgets/generation_phase_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cambia fase durante una generazione attiva', (tester) async {
    final startedAt = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenerationPhaseLabel(
            isActive: true,
            startedAt: startedAt,
            idleLabel: 'Rigenera',
          ),
        ),
      ),
    );

    expect(find.text('Pensando...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Scrivendo...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Rifinendo...'), findsOneWidget);
  });

  testWidgets('mostra il testo idle quando inattiva', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationPhaseLabel(isActive: false, idleLabel: 'Rigenera'),
        ),
      ),
    );

    expect(find.text('Rigenera'), findsOneWidget);
  });
}
