import 'package:flutter/material.dart';

class SummaryContentView extends StatelessWidget {
  const SummaryContentView({
    required this.content,
    this.maxHeightFactor = 0.55,
    this.constrainHeight = true,
    super.key,
  });

  final String content;
  final double maxHeightFactor;
  final bool constrainHeight;

  @override
  Widget build(BuildContext context) {
    final blocks = summaryBlocks(content);
    final contentView = SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < blocks.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _SummaryBlockCard(block: blocks[index]),
          ],
        ],
      ),
    );

    if (!constrainHeight) {
      return contentView;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenHeight * maxHeightFactor).clamp(240.0, 640.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.only(right: 4),
        child: contentView,
      ),
    );
  }
}

class _SummaryBlockCard extends StatelessWidget {
  const _SummaryBlockCard({required this.block});

  final String block;

  @override
  Widget build(BuildContext context) {
    final parsedBlock = _parseSummaryBlock(block);
    if (parsedBlock == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parsedBlock.heading != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  TextSpan(
                    children: _buildInlineSpans(
                      parsedBlock.heading!,
                      theme.textTheme.bodyMedium!,
                      theme.colorScheme,
                    ),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (parsedBlock.items.isNotEmpty) const SizedBox(height: 12),
            ],
            for (var index = 0; index < parsedBlock.items.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              if (parsedBlock.items[index] case final _ParsedSummaryLine line)
                _SummaryLine(line: line)
              else if (parsedBlock.items[index]
                  case final _ParsedSummaryTable table)
                _SummaryTable(table: table)
              else
                const SizedBox.shrink(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.line});

  final _ParsedSummaryLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (line.isHeading) {
      return Text.rich(
        TextSpan(
          children: _buildInlineSpans(
            line.text,
            textTheme.bodyMedium!,
            colorScheme,
          ),
        ),
        style: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
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
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _buildInlineSpans(
                  line.text,
                  textTheme.bodyMedium!,
                  colorScheme,
                ),
              ),
              style: textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        children: _buildInlineSpans(
          line.text,
          textTheme.bodyMedium!,
          colorScheme,
        ),
      ),
      style: textTheme.bodyMedium?.copyWith(height: 1.4),
    );
  }
}

List<InlineSpan> _buildInlineSpans(
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

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.table});

  final _ParsedSummaryTable table;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      primary: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            for (var index = 0; index < table.columnCount; index++)
              index: const IntrinsicColumnWidth(),
          },
          border: TableBorder.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
            width: 1,
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.42),
              ),
              children: [
                for (final header in table.headers)
                  _TableCell(
                    text: header,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            for (final row in table.rows)
              TableRow(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                ),
                children: [
                  for (final cell in row)
                    _TableCell(
                      text: cell,
                      style: textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text, style: style),
      ),
    );
  }
}

