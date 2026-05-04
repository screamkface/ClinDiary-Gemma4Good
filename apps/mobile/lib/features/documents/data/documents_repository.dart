import 'dart:convert';
import 'dart:math';

import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';

class DocumentsRepository {
  DocumentsRepository({
    required LocalDatabase localDatabase,
    OnDeviceAiService? onDeviceAiService,
    LocalDocumentVaultService? localVaultService,
  }) : _localDatabase = localDatabase,
       _onDeviceAiService = onDeviceAiService ?? OnDeviceAiService(),
       _localVaultService = localVaultService ?? LocalDocumentVaultService();

  final LocalDatabase _localDatabase;
  final OnDeviceAiService _onDeviceAiService;
  final LocalDocumentVaultService _localVaultService;

  Future<List<ClinicalDocumentSummary>> fetchDocuments() async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchDocumentsForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<ClinicalDocumentDetail> fetchDocumentDetail(String documentId) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchDocumentDetailForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<DocumentArchiveView> fetchArchive({
    String? folderId,
    String? query,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchArchiveForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      folderId: folderId,
      query: query,
    );
  }

  Future<List<DocumentFolderItem>> fetchFolders() async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchFoldersForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<ClinicalDocumentSummary> uploadDocument({
    required SelectedUploadDocument file,
    required Map<String, String> fields,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.uploadDocumentForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      file: file,
      fields: fields,
    );
  }

