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

    expect(find.text('Titolo recap'), findsOneWidget);
    expect(find.text('voce in corsivo e grassetto'), findsOneWidget);
    expect(find.text('Apri documento o note inline'), findsOneWidget);
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
    final section18Finder = find.text('Sezione 18');
    final initialViewport = tester.getRect(viewportFinder);

    expect(find.text('Sezione 1'), findsOneWidget);
    expect(tester.getTopLeft(section18Finder).dy, greaterThan(initialViewport.bottom));

    await tester.scrollUntilVisible(
      section18Finder,
      300,
      scrollable: scrollableFinder,
    );
    await tester.pumpAndSettle();

    final finalViewport = tester.getRect(viewportFinder);
    expect(tester.getTopLeft(section18Finder).dy, lessThan(finalViewport.bottom));
    expect(find.text('Dettaglio molto lungo 18'), findsOneWidget);
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

    expect(find.text('Sintomi recenti'), findsOneWidget);
    expect(find.text('Trend principali'), findsOneWidget);
    expect(find.textContaining('---'), findsNothing);
    expect(find.text('cefalea serale'), findsOneWidget);
  });

  testWidgets('summary content view renders markdown tables deterministically', (
    tester,
  ) async {
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

    expect(find.text('Punti da portare in visita'), findsOneWidget);
    expect(find.text('Area'), findsOneWidget);
    expect(find.text('Dato'), findsOneWidget);
    expect(find.text('Passi'), findsOneWidget);
    expect(find.text('8200/die'), findsOneWidget);
    expect(find.textContaining('---'), findsNothing);
  });

  testWidgets('summary content view renders simple pipe tables deterministically', (
    tester,
  ) async {
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

    expect(find.text('Sintomo'), findsOneWidget);
    expect(find.text('Frequenza'), findsOneWidget);
    expect(find.text('cefalea'), findsOneWidget);
    expect(find.text('3 sere'), findsOneWidget);
  });
}

const _longContent =
    '**Sezione 1**\n- Riga 1\n- Dettaglio molto lungo 1\n\n'
    '**Sezione 2**\n- Riga 2\n- Dettaglio molto lungo 2\n\n'
    '**Sezione 3**\n- Riga 3\n- Dettaglio molto lungo 3\n\n'
    '**Sezione 4**\n- Riga 4\n- Dettaglio molto lungo 4\n\n'
    '**Sezione 5**\n- Riga 5\n- Dettaglio molto lungo 5\n\n'
    '**Sezione 6**\n- Riga 6\n- Dettaglio molto lungo 6\n\n'
    '**Sezione 7**\n- Riga 7\n- Dettaglio molto lungo 7\n\n'
    '**Sezione 8**\n- Riga 8\n- Dettaglio molto lungo 8\n\n'
    '**Sezione 9**\n- Riga 9\n- Dettaglio molto lungo 9\n\n'
    '**Sezione 10**\n- Riga 10\n- Dettaglio molto lungo 10\n\n'
    '**Sezione 11**\n- Riga 11\n- Dettaglio molto lungo 11\n\n'
    '**Sezione 12**\n- Riga 12\n- Dettaglio molto lungo 12\n\n'
    '**Sezione 13**\n- Riga 13\n- Dettaglio molto lungo 13\n\n'
    '**Sezione 14**\n- Riga 14\n- Dettaglio molto lungo 14\n\n'
    '**Sezione 15**\n- Riga 15\n- Dettaglio molto lungo 15\n\n'
    '**Sezione 16**\n- Riga 16\n- Dettaglio molto lungo 16\n\n'
    '**Sezione 17**\n- Riga 17\n- Dettaglio molto lungo 17\n\n'
    '**Sezione 18**\n- Riga 18\n- Dettaglio molto lungo 18';

const _markdownContent =
    '# Titolo recap\n\n'
    '* voce in *corsivo* e **grassetto**\n'
    '> [Apri documento](https://example.com) o `note inline`';

const _reportContent =
    'Sintomi recenti\n'
    '- cefalea serale\n'
    '- stanchezza lieve\n\n'
    '---\n\n'
    'Trend principali\n'
    'Energia media 5.4/10.\n'
    'Dolore medio 2.1/10.';

const _markdownTableContent =
    'Punti da portare in visita\n\n'
    '| Area | Dato | Nota |\n'
    '| --- | --- | --- |\n'
    '| Passi | 8200/die | andamento stabile |\n'
    '| Sonno | 6.8h | variabile |';

const _simplePipeTableContent =
    'Sintomo | Frequenza | Nota\n'
    'cefalea | 3 sere | più spesso dopo poco sonno\n'
    'stanchezza | quasi quotidiana | lieve';
