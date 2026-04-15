import 'dart:ffi';
import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/network/session_expiry_notifier.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeApiClient extends ApiClient {
  FakeApiClient({required LocalDatabase localDatabase})
    : this._(http.Client(), localDatabase: localDatabase);

  FakeApiClient._(this._client, {required LocalDatabase localDatabase})
    : super(
        client: _client,
        config: defaultAppConfig,
        tokenStorage: SecureTokenStorage(const FlutterSecureStorage()),
        sessionExpiryNotifier: SessionExpiryNotifier(),
        localDatabase: localDatabase,
      );

  final http.Client _client;
  int flushCalls = 0;
  List<dynamic>? documentsResponse;
  Map<String, dynamic>? documentResponse;
  Map<String, dynamic>? uploadResponse;
  Object? nextPutError;
  Object? nextDeleteError;

  void dispose() {
    _client.close();
  }

  @override
  Future<int> flushPendingOperations({int limit = 20}) async {
    flushCalls += 1;
    return 0;
  }

  @override
  Future<List<dynamic>> getJsonList(
    String path, {
    bool authenticated = true,
  }) async {
    if (path == '/api/v1/documents' && documentsResponse != null) {
      return documentsResponse!;
    }
    throw StateError('Unexpected GET list $path');
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    if (path.startsWith('/api/v1/documents/') && documentResponse != null) {
      return documentResponse!;
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = true,
  }) async {
    if (nextPutError != null) {
      throw nextPutError!;
    }
    return <String, dynamic>{
      'document': documentResponse ?? <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<MultipartUploadFile> files,
    bool authenticated = true,
  }) async {
    if (uploadResponse != null) {
      return uploadResponse!;
    }
    throw StateError('Unexpected multipart POST $path');
  }

  @override
  Future<void> delete(String path, {bool authenticated = true}) async {
    if (nextDeleteError != null) {
      throw nextDeleteError!;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hasSqliteLibrary = _hasSqliteLibrary();

  group('DocumentsRepository offline queue', () {
    test('fetchDocuments flushes pending operations before refresh', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      apiClient.documentsResponse = [_sampleDocumentSummaryJson()];
      addTearDown(database.close);
      addTearDown(apiClient.dispose);
      await _setCloudStorageMode(database);

      final repository = DocumentsRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      final documents = await repository.fetchDocuments();
      expect(apiClient.flushCalls, 1);
      expect(documents, hasLength(1));
      expect(documents.single.title, 'Esami marzo');
    });

    test(
      'fetchDocuments falls back to cached data on transport error',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);
        await _setCloudStorageMode(database);

        await database.putCache(
          key: 'documents_list',
          payload: jsonEncode([_sampleDocumentSummaryJson()]),
        );

        final repository = DocumentsRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        final documents = await repository.fetchDocuments();
        expect(apiClient.flushCalls, 1);
        expect(documents, hasLength(1));
        expect(documents.single.title, 'Esami marzo');
      },
    );

    test(
      'fetchDocumentDetail flushes pending operations before refresh',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.documentResponse = _sampleDocumentDetailJson();
        addTearDown(database.close);
        addTearDown(apiClient.dispose);
        await _setCloudStorageMode(database);

        final repository = DocumentsRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        final detail = await repository.fetchDocumentDetail('doc-1');
        expect(apiClient.flushCalls, 1);
        expect(detail.title, 'Referto laboratorio aprile');
      },
    );

    test(
      'fetchDocumentDetail falls back to cached data on transport error',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);
        await _setCloudStorageMode(database);

        await database.putCache(
          key: 'document_detail_doc-1',
          payload: jsonEncode(_sampleDocumentDetailJson()),
        );

        final repository = DocumentsRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        final detail = await repository.fetchDocumentDetail('doc-1');
        expect(apiClient.flushCalls, 1);
        expect(detail.title, 'Referto laboratorio aprile');
        expect(detail.pendingSync, isFalse);
      },
    );

    test(
      'uploadDocument aggiorna la cache documenti senza svuotarla',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.uploadResponse = _sampleUploadResponseJson();
        addTearDown(database.close);
        addTearDown(apiClient.dispose);
        await _setCloudStorageMode(database);

        await database.putCache(
          key: 'documents_list',
          payload: jsonEncode([_sampleDocumentSummaryJson()]),
        );

        final repository = DocumentsRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        final uploaded = await repository.uploadDocument(
          file: const SelectedUploadDocument(
            name: 'nuovo-referto.pdf',
            bytes: [37, 80, 68, 70],
            mimeType: 'application/pdf',
          ),
          fields: const {'title': 'Nuovo referto'},
        );
        final cachedList = await database.readCache('documents_list');
        final cachedItems = jsonDecode(cachedList!) as List<dynamic>;

        expect(apiClient.flushCalls, 1);
        expect(uploaded.id, 'doc-2');
        expect(cachedItems, hasLength(2));
        expect(
          ClinicalDocumentSummary.fromJson(
            cachedItems.last as Map<String, dynamic>,
          ).title,
          'Nuovo referto',
        );
      },
    );

    test(
      'updateDocumentContextStatus queues offline and marks cache pending',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.nextPutError = ApiException('offline', statusCode: 503);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);
        await _setCloudStorageMode(database);

        await database.putCache(
          key: 'documents_list',
          payload: jsonEncode([_sampleDocumentSummaryJson()]),
        );
        await database.putCache(
          key: 'document_detail_doc-1',
          payload: jsonEncode(_sampleDocumentDetailJson()),
        );

        final repository = DocumentsRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        final detail = await repository.updateDocumentContextStatus(
          'doc-1',
          contextStatus: 'old',
        );
        final queued = await database.listPendingOperations();
        final cachedList = await database.readCache('documents_list');
        final cachedDetail = await database.readCache('document_detail_doc-1');

        expect(apiClient.flushCalls, 1);
        expect(detail.contextStatus, 'old');
        expect(detail.pendingSync, isTrue);
        expect(queued, hasLength(1));
        expect(queued.single.method, 'PUT');
        expect(queued.single.path, '/api/v1/documents/doc-1/status');
        final cachedListItems = jsonDecode(cachedList!) as List<dynamic>;
        expect(
          ClinicalDocumentSummary.fromJson(
            cachedListItems.first as Map<String, dynamic>,
          ).contextStatus,
          'old',
        );
        expect(
          ClinicalDocumentSummary.fromJson(
            cachedListItems.first as Map<String, dynamic>,
          ).pendingSync,
          isTrue,
        );
        expect(
          ClinicalDocumentDetail.fromJson(
            jsonDecode(cachedDetail!) as Map<String, dynamic>,
          ).pendingSync,
          isTrue,
        );
      },
    );

    test('deleteDocument queues offline and removes cached entries', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      apiClient.nextDeleteError = ApiException('offline', statusCode: 503);
      addTearDown(database.close);
      addTearDown(apiClient.dispose);
      await _setCloudStorageMode(database);

      await database.putCache(
        key: 'documents_list',
        payload: jsonEncode([_sampleDocumentSummaryJson()]),
      );
      await database.putCache(
        key: 'document_detail_doc-1',
        payload: jsonEncode(_sampleDocumentDetailJson()),
      );

      final repository = DocumentsRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      await repository.deleteDocument('doc-1');
      final queued = await database.listPendingOperations();
      final cachedList = await database.readCache('documents_list');
      final cachedDetail = await database.readCache('document_detail_doc-1');

      expect(apiClient.flushCalls, 1);
      expect(queued, hasLength(1));
      expect(queued.single.method, 'DELETE');
      expect(queued.single.path, '/api/v1/documents/doc-1');
      expect(cachedList, isNotNull);
      expect((jsonDecode(cachedList!) as List<dynamic>), isEmpty);
      expect(cachedDetail, isNull);
    });
  }, skip: !hasSqliteLibrary);
}