List<String> summaryBlocks(String content) {
  final paragraphs = content
      .split(RegExp(r'\n\s*\n'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (paragraphs.isNotEmpty) {
    return paragraphs;
  }
  return content
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

bool _looksLikeHeading(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('#') ||
      RegExp(r'^\d+\.\s+').hasMatch(trimmed) ||
      (trimmed.startsWith('**') &&
          trimmed.endsWith('**') &&
          trimmed.length > 4);
}

bool _looksLikeBullet(String line) {
  final trimmed = line.trim();
  return RegExp(
    r'^([-+*•]\s+|[-+*]\s+\[[xX ]\]\s*|\d+\)\s+)',
  ).hasMatch(trimmed);
}

bool _isVisualDivider(String line) {
  final trimmed = line.trim();
  return trimmed == '---' || trimmed == '***' || trimmed == '___';
}

_ParsedSummaryLine? _parseSummaryLine(String rawLine) {
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

  return _ParsedSummaryLine(
    text: normalized,
    isHeading: isHeading && !isBullet,
    isBullet: isBullet,
  );
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
    RegExp(r'^\d+\)\s+'),
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

_ParsedSummaryBlock? _parseSummaryBlock(String block) {
  final rawLines = block
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (rawLines.isEmpty) {
    return null;
  }

  String? heading;
  final remainingLines = [...rawLines];
  final firstParsedLine = _parseSummaryLine(rawLines.first);
  if (firstParsedLine == null) {
    return null;
  }
  final promoteFirstLine =
      !firstParsedLine.isBullet &&
      !_looksLikeTableRow(rawLines.first) &&
      !_isTableSeparatorRow(rawLines.first) &&
      (firstParsedLine.isHeading ||
          (rawLines.length > 1 && firstParsedLine.text.length <= 80));

  if (promoteFirstLine) {
    heading = firstParsedLine.text;
    remainingLines.removeAt(0);
  }

  final items = <_ParsedSummaryItem>[];
  var index = 0;
  while (index < remainingLines.length) {
    final currentLine = remainingLines[index];
    if (_looksLikeTableRow(currentLine) || _isTableSeparatorRow(currentLine)) {
      final tableLines = <String>[];
      var cursor = index;
      while (cursor < remainingLines.length) {
        final candidate = remainingLines[cursor];
        if (!_looksLikeTableRow(candidate) &&
            !_isTableSeparatorRow(candidate)) {
          break;
        }
        tableLines.add(candidate);
        cursor += 1;
      }
      final table = _parseSummaryTable(tableLines);
      if (table != null) {
        items.add(table);
        index = cursor;
        continue;
      }
    }

    final parsedLine = _parseSummaryLine(currentLine);
    if (parsedLine != null) {
      items.add(parsedLine);
    }
    index += 1;
  }

  if (items.isEmpty && heading == null) {
    return null;
  }

  return _ParsedSummaryBlock(heading: heading, items: items);
}

bool _looksLikeTableRow(String line) {
  final cells = _splitTableCells(line);
  return cells.length >= 2 && !_isTableSeparatorRow(line);
}

bool _isTableSeparatorRow(String line) {
  final cells = _splitTableCells(line);
  if (cells.length < 2) {
    return false;
  }
  return cells.every(
    (cell) =>
        cell.trim().isNotEmpty && RegExp(r'^:?-{2,}:?$').hasMatch(cell.trim()),
  );
}

List<String> _splitTableCells(String line) {
  final trimmed = line.trim();
  if (!trimmed.contains('|')) {
    return const [];
  }
  final normalized = trimmed.startsWith('|') ? trimmed.substring(1) : trimmed;
  final withoutTrailing = normalized.endsWith('|')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  return withoutTrailing
      .split('|')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

_ParsedSummaryTable? _parseSummaryTable(List<String> lines) {
  if (lines.length < 2) {
    return null;
  }

  final hasSeparator = lines.length > 1 && _isTableSeparatorRow(lines[1]);
  final normalizedRows = lines
      .where((line) => !_isTableSeparatorRow(line))
      .map(
        (line) => _splitTableCells(
          _normalizeMarkdownLine(line, stripBulletMarker: false),
        ),
      )
      .where((row) => row.length >= 2)
      .toList();

  if (normalizedRows.length < 2) {
    return null;
  }

  final columnCount = normalizedRows.fold<int>(
    0,
    (max, row) => row.length > max ? row.length : max,
  );
  if (columnCount < 2) {
    return null;
  }

  final paddedRows = normalizedRows
      .map((row) => [...row, ...List.filled(columnCount - row.length, '')])
      .toList();

  final headers = paddedRows.first;
  final rows = paddedRows.skip(1).toList();

  if (rows.isEmpty && !hasSeparator) {
    return null;
  }

  return _ParsedSummaryTable(
    headers: headers,
    rows: rows,
    columnCount: columnCount,
  );
}

String _stripInlineLatex(String value) {
  var cleaned = value;

  // Preserve math payload while removing inline/display delimiters.
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

  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\^\{([^{}]+)\}'),
    (match) => '^${match.group(1) ?? ''}',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'_\{([^{}]+)\}'),
    (match) => '_${match.group(1) ?? ''}',
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

  const escapedReplacements = {
    r'\%': '%',
    r'\_': '_',
    r'\&': '&',
    r'\#': '#',
    r'\\$': r'$',
    r'\{': '{',
    r'\}': '}',
  };
  escapedReplacements.forEach((pattern, replacement) {
    cleaned = cleaned.replaceAll(pattern, replacement);
  });

  // Unwrap remaining commands that still carry one argument.
  for (var i = 0; i < 3; i++) {
    final next = cleaned.replaceAllMapped(
      RegExp(r'\\[a-zA-Z]+\s*\{([^{}]*)\}'),
      (match) => match.group(1) ?? '',
    );
    if (next == cleaned) {
      break;
    }
    cleaned = next;
  }

  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\\[a-zA-Z]+'),
    (match) => match.group(0)!.replaceFirst('\\', ''),
  );

  cleaned = cleaned
      .replaceAll(r'\(', '')
      .replaceAll(r'\)', '')
      .replaceAll(r'\[', '')
      .replaceAll(r'\]', '')
      .replaceAll('{', '')
      .replaceAll('}', '');

  cleaned = cleaned.replaceAll(RegExp(r'(?<=\s)\$(?=\s|[A-Za-z])'), '');
  cleaned = cleaned.replaceAll(RegExp(r'^\$+|\$+$'), '');

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

sealed class _ParsedSummaryItem {
  const _ParsedSummaryItem();
}

class _ParsedSummaryTable extends _ParsedSummaryItem {
  const _ParsedSummaryTable({
    required this.headers,
    required this.rows,
    required this.columnCount,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final int columnCount;
}

class _ParsedSummaryLine extends _ParsedSummaryItem {
  const _ParsedSummaryLine({
    required this.text,
    required this.isHeading,
    required this.isBullet,
  });

  final String text;
  final bool isHeading;
  final bool isBullet;
}

class _ParsedSummaryBlock {
  const _ParsedSummaryBlock({required this.heading, required this.items});

  final String? heading;
  final List<_ParsedSummaryItem> items;
}
