import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final command = args.isEmpty ? 'help' : args.first;
  final rest = args.length > 1 ? args.sublist(1) : const <String>[];

  switch (command) {
    case 'audit':
      await _runAudit(_parseOptions(rest));
      return;
    case 'merge-arb':
      await _runMergeArb(_parseOptions(rest));
      return;
    case 'build-ai-catalog':
      await _runBuildAiCatalog(_parseOptions(rest));
      return;
    case 'help':
    case '--help':
    case '-h':
      _printHelp();
      return;
    default:
      stderr.writeln('Unknown command: $command');
      _printHelp();
      exitCode = 64;
  }
}

void _printHelp() {
  stdout.writeln('''
Localization automation pipeline

Usage:
  dart run tool/localization_pipeline.dart audit [--output-dir build/localization]
  dart run tool/localization_pipeline.dart merge-arb --input build/localization/arb_translation_workfile.json
  dart run tool/localization_pipeline.dart build-ai-catalog --input build/localization/ai_translation_workfile.json

Commands:
  audit
    Scans lib/**/*.dart, finds localizable UI strings, AI prompt strings,
    demo content, hardcoded locale issues and forced language settings.
    Outputs JSON workfiles plus a markdown summary under build/localization.

  merge-arb
    Merges a translated ARB workfile back into lib/l10n/app_en.arb and
    lib/l10n/app_it.arb. New placeholder metadata is generated automatically.

  build-ai-catalog
    Builds simple EN/IT JSON catalogs from the translated AI workfile so prompt
    strings can later be consumed by a runtime prompt registry.
''');
}

Map<String, String> _parseOptions(List<String> args) {
  final options = <String, String>{};
  for (var index = 0; index < args.length; index += 1) {
    final token = args[index];
    if (!token.startsWith('--')) {
      throw FormatException('Unexpected argument: $token');
    }
    final key = token.substring(2);
    if (index + 1 < args.length && !args[index + 1].startsWith('--')) {
      options[key] = args[index + 1];
      index += 1;
    } else {
      options[key] = 'true';
    }
  }
  return options;
}

Future<void> _runAudit(Map<String, String> options) async {
  final packageRoot = Directory.current;
  final libDir = Directory(p.join(packageRoot.path, 'lib'));
  final arbFile = File(p.join(packageRoot.path, 'lib', 'l10n', 'app_en.arb'));
  if (!libDir.existsSync() || !arbFile.existsSync()) {
    stderr.writeln(
      'Run this command from apps/mobile so lib/ and lib/l10n/app_en.arb are available.',
    );
    exitCode = 64;
    return;
  }

  final outputDir = Directory(
    p.join(
      packageRoot.path,
      options['output-dir'] ?? p.join('build', 'localization'),
    ),
  );
  outputDir.createSync(recursive: true);

  final existingArb = _readJsonObject(arbFile);
  final existingValueToKey = <String, String>{};
  for (final entry in existingArb.entries) {
    if (entry.key.startsWith('@')) {
      continue;
    }
    if (entry.value is String) {
      existingValueToKey[entry.value as String] = entry.key;
    }
  }

  final dartFiles =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !_isGeneratedFile(file.path))
          .where(
            (file) =>
                !p.isWithin(p.join(packageRoot.path, 'lib', 'l10n'), file.path),
          )
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  final findings = <_Finding>[];
  for (final file in dartFiles) {
    final relativePath = p.relative(file.path, from: packageRoot.path);
    final content = file.readAsStringSync();
    findings.addAll(
      _collectFindings(
        relativePath: relativePath,
        content: content,
        existingValueToKey: existingValueToKey,
      ),
    );
  }

  final uniqueFindings = _dedupeFindings(findings);
  final uiEntries = _buildArbWorkItems(uniqueFindings);
  final aiEntries = _buildAiWorkItems(uniqueFindings);
  final localeIssues = uniqueFindings
      .where(
        (finding) =>
            finding.category == _FindingCategory.localeIssue ||
            finding.category == _FindingCategory.forcedLanguage,
      )
      .toList();

  final report = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'projectRoot': packageRoot.path,
    'supportedLanguages': const ['en', 'it'],
    'summary': {
      'totalFindings': uniqueFindings.length,
      'uiStrings': uiEntries.length,
      'aiStrings': aiEntries.length,
      'localeIssues': localeIssues.length,
    },
    'findings': uniqueFindings.map((finding) => finding.toJson()).toList(),
  };

  _writePrettyJson(File(p.join(outputDir.path, 'audit_report.json')), report);
  _writePrettyJson(
    File(p.join(outputDir.path, 'arb_translation_workfile.json')),
    {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'instructions': {
        'goal': 'Fill translated EN/IT values for user-facing UI strings.',
        'rules': const [
          'Do not change keys.',
          'Preserve {placeholders} exactly.',
          'Keep the tone simple and child-friendly.',
          'Do not translate technical IDs or file paths in notes.',
        ],
      },
      'entries': uiEntries.map((entry) => entry.toJson()).toList(),
    },
  );
  _writePrettyJson(
    File(p.join(outputDir.path, 'ai_translation_workfile.json')),
    {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'instructions': {
        'goal': 'Translate AI prompt and safety copy to EN/IT catalogs.',
        'rules': const [
          'Do not change keys.',
          'Preserve placeholders exactly.',
          'Keep safety constraints explicit.',
          'The output language should match the active app language.',
        ],
      },
      'entries': aiEntries.map((entry) => entry.toJson()).toList(),
    },
  );
  _writePrettyJson(File(p.join(outputDir.path, 'locale_issues.json')), {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'entries': localeIssues.map((issue) => issue.toJson()).toList(),
  });
  File(p.join(outputDir.path, 'summary.md')).writeAsStringSync(
    _buildSummaryMarkdown(
      findings: uniqueFindings,
      uiEntries: uiEntries,
      aiEntries: aiEntries,
      localeIssues: localeIssues,
    ),
  );

  stdout.writeln('Audit completed. Output written to ${outputDir.path}');
}

