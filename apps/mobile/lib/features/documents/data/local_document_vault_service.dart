import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clindiary/features/documents/data/local_lab_text_parser.dart';
import 'package:clindiary/features/documents/data/local_document_vault_cipher.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';
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
  final Map<String, LocalDocumentParseProgress> _parseProgressByDocumentId = {};
  final StreamController<LocalDocumentParseProgressSnapshot>
  _parseProgressController =
      StreamController<LocalDocumentParseProgressSnapshot>.broadcast();

  Stream<LocalDocumentParseProgressSnapshot> watchParseProgress() async* {
    yield currentParseProgress();
    yield* _parseProgressController.stream;
  }

  LocalDocumentParseProgressSnapshot currentParseProgress() {
    return LocalDocumentParseProgressSnapshot(
      updatedAt: DateTime.now().toUtc(),
      items: Map<String, LocalDocumentParseProgress>.unmodifiable(
        _parseProgressByDocumentId,
      ),
    );
  }

  void dispose() {
    _parseProgressController.close();
  }

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
    final documents = await _buildSummariesForDocuments(
      state.documents,
      folders: folders,
    );
    documents.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
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

    final filteredDocuments = state.documents
        .where((document) {
          if (normalizedQuery != null) {
            return _matchesSearch(document, folders, normalizedQuery);
          }
          return document.folderId == currentFolder?.id;
        })
        .toList(growable: false);
    final documentsForView = await _buildSummariesForDocuments(
      filteredDocuments,
      folders: folders,
    );
    documentsForView.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));

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
      throw Exception('Local files can be at most 10 MB.');
    }

    final state = await _loadState(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    if (state.documents.length >= maxDocumentCount) {
      throw Exception('You have reached the local limit of 80 documents.');
    }
    final totalBytes = state.documents.fold<int>(
      0,
      (sum, item) => sum + item.fileSizeBytes,
    );
    if (totalBytes + file.bytes.length > maxTotalBytes) {
      throw Exception('You have reached the local storage limit of 200 MB.');
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
    final inferredOcrText = await _inferTextPreview(file);
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
      throw Exception('Folder name cannot be empty.');
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
      throw Exception('A folder with this name already exists in this path.');
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
      throw Exception('Document not found.');
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
      throw Exception('Invalid document status.');
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
      throw Exception('Document not found.');
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
      throw Exception('Local file not found.');
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
    final manualStructuredData = _manualStructuredData(document);
    if (manualStructuredData != null) {
      return manualStructuredData;
    }

    final text = document.ocrText?.trim();
    if (text == null || text.isEmpty) {
      if (_requiresStructuredData(document.documentType)) {
        return const _LocalStructuredData(
          parsedStatus: 'review_required',
          processingError:
              'No text could be extracted locally from this file. Open Manual review to add values.',
        );
      }
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

    _setParseProgress(documentId: document.id, stage: 'queued', progress: 0.1);
    final future = _enqueueParseTask(() async {
      _setParseProgress(
        documentId: document.id,
        stage: 'processing',
        progress: 0.45,
      );
      final parsed = await _labTextParser.parse(
        documentId: document.id,
        documentType: document.documentType,
        title: document.title,
        examDateIso: document.examDateIso,
        text: text,
      );
      final isParsed = parsed.parsedStatus == 'parsed';
      final requiresStructuredData = _requiresStructuredData(
        document.documentType,
      );

      _setParseProgress(
        documentId: document.id,
        stage: 'finalizing',
        progress: 0.9,
      );

      return _LocalStructuredData(
        parsedStatus: isParsed
            ? 'parsed'
            : (requiresStructuredData ? 'review_required' : null),
        parsingConfidence: parsed.parsingConfidence,
        processingError: isParsed || !requiresStructuredData
            ? null
            : 'Automatic parsing could not detect structured values. Open Manual review to confirm them.',
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
      _clearParseProgress(document.id);
    }
  }

  Future<_LocalStructuredData> _resolveStructuredDataForView(
    _StoredDocument document,
  ) async {
    final manualStructuredData = _manualStructuredData(document);
    if (manualStructuredData != null) {
      return manualStructuredData;
    }

    final text = document.ocrText?.trim();
    if (text == null || text.isEmpty) {
      if (_requiresStructuredData(document.documentType)) {
        return const _LocalStructuredData(
          parsedStatus: 'review_required',
          processingError:
              'No text could be extracted locally from this file. Open Manual review to add values.',
        );
      }
      return const _LocalStructuredData();
    }

    final cacheKey = _structuredDataCacheKey(document, text);
    final cached = _structuredDataCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    if (!_inFlightStructuredData.containsKey(cacheKey)) {
      unawaited(_resolveStructuredData(document));
    }

    return const _LocalStructuredData(
      parsedStatus: 'processing',
      processingError: 'Local parsing is running in background.',
    );
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

    _clearParseProgress(documentId);
  }

  void _clearStructuredDataCache() {
    _structuredDataCache.clear();
    _inFlightStructuredData.clear();
    _parseProgressByDocumentId.clear();
    _emitParseProgress();
  }

  void _setParseProgress({
    required String documentId,
    required String stage,
    required double progress,
  }) {
    final normalizedProgress = progress.clamp(0.0, 1.0);
    _parseProgressByDocumentId[documentId] = LocalDocumentParseProgress(
      documentId: documentId,
      stage: stage,
      progress: normalizedProgress,
      updatedAt: DateTime.now().toUtc(),
    );
    _emitParseProgress();
  }

  void _clearParseProgress(String documentId) {
    if (_parseProgressByDocumentId.remove(documentId) != null) {
      _emitParseProgress();
    }
  }

  void _emitParseProgress() {
    if (_parseProgressController.isClosed) {
      return;
    }
    _parseProgressController.add(currentParseProgress());
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

  _LocalStructuredData? _manualStructuredData(_StoredDocument document) {
    if (document.manualLabPanels.isNotEmpty) {
      return _LocalStructuredData(
        parsedStatus: 'reviewed',
        parsingConfidence: 1,
        processedAt: DateTime.now().toUtc(),
        labPanels: document.manualLabPanels,
      );
    }
    if (document.manualImagingReports.isNotEmpty) {
      return _LocalStructuredData(
        parsedStatus: 'reviewed',
        parsingConfidence: 1,
        processedAt: DateTime.now().toUtc(),
        imagingReports: document.manualImagingReports,
      );
    }
    return null;
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
      orElse: () => throw Exception('Folder not found.'),
    );
  }

  _StoredDocument _requireDocument(_LocalVaultState state, String documentId) {
    return state.documents.firstWhere(
      (document) => document.id == documentId,
      orElse: () => throw Exception('Document not found.'),
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

  Future<List<ClinicalDocumentSummary>> _buildSummariesForDocuments(
    List<_StoredDocument> documents, {
    required Map<String, _StoredFolder> folders,
  }) {
    return Future.wait(
      documents.map(
        (document) => _toSummaryWithStructuredData(document, folders: folders),
      ),
    );
  }

  Future<ClinicalDocumentSummary> _toSummaryWithStructuredData(
    _StoredDocument document, {
    required Map<String, _StoredFolder> folders,
  }) async {
    final folderName = _pathLabelForFolder(document.folderId, folders);
    if (!_requiresStructuredData(document.documentType)) {
      return document.toSummary(folderName: folderName);
    }

    final structuredData = await _resolveStructuredDataForView(document);
    return document.toSummary(
      folderName: folderName,
      parsedStatusOverride: structuredData.parsedStatus,
      parsingConfidence: structuredData.parsingConfidence,
      processingError: structuredData.processingError,
    );
  }

  bool _requiresStructuredData(String documentType) {
    final normalizedType = documentType.trim().toLowerCase();
    return normalizedType == 'lab_report' || normalizedType == 'imaging_report';
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
    final normalizedDocumentType =
        _normalizeText(input.documentType) ?? document.documentType;
    final manualLabPanels = input.labPanel == null
        ? (normalizedDocumentType == 'lab_report'
              ? document.manualLabPanels
              : const <LabPanelItem>[])
        : <LabPanelItem>[
            _manualLabPanelToItem(
              documentId: document.id,
              panel: input.labPanel!,
            ),
          ];
    final manualImagingReports = input.imagingReport == null
        ? (normalizedDocumentType == 'imaging_report'
              ? document.manualImagingReports
              : const <ImagingReportItem>[])
        : <ImagingReportItem>[
            _manualImagingReportToItem(
              documentId: document.id,
              report: input.imagingReport!,
            ),
          ];
    final updatedExamDateIso = _resolveManualReviewExamDateIso(
      requestedExamDate: input.examDate,
      existingExamDateIso: document.examDateIso,
    );

    return _StoredDocument(
      id: document.id,
      folderId: document.folderId,
      title: _normalizeText(input.title) ?? document.title,
      documentType: normalizedDocumentType,
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
      manualLabPanels: manualLabPanels,
      manualImagingReports: manualImagingReports,
    );
  }

  LabPanelItem _manualLabPanelToItem({
    required String documentId,
    required ManualLabPanelDraft panel,
  }) {
    return LabPanelItem(
      id: 'manual-lab-panel-$documentId-1',
      panelName: panel.panelName,
      panelDate: _tryParseDate(panel.panelDate),
      confidenceScore: 1,
      results: panel.results
          .asMap()
          .entries
          .map(
            (entry) => LabResultItem(
              id: 'manual-lab-result-$documentId-${entry.key + 1}',
              analyteName: entry.value.analyteName,
              value: entry.value.value,
              unit: entry.value.unit,
              refMin: entry.value.refMin,
              refMax: entry.value.refMax,
              abnormalFlag: entry.value.abnormalFlag,
              confidenceScore: 1,
            ),
          )
          .toList(growable: false),
    );
  }

  ImagingReportItem _manualImagingReportToItem({
    required String documentId,
    required ManualImagingReportDraft report,
  }) {
    return ImagingReportItem(
      id: 'manual-imaging-report-$documentId-1',
      examType: _normalizeText(report.examType),
      bodyPart: _normalizeText(report.bodyPart),
      reportText: report.reportText,
      impression: _normalizeText(report.impression),
      confidenceScore: 1,
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
      throw Exception('Exam date is invalid. Use ISO format YYYY-MM-DD.');
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

  Future<String?> _inferTextPreview(SelectedUploadDocument file) async {
    final mimeType = file.mimeType.toLowerCase();
    final extension = path.extension(file.name).toLowerCase();
    final isTextMime = mimeType.startsWith('text/');
    final isTxtFile = extension == '.txt';

    if (isTextMime || isTxtFile) {
      final text = utf8.decode(file.bytes, allowMalformed: true).trim();
      return text.isEmpty ? null : text;
    }

    final isPdf = mimeType == 'application/pdf' || extension == '.pdf';
    if (!isPdf) {
      return null;
    }

    return _extractPdfTextPreview(file);
  }

  Future<String?> _extractPdfTextPreview(SelectedUploadDocument file) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }

    File? tempFile;
    try {
      final tempDir = await _temporaryExtractionDirectory();
      final tempName =
          'vault-parse-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(16)}.pdf';
      tempFile = File(path.join(tempDir.path, tempName));
      await tempFile.writeAsBytes(file.bytes, flush: true);

      final document = await PDFDoc.fromPath(tempFile.path);
      final extracted = await document.text;
      return _normalizeExtractedText(extracted);
    } catch (_) {
      return null;
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {
          // Ignore cleanup failures for temporary extraction files.
        }
      }
    }
  }

  String? _normalizeExtractedText(String rawText) {
    final normalized = rawText
        .replaceAll('\u0000', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length <= 50000) {
      return normalized;
    }
    return normalized.substring(0, 50000);
  }

  Future<Directory> _temporaryExtractionDirectory() async {
    if (_rootDirectory != null) {
      final directory = Directory(
        path.join(_rootDirectory.path, '.tmp_extract'),
      );
      return directory.create(recursive: true);
    }

    final tempRoot = await getTemporaryDirectory();
    final directory = Directory(
      path.join(tempRoot.path, 'clindiary_tmp_extract'),
    );
    return directory.create(recursive: true);
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
    this.manualLabPanels = const [],
    this.manualImagingReports = const [],
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
  final List<LabPanelItem> manualLabPanels;
  final List<ImagingReportItem> manualImagingReports;

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
      manualLabPanels: manualLabPanels,
      manualImagingReports: manualImagingReports,
    );
  }

  ClinicalDocumentSummary toSummary({
    String? folderName,
    String? parsedStatusOverride,
    double? parsingConfidence,
    String? processingError,
  }) {
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
      parsedStatus: parsedStatusOverride ?? parsedStatus,
      contextStatus: contextStatus,
      parsingConfidence: parsingConfidence,
      processingError: processingError,
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
      'manual_lab_panels': manualLabPanels
          .map(_labPanelItemToJson)
          .toList(growable: false),
      'manual_imaging_reports': manualImagingReports
          .map(_imagingReportItemToJson)
          .toList(growable: false),
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
      manualLabPanels: (json['manual_lab_panels'] as List<dynamic>? ?? const [])
          .map((item) => LabPanelItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      manualImagingReports:
          (json['manual_imaging_reports'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ImagingReportItem.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
    );
  }
}

Map<String, dynamic> _labResultItemToJson(LabResultItem item) {
  return {
    'id': item.id,
    'analyte_name': item.analyteName,
    'value': item.value,
    if (item.unit != null) 'unit': item.unit,
    if (item.refMin != null) 'ref_min': item.refMin,
    if (item.refMax != null) 'ref_max': item.refMax,
    if (item.abnormalFlag != null) 'abnormal_flag': item.abnormalFlag,
    if (item.confidenceScore != null) 'confidence_score': item.confidenceScore,
  };
}

Map<String, dynamic> _labPanelItemToJson(LabPanelItem item) {
  return {
    'id': item.id,
    'panel_name': item.panelName,
    if (item.panelDate != null) 'panel_date': item.panelDate!.toIso8601String(),
    if (item.confidenceScore != null) 'confidence_score': item.confidenceScore,
    'results': item.results.map(_labResultItemToJson).toList(growable: false),
  };
}

Map<String, dynamic> _imagingReportItemToJson(ImagingReportItem item) {
  return {
    'id': item.id,
    if (item.examType != null) 'exam_type': item.examType,
    if (item.bodyPart != null) 'body_part': item.bodyPart,
    'report_text': item.reportText,
    if (item.impression != null) 'impression': item.impression,
    if (item.confidenceScore != null) 'confidence_score': item.confidenceScore,
  };
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

class LocalDocumentParseProgressSnapshot {
  const LocalDocumentParseProgressSnapshot({
    required this.updatedAt,
    required this.items,
  });

  const LocalDocumentParseProgressSnapshot.empty()
    : updatedAt = null,
      items = const <String, LocalDocumentParseProgress>{};

  final DateTime? updatedAt;
  final Map<String, LocalDocumentParseProgress> items;

  int get activeCount => items.length;

  LocalDocumentParseProgress? progressFor(String documentId) {
    return items[documentId];
  }
}

class LocalDocumentParseProgress {
  const LocalDocumentParseProgress({
    required this.documentId,
    required this.stage,
    required this.progress,
    required this.updatedAt,
  });

  final String documentId;
  final String stage;
  final double progress;
  final DateTime updatedAt;
}
