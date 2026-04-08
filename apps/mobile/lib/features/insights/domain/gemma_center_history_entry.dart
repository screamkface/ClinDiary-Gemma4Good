class GemmaCenterHistoryEntry {
  const GemmaCenterHistoryEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.response,
    required this.createdAt,
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
  final String? prompt;
  final DateTime? referenceDate;
  final String? documentId;
  final String? documentTitle;

  factory GemmaCenterHistoryEntry.question({
    required String question,
    required String response,
    required DateTime referenceDate,
    DateTime? createdAt,
  }) {
    final normalizedQuestion = question.trim();
    return GemmaCenterHistoryEntry(
      id: _buildId('question'),
      kind: 'question',
      title: normalizedQuestion.isEmpty ? 'Domanda clinica' : normalizedQuestion,
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      prompt: normalizedQuestion,
      referenceDate: referenceDate.toUtc(),
    );
  }

  factory GemmaCenterHistoryEntry.trend({
    required String response,
    required DateTime referenceDate,
    DateTime? createdAt,
  }) {
    return GemmaCenterHistoryEntry(
      id: _buildId('trend'),
      kind: 'trend',
      title: 'Spiegazione andamento',
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      referenceDate: referenceDate.toUtc(),
    );
  }

  factory GemmaCenterHistoryEntry.preVisit({
    required String response,
    required DateTime referenceDate,
    DateTime? createdAt,
  }) {
    return GemmaCenterHistoryEntry(
      id: _buildId('pre_visit'),
      kind: 'pre_visit',
      title: 'Scheda pre-visita',
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      referenceDate: referenceDate.toUtc(),
    );
  }

  factory GemmaCenterHistoryEntry.documentSummary({
    required String response,
    required String documentId,
    required String documentTitle,
    required DateTime referenceDate,
    DateTime? createdAt,
  }) {
    return GemmaCenterHistoryEntry(
      id: _buildId('document_summary'),
      kind: 'document_summary',
      title: documentTitle.trim().isEmpty
          ? 'Riassunto documento'
          : 'Riassunto: ${documentTitle.trim()}',
      response: response.trim(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      referenceDate: referenceDate.toUtc(),
      documentId: documentId.trim(),
      documentTitle: documentTitle.trim(),
    );
  }

  String get kindLabel {
    switch (kind) {
      case 'question':
        return 'Domanda';
      case 'trend':
        return 'Andamento';
      case 'pre_visit':
        return 'Pre-visita';
      case 'document_summary':
        return 'Documento';
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
    final normalized = response.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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
      'prompt': prompt,
      'reference_date': referenceDate?.toIso8601String(),
      'document_id': documentId,
      'document_title': documentTitle,
    };
  }

  factory GemmaCenterHistoryEntry.fromJson(Map<String, dynamic> json) {
    return GemmaCenterHistoryEntry(
      id: json['id']?.toString() ?? _buildId('legacy'),
      kind: json['kind']?.toString() ?? 'question',
      title: json['title']?.toString() ?? 'Gemma',
      response: json['response']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      prompt: json['prompt']?.toString(),
      referenceDate: json['reference_date'] == null
          ? null
          : DateTime.parse(json['reference_date'].toString()).toUtc(),
      documentId: json['document_id']?.toString(),
      documentTitle: json['document_title']?.toString(),
    );
  }

  static String _buildId(String kind) {
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$kind';
  }
}