Future<void> _runMergeArb(Map<String, String> options) async {
  final packageRoot = Directory.current;
  final inputPath = options['input'];
  if (inputPath == null || inputPath.trim().isEmpty) {
    stderr.writeln('merge-arb requires --input <path-to-json>');
    exitCode = 64;
    return;
  }

  final inputFile = File(p.join(packageRoot.path, inputPath));
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: ${inputFile.path}');
    exitCode = 66;
    return;
  }

  final enFile = File(p.join(packageRoot.path, 'lib', 'l10n', 'app_en.arb'));
  final itFile = File(p.join(packageRoot.path, 'lib', 'l10n', 'app_it.arb'));
  final enMap = _readJsonObject(enFile);
  final itMap = _readJsonObject(itFile);
  final payload = _readJsonObject(inputFile);
  final entries = (payload['entries'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>();

  var mergedCount = 0;
  for (final entry in entries) {
    final key = entry['key']?.toString().trim() ?? '';
    if (key.isEmpty) {
      continue;
    }

    final enValue = entry['en']?.toString().trim() ?? '';
    final itValue = entry['it']?.toString().trim() ?? '';
    final description = entry['description']?.toString().trim() ?? '';
    final placeholders =
        (entry['placeholders'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (enValue.isNotEmpty) {
      enMap[key] = _escapeArbMessage(enValue);
    }
    if (itValue.isNotEmpty) {
      itMap[key] = _escapeArbMessage(itValue);
    }

    final metadata = _buildArbMetadata(
      existingMetadata:
          (enMap['@$key'] as Map<String, dynamic>?) ??
          (itMap['@$key'] as Map<String, dynamic>?),
      description: description,
      placeholders: placeholders,
    );
    if (metadata != null) {
      enMap['@$key'] = metadata;
      itMap['@$key'] = metadata;
    }
    mergedCount += 1;
  }

  _writePrettyJson(enFile, _orderArbMap(enMap));
  _writePrettyJson(itFile, _orderArbMap(itMap));
  stdout.writeln('Merged $mergedCount entries into app_en.arb and app_it.arb');
}

Future<void> _runBuildAiCatalog(Map<String, String> options) async {
  final packageRoot = Directory.current;
  final inputPath = options['input'];
  final outputDirPath =
      options['output-dir'] ?? p.join('build', 'localization');
  if (inputPath == null || inputPath.trim().isEmpty) {
    stderr.writeln('build-ai-catalog requires --input <path-to-json>');
    exitCode = 64;
    return;
  }

  final inputFile = File(p.join(packageRoot.path, inputPath));
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: ${inputFile.path}');
    exitCode = 66;
    return;
  }

  final payload = _readJsonObject(inputFile);
  final entries = (payload['entries'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>();

  final enCatalog = <String, String>{};
  final itCatalog = <String, String>{};
  for (final entry in entries) {
    final key = entry['key']?.toString().trim() ?? '';
    if (key.isEmpty) {
      continue;
    }
    final enValue = entry['en']?.toString().trim() ?? '';
    final itValue = entry['it']?.toString().trim() ?? '';
    if (enValue.isNotEmpty) {
      enCatalog[key] = enValue;
    }
    if (itValue.isNotEmpty) {
      itCatalog[key] = itValue;
    }
  }

  final outputDir = Directory(p.join(packageRoot.path, outputDirPath));
  outputDir.createSync(recursive: true);
  _writePrettyJson(File(p.join(outputDir.path, 'ai_catalog_en.json')), {
    'locale': 'en',
    'entries': enCatalog,
  });
  _writePrettyJson(File(p.join(outputDir.path, 'ai_catalog_it.json')), {
    'locale': 'it',
    'entries': itCatalog,
  });
  stdout.writeln('AI catalogs written to ${outputDir.path}');
}

List<_Finding> _collectFindings({
  required String relativePath,
  required String content,
  required Map<String, String> existingValueToKey,
}) {
  final findings = <_Finding>[];
  final normalizedPath = p.posix.normalize(relativePath.replaceAll('\\', '/'));
  final lines = const LineSplitter().convert(content);

  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];
    final lineNumber = index + 1;

    final localeMatch = RegExp(
      r'''DateFormat\([^\n]*?,\s*'([^']+)'\)|DateFormat\([^\n]*?,\s*"([^"]+)"\)|Locale\(\s*'([^']+)'(?:\s*,\s*'([^']+)')?\s*\)|Locale\(\s*"([^"]+)"(?:\s*,\s*"([^"]+)")?\s*\)''',
    ).firstMatch(line);
    if (localeMatch != null) {
      findings.add(
        _Finding(
          category: _FindingCategory.localeIssue,
          file: normalizedPath,
          line: lineNumber,
          text: line.trim(),
          context: 'Hardcoded locale or display format',
          suggestedKey: null,
          existingKey: null,
          placeholders: const <String>[],
        ),
      );
    }

    final forcedLanguageMatch = RegExp(
      r'copyWith\(language:\s*AppLanguagePreference\.(en|it)\)',
    ).firstMatch(line);
    if (forcedLanguageMatch != null) {
      findings.add(
        _Finding(
          category: _FindingCategory.forcedLanguage,
          file: normalizedPath,
          line: lineNumber,
          text: line.trim(),
          context: 'Forced app language in settings bootstrap',
          suggestedKey: null,
          existingKey: null,
          placeholders: const <String>[],
        ),
      );
    }
  }

  final tripleQuoteMatches = RegExp(
    "'''([\\s\\S]*?)'''|\"\"\"([\\s\\S]*?)\"\"\"",
    multiLine: true,
  ).allMatches(content).toList();

  final tripleQuoteRanges = <_Span>[];
  for (final match in tripleQuoteMatches) {
    final rawText = match.group(1) ?? match.group(2) ?? '';
    if (!_looksHumanText(rawText)) {
      continue;
    }
    final start = match.start;
    final line = _lineNumberForOffset(content, start);
    tripleQuoteRanges.add(_Span(start, match.end));

    final category = _categoryForBlock(normalizedPath);
    if (category == null) {
      continue;
    }

    final template = _toTemplateText(rawText);
    findings.add(
      _Finding(
        category: category,
        file: normalizedPath,
        line: line,
        text: rawText.trim(),
        context: category == _FindingCategory.aiPrompt
            ? 'Multiline AI prompt or safety instruction'
            : 'Multiline demo content',
        suggestedKey: _buildSuggestedKey(
          relativePath: normalizedPath,
          text: template.template,
          existingValueToKey: existingValueToKey,
        ),
        existingKey: existingValueToKey[template.template],
        placeholders: template.placeholders,
      ),
    );
  }

  final stringPattern = RegExp(
    r'''(?<![A-Za-z0-9_])(['"])((?:\\.|(?!\1).)*)\1''',
  );
  final offsetStarts = _lineOffsets(content);
  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('import ') || trimmed.startsWith('//')) {
      continue;
    }

    final lineStartOffset = offsetStarts[index];
    for (final match in stringPattern.allMatches(line)) {
      final absoluteStart = lineStartOffset + match.start;
      if (_isInsideAnySpan(absoluteStart, tripleQuoteRanges)) {
        continue;
      }

      final rawText = _unescapeSimple(match.group(2) ?? '');
      if (!_looksHumanText(rawText)) {
        continue;
      }
      if (_isClearlyTechnicalString(rawText)) {
        continue;
      }

      final category = _categoryForLine(
        relativePath: normalizedPath,
        line: line,
      );
      if (category == null) {
        continue;
      }
      if (category == _FindingCategory.uiLiteral &&
          !_isArbSafeUiText(rawText)) {
        continue;
      }

      final template = _toTemplateText(rawText);
      findings.add(
        _Finding(
          category: category,
          file: normalizedPath,
          line: index + 1,
          text: rawText.trim(),
          context: _contextForLine(category, line),
          suggestedKey: _buildSuggestedKey(
            relativePath: normalizedPath,
            text: template.template,
            existingValueToKey: existingValueToKey,
          ),
          existingKey: existingValueToKey[template.template],
          placeholders: template.placeholders,
        ),
      );
    }
  }

  return findings;
}

