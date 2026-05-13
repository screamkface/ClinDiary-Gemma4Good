import 'package:flutter/material.dart';

class ChatMarkdownText extends StatelessWidget {
  const ChatMarkdownText({
    super.key,
    required this.text,
    required this.foreground,
  });

  final String text;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle =
        Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: foreground, height: 1.42) ??
        const TextStyle();

    return SelectableText.rich(
      TextSpan(
        style: baseStyle,
        children: chatInlineSpans(text, baseStyle, colorScheme),
      ),
    );
  }
}

List<InlineSpan> chatInlineSpans(
  String text,
  TextStyle baseStyle,
  ColorScheme colorScheme,
) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    r'(\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`)',
  );
  var lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }

    final boldItalic = match.group(2);
    final bold = match.group(3);
    final italic = match.group(4);
    final code = match.group(5);

    if (boldItalic != null) {
      spans.add(
        TextSpan(
          text: boldItalic,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
    } else if (italic != null) {
      spans.add(
        TextSpan(
          text: italic,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (code != null) {
      spans.add(
        TextSpan(
          text: code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! - 1 : 12,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return spans;
}
