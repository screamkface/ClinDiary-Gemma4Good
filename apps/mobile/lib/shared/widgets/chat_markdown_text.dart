import 'package:flutter/material.dart';

class ChatMarkdownText extends StatelessWidget {
  const ChatMarkdownText({
    super.key,
    required this.text,
    required this.foreground,
    this.showTrailingCursor = false,
  });

  final String text;
  final Color foreground;
  final bool showTrailingCursor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle =
        Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: foreground, height: 1.42) ??
        TextStyle(color: foreground, height: 1.42);
    final content = showTrailingCursor ? '$text|' : text;
    final blocks = _chatBlocks(content);

    return SelectionArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (
            var blockIndex = 0;
            blockIndex < blocks.length;
            blockIndex++
          ) ...[
            if (blockIndex > 0) const SizedBox(height: 8),
            _ChatMarkdownBlock(
              block: blocks[blockIndex],
              baseStyle: baseStyle,
              colorScheme: colorScheme,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatMarkdownBlock extends StatelessWidget {
  const _ChatMarkdownBlock({
    required this.block,
    required this.baseStyle,
    required this.colorScheme,
  });

  final String block;
  final TextStyle baseStyle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final lines = block
        .split('\n')
        .map((item) => item.trimRight())
        .where((item) => item.trim().isNotEmpty)
        .map(_parseChatLine)
        .whereType<_ParsedChatLine>()
        .toList(growable: false);

    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          _ChatMarkdownLine(
            line: lines[index],
            baseStyle: baseStyle,
            colorScheme: colorScheme,
          ),
        ],
      ],
    );
  }
}

class _ChatMarkdownLine extends StatelessWidget {
  const _ChatMarkdownLine({
    required this.line,
    required this.baseStyle,
    required this.colorScheme,
  });

  final _ParsedChatLine line;
  final TextStyle baseStyle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final spans = _chatInlineSpans(line.text, baseStyle, colorScheme);

    if (line.isHeading) {
      return Text.rich(
        TextSpan(style: baseStyle, children: spans),
        style: baseStyle.copyWith(fontWeight: FontWeight.w800, height: 1.3),
      );
    }

    if (line.isBullet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(style: baseStyle, children: spans),
              style: baseStyle,
            ),
          ),
        ],
      );
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      style: baseStyle,
    );
  }
}

class _ParsedChatLine {
  const _ParsedChatLine({
    required this.text,
    required this.isHeading,
    required this.isBullet,
  });

  final String text;
  final bool isHeading;
  final bool isBullet;
}

List<String> _chatBlocks(String content) {
  final paragraphs = content
      .split(RegExp(r'\n\s*\n'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (paragraphs.isNotEmpty) {
    return paragraphs;
  }
  return content
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

_ParsedChatLine? _parseChatLine(String rawLine) {
  final trimmed = rawLine.trim();
  if (trimmed.isEmpty || trimmed == '```' || _isVisualDivider(trimmed)) {
    return null;
  }

  final isHeading = _looksLikeHeading(trimmed);
  final isBullet = _looksLikeBullet(trimmed);
  final normalized = _normalizeMarkdownLine(
    trimmed,
    stripBulletMarker: isBullet,
  );
  if (normalized.isEmpty) {
    return null;
  }

  return _ParsedChatLine(
    text: normalized,
    isHeading: isHeading && !isBullet,
    isBullet: isBullet,
  );
}

List<InlineSpan> _chatInlineSpans(
  String text,
  TextStyle baseStyle,
  ColorScheme colorScheme,
) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    r'(\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|`(.+?)`)',
  );
  var lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      final plain = _stripResidualMarkdownMarkers(
        text.substring(lastEnd, match.start),
      );
      if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain));
      }
    }

    final boldItalic = match.group(2);
    final bold = match.group(3) ?? match.group(4);
    final italic = match.group(5) ?? match.group(6);
    final code = match.group(7);

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
    final plain = _stripResidualMarkdownMarkers(text.substring(lastEnd));
    if (plain.isNotEmpty) {
      spans.add(TextSpan(text: plain));
    }
  }

  if (spans.isEmpty) {
    return [TextSpan(text: _stripResidualMarkdownMarkers(text))];
  }

  return spans;
}