List<_Finding> _dedupeFindings(List<_Finding> findings) {
  final seen = <String>{};
  final result = <_Finding>[];
  for (final finding in findings) {
    final key = [
      finding.category.name,
      finding.file,
      finding.line.toString(),
      finding.text,
    ].join('|');
    if (seen.add(key)) {
      result.add(finding);
    }
  }
  return result;
}

List<_ArbWorkItem> _buildArbWorkItems(List<_Finding> findings) {
  final uiFindings = findings
      .where((finding) => finding.category == _FindingCategory.uiLiteral)
      .toList();
  final usedKeys = <String, int>{};
  final items = <_ArbWorkItem>[];
  for (final finding in uiFindings) {
    final template = _toTemplateText(finding.text);
    final baseKey = finding.existingKey ?? finding.suggestedKey ?? 'appText';
    final key = _dedupeKey(baseKey, usedKeys);
    items.add(
      _ArbWorkItem(
        key: key,
        source: finding.text,
        en: template.template,
        it: '',
        description: '${finding.context} (${finding.file}:${finding.line})',
        placeholders: template.placeholders,
        file: finding.file,
        line: finding.line,
      ),
    );
  }
  return items;
}

List<_AiWorkItem> _buildAiWorkItems(List<_Finding> findings) {
  final aiFindings = findings
      .where(
        (finding) =>
            finding.category == _FindingCategory.aiPrompt ||
            finding.category == _FindingCategory.seedContent,
      )
      .toList();
  final usedKeys = <String, int>{};
  final items = <_AiWorkItem>[];
  for (final finding in aiFindings) {
    final template = _toTemplateText(finding.text);
    final defaultPrefix = finding.category == _FindingCategory.seedContent
        ? 'demo'
        : 'ai';
    final baseKey =
        finding.suggestedKey ??
        _buildFallbackKey(finding.file, template.template, defaultPrefix);
    final key = _dedupeKey(baseKey, usedKeys);
    items.add(
      _AiWorkItem(
        key: key,
        category: finding.category.name,
        source: finding.text,
        en: template.template,
        it: '',
        context: '${finding.context} (${finding.file}:${finding.line})',
        placeholders: template.placeholders,
        file: finding.file,
        line: finding.line,
      ),
    );
  }
  return items;
}

