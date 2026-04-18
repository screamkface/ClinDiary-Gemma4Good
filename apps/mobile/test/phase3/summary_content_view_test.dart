import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('summary content view normalizes gemini markdown markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SummaryContentView(content: _markdownContent),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recap title'), findsOneWidget);
    expect(find.text('item in italic and bold'), findsOneWidget);
    expect(find.text('Open document or inline notes'), findsOneWidget);
    expect(find.textContaining('*'), findsNothing);
    expect(find.textContaining('`'), findsNothing);
    expect(find.textContaining('['), findsNothing);
  });

  testWidgets('summary content view keeps long reports scrollable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 280,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SummaryContentView(content: _longContent),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final viewportFinder = find.byType(SingleChildScrollView);
    final scrollableFinder = find.byType(Scrollable);
    final section18Finder = find.text('Section 18');
    final initialViewport = tester.getRect(viewportFinder);

    expect(find.text('Section 1'), findsOneWidget);
    expect(
      tester.getTopLeft(section18Finder).dy,
      greaterThan(initialViewport.bottom),
    );

    await tester.scrollUntilVisible(
      section18Finder,
      300,
      scrollable: scrollableFinder,
    );
    await tester.pumpAndSettle();

    final finalViewport = tester.getRect(viewportFinder);
    expect(
      tester.getTopLeft(section18Finder).dy,
      lessThan(finalViewport.bottom),
    );
    expect(find.text('Very long detail 18'), findsOneWidget);
  });

  testWidgets('summary content view promotes plain report section titles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SummaryContentView(content: _reportContent),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recent symptoms'), findsOneWidget);
    expect(find.text('Main trends'), findsOneWidget);
    expect(find.textContaining('---'), findsNothing);
    expect(find.text('evening headache'), findsOneWidget);
  });

  testWidgets(
    'summary content view renders markdown tables deterministically',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: SummaryContentView(
                content: _markdownTableContent,
                constrainHeight: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Points to bring to the visit'), findsOneWidget);
      expect(find.text('Area'), findsOneWidget);
      expect(find.text('Value'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('8200/day'), findsOneWidget);
      expect(find.textContaining('---'), findsNothing);
    },
  );

  testWidgets(
    'summary content view renders simple pipe tables deterministically',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: SummaryContentView(
                content: _simplePipeTableContent,
                constrainHeight: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Symptom'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('headache'), findsOneWidget);
      expect(find.text('3 evenings'), findsOneWidget);
    },
  );
}

const _longContent =
    '**Section 1**\n- Line 1\n- Very long detail 1\n\n'
    '**Section 2**\n- Line 2\n- Very long detail 2\n\n'
    '**Section 3**\n- Line 3\n- Very long detail 3\n\n'
    '**Section 4**\n- Line 4\n- Very long detail 4\n\n'
    '**Section 5**\n- Line 5\n- Very long detail 5\n\n'
    '**Section 6**\n- Line 6\n- Very long detail 6\n\n'
    '**Section 7**\n- Line 7\n- Very long detail 7\n\n'
    '**Section 8**\n- Line 8\n- Very long detail 8\n\n'
    '**Section 9**\n- Line 9\n- Very long detail 9\n\n'
    '**Section 10**\n- Line 10\n- Very long detail 10\n\n'
    '**Section 11**\n- Line 11\n- Very long detail 11\n\n'
    '**Section 12**\n- Line 12\n- Very long detail 12\n\n'
    '**Section 13**\n- Line 13\n- Very long detail 13\n\n'
    '**Section 14**\n- Line 14\n- Very long detail 14\n\n'
    '**Section 15**\n- Line 15\n- Very long detail 15\n\n'
    '**Section 16**\n- Line 16\n- Very long detail 16\n\n'
    '**Section 17**\n- Line 17\n- Very long detail 17\n\n'
    '**Section 18**\n- Line 18\n- Very long detail 18';

const _markdownContent =
    '# Recap title\n\n'
    '* item in *italic* and **bold**\n'
    '> [Open document](https://example.com) or `inline notes`';

const _reportContent =
    'Recent symptoms\n'
    '- evening headache\n'
    '- mild fatigue\n\n'
    '---\n\n'
    'Main trends\n'
    'Average energy 5.4/10.\n'
    'Average pain 2.1/10.';

const _markdownTableContent =
    'Points to bring to the visit\n\n'
    '| Area | Value | Note |\n'
    '| --- | --- | --- |\n'
    '| Steps | 8200/day | stable trend |\n'
    '| Sleep | 6.8h | variable |';

const _simplePipeTableContent =
    'Symptom | Frequency | Note\n'
    'headache | 3 evenings | more often after poor sleep\n'
    'fatigue | almost daily | mild';