  Future<DocumentFolderItem> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.createFolderForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      name: name,
      parentFolderId: parentFolderId,
    );
  }

  Future<DocumentQueryResult> queryDocuments({
    required String question,
    String? folderId,
    int? topK,
  }) async {
    return _queryLocalDocuments(
      question: question,
      folderId: folderId,
      topK: topK,
    );
  }

  Future<int> reindexDocuments() async {
    final scope = await _resolveLocalScope();
    final localDocuments = await _localVaultService.fetchDocumentsForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
    return localDocuments.length;
  }

  Future<int> reindexDocument(String documentId) async {
    return 1;
  }

  Future<ClinicalDocumentDetail> processDocument(String documentId) async {
    return fetchDocumentDetail(documentId);
  }

  Future<ClinicalDocumentDetail> submitManualReview(
    String documentId,
    DocumentManualReviewInput input,
  ) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.submitManualReviewForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      input: input,
    );
  }

  Future<ClinicalDocumentDetail> updateDocumentContextStatus(
    String documentId, {
    required String contextStatus,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.updateDocumentContextStatusForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      contextStatus: contextStatus,
    );
  }

  Future<void> deleteDocument(String documentId) async {
    final scope = await _resolveLocalScope();
    await _localVaultService.deleteDocumentForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<ClinicalDocumentDetail> moveDocument(
    String documentId, {
    String? folderId,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.moveDocumentForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      folderId: folderId,
    );
  }

  Future<String> prepareLocalViewerFile(String documentId) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.prepareViewerFileForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<DocumentQueryResult> _queryLocalDocuments({
    required String question,
    String? folderId,
    int? topK,
  }) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw Exception('Please enter a question before searching documents.');
    }

    final scope = await _resolveLocalScope();
    final archive = await _localVaultService.fetchArchiveForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      folderId: folderId,
      query: null,
    );

    final localDocuments = archive.documents
        .where((item) => item.isLocal)
        .toList();
    if (localDocuments.isEmpty) {
      return DocumentQueryResult(
        answer:
            'No local documents are available yet. Import at least one file to use Document Q&A.',
        citations: const [],
        providerName: 'on_device_litertlm',
        modelName: 'gemma-4-E2B-it.litertlm',
        embeddingModelName: 'local-keyword-index',
        rerankerModelName: 'local-heuristic-ranker',
        retrievedChunks: 0,
        retrievedDocuments: 0,
        searchScopeLabel: folderId == null
            ? 'Entire local archive'
            : 'Selected local folder',
        coverageNote: 'No matching local documents found.',
        usedFallback: true,
      );
    }

    final questionEmbedding = await _onDeviceAiService.generateEmbedding(text: normalizedQuestion).catchError((_) => <double>[]);

    final ranked = <_LocalQueryCandidate>[];
    for (final summary in localDocuments) {
      final detail = await fetchDocumentDetail(summary.id);
      final candidate = await _buildLocalQueryCandidate(
        summary,
        detail,
        normalizedQuestion,
        questionEmbedding,
      );
      if (candidate.score > 0) {
        ranked.add(candidate);
      }
    }

    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      return b.summary.uploadDate.compareTo(a.summary.uploadDate);
    });

    final limited = ranked.take((topK ?? 3).clamp(1, 8)).toList();
    if (limited.isEmpty) {
      return DocumentQueryResult(
        answer:
            'I could not find relevant information in local documents for this question. Try adding key terms (exam name, date, analyte, or symptom).',
        citations: const [],
        providerName: 'on_device_litertlm',
        modelName: 'gemma-4-E2B-it.litertlm',
        embeddingModelName: 'on_device_mediapipe',
        rerankerModelName: 'local-semantic-ranker',
        retrievedChunks: 0,
        retrievedDocuments: 0,
        searchScopeLabel: folderId == null
            ? 'Entire local archive'
            : 'Selected local folder',
        coverageNote: 'No relevant excerpts were found in local documents.',
        usedFallback: true,
      );
    }

    final citations = limited
        .map(
          (candidate) => DocumentQueryCitation(
            documentId: candidate.summary.id,
            documentTitle: candidate.summary.title,
            documentType: candidate.summary.documentType,
            folderName: candidate.summary.folderName,
            examDate: candidate.summary.examDate,
            chunkKind: candidate.chunkKind,
            chunkLabel: candidate.chunkLabel,
            excerpt: candidate.excerpt,
            score: candidate.score,
            viewerUrl: candidate.detail.viewerUrl,
          ),
        )
        .toList();

    final answer = await _generateLocalQueryAnswer(
      question: normalizedQuestion,
      candidates: limited,
    );

    return DocumentQueryResult(
      answer: answer,
      citations: citations,
      providerName: 'on_device_litertlm',
      modelName: 'gemma-4-E2B-it.litertlm',
      embeddingModelName: 'on_device_mediapipe',
      rerankerModelName: 'local-semantic-ranker',
      retrievedChunks: limited.length,
      retrievedDocuments: limited.map((item) => item.summary.id).toSet().length,
      searchScopeLabel: folderId == null
          ? 'Entire local archive'
          : 'Selected local folder',
      coverageNote: 'Answer generated from local encrypted document snippets.',
      usedFallback: false,
    );
  }

  Future<List<double>> _getDocumentEmbedding(ClinicalDocumentDetail detail) async {
    final cacheKey = 'doc_embed_${detail.id}';
    final cached = await _localDatabase.readCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List<dynamic>;
        return decoded.map((e) => (e as num).toDouble()).toList();
      } catch (_) {}
    }
    
    final fragments = <String>[
      detail.title,
      detail.documentType,
      if (detail.source != null) detail.source!,
      if (detail.ocrText != null && detail.ocrText!.trim().isNotEmpty) detail.ocrText!,
      for (final panel in detail.labPanels)
        '${panel.panelName} ${panel.results.map((item) => '${item.analyteName} ${item.value}${item.unit == null ? '' : ' ${item.unit}'}').join(' ')}',
      for (final report in detail.imagingReports)
        '${report.examType ?? 'imaging'} ${report.bodyPart ?? ''} ${report.impression ?? report.reportText}',
    ];
    final corpus = fragments.join(' ');
    
    try {
      final embedding = await _onDeviceAiService.generateEmbedding(text: corpus);
      await _localDatabase.putCache(key: cacheKey, payload: jsonEncode(embedding));
      return embedding;
    } catch (_) {
      return [];
    }
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  Future<_LocalQueryCandidate> _buildLocalQueryCandidate(
    ClinicalDocumentSummary summary,
    ClinicalDocumentDetail detail,
    String question,
    List<double> questionEmbedding,
  ) async {
    var score = 0.0;
    
    // Semantic search
    if (questionEmbedding.isNotEmpty) {
      final documentEmbedding = await _getDocumentEmbedding(detail);
      score = _cosineSimilarity(questionEmbedding, documentEmbedding);
    } else {
      // Fallback: Keyword search
      final fragments = <String>[
        summary.title,
        summary.documentType,
        if (summary.source != null) summary.source!,
        if (detail.ocrText != null && detail.ocrText!.trim().isNotEmpty)
          detail.ocrText!,
        for (final panel in detail.labPanels)
          '${panel.panelName} ${panel.results.map((item) => '${item.analyteName} ${item.value}${item.unit == null ? '' : ' ${item.unit}'}').join(' ')}',
        for (final report in detail.imagingReports)
          '${report.examType ?? 'imaging'} ${report.bodyPart ?? ''} ${report.impression ?? report.reportText}',
      ];

      final corpus = fragments.join(' ').toLowerCase();
      final tokens = question
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .where((item) => item.trim().length >= 3)
          .toSet();

      for (final token in tokens) {
        if (corpus.contains(token)) {
          score += 1.0;
        }
      }
      
      if (summary.title.toLowerCase().contains(question.toLowerCase())) {
        score += 2.0;
      }
      if (detail.labPanels.isNotEmpty && question.toLowerCase().contains('lab')) {
        score += 0.8;
      }
      if (detail.imagingReports.isNotEmpty &&
          question.toLowerCase().contains('imaging')) {
        score += 0.8;
      }
    }

    final excerpt = _buildExcerpt(detail);
    return _LocalQueryCandidate(
      summary: summary,
      detail: detail,
      score: score,
      excerpt: excerpt,
      chunkKind: detail.labPanels.isNotEmpty
          ? 'lab_panel'
          : detail.imagingReports.isNotEmpty
          ? 'imaging_report'
          : 'ocr_text',
      chunkLabel: detail.labPanels.isNotEmpty
          ? detail.labPanels.first.panelName
          : detail.imagingReports.isNotEmpty
          ? detail.imagingReports.first.examType
          : 'Extracted text',
    );
  }

  Future<String> _generateLocalQueryAnswer({
    required String question,
    required List<_LocalQueryCandidate> candidates,
  }) async {
    final context = candidates
        .asMap()
        .entries
        .map(
          (entry) =>
              '[${entry.key + 1}] ${entry.value.summary.title}: ${entry.value.excerpt}',
        )
        .join('\n\n');

    final systemPrompt =
        'You are a careful clinical assistant. Use only the provided local document context. '
        'Do not invent data, and clearly mention uncertainty when information is incomplete.';
    final userPrompt =
        'Question: $question\n\n'
        'Local document context:\n$context\n\n'
        'Write a concise answer in English using plain text only.\n'
        'Do not use Markdown, LaTeX, \$, code fences, or special formatting markers.\n'
        'Use exactly these lines:\n'
        'Direct answer: ...\n'
        'Key findings: ...\n'
        'Caution: ...';

    try {
      return await _onDeviceAiService.generateText(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );
    } catch (_) {
      final top = candidates.first;
      return 'Based on local documents, the most relevant file is "${top.summary.title}". '
          'Key extracted evidence: ${top.excerpt}. '
          'Review the cited snippets for full context before making clinical decisions.';
    }
  }

  Future<_LocalVaultScope> _resolveLocalScope() async {
    final userId =
        await _localDatabase.readCache(activeUserIdCacheKey) ?? 'anonymous';
    final profileId = await _localDatabase.readCache(activeProfileIdCacheKey);
    return _LocalVaultScope(userId: userId, profileId: profileId);
  }

  bool _isLocalDocumentId(String documentId) =>
      documentId.startsWith('local-doc-');

  Future<List<ClinicalDocumentSummary>> _fetchReadOnlyCloudDocuments({
    String? query,
  }) async {
    try {
      final scope = await _resolveLocalScope();
      final documents = await _localVaultService.fetchDocumentsForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
      );
      final normalizedQuery = query?.trim().toLowerCase();
      if (normalizedQuery == null || normalizedQuery.isEmpty) {
        return documents;
      }
      return documents.where((document) {
        final haystack = [
          document.title,
          document.originalFilename,
          document.source,
          document.folderName,
          document.documentType,
        ].whereType<String>().join(' ').toLowerCase();
        return haystack.contains(normalizedQuery);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

}

class _LocalQueryCandidate {
  const _LocalQueryCandidate({
    required this.summary,
    required this.detail,
    required this.score,
    required this.excerpt,
    required this.chunkKind,
    required this.chunkLabel,
  });

  final ClinicalDocumentSummary summary;
  final ClinicalDocumentDetail detail;
  final double score;
  final String excerpt;
  final String chunkKind;
  final String? chunkLabel;
}

String _buildExcerpt(ClinicalDocumentDetail detail) {
  if (detail.labPanels.isNotEmpty) {
    final panel = detail.labPanels.first;
    final values = panel.results
        .take(3)
        .map((item) {
          final unit = item.unit == null ? '' : ' ${item.unit}';
          return '${item.analyteName}: ${item.value}$unit';
        })
        .join('; ');
    return '${panel.panelName}. $values';
  }

  if (detail.imagingReports.isNotEmpty) {
    final report = detail.imagingReports.first;
    final impression = report.impression?.trim();
    if (impression != null && impression.isNotEmpty) {
      return impression;
    }
    return report.reportText;
  }

  final ocrText = detail.ocrText?.trim();
  if (ocrText != null && ocrText.isNotEmpty) {
    return ocrText.length > 500 ? '${ocrText.substring(0, 500)}...' : ocrText;
  }

  return 'No extractable text available.';
}

class _LocalVaultScope {
  const _LocalVaultScope({required this.userId, required this.profileId});

  final String userId;
  final String? profileId;
}