String _buildSummaryMarkdown({
  required List<_Finding> findings,
  required List<_ArbWorkItem> uiEntries,
  required List<_AiWorkItem> aiEntries,
  required List<_Finding> localeIssues,
}) {
  final counts = <String, int>{};
  for (final finding in findings) {
    counts.update(
      finding.category.name,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  final topFiles = <String, int>{};
  for (final finding in findings) {
    topFiles.update(finding.file, (value) => value + 1, ifAbsent: () => 1);
  }
  final topFileRows = topFiles.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));

  final buffer = StringBuffer();
  buffer.writeln('# Localization Audit Summary');
  buffer.writeln();
  buffer.writeln('## Totals');
  buffer.writeln('- UI strings: ${uiEntries.length}');
  buffer.writeln('- AI and demo strings: ${aiEntries.length}');
  buffer.writeln('- Locale issues: ${localeIssues.length}');
  buffer.writeln();
  buffer.writeln('## By Category');
  final sortedCounts = counts.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  for (final entry in sortedCounts) {
    buffer.writeln('- ${entry.key}: ${entry.value}');
  }
  buffer.writeln();
  buffer.writeln('## Highest Impact Files');
  for (final entry in topFileRows.take(15)) {
    buffer.writeln('- ${entry.key}: ${entry.value} findings');
  }
  buffer.writeln();
  buffer.writeln('## Notes');
  buffer.writeln(
    '- `arb_translation_workfile.json` is the file to give to the local LLM for UI copy.',
  );
  buffer.writeln(
    '- `ai_translation_workfile.json` captures prompt, fallback and demo text that must become bilingual too.',
  );
  buffer.writeln(
    '- `locale_issues.json` contains hardcoded `en_US` / `it_IT` style display issues and forced language code paths.',
  );
  return buffer.toString();
}

