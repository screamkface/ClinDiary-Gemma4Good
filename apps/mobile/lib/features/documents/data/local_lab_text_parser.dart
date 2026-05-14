import 'dart:isolate';

import 'package:clindiary/features/documents/domain/clinical_document.dart';

class LocalLabTextParser {
  const LocalLabTextParser();

  Future<LocalStructuredParseResult> parse({
    required String documentId,
    required String documentType,
    required String title,
    String? examDateIso,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const LocalStructuredParseResult.empty();
    }

    final payload = <String, String?>{
      'document_id': documentId,
      'document_type': documentType,
      'title': title,
      'exam_date_iso': examDateIso,
      'text': normalized,
    };

    final isImagingDocument =
        _isImagingDocumentType(documentType) ||
        _looksLikeImagingText(normalized);
    final raw = await Isolate.run(
      () => isImagingDocument
          ? _parseImagingInIsolate(payload)
          : _parseLabInIsolate(payload),
    );
    return LocalStructuredParseResult.fromJson(raw);
  }
}

class LocalStructuredParseResult {
  const LocalStructuredParseResult({
    required this.parsedStatus,
    required this.parsingConfidence,
    required this.processedAt,
    required this.labPanels,
    required this.imagingReports,
  });

  const LocalStructuredParseResult.empty()
    : parsedStatus = 'local_only',
      parsingConfidence = null,
      processedAt = null,
      labPanels = const [],
      imagingReports = const [];

  final String parsedStatus;
  final double? parsingConfidence;
  final DateTime? processedAt;
  final List<LabPanelItem> labPanels;
  final List<ImagingReportItem> imagingReports;