bool _looksLikeHeading(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('#') ||
      (trimmed.startsWith('**') &&
          trimmed.endsWith('**') &&
          trimmed.length > 4);
}

bool _looksLikeBullet(String line) {
  final trimmed = line.trim();
  return RegExp(
    r'^([-+*•]\s+|[-+*]\s+\[[xX ]\]\s*|\d+[\.)]\s+)',
  ).hasMatch(trimmed);
}

bool _isVisualDivider(String line) {
  final trimmed = line.trim();
  return trimmed == '---' || trimmed == '***' || trimmed == '___';
}

String _normalizeMarkdownLine(String line, {required bool stripBulletMarker}) {
  var cleaned = line.trim();
  cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s*'), '');
  cleaned = cleaned.replaceAll(RegExp(r'^>\s*'), '');
  cleaned = cleaned.replaceAll(
    RegExp(r'^[-+*]\s+\[[xX ]\]\s*'),
    stripBulletMarker ? '' : '- ',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'^\d+[\.)]\s+'),
    stripBulletMarker ? '' : '- ',
  );

  if (stripBulletMarker) {
    cleaned = cleaned.replaceAll(RegExp(r'^[-+*•]\s+'), '');
  } else {
    cleaned = cleaned.replaceAll(RegExp(r'^[-+*•]\s+'), '- ');
  }

  cleaned = cleaned.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAll('```', '');
  cleaned = _stripInlineLatex(cleaned);
  cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return cleaned;
}

String _stripResidualMarkdownMarkers(String value) {
  return value
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('~~', '')
      .replaceAll('```', '')
      .replaceAll('`', '')
      .replaceAll('[', '')
      .replaceAll(']', '')
      .replaceAll(RegExp(r'\s{2,}'), ' ');
}

String _stripInlineLatex(String value) {
  var cleaned = value;

  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\$\$([\s\S]*?)\$\$'),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\$([^$\n]+)\$'),
    (match) => match.group(1) ?? '',
  );

  cleaned = _replaceLatexCommandsWithInnerText(
    cleaned,
    commands: const [
      'text',
      'mathrm',
      'mathbf',
      'mathit',
      'operatorname',
      'textbf',
      'textit',
      'underline',
      'overline',
    ],
  );

  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\\frac\s*\{([^{}]+)\}\{([^{}]+)\}'),
    (match) => '${match.group(1) ?? ''}/${match.group(2) ?? ''}',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\\sqrt\s*\{([^{}]+)\}'),
    (match) => 'sqrt(${match.group(1) ?? ''})',
  );

  const symbolReplacements = {
    r'\pm': '+/-',
    r'\times': 'x',
    r'\cdot': '*',
    r'\ge': '>=',
    r'\le': '<=',
    r'\neq': '!=',
    r'\approx': '~',
    r'\to': '->',
    r'\degree': 'deg',
  };
  symbolReplacements.forEach((pattern, replacement) {
    cleaned = cleaned.replaceAll(pattern, replacement);
  });

  cleaned = cleaned
      .replaceAll(r'\(', '')
      .replaceAll(r'\)', '')
      .replaceAll(r'\[', '')
      .replaceAll(r'\]', '')
      .replaceAll('{', '')
      .replaceAll('}', '');

  return cleaned;
}

String _replaceLatexCommandsWithInnerText(
  String value, {
  required List<String> commands,
}) {
  var cleaned = value;
  for (final command in commands) {
    final pattern = RegExp('\\\\$command\\s*\\{([^{}]+)\\}');
    var previous = '';
    while (previous != cleaned) {
      previous = cleaned;
      cleaned = cleaned.replaceAllMapped(
        pattern,
        (match) => match.group(1) ?? '',
      );
    }
  }
  return cleaned;
}