Map<String, dynamic> _readJsonObject(File file) {
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void _writePrettyJson(File file, Object value) {
  file.parent.createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(value)}\n');
}

Map<String, dynamic> _orderArbMap(Map<String, dynamic> original) {
  final ordered = <String, dynamic>{};
  if (original.containsKey('@@locale')) {
    ordered['@@locale'] = original['@@locale'];
  }
  final baseKeys =
      original.keys
          .where((key) => !key.startsWith('@'))
          .where((key) => key != '@@locale')
          .toList()
        ..sort();
  for (final key in baseKeys) {
    ordered[key] = original[key];
    final metadataKey = '@$key';
    if (original.containsKey(metadataKey)) {
      ordered[metadataKey] = original[metadataKey];
    }
  }
  final remainingMetaKeys =
      original.keys
          .where((key) => key.startsWith('@'))
          .where((key) => key != '@@locale')
          .where((key) => !ordered.containsKey(key))
          .toList()
        ..sort();
  for (final key in remainingMetaKeys) {
    ordered[key] = original[key];
  }
  return ordered;
}

Map<String, dynamic>? _buildArbMetadata({
  required Map<String, dynamic>? existingMetadata,
  required String description,
  required List<String> placeholders,
}) {
  if ((existingMetadata == null || existingMetadata.isEmpty) &&
      description.isEmpty &&
      placeholders.isEmpty) {
    return null;
  }

  final metadata = <String, dynamic>{...?existingMetadata};
  if (description.isNotEmpty) {
    metadata['description'] = description;
  }
  if (placeholders.isNotEmpty) {
    final existingPlaceholders =
        (metadata['placeholders'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final mergedPlaceholders = <String, dynamic>{...existingPlaceholders};
    for (final placeholder in placeholders) {
      mergedPlaceholders.putIfAbsent(placeholder, () => <String, dynamic>{});
    }
    metadata['placeholders'] = mergedPlaceholders;
  }
  return metadata;
}

_TemplateText _toTemplateText(String text) {
  final placeholders = <String>[];
  var template = text;
  final braced = RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}');
  template = template.replaceAllMapped(braced, (match) {
    final name = match.group(1)!;
    placeholders.add(name);
    return '{$name}';
  });
  final bare = RegExp(r'\$([A-Za-z_][A-Za-z0-9_]*)');
  template = template.replaceAllMapped(bare, (match) {
    final name = match.group(1)!;
    placeholders.add(name);
    return '{$name}';
  });
  final uniquePlaceholders = placeholders.toSet().toList()..sort();
  return _TemplateText(template: template, placeholders: uniquePlaceholders);
}

String _buildSuggestedKey({
  required String relativePath,
  required String text,
  required Map<String, String> existingValueToKey,
}) {
  final existingKey = existingValueToKey[text];
  if (existingKey != null && existingKey.trim().isNotEmpty) {
    return existingKey;
  }
  final scope = _scopeFromPath(relativePath);
  final words = _tokenizeText(text).take(6).toList();
  if (words.isEmpty) {
    return '${scope}Text';
  }
  return '$scope${words.map(_capitalize).join()}';
}

String _buildFallbackKey(String relativePath, String text, String prefix) {
  final words = _tokenizeText(text).take(6).toList();
  final scope = _scopeFromPath(relativePath);
  if (words.isEmpty) {
    return '$prefix${_capitalize(scope)}Text';
  }
  return '$prefix${_capitalize(scope)}${words.map(_capitalize).join()}';
}

String _dedupeKey(String baseKey, Map<String, int> usedKeys) {
  final count = usedKeys.update(
    baseKey,
    (value) => value + 1,
    ifAbsent: () => 1,
  );
  return count == 1 ? baseKey : '$baseKey$count';
}

String _scopeFromPath(String relativePath) {
  final parts = p.posix.split(relativePath);
  final featureIndex = parts.indexOf('features');
  if (featureIndex >= 0 && featureIndex + 1 < parts.length) {
    return _camelize(parts[featureIndex + 1]);
  }
  if (parts.length >= 2) {
    return _camelize(p.basenameWithoutExtension(parts.last));
  }
  return 'app';
}

List<String> _tokenizeText(String text) {
  final normalized = text
      .replaceAll(RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}'), ' ')
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
      .trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((part) => part.toLowerCase())
      .where((part) => part.isNotEmpty)
      .toList();
}

String _camelize(String text) {
  final tokens = text
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (tokens.isEmpty) {
    return 'app';
  }
  return tokens.first.toLowerCase() + tokens.skip(1).map(_capitalize).join();
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

_FindingCategory? _categoryForBlock(String relativePath) {
  if (_isAiFile(relativePath)) {
    return _FindingCategory.aiPrompt;
  }
  if (_isSeedContentFile(relativePath)) {
    return _FindingCategory.seedContent;
  }
  return null;
}

_FindingCategory? _categoryForLine({
  required String relativePath,
  required String line,
}) {
  if (_isSeedContentFile(relativePath)) {
    return _FindingCategory.seedContent;
  }
  if (_isAiFile(relativePath)) {
    return _FindingCategory.aiPrompt;
  }
  if (_isUiFile(relativePath) || _looksLikeUiContext(line)) {
    return _FindingCategory.uiLiteral;
  }
  return null;
}

String _contextForLine(_FindingCategory category, String line) {
  if (category == _FindingCategory.aiPrompt) {
    return 'AI prompt, fallback or assistant-facing text';
  }
  if (category == _FindingCategory.seedContent) {
    return 'Demo content shown to the user or passed to AI';
  }
  if (line.contains('hintText:')) {
    return 'Input hint text';
  }
  if (line.contains('labelText:')) {
    return 'Input label text';
  }
  if (line.contains('tooltip:')) {
    return 'Tooltip';
  }
  if (line.contains('SnackBar')) {
    return 'Snackbar message';
  }
  if (line.contains('title:')) {
    return 'Title text';
  }
  if (line.contains('subtitle:')) {
    return 'Subtitle text';
  }
  return 'User-facing UI text';
}

bool _isGeneratedFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('.g.dart') ||
      normalized.endsWith('.freezed.dart') ||
      normalized.endsWith('.mocks.dart') ||
      normalized.endsWith('app_localizations.dart') ||
      normalized.endsWith('app_localizations_en.dart') ||
      normalized.endsWith('app_localizations_it.dart');
}

bool _looksHumanText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(trimmed)) {
    return false;
  }
  if (trimmed.startsWith('package:') || trimmed.contains('.dart')) {
    return false;
  }
  if (RegExp(r'^[a-z0-9_./:-]+$').hasMatch(trimmed) &&
      !trimmed.contains(' ') &&
      trimmed == trimmed.toLowerCase()) {
    return false;
  }
  return true;
}