  factory LocalStructuredParseResult.fromJson(Map<String, dynamic> json) {
    return LocalStructuredParseResult(
      parsedStatus: json['parsed_status']?.toString() ?? 'local_only',
      parsingConfidence: (json['parsing_confidence'] as num?)?.toDouble(),
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.tryParse(json['processed_at'].toString()),
      labPanels: (json['lab_panels'] as List<dynamic>? ?? const [])
          .map((item) => LabPanelItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      imagingReports: (json['imaging_reports'] as List<dynamic>? ?? const [])
          .map(
            (item) => ImagingReportItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

final RegExp _numberPattern = RegExp(r'-?\d+(?:[.,]\d+)?');
final RegExp _rangePattern = RegExp(
  r'(-?\d+(?:[.,]\d+)?)\s*(?:-|to)\s*(-?\d+(?:[.,]\d+)?)',
  caseSensitive: false,
);
final RegExp _thresholdPattern = RegExp(r'(<=|>=|<|>)\s*(-?\d+(?:[.,]\d+)?)');
final RegExp _flagPattern = RegExp(
  r'\b(HIGH|LOW|NORMAL|H|L|N)\b',
  caseSensitive: false,
);
final RegExp _lettersPattern = RegExp(r'[A-Za-z]');
final RegExp _unitPattern = RegExp(r'[A-Za-z%/]');
final RegExp _labKeywordPattern = RegExp(
  r'\b(wbc|rbc|hgb|hct|plt|glucose|creatinine|cholesterol|triglycerides|ast|alt|tsh|ferritin|crp|pcr)\b',
  caseSensitive: false,
);
final RegExp _imagingKeywordPattern = RegExp(
  r'\b(ultrasound|ecografia|imaging|radiology|radiographic|x[- ]?ray|rx|ct|mri|rm|mammography|mammografia|tomography|scan|referto)\b',
  caseSensitive: false,
);
final RegExp _impressionMarkerPattern = RegExp(
  r'\b(impression|conclusion|conclusions|conclusioni|result|results|esito|diagnosis|verdict|final)\b',
  caseSensitive: false,
);

Map<String, dynamic> _parseLabInIsolate(Map<String, String?> payload) {
  final documentId = (payload['document_id'] ?? 'local-doc').trim();
  final documentType = (payload['document_type'] ?? '').trim().toLowerCase();
  final title = (payload['title'] ?? '').trim();
  final examDateIso = payload['exam_date_iso'];
  final text = (payload['text'] ?? '').trim();

  if (text.isEmpty) {
    return _emptyPayload();
  }

  final isLabDocument = documentType == 'lab_report';
  if (!isLabDocument && !_looksLikeLabText(text)) {
    return _emptyPayload();
  }

  final lines = text.split(RegExp(r'[\r\n]+'));
  final results = <Map<String, dynamic>>[];
  final seenRows = <String>{};

  for (final rawLine in lines) {
    final line = _normalizeLine(rawLine);
    if (line == null) {
      continue;
    }

    final parsedRow = _parseLabLine(line);
    if (parsedRow == null) {
      continue;
    }

    final dedupeKey =
        '${parsedRow['analyte_name']}|${parsedRow['value']}|${parsedRow['unit'] ?? ''}'
            .toLowerCase();
    if (!seenRows.add(dedupeKey)) {
      continue;
    }

    parsedRow['id'] = 'local-lab-result-$documentId-${results.length + 1}';
    results.add(parsedRow);
    if (results.length >= 160) {
      break;
    }
  }

  if (results.isEmpty) {
    return _emptyPayload();
  }

  final confidence = _averageConfidence(results);
  final panel = <String, dynamic>{
    'id': 'local-lab-panel-$documentId-1',
    'panel_name': title.isEmpty ? 'Local lab panel' : title,
    'panel_date': examDateIso,
    'confidence_score': confidence,
    'results': results,
  };

  return <String, dynamic>{
    'parsed_status': 'parsed',
    'parsing_confidence': confidence,
    'processed_at': DateTime.now().toUtc().toIso8601String(),
    'lab_panels': <Map<String, dynamic>>[panel],
    'imaging_reports': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _parseImagingInIsolate(Map<String, String?> payload) {
  final documentId = (payload['document_id'] ?? 'local-doc').trim();
  final documentType = (payload['document_type'] ?? '').trim().toLowerCase();
  final title = (payload['title'] ?? '').trim();
  final examDateIso = payload['exam_date_iso'];
  final text = (payload['text'] ?? '').trim();

  if (text.isEmpty) {
    return _emptyPayload();
  }

  if (!_isImagingDocumentType(documentType) && !_looksLikeImagingText(text)) {
    return _emptyPayload();
  }

  final impression = _extractImpression(text);
  final examType = _extractImagingExamType(title: title, text: text);
  final bodyPart = _extractImagingBodyPart(title: title, text: text);
  final confidence = _resolveImagingConfidence(
    hasImpression: impression != null && impression.isNotEmpty,
    hasExamType: examType != null && examType.isNotEmpty,
    hasBodyPart: bodyPart != null && bodyPart.isNotEmpty,
  );

  final report = <String, dynamic>{
    'id': 'local-imaging-report-$documentId-1',
    'exam_type': examType,
    'body_part': bodyPart,
    'report_text': text,
    'impression': impression,
    'document_title': title.isEmpty ? 'Local imaging report' : title,
    'exam_date': examDateIso,
    'confidence_score': confidence,
  };

  return <String, dynamic>{
    'parsed_status': 'parsed',
    'parsing_confidence': confidence,
    'processed_at': DateTime.now().toUtc().toIso8601String(),
    'lab_panels': <Map<String, dynamic>>[],
    'imaging_reports': <Map<String, dynamic>>[report],
  };
}

Map<String, dynamic> _emptyPayload() {
  return <String, dynamic>{
    'parsed_status': 'local_only',
    'parsing_confidence': null,
    'processed_at': null,
    'lab_panels': <Map<String, dynamic>>[],
    'imaging_reports': <Map<String, dynamic>>[],
  };
}

bool _looksLikeLabText(String text) {
  final normalized = text.toLowerCase();
  if (_labKeywordPattern.hasMatch(normalized)) {
    return true;
  }

  final hasReference =
      _rangePattern.hasMatch(normalized) ||
      _thresholdPattern.hasMatch(normalized);
  if (!hasReference) {
    return false;
  }

  var informativeRows = 0;
  for (final line in normalized.split(RegExp(r'[\r\n]+'))) {
    if (_lettersPattern.hasMatch(line) && _numberPattern.hasMatch(line)) {
      informativeRows += 1;
      if (informativeRows >= 2) {
        return true;
      }
    }
  }
  return false;
}

String? _normalizeLine(String rawLine) {
  var line = rawLine.replaceAll('\t', ' ');
  line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (line.length < 4) {
    return null;
  }
  if (!_lettersPattern.hasMatch(line) || !_numberPattern.hasMatch(line)) {
    return null;
  }

  final lowered = line.toLowerCase();
  if (lowered.startsWith('range') || lowered.startsWith('reference')) {
    return null;
  }
  return line;
}

Map<String, dynamic>? _parseLabLine(String line) {
  final rangeMatch = _rangePattern.firstMatch(line);
  final thresholdMatch = _thresholdPattern.firstMatch(line);

  int? referenceStart;
  double? refMin;
  double? refMax;

  if (rangeMatch != null) {
    referenceStart = rangeMatch.start;
    refMin = _toDouble(rangeMatch.group(1));
    refMax = _toDouble(rangeMatch.group(2));
    if (refMin != null && refMax != null && refMin > refMax) {
      final swap = refMin;
      refMin = refMax;
      refMax = swap;
    }
  } else if (thresholdMatch != null) {
    referenceStart = thresholdMatch.start;
    final thresholdValue = _toDouble(thresholdMatch.group(2));
    final op = thresholdMatch.group(1);
    if (thresholdValue != null && op != null) {
      if (op.contains('<')) {
        refMax = thresholdValue;
      } else if (op.contains('>')) {
        refMin = thresholdValue;
      }
    }
  }

  final numberMatches = _numberPattern.allMatches(line).toList(growable: false);
  if (numberMatches.isEmpty) {
    return null;
  }

  RegExpMatch? valueMatch;
  if (referenceStart != null) {
    for (final candidate in numberMatches.reversed) {
      if (candidate.start < referenceStart &&
          _isLikelyMeasurementNumber(line, candidate)) {
        valueMatch = candidate;
        break;
      }
    }
  }
  valueMatch ??= numberMatches.firstWhere(
    (candidate) => _isLikelyMeasurementNumber(line, candidate),
    orElse: () => numberMatches.first,
  );

  final analyte = _normalizeAnalyte(line.substring(0, valueMatch.start));
  if (analyte == null) {
    return null;
  }

  final valueText = valueMatch.group(0)!;
  final numericValue = _toDouble(valueText);
  final flagToken = _extractFlagToken(line);
  final abnormalFlag = _resolveAbnormalFlag(
    flagToken: flagToken,
    numericValue: numericValue,
    refMin: refMin,
    refMax: refMax,
  );
  final unit = _extractUnit(
    line,
    valueEnd: valueMatch.end,
    referenceStart: referenceStart,
  );
  final confidence = _resolveConfidence(
    hasReference: refMin != null || refMax != null,
    hasFlag: flagToken != null,
  );

  return <String, dynamic>{
    'analyte_name': analyte,
    'value': valueText,
    if (unit != null) 'unit': unit,
    if (refMin != null) 'ref_min': refMin,
    if (refMax != null) 'ref_max': refMax,
    if (abnormalFlag != null) 'abnormal_flag': abnormalFlag,
    'confidence_score': confidence,
  };
}

String? _normalizeAnalyte(String raw) {
  var analyte = raw.trim();
  analyte = analyte.replaceAll(RegExp(r'^[\-:*]+|[\-:*]+$'), '').trim();
  analyte = analyte.replaceAll(RegExp(r'\s+'), ' ');
  if (analyte.isEmpty || analyte.length < 2) {
    return null;
  }
  if (RegExp(r'^\d').hasMatch(analyte)) {
    return null;
  }
  if (!_lettersPattern.hasMatch(analyte)) {
    return null;
  }

  final lowered = analyte.toLowerCase();
  if (lowered == 'analyte' ||
      lowered.startsWith('value') ||
      lowered.startsWith('range') ||
      lowered.startsWith('reference')) {
    return null;
  }

  return analyte;
}

String? _extractUnit(
  String line, {
  required int valueEnd,
  int? referenceStart,
}) {
  var end = referenceStart ?? line.length;
  final flagMatch = _flagPattern.firstMatch(line);
  if (flagMatch != null &&
      flagMatch.start > valueEnd &&
      flagMatch.start < end) {
    end = flagMatch.start;
  }
  if (end <= valueEnd) {
    return null;
  }

  var segment = line.substring(valueEnd, end).trim();
  segment = segment.replaceAll(RegExp(r'^[=:;,\-]+|[=:;,\-]+$'), '').trim();
  if (segment.isEmpty || !_unitPattern.hasMatch(segment)) {
    return null;
  }

  final chunks = segment
      .split(' ')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (chunks.isEmpty) {
    return null;
  }

  final candidate = chunks.first;
  if (candidate.length > 24 || !_unitPattern.hasMatch(candidate)) {
    return null;
  }
  return candidate;
}

String? _extractFlagToken(String line) {
  final match = _flagPattern.firstMatch(line);
  return match?.group(1)?.toUpperCase();
}

bool? _resolveAbnormalFlag({
  required String? flagToken,
  required double? numericValue,
  required double? refMin,
  required double? refMax,
}) {
  if (flagToken != null) {
    if (flagToken == 'H' ||
        flagToken == 'L' ||
        flagToken == 'HIGH' ||
        flagToken == 'LOW') {
      return true;
    }
    if (flagToken == 'N' || flagToken == 'NORMAL') {
      return false;
    }
  }

  if (numericValue == null) {
    return null;
  }

  var compared = false;
  var abnormal = false;
  if (refMin != null) {
    compared = true;
    if (numericValue < refMin) {
      abnormal = true;
    }
  }
  if (refMax != null) {
    compared = true;
    if (numericValue > refMax) {
      abnormal = true;
    }
  }
  return compared ? abnormal : null;
}

double _resolveConfidence({required bool hasReference, required bool hasFlag}) {
  if (hasReference) {
    return 0.92;
  }
  if (hasFlag) {
    return 0.82;
  }
  return 0.72;
}

double _averageConfidence(List<Map<String, dynamic>> results) {
  var total = 0.0;
  for (final result in results) {
    total += (result['confidence_score'] as num?)?.toDouble() ?? 0.72;
  }
  final average = total / results.length;
  return (average.clamp(0.0, 1.0) as num).toDouble();
}

bool _isLikelyMeasurementNumber(String line, RegExpMatch match) {
  if (match.start > 0) {
    final previousChar = line[match.start - 1];
    if (RegExp(r'[A-Za-z/^]').hasMatch(previousChar)) {
      return false;
    }
  }

  if (match.end < line.length) {
    final nextChar = line[match.end];
    if (RegExp(r'[A-Za-z]').hasMatch(nextChar)) {
      return false;
    }
  }

  return true;
}

bool _isImagingDocumentType(String documentType) {
  return documentType == 'imaging_report' ||
      documentType == 'prevention_report' ||
      documentType == 'specialist_visit';
}

bool _looksLikeImagingText(String text) {
  final normalized = text.toLowerCase();
  return _imagingKeywordPattern.hasMatch(normalized) ||
      _impressionMarkerPattern.hasMatch(normalized);
}

String? _extractImagingExamType({required String title, required String text}) {
  final fromTitle = _firstKeywordMatch(title, const [
    'ultrasound',
    'ecografia',
    'radiology',
    'rx',
    'x-ray',
    'mammography',
    'mri',
    'ct',
    'rm',
    'scan',
    'tomography',
  ]);
  if (fromTitle != null) {
    return fromTitle;
  }

  return _firstKeywordMatch(text, const [
    'ultrasound',
    'ecografia',
    'radiology',
    'radiographic',
    'x-ray',
    'rx',
    'mammography',
    'mammografia',
    'mri',
    'ct',
    'rm',
    'tomography',
    'scan',
  ]);
}

String? _extractImagingBodyPart({required String title, required String text}) {
  final combined = '$title\n$text'.toLowerCase();
  const candidates = <String>[
    'abdomen',
    'abdominal',
    'addome',
    'chest',
    'thorax',
    'torace',
    'breast',
    'mammary',
    'mammella',
    'thyroid',
    'tiroide',
    'pelvis',
    'pelvi',
    'hip',
    'shoulder',
    'knee',
    'neck',
    'collo',
    'heart',
    'cardiac',
    'brain',
    'cranial',
  ];

  for (final candidate in candidates) {
    if (combined.contains(candidate)) {
      return candidate;
    }
  }
  return null;
}

String? _extractImpression(String text) {
  final lines = text.split(RegExp(r'[\r\n]+'));
  final buffer = StringBuffer();
  var collecting = false;
  for (final rawLine in lines) {
    final line = rawLine.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isEmpty) {
      continue;
    }
    final lowered = line.toLowerCase();
    final marker = _impressionLineMarker(lowered);
    if (marker != null) {
      collecting = true;
      final afterMarker = line
          .substring(marker.length)
          .replaceFirst(RegExp(r'^[\s:=-]+'), '');
      if (afterMarker.isNotEmpty) {
        buffer.writeln(afterMarker);
      }
      continue;
    }
    if (collecting) {
      if (_looksLikeSectionBoundary(lowered)) {
        break;
      }
      buffer.writeln(line);
    }
  }

  final impression = buffer.toString().trim();
  return impression.isEmpty ? null : impression;
}

String? _impressionLineMarker(String loweredLine) {
  const markers = <String>[
    'impression',
    'conclusion',
    'conclusions',
    'conclusioni',
    'esito',
    'result',
    'results',
    'final',
  ];
  for (final marker in markers) {
    if (loweredLine.startsWith(marker)) {
      return marker;
    }
  }
  return null;
}

bool _looksLikeSectionBoundary(String loweredLine) {
  const boundaries = <String>[
    'recommend',
    'findings',
    'description',
    'diagnosis',
    'therapy',
    'follow-up',
    'follow up',
  ];
  for (final boundary in boundaries) {
    if (loweredLine.startsWith(boundary)) {
      return true;
    }
  }
  return _impressionMarkerPattern.hasMatch(loweredLine) &&
      _impressionLineMarker(loweredLine)!.isNotEmpty;
}

String? _firstKeywordMatch(String text, List<String> keywords) {
  final lowered = text.toLowerCase();
  for (final keyword in keywords) {
    if (lowered.contains(keyword)) {
      return keyword;
    }
  }
  return null;
}

double _resolveImagingConfidence({
  required bool hasImpression,
  required bool hasExamType,
  required bool hasBodyPart,
}) {
  var confidence = 0.68;
  if (hasExamType) {
    confidence += 0.12;
  }
  if (hasBodyPart) {
    confidence += 0.1;
  }
  if (hasImpression) {
    confidence += 0.1;
  }
  return confidence.clamp(0.0, 1.0).toDouble();
}

double? _toDouble(String? value) {
  if (value == null) {
    return null;
  }
  return double.tryParse(value.replaceAll(',', '.'));
}
