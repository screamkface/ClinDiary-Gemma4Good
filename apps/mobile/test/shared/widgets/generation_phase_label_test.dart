import 'package:clindiary/shared/widgets/generation_phase_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('changes phase during active generation', (tester) async {
    final startedAt = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenerationPhaseLabel(
            isActive: true,
            startedAt: startedAt,
            idleLabel: 'Regenerate',
          ),
        ),
      ),
    );

    expect(find.text('Thinking...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Writing...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Refining...'), findsOneWidget);
  });

  testWidgets('shows idle text when inactive', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationPhaseLabel(isActive: false, idleLabel: 'Regenerate'),
        ),
      ),
    );

    expect(find.text('Regenerate'), findsOneWidget);
  });
}