Future<void> _setCloudStorageMode(LocalDatabase database) {
  return database.putCache(key: 'document_storage_mode', payload: 'cloud');
}

bool _hasSqliteLibrary() {
  try {
    DynamicLibrary.open('libsqlite3.so');
    return true;
  } catch (_) {
    return false;
  }
}

Map<String, dynamic> _sampleDocumentSummaryJson() {
  return {
    'id': 'doc-1',
    'title': 'Esami marzo',
    'document_type': 'lab_report',
    'upload_date': '2026-03-20T08:00:00Z',
    'exam_date': '2026-03-19',
    'source': 'Laboratorio locale',
    'original_filename': 'esami-marzo.pdf',
    'mime_type': 'application/pdf',
    'file_size_bytes': 182400,
    'parsed_status': 'parsed',
    'context_status': 'active',
    'classification_confidence': 0.91,
    'parsing_confidence': 0.84,
    'processing_error': null,
    'pending_sync': false,
  };
}

Map<String, dynamic> _sampleDocumentDetailJson() {
  return {
    ..._sampleDocumentSummaryJson(),
    'title': 'Referto laboratorio aprile',
    'upload_date': '2026-04-02T09:00:00Z',
    'exam_date': '2026-04-01',
    'file_url': 'patients/demo/lab-aprile.pdf',
    'ocr_text': 'Glucosio 110 mg/dL 70-99',
    'viewer_url': '/api/v1/documents/doc-1/content?token=abc',
    'processed_at': '2026-04-02T09:05:00Z',
    'lab_panels': [
      {
        'id': 'panel-1',
        'panel_name': 'Esami del sangue',
        'panel_date': '2026-04-01',
        'confidence_score': 0.84,
        'results': [
          {
            'id': 'result-1',
            'analyte_name': 'Glucosio',
            'value': '110',
            'unit': 'mg/dL',
            'ref_min': 70,
            'ref_max': 99,
            'abnormal_flag': true,
            'confidence_score': 0.81,
          },
        ],
      },
    ],
    'imaging_reports': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _sampleUploadResponseJson() {
  return {
    'id': 'doc-2',
    'title': 'Nuovo referto',
    'document_type': 'generic_document',
    'upload_date': '2026-03-25T09:00:00Z',
    'exam_date': null,
    'source': null,
    'original_filename': 'nuovo-referto.pdf',
    'mime_type': 'application/pdf',
    'file_size_bytes': 4096,
    'parsed_status': 'pending',
    'context_status': 'active',
    'classification_confidence': null,
    'parsing_confidence': null,
    'processing_error': null,
    'pending_sync': false,
  };
}
