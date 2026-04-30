import 'dart:convert';
import 'dart:math';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';

enum _DocumentStorageMode { local, cloud }

class DocumentsRepository {
  DocumentsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
    AppConfig appConfig = defaultAppConfig,
    OnDeviceAiService? onDeviceAiService,
    LocalDocumentVaultService? localVaultService,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase,
       _appConfig = appConfig,
       _onDeviceAiService = onDeviceAiService ?? OnDeviceAiService(),
       _localVaultService = localVaultService ?? LocalDocumentVaultService();

  static const _documentsCacheKey = 'documents_list';
  static const _documentStorageModeCacheKey = 'document_storage_mode';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;
  final AppConfig _appConfig;
  final OnDeviceAiService _onDeviceAiService;
  final LocalDocumentVaultService _localVaultService;
  _DocumentStorageMode? _cachedStorageMode;

  Future<List<ClinicalDocumentSummary>> fetchDocuments() async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      return _localVaultService.fetchDocumentsForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
      );
    }
    return _fetchCloudDocuments();
  }

  Future<ClinicalDocumentDetail> fetchDocumentDetail(String documentId) async {
    if (_isLocalDocumentId(documentId)) {
      final scope = await _resolveLocalScope();
      return _localVaultService.fetchDocumentDetailForScope(
        documentId,
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
      );
    }

    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final cached = await _readCachedDocumentDetailJson(documentId);
      if (cached != null) {
        return ClinicalDocumentDetail.fromJson(cached);
      }
      throw ApiException(
        'Archived documents are read-only while local-only mode is active.',
        statusCode: 409,
      );
    }

    return _fetchCloudDocumentDetail(documentId);
  }

  Future<DocumentArchiveView> fetchArchive({
    String? folderId,
    String? query,
  }) async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      return _localVaultService.fetchArchiveForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
        folderId: folderId,
        query: query,
      );
    }
    return _fetchCloudArchive(folderId: folderId, query: query);
  }

  Future<List<DocumentFolderItem>> fetchFolders() async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      return _localVaultService.fetchFoldersForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
      );
    }
    return _fetchCloudFolders();
  }

  Future<ClinicalDocumentSummary> uploadDocument({
    required SelectedUploadDocument file,
    required Map<String, String> fields,
  }) async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      return _localVaultService.uploadDocumentForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
        file: file,
        fields: fields,
      );
    }
    return _uploadCloudDocument(file: file, fields: fields);
  }

  Future<DocumentFolderItem> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      return _localVaultService.createFolderForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
        name: name,
        parentFolderId: parentFolderId,
      );
    }
    return _createCloudFolder(name: name, parentFolderId: parentFolderId);
  }

  Future<DocumentQueryResult> queryDocuments({
    required String question,
    String? folderId,
    int? topK,
  }) async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      return _queryLocalDocuments(
        question: question,
        folderId: folderId,
        topK: topK,
      );
    }
    return _queryCloudDocuments(
      question: question,
      folderId: folderId,
      topK: topK,
    );
  }

  Future<int> reindexDocuments() async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      final localDocuments = await _localVaultService.fetchDocumentsForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
      );
      return localDocuments.length;
    }
    return _reindexCloudDocuments();
  }

  Future<int> reindexDocument(String documentId) async {
    final storageMode = await _getStorageMode();
    if (_isLocalDocumentId(documentId)) {
      return 1;
    }
    if (storageMode == _DocumentStorageMode.local) {
      return 0;
    }
    return _reindexCloudDocument(documentId);
  }

  Future<ClinicalDocumentDetail> processDocument(String documentId) async {
    final storageMode = await _getStorageMode();
    if (_isLocalDocumentId(documentId)) {
      return fetchDocumentDetail(documentId);
    }
    if (storageMode == _DocumentStorageMode.local) {
      final cached = await _readCachedDocumentDetailJson(documentId);
      if (cached != null) {
        return ClinicalDocumentDetail.fromJson(cached);
      }
      throw ApiException(
        'Archived documents are read-only while local-only mode is active.',
        statusCode: 409,
      );
    }
    return _processCloudDocument(documentId);
  }

  Future<ClinicalDocumentDetail> submitManualReview(
    String documentId,
    DocumentManualReviewInput input,
  ) async {
    final storageMode = await _getStorageMode();
    if (_isLocalDocumentId(documentId)) {
      final scope = await _resolveLocalScope();
      return _localVaultService.submitManualReviewForScope(
        documentId,
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
        input: input,
      );
    }
    if (storageMode == _DocumentStorageMode.local) {
      final cached = await _readCachedDocumentDetailJson(documentId);
      if (cached != null) {
        return ClinicalDocumentDetail.fromJson(cached);
      }
      throw ApiException(
        'Archived documents are read-only while local-only mode is active.',
        statusCode: 409,
      );
    }
    return _submitCloudManualReview(documentId, input);
  }

  Future<ClinicalDocumentDetail> updateDocumentContextStatus(
    String documentId, {
    required String contextStatus,
  }) async {
    if (_isLocalDocumentId(documentId)) {
      final scope = await _resolveLocalScope();
      return _localVaultService.updateDocumentContextStatusForScope(
        documentId,
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
        contextStatus: contextStatus,
      );
    }
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      throw ApiException(
        'Archived documents are read-only while local-only mode is active.',
        statusCode: 409,
      );
    }
    return _updateCloudDocumentContextStatus(
      documentId,
      contextStatus: contextStatus,
    );
  }

  Future<void> deleteDocument(String documentId) async {
    if (_isLocalDocumentId(documentId)) {
      final scope = await _resolveLocalScope();
      await _localVaultService.deleteDocumentForScope(
        documentId,
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
      );
      return;
    }
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      throw ApiException(
        'Archived documents are read-only while local-only mode is active.',
        statusCode: 409,
      );
    }
    return _deleteCloudDocument(documentId);
  }

  Future<ClinicalDocumentDetail> moveDocument(
    String documentId, {
    String? folderId,
  }) async {
    if (_isLocalDocumentId(documentId)) {
      final scope = await _resolveLocalScope();
      return _localVaultService.moveDocumentForScope(
        documentId,
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
        folderId: folderId,
      );
    }
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      throw ApiException(
        'Archived documents are read-only while local-only mode is active.',
        statusCode: 409,
      );
    }
    return _moveCloudDocument(documentId, folderId: folderId);
  }

  Future<String> prepareLocalViewerFile(String documentId) async {
    if (!_isLocalDocumentId(documentId)) {
      throw ApiException(
        'This document does not use the local vault.',
        statusCode: 400,
      );
    }
    final scope = await _resolveLocalScope();
    return _localVaultService.prepareViewerFileForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<_DocumentStorageMode> _getStorageMode() async {
    _cachedStorageMode = _DocumentStorageMode.local;
    await _localDatabase.putCache(
      key: _documentStorageModeCacheKey,
      payload: _DocumentStorageMode.local.name,
    );
    return _DocumentStorageMode.local;
  }

  Future<DocumentQueryResult> _queryLocalDocuments({
    required String question,
    String? folderId,
    int? topK,
  }) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw ApiException('Please enter a question before searching documents.');
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
      final documents = await _fetchCloudDocuments();
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

  Future<List<ClinicalDocumentSummary>> _fetchCloudDocuments() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJsonList('/api/v1/documents');
      await _localDatabase.putCache(
        key: await _documentsScopedCacheKey(),
        payload: jsonEncode(response),
      );
      return response
          .map(
            (item) =>
                ClinicalDocumentSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on ApiException {
      final cached = await _readCachedDocuments();
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (item) =>
                ClinicalDocumentSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      final cached = await _readCachedDocuments();
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (item) =>
                ClinicalDocumentSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
  }

  Future<ClinicalDocumentDetail> _fetchCloudDocumentDetail(
    String documentId,
  ) async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson(
        '/api/v1/documents/$documentId',
      );
      await _localDatabase.putCache(
        key: await _detailScopedCacheKey(documentId),
        payload: jsonEncode(response),
      );
      return ClinicalDocumentDetail.fromJson(response);
    } on ApiException {
      final cached = await _readCachedDocumentDetailJson(documentId);
      if (cached == null) rethrow;
      return ClinicalDocumentDetail.fromJson(cached);
    } catch (_) {
      final cached = await _readCachedDocumentDetailJson(documentId);
      if (cached == null) rethrow;
      return ClinicalDocumentDetail.fromJson(cached);
    }
  }

  Future<DocumentArchiveView> _fetchCloudArchive({
    String? folderId,
    String? query,
  }) async {
    await _apiClient.flushPendingOperations();
    final uri = Uri(
      path: '/api/v1/documents/archive',
      queryParameters: {
        if (folderId != null && folderId.isNotEmpty) 'folder_id': folderId,
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      },
    );
    final response = await _apiClient.getJson(uri.toString());
    return DocumentArchiveView.fromJson(response);
  }

  Future<List<DocumentFolderItem>> _fetchCloudFolders() async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.getJsonList('/api/v1/documents/folders');
    return response
        .map(
          (item) => DocumentFolderItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ClinicalDocumentSummary> _uploadCloudDocument({
    required SelectedUploadDocument file,
    required Map<String, String> fields,
  }) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postMultipart(
      '/api/v1/documents/upload',
      fields: fields,
      files: [
        MultipartUploadFile(
          fieldName: 'file',
          filename: file.name,
          bytes: file.bytes,
          contentType: file.mimeType,
        ),
      ],
    );
    await _cacheDocumentListItem(response);
    return ClinicalDocumentSummary.fromJson(response);
  }

  Future<DocumentFolderItem> _createCloudFolder({
    required String name,
    String? parentFolderId,
  }) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson(
      '/api/v1/documents/folders',
      body: {'name': name.trim(), 'parent_folder_id': parentFolderId},
    );
    return DocumentFolderItem.fromJson(response);
  }

  Future<DocumentQueryResult> _queryCloudDocuments({
    required String question,
    String? folderId,
    int? topK,
  }) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson(
      '/api/v1/documents/query',
      body: {
        'question': question.trim(),
        if (folderId != null && folderId.isNotEmpty) 'folder_id': folderId,
        if (topK != null) 'top_k': topK,
      },
    );
    return DocumentQueryResult.fromJson(response);
  }

  Future<int> _reindexCloudDocuments() async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson('/api/v1/documents/reindex');
    return response['queued_documents'] as int? ?? 0;
  }

  Future<int> _reindexCloudDocument(String documentId) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson(
      '/api/v1/documents/$documentId/reindex',
    );
    return response['queued_documents'] as int? ?? 0;
  }

  Future<ClinicalDocumentDetail> _processCloudDocument(
    String documentId,
  ) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson(
      '/api/v1/documents/$documentId/process',
    );
    final detail = ClinicalDocumentDetail.fromJson(
      response['document'] as Map<String, dynamic>,
    );
    await _cacheDocumentDetail(response['document'] as Map<String, dynamic>);
    await _cacheDocumentListItem(response['document'] as Map<String, dynamic>);
    return detail;
  }

  Future<ClinicalDocumentDetail> _submitCloudManualReview(
    String documentId,
    DocumentManualReviewInput input,
  ) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson(
      '/api/v1/documents/$documentId/review',
      body: input.toJson(),
    );
    final detail = ClinicalDocumentDetail.fromJson(
      response['document'] as Map<String, dynamic>,
    );
    await _cacheDocumentDetail(response['document'] as Map<String, dynamic>);
    await _cacheDocumentListItem(response['document'] as Map<String, dynamic>);
    return detail;
  }

  Future<ClinicalDocumentDetail> _updateCloudDocumentContextStatus(
    String documentId, {
    required String contextStatus,
  }) async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.putJson(
        '/api/v1/documents/$documentId/status',
        body: {'context_status': contextStatus},
      );
      final detail = ClinicalDocumentDetail.fromJson(
        response['document'] as Map<String, dynamic>,
      );
      await _cacheDocumentDetail(response['document'] as Map<String, dynamic>);
      await _cacheDocumentListItem(
        response['document'] as Map<String, dynamic>,
      );
      return detail;
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueDocumentContextStatusUpdate(
        documentId: documentId,
        contextStatus: contextStatus,
        lastError: error.message,
      );
    } catch (error) {
      return _queueDocumentContextStatusUpdate(
        documentId: documentId,
        contextStatus: contextStatus,
        lastError: error.toString(),
      );
    }
  }

  Future<void> _deleteCloudDocument(String documentId) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.delete('/api/v1/documents/$documentId');
      await _removeDocumentFromCache(documentId);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      await _queueDocumentDeletion(documentId, error.message);
    } catch (error) {
      await _queueDocumentDeletion(documentId, error.toString());
    }
  }

  Future<ClinicalDocumentDetail> _moveCloudDocument(
    String documentId, {
    String? folderId,
  }) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson(
      '/api/v1/documents/$documentId/move',
      body: {'folder_id': folderId},
    );
    final detail = ClinicalDocumentDetail.fromJson(
      response['document'] as Map<String, dynamic>,
    );
    await _cacheDocumentDetail(response['document'] as Map<String, dynamic>);
    await _cacheDocumentListItem(response['document'] as Map<String, dynamic>);
    return detail;
  }

  static String _detailCacheKey(String documentId) =>
      'document_detail_$documentId';

  Future<ClinicalDocumentDetail> _queueDocumentContextStatusUpdate({
    required String documentId,
    required String contextStatus,
    required String lastError,
  }) async {
    await _apiClient.enqueueJsonOperation(
      method: 'PUT',
      path: '/api/v1/documents/$documentId/status',
      body: {'context_status': contextStatus},
      lastError: lastError,
      replaceExisting: true,
    );
    final updated = await _patchCachedDocumentContextStatus(
      documentId,
      contextStatus,
    );
    return ClinicalDocumentDetail.fromJson(updated);
  }

  Future<void> _queueDocumentDeletion(
    String documentId,
    String lastError,
  ) async {
    await _apiClient.enqueueJsonOperation(
      method: 'DELETE',
      path: '/api/v1/documents/$documentId',
      body: const {},
      lastError: lastError,
      replaceExisting: true,
    );
    await _removeDocumentFromCache(documentId);
  }

  Future<void> _cacheDocumentDetail(Map<String, dynamic> document) async {
    await _localDatabase.putCache(
      key: await _detailScopedCacheKey(document['id'].toString()),
      payload: jsonEncode(document),
    );
  }

  Future<void> _cacheDocumentListItem(Map<String, dynamic> document) async {
    final cached = await _readCachedDocuments();
    if (cached == null) {
      await _localDatabase.putCache(
        key: await _documentsScopedCacheKey(),
        payload: jsonEncode([document]),
      );
      return;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    var found = false;
    final updated = decoded.map((item) {
      final current = Map<String, dynamic>.from(item as Map);
      if (current['id'].toString() == document['id'].toString()) {
        found = true;
        return document;
      }
      return current;
    }).toList();
    if (!found) {
      updated.add(document);
    }
    await _localDatabase.putCache(
      key: await _documentsScopedCacheKey(),
      payload: jsonEncode(updated),
    );
  }

  Future<Map<String, dynamic>> _patchCachedDocumentContextStatus(
    String documentId,
    String contextStatus,
  ) async {
    final detail = await _readCachedDocumentDetailJson(documentId);
    if (detail != null) {
      detail['context_status'] = contextStatus;
      detail['pending_sync'] = true;
      await _cacheDocumentDetail(detail);
      await _cacheDocumentListItem(detail);
      return detail;
    }

    final listItem = await _readCachedDocumentListItem(documentId);
    if (listItem != null) {
      listItem['context_status'] = contextStatus;
      listItem['pending_sync'] = true;
      await _cacheDocumentListItem(listItem);
      final fallback = _buildFallbackDetailJson(listItem, contextStatus);
      await _cacheDocumentDetail(fallback);
      return fallback;
    }

    final fallback = _buildFallbackDetailJson({
      'id': documentId,
      'title': 'Document',
      'document_type': 'generic_document',
      'upload_date': DateTime.now().toUtc().toIso8601String(),
      'exam_date': null,
      'source': null,
      'original_filename': 'document',
      'mime_type': 'application/pdf',
      'file_size_bytes': 0,
      'parsed_status': 'pending',
      'context_status': contextStatus,
      'classification_confidence': null,
      'parsing_confidence': null,
      'processing_error': null,
      'pending_sync': true,
    }, contextStatus);
    await _cacheDocumentDetail(fallback);
    return fallback;
  }

  Future<void> _removeDocumentFromCache(String documentId) async {
    await _localDatabase.removeCache(await _detailScopedCacheKey(documentId));
    final cached = await _readCachedDocuments();
    if (cached == null) {
      return;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    final updated = decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => item['id'].toString() != documentId)
        .toList();
    await _localDatabase.putCache(
      key: await _documentsScopedCacheKey(),
      payload: jsonEncode(updated),
    );
  }

  Future<Map<String, dynamic>?> _readCachedDocumentDetailJson(
    String documentId,
  ) async {
    final cached = await _localDatabase.readCache(
      await _detailScopedCacheKey(documentId),
    );
    if (cached == null) {
      return null;
    }
    return Map<String, dynamic>.from(
      jsonDecode(cached) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>?> _readCachedDocumentListItem(
    String documentId,
  ) async {
    final cached = await _readCachedDocuments();
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    for (final item in decoded) {
      final current = Map<String, dynamic>.from(item as Map);
      if (current['id'].toString() == documentId) {
        return current;
      }
    }
    return null;
  }

  Future<String> _documentsScopedCacheKey() {
    return profileScopedCacheKey(_localDatabase, _documentsCacheKey);
  }

  Future<String> _detailScopedCacheKey(String documentId) {
    return profileScopedCacheKey(_localDatabase, _detailCacheKey(documentId));
  }

  Future<String?> _readCachedDocuments() {
    return readProfileScopedCache(_localDatabase, _documentsCacheKey);
  }

  Map<String, dynamic> _buildFallbackDetailJson(
    Map<String, dynamic> base,
    String contextStatus,
  ) {
    return {
      'id': base['id'].toString(),
      'title': base['title']?.toString() ?? 'Document',
      'document_type': base['document_type']?.toString() ?? 'generic_document',
      'upload_date':
          base['upload_date']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      'exam_date': base['exam_date'],
      'source': base['source'],
      'original_filename': base['original_filename']?.toString() ?? 'document',
      'mime_type': base['mime_type']?.toString() ?? 'application/pdf',
      'file_size_bytes': base['file_size_bytes'] ?? 0,
      'parsed_status': base['parsed_status']?.toString() ?? 'pending',
      'context_status': contextStatus,
      'classification_confidence': base['classification_confidence'],
      'parsing_confidence': base['parsing_confidence'],
      'processing_error': base['processing_error'],
      'file_url': base['file_url']?.toString() ?? '',
      'ocr_text': base['ocr_text'],
      'viewer_url': base['viewer_url'],
      'processed_at': base['processed_at'],
      'lab_panels': base['lab_panels'] ?? const <Map<String, dynamic>>[],
      'imaging_reports':
          base['imaging_reports'] ?? const <Map<String, dynamic>>[],
      'pending_sync': true,
      'storage_location': base['storage_location'] ?? 'cloud',
      'local_file_path': base['local_file_path'],
    };
  }

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
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