bool _isClearlyTechnicalString(String text) {
  final trimmed = text.trim();
  const ignored = {
    'processing',
    'parsed',
    'local_only',
    'review_required',
    'en_US',
    'it_IT',
    'en',
    'it',
    'daily',
    'clinical_question',
    'on_device_litertlm',
  };
  if (ignored.contains(trimmed)) {
    return true;
  }
  if (trimmed.startsWith('/') || trimmed.startsWith('assets/')) {
    return true;
  }
  return false;
}

bool _isArbSafeUiText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.contains(r'${') || trimmed.contains(r'$')) {
    return false;
  }
  if (trimmed.contains('{') || trimmed.contains('}')) {
    return false;
  }
  if (trimmed.contains('=>') ||
      trimmed.contains('??') ||
      trimmed.contains('DateFormat(') ||
      trimmed.contains('RegExp(') ||
      trimmed.contains('.toString') ||
      trimmed.contains('.format(') ||
      trimmed.contains('.length') ||
      trimmed.contains('Platform.') ||
      trimmed.contains('Directory.') ||
      trimmed.contains('Navigator.') ||
      trimmed.contains('DateTime.')) {
    return false;
  }
  if (trimmed.contains('\\') ||
      trimmed.contains('^') ||
      trimmed.contains(r'\s')) {
    return false;
  }
  return true;
}

