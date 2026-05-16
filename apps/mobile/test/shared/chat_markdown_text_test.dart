import 'package:clindiary/shared/widgets/chat_markdown_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat markdown text renders formatted content cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ChatMarkdownText(
              text:
                  '# Recap title\n\n- item in *italic* and **bold**\n> [Open document](https://example.com) or `inline notes`',
              foreground: Colors.black,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recap title'), findsOneWidget);
    expect(find.text('item in italic and bold'), findsOneWidget);
    expect(find.text('Open document or inline notes'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('`'), findsNothing);
    expect(find.textContaining('['), findsNothing);
  });

  testWidgets('chat markdown text strips malformed emphasis markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ChatMarkdownText(
              text:
                  '**Pending section\n- Keep **only** the content\n- stray marker ** after text',
              foreground: Colors.black,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pending section'), findsOneWidget);
    expect(find.text('Keep only the content'), findsOneWidget);
    expect(find.text('stray marker after text'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });
}
