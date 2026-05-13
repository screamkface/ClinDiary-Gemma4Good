import 'package:clindiary/features/documents/domain/clinical_document.dart';

class DocumentQueryHistoryEntry {
  const DocumentQueryHistoryEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.citations,
    required this.modelName,
    required this.providerName,
    required this.createdAt,
    this.embeddingModelName,
    this.retrievedChunks = 0,
    this.retrievedDocuments = 0,
    this.searchScopeLabel = 'Entire archive',
    this.languageCode = 'en',
  });

  final String id;
  final String question;
  final String answer;
  final List<DocumentQueryCitation> citations;
  final String modelName;
  final String providerName;
  final DateTime createdAt;
  final String? embeddingModelName;
  final int retrievedChunks;
  final int retrievedDocuments;
  final String searchScopeLabel;
  final String languageCode;

  factory DocumentQueryHistoryEntry.fromQueryResult({
    required String question,
    required DocumentQueryResult result,
    DateTime? createdAt,
  }) {
    return DocumentQueryHistoryEntry(
      id: _buildId(),
      question: question.trim(),
      answer: result.answer.trim(),
      citations: result.citations,
      modelName: result.modelName,
      providerName: result.providerName,
      embeddingModelName: result.embeddingModelName,
      retrievedChunks: result.retrievedChunks,
      retrievedDocuments: result.retrievedDocuments,
      searchScopeLabel: result.searchScopeLabel,
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
    );
  }

  DocumentQueryHistoryEntry copyWith({String? languageCode}) {
    return DocumentQueryHistoryEntry(
      id: id,
      question: question,
      answer: answer,
      citations: citations,
      modelName: modelName,
      providerName: providerName,
      createdAt: createdAt,
      embeddingModelName: embeddingModelName,
      retrievedChunks: retrievedChunks,
      retrievedDocuments: retrievedDocuments,
      searchScopeLabel: searchScopeLabel,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  DocumentQueryResult toQueryResult() {
    return DocumentQueryResult(
      answer: answer,
      citations: citations,
      providerName: providerName,
      modelName: modelName,
      embeddingModelName: embeddingModelName,
      rerankerModelName: null,
      retrievedChunks: retrievedChunks > 0 ? retrievedChunks : citations.length,
      retrievedDocuments: retrievedDocuments,
      searchScopeLabel: searchScopeLabel,
      coverageNote: null,
      usedFallback: false,
    );
  }

  static String _buildId([String? prefix]) {
    final namespace = prefix ?? 'document-query';
    return '$namespace-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'question': question,
    'answer': answer,
    'citations': citations.map((item) => item.toJson()).toList(),
    'model_name': modelName,
    'provider_name': providerName,
    'embedding_model_name': embeddingModelName,
    'retrieved_chunks': retrievedChunks,
    'retrieved_documents': retrievedDocuments,
    'search_scope_label': searchScopeLabel,
    'language_code': languageCode,
    'created_at': createdAt.toIso8601String(),
  };

  factory DocumentQueryHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DocumentQueryHistoryEntry(
        id: json['id'].toString(),
        question: json['question'].toString(),
        answer: json['answer'].toString(),
        citations: (json['citations'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  DocumentQueryCitation.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        modelName: json['model_name'].toString(),
        providerName: json['provider_name'].toString(),
        embeddingModelName: json['embedding_model_name'] as String?,
        retrievedChunks: json['retrieved_chunks'] as int? ?? 0,
        retrievedDocuments: json['retrieved_documents'] as int? ?? 0,
        searchScopeLabel:
            json['search_scope_label']?.toString() ?? 'Entire archive',
        languageCode: json['language_code']?.toString() ?? 'en',
        createdAt: DateTime.parse(json['created_at'].toString()).toUtc(),
      );

  @override
  String toString() =>
      'DocumentQueryHistoryEntry($id, question: $question, modelName: $modelName)';
}
