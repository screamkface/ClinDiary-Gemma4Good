import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/billing/data/billing_repository.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';

enum _DocumentStorageMode { local, cloud }

class DocumentsRepository {
  DocumentsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
    BillingRepository? billingRepository,
    LocalDocumentVaultService? localVaultService,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase,
       _billingRepository =
           billingRepository ?? BillingRepository(apiClient: apiClient),
       _localVaultService =
           localVaultService ?? LocalDocumentVaultService();

  static const _documentsCacheKey = 'documents_list';
  static const _documentStorageModeCacheKey = 'document_storage_mode';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;
  final BillingRepository _billingRepository;
  final LocalDocumentVaultService _localVaultService;
  _DocumentStorageMode? _cachedStorageMode;

  Future<List<ClinicalDocumentSummary>> fetchDocuments() async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      final localDocuments = await _localVaultService.fetchDocumentsForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
      );
      final legacyCloudDocuments = await _fetchReadOnlyCloudDocuments();
      final merged = [...localDocuments, ...legacyCloudDocuments]
        ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      return merged;
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
    return _fetchCloudDocumentDetail(documentId);
  }

  Future<DocumentArchiveView> fetchArchive({
    String? folderId,
    String? query,
  }) async {
    final storageMode = await _getStorageMode();
    if (storageMode == _DocumentStorageMode.local) {
      final scope = await _resolveLocalScope();
      final localArchive = await _localVaultService.fetchArchiveForScope(
        userScopeId: scope.userId,
        profileScopeId: scope.profileId,
        folderId: folderId,
        query: query,
      );
      final shouldIncludeLegacyCloud =
          folderId == null || query?.trim().isNotEmpty == true;
      if (!shouldIncludeLegacyCloud) {
        return localArchive;
      }
      final legacyCloudDocuments = await _fetchReadOnlyCloudDocuments(
        query: query,
      );
      return DocumentArchiveView(
        currentFolder: localArchive.currentFolder,
        breadcrumbs: localArchive.breadcrumbs,
        folders: localArchive.folders,
        documents: localArchive.documents,
        legacyCloudDocuments: legacyCloudDocuments,
        query: localArchive.query,
        isSearch: localArchive.isSearch,
        storageLocation: localArchive.storageLocation,
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
      throw _featureLocked(
        message:
            'Le domande ai documenti usano l archivio cloud indicizzato e richiedono ClinDiary AI Plus.',
        featureCode: 'ai_document_query',
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
      throw _featureLocked(
        message:
            'Indicizzazione, OCR e parsing automatico sono disponibili solo per l archivio cloud AI Plus.',
        featureCode: 'cloud_document_storage',
      );
    }
    return _reindexCloudDocuments();
  }

  Future<int> reindexDocument(String documentId) async {
    final storageMode = await _getStorageMode();
    if (_isLocalDocumentId(documentId) || storageMode == _DocumentStorageMode.local) {
      throw _featureLocked(
        message:
            'Indicizzazione, OCR e parsing automatico sono disponibili solo per l archivio cloud AI Plus.',
        featureCode: 'cloud_document_storage',
      );
    }
    return _reindexCloudDocument(documentId);
  }

  Future<ClinicalDocumentDetail> processDocument(String documentId) async {
    final storageMode = await _getStorageMode();
    if (_isLocalDocumentId(documentId) || storageMode == _DocumentStorageMode.local) {
      throw _featureLocked(
        message:
            'OCR, parsing e timeline documentale avanzata richiedono il salvataggio cloud AI Plus.',
        featureCode: 'cloud_document_storage',
      );
    }
    return _processCloudDocument(documentId);
  }

  Future<ClinicalDocumentDetail> submitManualReview(
    String documentId,
    DocumentManualReviewInput input,
  ) async {
    final storageMode = await _getStorageMode();
    if (_isLocalDocumentId(documentId) || storageMode == _DocumentStorageMode.local) {
      throw _featureLocked(
        message:
            'La revisione strutturata dei documenti fa parte dell archivio cloud AI Plus.',
        featureCode: 'cloud_document_storage',
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
      throw _featureLocked(
        message:
            'Sul piano free i documenti cloud già caricati restano consultabili, ma modifiche e processing richiedono AI Plus.',
        featureCode: 'cloud_document_storage',
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
      throw _featureLocked(
        message:
            'Sul piano free i documenti cloud già caricati restano consultabili, ma non eliminabili.',
        featureCode: 'cloud_document_storage',
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
      throw _featureLocked(
        message:
            'Sul piano free i documenti cloud restano in sola lettura. Per spostarli serve AI Plus.',
        featureCode: 'cloud_document_storage',
      );
    }
    return _moveCloudDocument(documentId, folderId: folderId);
  }

  Future<String> prepareLocalViewerFile(String documentId) async {
    if (!_isLocalDocumentId(documentId)) {
      throw ApiException('Il documento non usa il vault locale.', statusCode: 400);
    }
    final scope = await _resolveLocalScope();
    return _localVaultService.prepareViewerFileForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<_DocumentStorageMode> _getStorageMode() async {
    try {
      final status = await _billingRepository.fetchStatus();
      final resolved = status.hasFeature('cloud_document_storage')
          ? _DocumentStorageMode.cloud
          : _DocumentStorageMode.local;
      _cachedStorageMode = resolved;
      await _localDatabase.putCache(
        key: _documentStorageModeCacheKey,
        payload: resolved.name,
      );
      return resolved;
    } catch (_) {
      if (_cachedStorageMode != null) {
        return _cachedStorageMode!;
      }
      final persisted = await _localDatabase.readCache(
        _documentStorageModeCacheKey,
      );
      if (persisted == _DocumentStorageMode.cloud.name) {
        _cachedStorageMode = _DocumentStorageMode.cloud;
        return _DocumentStorageMode.cloud;
      }
      _cachedStorageMode = _DocumentStorageMode.local;
      return _DocumentStorageMode.local;
    }
  }

  Future<_LocalVaultScope> _resolveLocalScope() async {
    final userId =
        await _localDatabase.readCache(activeUserIdCacheKey) ?? 'anonymous';
    final profileId = await _localDatabase.readCache(activeProfileIdCacheKey);
    return _LocalVaultScope(userId: userId, profileId: profileId);
  }

  bool _isLocalDocumentId(String documentId) => documentId.startsWith('local-doc-');

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
      body: {
        'name': name.trim(),
        'parent_folder_id': parentFolderId,
      },
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
      'title': 'Documento',
      'document_type': 'generic_document',
      'upload_date': DateTime.now().toUtc().toIso8601String(),
      'exam_date': null,
      'source': null,
      'original_filename': 'documento',
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
      'title': base['title']?.toString() ?? 'Documento',
      'document_type': base['document_type']?.toString() ?? 'generic_document',
      'upload_date':
          base['upload_date']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      'exam_date': base['exam_date'],
      'source': base['source'],
      'original_filename': base['original_filename']?.toString() ?? 'documento',
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

  ApiException _featureLocked({
    required String message,
    required String featureCode,
  }) {
    return ApiException(
      message,
      statusCode: 402,
      code: 'feature_locked',
      details: {
        'feature_code': featureCode,
        'recommended_plan_code': 'ai_plus_yearly',
      },
    );
  }

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
}

class _LocalVaultScope {
  const _LocalVaultScope({required this.userId, required this.profileId});

  final String userId;
  final String? profileId;
}
