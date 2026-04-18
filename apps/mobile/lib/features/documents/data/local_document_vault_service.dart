import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/features/documents/data/local_lab_text_parser.dart';
import 'package:clindiary/features/documents/data/local_document_vault_cipher.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LocalDocumentVaultService {
  LocalDocumentVaultService({
    Directory? rootDirectory,
    FlutterSecureStorage? secureStorage,
    LocalDocumentVaultCipher? cipher,
    LocalLabTextParser? labTextParser,
  }) : _rootDirectory = rootDirectory,
       _labTextParser = labTextParser ?? const LocalLabTextParser(),
       _cipher =
           cipher ?? LocalDocumentVaultCipher(secureStorage: secureStorage);

  static const int maxDocumentCount = 80;
  static const int maxSingleFileBytes = 10 * 1024 * 1024;
  static const int maxTotalBytes = 200 * 1024 * 1024;

  final Directory? _rootDirectory;
  final LocalLabTextParser _labTextParser;
  final LocalDocumentVaultCipher _cipher;
  final Random _random = Random.secure();
  final Map<String, _LocalStructuredData> _structuredDataCache = {};
  final Map<String, Future<_LocalStructuredData>> _inFlightStructuredData = {};
  Future<void> _parseQueueTail = Future<void>.value();

  Future<List<ClinicalDocumentSummary>> fetchDocuments() async {
    throw UnimplementedError('Use scoped fetchDocumentsForScope.');
  }

  Future<List<ClinicalDocumentSummary>> fetchDocumentsForScope({
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final folder in state.folders) folder.id: folder};
    final documents =
        state.documents
            .map(
              (item) => item.toSummary(
                folderName: _pathLabelForFolder(item.folderId, folders),
              ),
            )
            .toList()
          ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    return documents;
  }

  Future<ClinicalDocumentDetail> fetchDocumentDetail(String documentId) async {
    throw UnimplementedError('Use scoped fetchDocumentDetailForScope.');
  }

  Future<ClinicalDocumentDetail> fetchDocumentDetailForScope(
    String documentId, {
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final folder in state.folders) folder.id: folder};
    final document = _requireDocument(state, documentId);
    final structuredData = await _resolveStructuredData(document);
    return document.toDetail(
      folderName: _pathLabelForFolder(document.folderId, folders),
      parsedStatusOverride: structuredData.parsedStatus,
      parsingConfidence: structuredData.parsingConfidence,
      processingError: structuredData.processingError,
      processedAt: structuredData.processedAt,
      labPanels: structuredData.labPanels,
      imagingReports: structuredData.imagingReports,
    );
  }

  Future<DocumentArchiveView> fetchArchive({
    String? folderId,
    String? query,
  }) async {
    throw UnimplementedError('Use scoped fetchArchiveForScope.');
  }

  Future<DocumentArchiveView> fetchArchiveForScope({
    required String userScopeId,
    String? profileScopeId,
    String? folderId,
    String? query,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final folder in state.folders) folder.id: folder};
    final currentFolder = folderId == null
        ? null
        : _requireFolder(state, folderId);
    final normalizedQuery = _normalizeText(query);

    final childFolderCounts = <String?, int>{};
    for (final folder in state.folders) {
      childFolderCounts[folder.parentFolderId] =
          (childFolderCounts[folder.parentFolderId] ?? 0) + 1;
    }

    final documentCounts = <String?, int>{};
    for (final document in state.documents) {
      documentCounts[document.folderId] =
          (documentCounts[document.folderId] ?? 0) + 1;
    }

    final foldersForView = normalizedQuery == null
        ? state.folders
              .where((folder) => folder.parentFolderId == currentFolder?.id)
              .map(
                (folder) => _folderToItem(
                  folder,
                  folders,
                  childFolderCounts,
                  documentCounts,
                ),
              )
              .toList()
        : <DocumentFolderItem>[];

    final documentsForView =
        state.documents
            .where((document) {
              if (normalizedQuery != null) {
                return _matchesSearch(document, folders, normalizedQuery);
              }
              return document.folderId == currentFolder?.id;
            })
            .map(
              (document) => document.toSummary(
                folderName: _pathLabelForFolder(document.folderId, folders),
              ),
            )
            .toList()
          ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));

    final breadcrumbs = <DocumentFolderItem>[];
    var node = currentFolder;
    while (node != null) {
      breadcrumbs.insert(
        0,
        _folderToItem(node, folders, childFolderCounts, documentCounts),
      );
      node = node.parentFolderId == null ? null : folders[node.parentFolderId];
    }

    return DocumentArchiveView(
      currentFolder: currentFolder == null
          ? null
          : _folderToItem(
              currentFolder,
              folders,
              childFolderCounts,
              documentCounts,
            ),
      breadcrumbs: breadcrumbs,
      folders: foldersForView,
      documents: documentsForView,
      query: normalizedQuery,
      isSearch: normalizedQuery != null,
      storageLocation: 'local',
    );
  }

  Future<List<DocumentFolderItem>> fetchFolders() async {
    throw UnimplementedError('Use scoped fetchFoldersForScope.');
  }

  Future<List<DocumentFolderItem>> fetchFoldersForScope({
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final folder in state.folders) folder.id: folder};
    final childFolderCounts = <String?, int>{};
    for (final folder in state.folders) {
      childFolderCounts[folder.parentFolderId] =
          (childFolderCounts[folder.parentFolderId] ?? 0) + 1;
    }
    final documentCounts = <String?, int>{};
    for (final document in state.documents) {
      documentCounts[document.folderId] =
          (documentCounts[document.folderId] ?? 0) + 1;
    }
    return state.folders
        .map(
          (folder) =>
              _folderToItem(folder, folders, childFolderCounts, documentCounts),
        )
        .toList()
      ..sort((a, b) => a.pathLabel.compareTo(b.pathLabel));
  }

  Future<ClinicalDocumentSummary> uploadDocument({
    required SelectedUploadDocument file,
    required Map<String, String> fields,
  }) async {
    throw UnimplementedError('Use scoped uploadDocumentForScope.');
  }

  Future<ClinicalDocumentSummary> uploadDocumentForScope({
    required String userScopeId,
    String? profileScopeId,
    required SelectedUploadDocument file,
    required Map<String, String> fields,
  }) async {
    if (file.bytes.length > maxSingleFileBytes) {
      throw ApiException('Local files can be at most 10 MB.', statusCode: 413);
    }

    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    if (state.documents.length >= maxDocumentCount) {
      throw ApiException(
        'You have reached the local limit of 80 documents.',
        statusCode: 409,
      );
    }
    final totalBytes = state.documents.fold<int>(
      0,
      (sum, item) => sum + item.fileSizeBytes,
    );
    if (totalBytes + file.bytes.length > maxTotalBytes) {
      throw ApiException(
        'You have reached the local storage limit of 200 MB.',
        statusCode: 409,
      );
    }

    final normalizedFolderId = _normalizeText(fields['folder_id']);
    if (normalizedFolderId != null) {
      _requireFolder(state, normalizedFolderId);
    }

    final documentId = _newId('local-doc');
    final extension = path.extension(file.name).trim();
    final documentsDir = await _documentsDirectory(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final safeExtension = extension.isEmpty ? '' : extension.toLowerCase();
    final savedFile = File(
      path.join(documentsDir.path, '$documentId$safeExtension'),
    );
    final encryptedBytes = await _cipher.encryptDocument(
      file.bytes,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
      documentId: documentId,
    );
    await savedFile.writeAsBytes(encryptedBytes, flush: true);

    final title =
        _normalizeText(fields['title']) ??
        path.basenameWithoutExtension(file.name);
    final source = _normalizeText(fields['source']);
    final examDate = _tryParseDate(fields['exam_date']);
    final explicitOcrText = _normalizeText(fields['ocr_text']);
    final inferredOcrText = _inferTextPreview(file);
    final document = _StoredDocument(
      id: documentId,
      folderId: normalizedFolderId,
      title: title,
      documentType:
          _normalizeText(fields['document_type']) ?? 'generic_document',
      uploadDateIso: DateTime.now().toUtc().toIso8601String(),
      examDateIso: examDate?.toIso8601String(),
      source: source,
      originalFilename: file.name,
      mimeType: file.mimeType,
      fileSizeBytes: file.bytes.length,
      parsedStatus: 'local_only',
      contextStatus: 'active',
      localFilePath: savedFile.path,
      ocrText: explicitOcrText ?? inferredOcrText,
    );

    final nextState = state.copyWith(documents: [...state.documents, document]);
    await _saveState(
      nextState,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );

    unawaited(_warmStructuredData(document));

    final folders = {for (final folder in nextState.folders) folder.id: folder};
    return document.toSummary(
      folderName: _pathLabelForFolder(document.folderId, folders),
    );
  }

  Future<DocumentFolderItem> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    throw UnimplementedError('Use scoped createFolderForScope.');
  }

  Future<DocumentFolderItem> createFolderForScope({
    required String userScopeId,
    String? profileScopeId,
    required String name,
    String? parentFolderId,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ApiException('Folder name cannot be empty.');
    }

    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final normalizedParentId = _normalizeText(parentFolderId);
    if (normalizedParentId != null) {
      _requireFolder(state, normalizedParentId);
    }

    final siblingExists = state.folders.any(
      (folder) =>
          folder.parentFolderId == normalizedParentId &&
          folder.name.toLowerCase() == normalizedName.toLowerCase(),
    );
    if (siblingExists) {
      throw ApiException(
        'A folder with this name already exists in this path.',
        statusCode: 409,
      );
    }

    final folder = _StoredFolder(
      id: _newId('local-folder'),
      name: normalizedName,
      parentFolderId: normalizedParentId,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    final nextState = state.copyWith(folders: [...state.folders, folder]);
    await _saveState(
      nextState,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final item in nextState.folders) item.id: item};
    final childFolderCounts = <String?, int>{};
    for (final item in nextState.folders) {
      childFolderCounts[item.parentFolderId] =
          (childFolderCounts[item.parentFolderId] ?? 0) + 1;
    }
    final documentCounts = <String?, int>{};
    for (final document in nextState.documents) {
      documentCounts[document.folderId] =
          (documentCounts[document.folderId] ?? 0) + 1;
    }
    return _folderToItem(folder, folders, childFolderCounts, documentCounts);
  }

  Future<ClinicalDocumentDetail> moveDocument(
    String documentId, {
    String? folderId,
  }) async {
    throw UnimplementedError('Use scoped moveDocumentForScope.');
  }

  Future<ClinicalDocumentDetail> moveDocumentForScope(
    String documentId, {
    required String userScopeId,
    String? profileScopeId,
    String? folderId,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final normalizedFolderId = _normalizeText(folderId);
    if (normalizedFolderId != null) {
      _requireFolder(state, normalizedFolderId);
    }

    final updatedDocuments = state.documents.map((item) {
      if (item.id != documentId) {
        return item;
      }
      return item.copyWith(folderId: normalizedFolderId);
    }).toList();

    if (!updatedDocuments.any((item) => item.id == documentId)) {
      throw ApiException('Document not found.', statusCode: 404);
    }

    final nextState = state.copyWith(documents: updatedDocuments);
    await _saveState(
      nextState,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final folder in nextState.folders) folder.id: folder};
    final updated = updatedDocuments.firstWhere(
      (item) => item.id == documentId,
    );
    return updated.toDetail(
      folderName: _pathLabelForFolder(updated.folderId, folders),
    );
  }

  Future<ClinicalDocumentDetail> updateDocumentContextStatus(
    String documentId, {
    required String contextStatus,
  }) async {
    throw UnimplementedError('Use scoped updateDocumentContextStatusForScope.');
  }

  Future<ClinicalDocumentDetail> updateDocumentContextStatusForScope(
    String documentId, {
    required String userScopeId,
    String? profileScopeId,
    required String contextStatus,
  }) async {
    final normalizedStatus = contextStatus.trim().toLowerCase();
    if (normalizedStatus != 'active' && normalizedStatus != 'old') {
      throw ApiException('Invalid document status.', statusCode: 422);
    }

    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final updatedDocuments = state.documents.map((item) {
      if (item.id != documentId) {
        return item;
      }
      return item.copyWith(contextStatus: normalizedStatus);
    }).toList();
    if (!updatedDocuments.any((item) => item.id == documentId)) {
      throw ApiException('Document not found.', statusCode: 404);
    }

    final nextState = state.copyWith(documents: updatedDocuments);
    await _saveState(
      nextState,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final folder in nextState.folders) folder.id: folder};
    final updated = updatedDocuments.firstWhere(
      (item) => item.id == documentId,
    );
    return updated.toDetail(
      folderName: _pathLabelForFolder(updated.folderId, folders),
    );
  }

  Future<ClinicalDocumentDetail> submitManualReview(
    String documentId, {
    required DocumentManualReviewInput input,
  }) async {
    throw UnimplementedError('Use scoped submitManualReviewForScope.');
  }

  Future<ClinicalDocumentDetail> submitManualReviewForScope(
    String documentId, {
    required String userScopeId,
    String? profileScopeId,
    required DocumentManualReviewInput input,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final folders = {for (final folder in state.folders) folder.id: folder};
    final document = _requireDocument(state, documentId);
    final updatedDocument = _applyManualReview(document, input);

    final updatedDocuments = state.documents.map((item) {
      if (item.id != documentId) {
        return item;
      }
      return updatedDocument;
    }).toList();

    final nextState = state.copyWith(documents: updatedDocuments);
    await _saveState(
      nextState,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );

    _evictStructuredDataCache(documentId);
    unawaited(_warmStructuredData(updatedDocument));

    return updatedDocument.toDetail(
      folderName: _pathLabelForFolder(updatedDocument.folderId, folders),
    );
  }

  Future<void> deleteDocument(String documentId) async {
    throw UnimplementedError('Use scoped deleteDocumentForScope.');
  }

  Future<void> deleteDocumentForScope(
    String documentId, {
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final document = _requireDocument(state, documentId);
    final nextState = state.copyWith(
      documents: state.documents
          .where((item) => item.id != documentId)
          .toList(),
    );
    await _saveState(
      nextState,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final file = File(document.localFilePath);
    if (await file.exists()) {
      await file.delete();
    }
    final previewDir = await _previewDirectory(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final previewFile = File(
      path.join(
        previewDir.path,
        '${document.id}-preview${path.extension(document.originalFilename).toLowerCase()}',
      ),
    );
    if (await previewFile.exists()) {
      await previewFile.delete();
    }
    _evictStructuredDataCache(documentId);
  }

  Future<void> deleteAllForUserScope(String userScopeId) async {
    final baseDir = await _baseDirectory();
    final userSegment = _sanitizeSegment(userScopeId);
    final dir = Directory(path.join(baseDir.path, 'user-$userSegment'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _cipher.deleteKeyForUserScope(userScopeId);
    _clearStructuredDataCache();
  }

  Future<String> prepareViewerFileForScope(
    String documentId, {
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final document = _requireDocument(state, documentId);
    final sourceFile = File(document.localFilePath);
    if (!await sourceFile.exists()) {
      throw ApiException('Local file not found.', statusCode: 404);
    }
    final encryptedBytes = await sourceFile.readAsBytes();
    final clearBytes = await _cipher.decryptDocument(
      encryptedBytes,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
      documentId: documentId,
    );
    final previewDir = await _previewDirectory(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final extension = path.extension(document.originalFilename).toLowerCase();
    final previewFile = File(
      path.join(previewDir.path, '$documentId-preview$extension'),
    );
    await previewFile.writeAsBytes(clearBytes, flush: true);
    return previewFile.path;
  }

  Future<File> _stateFile({
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final baseDir = await _scopeDirectory(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    return File(path.join(baseDir.path, 'vault-index.json'));
  }

  Future<Directory> _documentsDirectory({
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final baseDir = await _scopeDirectory(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final dir = Directory(path.join(baseDir.path, 'files'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _previewDirectory({
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final baseDir = await _scopeDirectory(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final dir = Directory(path.join(baseDir.path, 'preview'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _baseDirectory() async {
    final rootDirectory = _rootDirectory;
    if (rootDirectory != null) {
      if (!await rootDirectory.exists()) {
        await rootDirectory.create(recursive: true);
      }
      return rootDirectory;
    }
    final applicationDocuments = await getApplicationDocumentsDirectory();
    final dir = Directory(
      path.join(applicationDocuments.path, 'clindiary-local-documents'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _scopeDirectory({
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final baseDir = await _baseDirectory();
    final userSegment = _sanitizeSegment(userScopeId);
    final profileSegment = _sanitizeSegment(profileScopeId ?? 'default');
    final dir = Directory(
      path.join(baseDir.path, 'user-$userSegment', 'profile-$profileSegment'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<_LocalVaultState> _loadState({
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final stateFile = await _stateFile(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    if (!await stateFile.exists()) {
      return const _LocalVaultState(folders: [], documents: []);
    }
    final rawBytes = await stateFile.readAsBytes();
    if (rawBytes.isEmpty) {
      return const _LocalVaultState(folders: [], documents: []);
    }
    final wasEncrypted = _cipher.isEncrypted(rawBytes);
    final raw = await _cipher.decryptState(
      rawBytes,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    if (raw.trim().isEmpty) {
      return const _LocalVaultState(folders: [], documents: []);
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final state = _LocalVaultState.fromJson(decoded);
    return _migrateStateIfNeeded(
      state,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
      rewriteState: !wasEncrypted,
    );
  }

  Future<void> _saveState(
    _LocalVaultState state, {
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final stateFile = await _stateFile(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final encrypted = await _cipher.encryptState(
      jsonEncode(state.toJson()),
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    await stateFile.writeAsBytes(encrypted, flush: true);
  }

  Future<_LocalVaultState> _migrateStateIfNeeded(
    _LocalVaultState state, {
    required String userScopeId,
    String? profileScopeId,
    required bool rewriteState,
  }) async {
    var migrated = rewriteState;
    for (final document in state.documents) {
      final file = File(document.localFilePath);
      if (!await file.exists()) {
        continue;
      }
      final bytes = await file.readAsBytes();
      if (_cipher.isEncrypted(bytes)) {
        continue;
      }
      final encrypted = await _cipher.encryptDocument(
        bytes,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        documentId: document.id,
      );
      await file.writeAsBytes(encrypted, flush: true);
      migrated = true;
    }
    if (migrated) {
      await _saveState(
        state,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
    }
    return state;
  }

  Future<_LocalStructuredData> _resolveStructuredData(
    _StoredDocument document,
  ) async {
    final text = document.ocrText?.trim();
    if (text == null || text.isEmpty) {
      return const _LocalStructuredData();
    }

    final cacheKey = _structuredDataCacheKey(document, text);
    final cached = _structuredDataCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final inFlight = _inFlightStructuredData[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _enqueueParseTask(() async {
      final parsed = await _labTextParser.parse(
        documentId: document.id,
        documentType: document.documentType,
        title: document.title,
        examDateIso: document.examDateIso,
        text: text,
      );

      return _LocalStructuredData(
        parsedStatus: parsed.parsedStatus == 'parsed' ? 'parsed' : null,
        parsingConfidence: parsed.parsingConfidence,
        processedAt: parsed.processedAt,
        labPanels: parsed.labPanels,
        imagingReports: parsed.imagingReports,
      );
    });
    _inFlightStructuredData[cacheKey] = future;

    try {
      final resolved = await future;
      _rememberStructuredData(cacheKey, resolved);
      return resolved;
    } finally {
      _inFlightStructuredData.remove(cacheKey);
    }
  }

  Future<void> _warmStructuredData(_StoredDocument document) async {
    try {
      await _resolveStructuredData(document);
    } catch (_) {
      // Parsing is best-effort during warm-up; on-demand detail loading retries.
    }
  }

  String _structuredDataCacheKey(_StoredDocument document, String text) {
    return '${document.id}|${document.documentType}|${document.title}|${document.examDateIso ?? ''}|${text.hashCode}';
  }

  void _rememberStructuredData(String cacheKey, _LocalStructuredData data) {
    _structuredDataCache[cacheKey] = data;
    if (_structuredDataCache.length <= 64) {
      return;
    }
    _structuredDataCache.remove(_structuredDataCache.keys.first);
  }

  void _evictStructuredDataCache(String documentId) {
    final cachedKeys = _structuredDataCache.keys
        .where((key) => key.startsWith('$documentId|'))
        .toList(growable: false);
    for (final key in cachedKeys) {
      _structuredDataCache.remove(key);
    }

    final inFlightKeys = _inFlightStructuredData.keys
        .where((key) => key.startsWith('$documentId|'))
        .toList(growable: false);
    for (final key in inFlightKeys) {
      _inFlightStructuredData.remove(key);
    }
  }

  void _clearStructuredDataCache() {
    _structuredDataCache.clear();
    _inFlightStructuredData.clear();
  }

  Future<T> _enqueueParseTask<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    final run = _parseQueueTail.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _parseQueueTail = run.catchError((_) {});
    return completer.future;
  }

  String _sanitizeSegment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'default';
    }
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  }

  _StoredFolder _requireFolder(_LocalVaultState state, String folderId) {
    return state.folders.firstWhere(
      (folder) => folder.id == folderId,
      orElse: () => throw ApiException('Folder not found.', statusCode: 404),
    );
  }

  _StoredDocument _requireDocument(_LocalVaultState state, String documentId) {
    return state.documents.firstWhere(
      (document) => document.id == documentId,
      orElse: () => throw ApiException('Document not found.', statusCode: 404),
    );
  }

  DocumentFolderItem _folderToItem(
    _StoredFolder folder,
    Map<String, _StoredFolder> folderMap,
    Map<String?, int> childFolderCounts,
    Map<String?, int> documentCounts,
  ) {
    return DocumentFolderItem(
      id: folder.id,
      name: folder.name,
      parentFolderId: folder.parentFolderId,
      pathLabel: _pathLabelForFolder(folder.id, folderMap),
      childFolderCount: childFolderCounts[folder.id] ?? 0,
      documentCount: documentCounts[folder.id] ?? 0,
    );
  }

  String _pathLabelForFolder(
    String? folderId,
    Map<String, _StoredFolder> folders,
  ) {
    if (folderId == null) {
      return '';
    }
    final labels = <String>[];
    var current = folders[folderId];
    while (current != null) {
      labels.insert(0, current.name);
      current = current.parentFolderId == null
          ? null
          : folders[current.parentFolderId];
    }
    return labels.join(' / ');
  }

  bool _matchesSearch(
    _StoredDocument document,
    Map<String, _StoredFolder> folders,
    String normalizedQuery,
  ) {
    final haystack = [
      document.title,
      document.originalFilename,
      document.source,
      document.documentType,
      _pathLabelForFolder(document.folderId, folders),
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(normalizedQuery);
  }

  String _newId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = _random.nextInt(1 << 32).toRadixString(16);
    return '$prefix-$timestamp-$random';
  }

  _StoredDocument _applyManualReview(
    _StoredDocument document,
    DocumentManualReviewInput input,
  ) {
    final updatedExamDateIso = _resolveManualReviewExamDateIso(
      requestedExamDate: input.examDate,
      existingExamDateIso: document.examDateIso,
    );

    return _StoredDocument(
      id: document.id,
      folderId: document.folderId,
      title: _normalizeText(input.title) ?? document.title,
      documentType: _normalizeText(input.documentType) ?? document.documentType,
      uploadDateIso: document.uploadDateIso,
      examDateIso: updatedExamDateIso,
      source: input.source == null
          ? document.source
          : _normalizeText(input.source),
      originalFilename: document.originalFilename,
      mimeType: document.mimeType,
      fileSizeBytes: document.fileSizeBytes,
      parsedStatus: document.parsedStatus,
      contextStatus: document.contextStatus,
      localFilePath: document.localFilePath,
      ocrText: input.ocrText == null
          ? document.ocrText
          : _normalizeText(input.ocrText),
    );
  }

  String? _resolveManualReviewExamDateIso({
    required String? requestedExamDate,
    required String? existingExamDateIso,
  }) {
    if (requestedExamDate == null) {
      return existingExamDateIso;
    }

    final trimmed = requestedExamDate.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      throw ApiException(
        'Exam date is invalid. Use ISO format YYYY-MM-DD.',
        statusCode: 422,
      );
    }
    return parsed.toIso8601String();
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  DateTime? _tryParseDate(String? value) {
    final normalized = _normalizeText(value);
    if (normalized == null) {
      return null;
    }
    return DateTime.tryParse(normalized);
  }

  String? _inferTextPreview(SelectedUploadDocument file) {
    final isTextMime = file.mimeType.toLowerCase().startsWith('text/');
    final isTxtFile = path.extension(file.name).toLowerCase() == '.txt';
    if (!isTextMime && !isTxtFile) {
      return null;
    }

    final text = utf8.decode(file.bytes, allowMalformed: true).trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }
}

class _LocalVaultState {
  const _LocalVaultState({required this.folders, required this.documents});

  final List<_StoredFolder> folders;
  final List<_StoredDocument> documents;

  _LocalVaultState copyWith({
    List<_StoredFolder>? folders,
    List<_StoredDocument>? documents,
  }) {
    return _LocalVaultState(
      folders: folders ?? this.folders,
      documents: documents ?? this.documents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'folders': folders.map((folder) => folder.toJson()).toList(),
      'documents': documents.map((document) => document.toJson()).toList(),
    };
  }

  factory _LocalVaultState.fromJson(Map<String, dynamic> json) {
    return _LocalVaultState(
      folders: (json['folders'] as List<dynamic>? ?? const [])
          .map((item) => _StoredFolder.fromJson(item as Map<String, dynamic>))
          .toList(),
      documents: (json['documents'] as List<dynamic>? ?? const [])
          .map((item) => _StoredDocument.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class _StoredFolder {
  const _StoredFolder({
    required this.id,
    required this.name,
    required this.parentFolderId,
    required this.createdAtIso,
  });

  final String id;
  final String name;
  final String? parentFolderId;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_folder_id': parentFolderId,
      'created_at': createdAtIso,
    };
  }

  factory _StoredFolder.fromJson(Map<String, dynamic> json) {
    return _StoredFolder(
      id: json['id'].toString(),
      name: json['name'].toString(),
      parentFolderId: json['parent_folder_id'] as String?,
      createdAtIso:
          json['created_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }
}

class _StoredDocument {
  const _StoredDocument({
    required this.id,
    required this.folderId,
    required this.title,
    required this.documentType,
    required this.uploadDateIso,
    required this.examDateIso,
    required this.source,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.parsedStatus,
    required this.contextStatus,
    required this.localFilePath,
    this.ocrText,
  });

  final String id;
  final String? folderId;
  final String title;
  final String documentType;
  final String uploadDateIso;
  final String? examDateIso;
  final String? source;
  final String originalFilename;
  final String mimeType;
  final int fileSizeBytes;
  final String parsedStatus;
  final String contextStatus;
  final String localFilePath;
  final String? ocrText;

  _StoredDocument copyWith({
    String? folderId,
    String? contextStatus,
    String? ocrText,
  }) {
    return _StoredDocument(
      id: id,
      folderId: folderId,
      title: title,
      documentType: documentType,
      uploadDateIso: uploadDateIso,
      examDateIso: examDateIso,
      source: source,
      originalFilename: originalFilename,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      parsedStatus: parsedStatus,
      contextStatus: contextStatus ?? this.contextStatus,
      localFilePath: localFilePath,
      ocrText: ocrText ?? this.ocrText,
    );
  }

  ClinicalDocumentSummary toSummary({String? folderName}) {
    return ClinicalDocumentSummary(
      id: id,
      folderId: folderId,
      folderName: folderName?.isEmpty == true ? null : folderName,
      title: title,
      documentType: documentType,
      uploadDate: DateTime.parse(uploadDateIso),
      examDate: examDateIso == null ? null : DateTime.parse(examDateIso!),
      source: source,
      originalFilename: originalFilename,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      parsedStatus: parsedStatus,
      contextStatus: contextStatus,
      pendingSync: false,
      storageLocation: 'local',
      localFilePath: localFilePath,
    );
  }

  ClinicalDocumentDetail toDetail({
    String? folderName,
    String? parsedStatusOverride,
    double? parsingConfidence,
    String? processingError,
    DateTime? processedAt,
    List<LabPanelItem> labPanels = const [],
    List<ImagingReportItem> imagingReports = const [],
  }) {
    return ClinicalDocumentDetail(
      id: id,
      folderId: folderId,
      folderName: folderName?.isEmpty == true ? null : folderName,
      title: title,
      documentType: documentType,
      uploadDate: DateTime.parse(uploadDateIso),
      examDate: examDateIso == null ? null : DateTime.parse(examDateIso!),
      source: source,
      originalFilename: originalFilename,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      parsedStatus: parsedStatusOverride ?? parsedStatus,
      contextStatus: contextStatus,
      parsingConfidence: parsingConfidence,
      processingError: processingError,
      pendingSync: false,
      fileUrl: localFilePath,
      ocrText: ocrText,
      viewerUrl: null,
      processedAt: processedAt,
      labPanels: labPanels,
      imagingReports: imagingReports,
      storageLocation: 'local',
      localFilePath: localFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folder_id': folderId,
      'title': title,
      'document_type': documentType,
      'upload_date': uploadDateIso,
      'exam_date': examDateIso,
      'source': source,
      'original_filename': originalFilename,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'parsed_status': parsedStatus,
      'context_status': contextStatus,
      'local_file_path': localFilePath,
      'ocr_text': ocrText,
    };
  }

  factory _StoredDocument.fromJson(Map<String, dynamic> json) {
    return _StoredDocument(
      id: json['id'].toString(),
      folderId: json['folder_id'] as String?,
      title: json['title'].toString(),
      documentType: json['document_type']?.toString() ?? 'generic_document',
      uploadDateIso:
          json['upload_date']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      examDateIso: json['exam_date'] as String?,
      source: json['source'] as String?,
      originalFilename: json['original_filename']?.toString() ?? 'document',
      mimeType: json['mime_type']?.toString() ?? 'application/octet-stream',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      parsedStatus: json['parsed_status']?.toString() ?? 'local_only',
      contextStatus: json['context_status']?.toString() ?? 'active',
      localFilePath: json['local_file_path']?.toString() ?? '',
      ocrText: json['ocr_text'] as String?,
    );
  }
}

class _LocalStructuredData {
  const _LocalStructuredData({
    this.parsedStatus,
    this.parsingConfidence,
    this.processingError,
    this.processedAt,
    this.labPanels = const [],
    this.imagingReports = const [],
  });

  final String? parsedStatus;
  final double? parsingConfidence;
  final String? processingError;
  final DateTime? processedAt;
  final List<LabPanelItem> labPanels;
  final List<ImagingReportItem> imagingReports;
}