String _escapeArbMessage(String value) {
  return value.replaceAll("'", "''");
}

bool _looksLikeUiContext(String line) {
  const signals = [
    'Text(',
    'RichText(',
    'SnackBar(',
    'labelText:',
    'hintText:',
    'helperText:',
    'errorText:',
    'tooltip:',
    'title:',
    'subtitle:',
    'content:',
    'label:',
    'empty',
    'message:',
  ];
  return signals.any(line.contains);
}

bool _isUiFile(String relativePath) {
  return relativePath.contains('/presentation/') ||
      relativePath.startsWith('lib/app/') ||
      relativePath.startsWith('lib/shared/widgets/') ||
      relativePath.contains('local_medication_reminder_service.dart');
}

bool _isAiFile(String relativePath) {
  return relativePath.endsWith('on_device_prompt_builder.dart') ||
      relativePath.endsWith('documents_repository.dart') ||
      relativePath.endsWith('reports_repository.dart') ||
      relativePath.endsWith('insights_repository.dart');
}

bool _isSeedContentFile(String relativePath) {
  return relativePath.endsWith('demo_seed_data.dart');
}

bool _isInsideAnySpan(int offset, List<_Span> spans) {
  for (final span in spans) {
    if (offset >= span.start && offset < span.end) {
      return true;
    }
  }
  return false;
}

List<int> _lineOffsets(String content) {
  final offsets = <int>[0];
  for (var index = 0; index < content.length; index += 1) {
    if (content.codeUnitAt(index) == 10) {
      offsets.add(index + 1);
    }
  }
  return offsets;
}

int _lineNumberForOffset(String content, int offset) {
  var line = 1;
  for (var index = 0; index < offset && index < content.length; index += 1) {
    if (content.codeUnitAt(index) == 10) {
      line += 1;
    }
  }
  return line;
}

String _unescapeSimple(String value) {
  return value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"');
}

class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;
}

class _TemplateText {
  const _TemplateText({required this.template, required this.placeholders});

  final String template;
  final List<String> placeholders;
}

enum _FindingCategory {
  uiLiteral,
  aiPrompt,
  seedContent,
  localeIssue,
  forcedLanguage,
}

class _Finding {
  const _Finding({
    required this.category,
    required this.file,
    required this.line,
    required this.text,
    required this.context,
    required this.suggestedKey,
    required this.existingKey,
    required this.placeholders,
  });

  final _FindingCategory category;
  final String file;
  final int line;
  final String text;
  final String context;
  final String? suggestedKey;
  final String? existingKey;
  final List<String> placeholders;

  Map<String, Object?> toJson() {
    return {
      'category': category.name,
      'file': file,
      'line': line,
      'text': text,
      'context': context,
      'suggestedKey': suggestedKey,
      'existingKey': existingKey,
      'placeholders': placeholders,
    };
  }
}

class _ArbWorkItem {
  const _ArbWorkItem({
    required this.key,
    required this.source,
    required this.en,
    required this.it,
    required this.description,
    required this.placeholders,
    required this.file,
    required this.line,
  });

  final String key;
  final String source;
  final String en;
  final String it;
  final String description;
  final List<String> placeholders;
  final String file;
  final int line;

  Map<String, Object?> toJson() {
    return {
      'key': key,
      'source': source,
      'en': en,
      'it': it,
      'description': description,
      'placeholders': placeholders,
      'file': file,
      'line': line,
    };
  }
}

class _AiWorkItem {
  const _AiWorkItem({
    required this.key,
    required this.category,
    required this.source,
    required this.en,
    required this.it,
    required this.context,
    required this.placeholders,
    required this.file,
    required this.line,
  });

  final String key;
  final String category;
  final String source;
  final String en;
  final String it;
  final String context;
  final List<String> placeholders;
  final String file;
  final int line;

  Map<String, Object?> toJson() {
    return {
      'key': key,
      'category': category,
      'source': source,
      'en': en,
      'it': it,
      'context': context,
      'placeholders': placeholders,
      'file': file,
      'line': line,
    };
  }
}
