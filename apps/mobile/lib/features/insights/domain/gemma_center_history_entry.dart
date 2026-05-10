import 'package:clindiary/app/core/localization/app_language.dart';

class GemmaCenterHistoryEntry {
  const GemmaCenterHistoryEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.response,
    required this.createdAt,
    this.languageCode = 'en',
    this.prompt,
    this.referenceDate,
    this.documentId,
    this.documentTitle,
  });

  final String id;
  final String kind;
  final String title;
  final String response;
  final DateTime createdAt;
  final String languageCode;
  final String? prompt;
  final DateTime? referenceDate;
  final String? documentId;
  final String? documentTitle;

  factory GemmaCenterHistoryEntry.question({
    required String question,
    required String response,
    required DateTime referenceDate,
    String languageCode = 'en',
    DateTime? createdAt,
  }) {
    final normalizedQuestion = question.trim();
    return GemmaCenterHistoryEntry(
      id: _buildId('question'),
      kind: 'question',
      title: normalizedQuestion.isEmpty
          ? (isItalianLanguageCode(languageCode)
                ? 'Domanda clinica'
                : 'Clinical question')
          : normalizedQuestion,
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      languageCode: languageCode,
      prompt: normalizedQuestion,
      referenceDate: referenceDate.toUtc(),
    );
  }

  factory GemmaCenterHistoryEntry.trend({
    required String response,
    required DateTime referenceDate,
    String languageCode = 'en',
    DateTime? createdAt,
  }) {
    return GemmaCenterHistoryEntry(
      id: _buildId('trend'),
      kind: 'trend',
      title: isItalianLanguageCode(languageCode)
          ? 'Analisi dell andamento'
          : 'Trend analysis',
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      languageCode: languageCode,
      referenceDate: referenceDate.toUtc(),
    );
  }

  factory GemmaCenterHistoryEntry.preVisit({
    required String response,
    required DateTime referenceDate,
    String languageCode = 'en',
    DateTime? createdAt,
  }) {
    return GemmaCenterHistoryEntry(
      id: _buildId('pre_visit'),
      kind: 'pre_visit',
      title: isItalianLanguageCode(languageCode)
          ? 'Nota pre visita'
          : 'Pre-visit brief',
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      languageCode: languageCode,
      referenceDate: referenceDate.toUtc(),
    );
  }

  factory GemmaCenterHistoryEntry.dailyRecap({
    required String response,
    required DateTime referenceDate,
    String languageCode = 'en',
    DateTime? createdAt,
  }) {
    return GemmaCenterHistoryEntry(
      id: _buildId('daily_recap'),
      kind: 'daily_recap',
      title: isItalianLanguageCode(languageCode)
          ? 'Riepilogo giornaliero'
          : 'Daily recap',
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      languageCode: languageCode,
      referenceDate: referenceDate.toUtc(),
    );
  }

  factory GemmaCenterHistoryEntry.documentSummary({
    required String response,
    required String documentId,
    required String documentTitle,
    required DateTime referenceDate,
    String languageCode = 'en',
    DateTime? createdAt,
  }) {
    return GemmaCenterHistoryEntry(
      id: _buildId('document_summary'),
      kind: 'document_summary',
      title: documentTitle.trim().isEmpty
          ? (isItalianLanguageCode(languageCode)
                ? 'Riepilogo documento'
                : 'Document summary')
          : (isItalianLanguageCode(languageCode)
                ? 'Riepilogo: ${documentTitle.trim()}'
                : 'Summary: ${documentTitle.trim()}'),
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      languageCode: languageCode,
      referenceDate: referenceDate.toUtc(),
      documentId: documentId.trim(),
      documentTitle: documentTitle.trim(),
    );
  }

  GemmaCenterHistoryEntry copyWith({String? languageCode}) {
    return GemmaCenterHistoryEntry(
      id: id,
      kind: kind,
      title: title,
      response: response,
      createdAt: createdAt,
      languageCode: languageCode ?? this.languageCode,
      prompt: prompt,
      referenceDate: referenceDate,
      documentId: documentId,
      documentTitle: documentTitle,
    );
  }

  String get kindLabel {
    switch (kind) {
      case 'question':
        return isItalianLanguageCode(languageCode) ? 'Domanda' : 'Question';
      case 'trend':
        return isItalianLanguageCode(languageCode) ? 'Andamento' : 'Trend';
      case 'pre_visit':
        return isItalianLanguageCode(languageCode) ? 'Pre visita' : 'Pre-visit';
      case 'document_summary':
        return isItalianLanguageCode(languageCode) ? 'Documento' : 'Document';
      case 'daily_recap':
        return isItalianLanguageCode(languageCode)
            ? 'Riepilogo giornaliero'
            : 'Daily recap';
      default:
        return 'Gemma';
    }
  }

  String get subtitle {
    final parts = <String>[];
    if (documentTitle != null && documentTitle!.trim().isNotEmpty) {
      parts.add(documentTitle!.trim());
    }
    parts.add(kindLabel);
    if (referenceDate != null) {
      parts.add(referenceDate!.toIso8601String().split('T').first);
    }
    return parts.join(' • ');
  }

  String get responsePreview {
    final normalized = response
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.length <= 180) {
      return normalized;
    }
    return '${normalized.substring(0, 177).trimRight()}...';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'kind': kind,
      'title': title,
      'response': response,
      'created_at': createdAt.toIso8601String(),
      'language_code': languageCode,
      'prompt': prompt,
      'reference_date': referenceDate?.toIso8601String(),
      'document_id': documentId,
      'document_title': documentTitle,
    };
  }

  factory GemmaCenterHistoryEntry.fromJson(Map<String, dynamic> json) {
    final normalizedKind = _normalizeKind(json['kind']?.toString());
    final rawTitle = json['title']?.toString() ?? '';
    return GemmaCenterHistoryEntry(
      id: json['id']?.toString() ?? _buildId('legacy'),
      kind: normalizedKind,
      title: _normalizeTitle(normalizedKind, rawTitle),
      response: json['response']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['created_at']?.toString() ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      languageCode: json['language_code']?.toString() ?? 'en',
      prompt: json['prompt']?.toString(),
      referenceDate: json['reference_date'] == null
          ? null
          : DateTime.parse(json['reference_date'].toString()).toUtc(),
      documentId: json['document_id']?.toString(),
      documentTitle: json['document_title']?.toString(),
    );
  }

  static bool needsEnglishMigration(Map<String, dynamic> json) {
    final kind = _normalizeKind(json['kind']?.toString());
    final title = json['title']?.toString() ?? '';
    return kind != (json['kind']?.toString() ?? 'question') ||
        _normalizeTitle(kind, title) != title;
  }

  static String _normalizeKind(String? rawKind) {
    switch (rawKind?.trim().toLowerCase()) {
      case 'question':
        return 'question';
      case 'trend':
      case 'trend_explanation':
        return 'trend';
      case 'pre_visit':
      case 'pre-visit':
      case 'pre_visit_brief':
        return 'pre_visit';
      case 'document_summary':
      case 'document':
        return 'document_summary';
      default:
        return rawKind?.trim().isNotEmpty == true
            ? rawKind!.trim()
            : 'question';
    }
  }

  static String _normalizeTitle(String kind, String rawTitle) {
    final title = rawTitle.trim();
    if (title.isEmpty) {
      switch (kind) {
        case 'question':
          return 'Clinical question';
        case 'trend':
          return 'Trend analysis';
        case 'pre_visit':
          return 'Pre-visit brief';
        case 'document_summary':
          return 'Document summary';
        case 'daily_recap':
          return 'Daily recap';
        default:
          return 'Gemma';
      }
    }

    if (kind == 'document_summary' && title.startsWith('Summary: ')) {
      return title;
    }
    return title;
  }

  static String _buildId(String kind) {
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$kind';
  }
}
