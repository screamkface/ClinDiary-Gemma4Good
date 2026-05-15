import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/documents/data/local_lab_text_parser.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local vault saves, searches, and moves documents in local folders',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'clindiary-local-vault-test',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final vault = LocalDocumentVaultService(rootDirectory: root);
      const userScopeId = 'user-1';
      const profileScopeId = 'profile-1';
      final folder = await vault.createFolderForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        name: 'Blood tests',
      );

      final uploaded = await vault.uploadDocumentForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        file: const SelectedUploadDocument(
          name: 'cbc-march.pdf',
          bytes: [37, 80, 68, 70],
          mimeType: 'application/pdf',
        ),
        fields: {
          'title': 'March CBC',
          'source': 'Local lab',
          'folder_id': folder.id,
        },
      );

      expect(uploaded.isLocal, isTrue);
      expect(uploaded.parsedStatus, 'local_only');
      expect(uploaded.folderId, folder.id);

      final archive = await vault.fetchArchiveForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        folderId: folder.id,
      );
      expect(archive.isLocal, isTrue);
      expect(archive.documents, hasLength(1));
      expect(archive.documents.single.title, 'March CBC');

      final search = await vault.fetchArchiveForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        query: 'lab',
      );
      expect(search.documents, hasLength(1));
      expect(search.documents.single.id, uploaded.id);

      final moved = await vault.moveDocumentForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        folderId: null,
      );
      expect(moved.folderId, isNull);

      final rootArchive = await vault.fetchArchiveForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      expect(rootArchive.documents, hasLength(1));
      expect(rootArchive.documents.single.id, uploaded.id);

      await vault.deleteDocumentForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      final afterDelete = await vault.fetchArchiveForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      expect(afterDelete.documents, isEmpty);
    },
  );

  test(
    'local vault encrypts file and index on device and opens with temporary copy',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'clindiary-local-vault-encryption',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final vault = LocalDocumentVaultService(rootDirectory: root);
      const userScopeId = 'user-secure';
      const profileScopeId = 'profile-secure';
      const clearBytes = [37, 80, 68, 70, 45, 115, 101, 99, 114, 101, 116];

      final uploaded = await vault.uploadDocumentForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        file: const SelectedUploadDocument(
          name: 'secret.pdf',
          bytes: clearBytes,
          mimeType: 'application/pdf',
        ),
        fields: const {'title': 'Encrypted document'},
      );

      final detail = await vault.fetchDocumentDetailForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      final encryptedFile = File(detail.localFilePath!);
      final storedBytes = await encryptedFile.readAsBytes();
      expect(storedBytes, isNot(equals(clearBytes)));

      final stateFile = File(
        '${root.path}/user-user-secure/profile-profile-secure/vault-index.json',
      );
      final stateBytes = await stateFile.readAsBytes();
      expect(
        String.fromCharCodes(stateBytes),
        isNot(contains('Encrypted document')),
      );

      final previewPath = await vault.prepareViewerFileForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      final previewBytes = await File(previewPath).readAsBytes();
      expect(previewBytes, clearBytes);
    },
  );

  test('local vault isolates documents by user and profile', () async {
    final root = await Directory.systemTemp.createTemp(
      'clindiary-local-vault-scope-test',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final vault = LocalDocumentVaultService(rootDirectory: root);

    await vault.uploadDocumentForScope(
      userScopeId: 'user-a',
      profileScopeId: 'profile-a',
      file: const SelectedUploadDocument(
        name: 'user-a.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Document A'},
    );

    await vault.uploadDocumentForScope(
      userScopeId: 'user-b',
      profileScopeId: 'profile-b',
      file: const SelectedUploadDocument(
        name: 'user-b.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Document B'},
    );

    final archiveA = await vault.fetchArchiveForScope(
      userScopeId: 'user-a',
      profileScopeId: 'profile-a',
    );
    final archiveB = await vault.fetchArchiveForScope(
      userScopeId: 'user-b',
      profileScopeId: 'profile-b',
    );

    expect(archiveA.documents, hasLength(1));
    expect(archiveA.documents.single.title, 'Document A');
    expect(archiveB.documents, hasLength(1));
    expect(archiveB.documents.single.title, 'Document B');
  });

  test('local vault can delete all documents for a user', () async {
    final root = await Directory.systemTemp.createTemp(
      'clindiary-local-vault-delete-user',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final vault = LocalDocumentVaultService(rootDirectory: root);

    await vault.uploadDocumentForScope(
      userScopeId: 'user-a',
      profileScopeId: 'profile-a',
      file: const SelectedUploadDocument(
        name: 'user-a.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Document A'},
    );
    await vault.uploadDocumentForScope(
      userScopeId: 'user-a',
      profileScopeId: 'profile-b',
      file: const SelectedUploadDocument(
        name: 'user-a-2.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Document B'},
    );

    await vault.deleteAllForUserScope('user-a');

    final archiveA = await vault.fetchArchiveForScope(
      userScopeId: 'user-a',
      profileScopeId: 'profile-a',
    );
    final archiveB = await vault.fetchArchiveForScope(
      userScopeId: 'user-a',
      profileScopeId: 'profile-b',
    );

    expect(archiveA.documents, isEmpty);
    expect(archiveB.documents, isEmpty);
  });

  test('local vault pre-warms parsing in background after upload', () async {
    final root = await Directory.systemTemp.createTemp(
      'clindiary-local-vault-prewarm-test',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final parser = _SpyLabTextParser();
    addTearDown(parser.dispose);
    final vault = LocalDocumentVaultService(
      rootDirectory: root,
      labTextParser: parser,
    );

    const userScopeId = 'user-prewarm';
    const profileScopeId = 'profile-prewarm';
    final uploaded = await vault.uploadDocumentForScope(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
      file: const SelectedUploadDocument(
        name: 'prewarm.txt',
        bytes: [
          71,
          108,
          117,
          99,
          111,
          115,
          101,
          32,
          49,
          50,
          48,
          32,
          109,
          103,
          47,
          100,
          76,
          32,
          55,
          48,
          32,
          45,
          32,
          57,
          57,
        ],
        mimeType: 'text/plain',
      ),
      fields: const {'title': 'Prewarm test', 'document_type': 'lab_report'},
    );

    await parser.waitForFirstCall();
    expect(parser.callCount, 1);

    await vault.fetchDocumentDetailForScope(
      uploaded.id,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    expect(parser.callCount, 1);
  });

  test(
    'local vault persists manual review OCR and structured results',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'clindiary-local-vault-review-prewarm-test',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final parser = _SpyLabTextParser();
      addTearDown(parser.dispose);
      final vault = LocalDocumentVaultService(
        rootDirectory: root,
        labTextParser: parser,
      );

      const userScopeId = 'user-review';
      const profileScopeId = 'profile-review';

      final uploaded = await vault.uploadDocumentForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        file: const SelectedUploadDocument(
          name: 'review.pdf',
          bytes: [37, 80, 68, 70],
          mimeType: 'application/pdf',
        ),
        fields: const {
          'title': 'Initial version',
          'document_type': 'generic_document',
        },
      );

      expect(parser.callCount, 0);

      await vault.submitManualReviewForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        input: const DocumentManualReviewInput(
          title: 'Updated report',
          documentType: 'lab_report',
          ocrText: 'Glucose 120 mg/dL 70 - 99',
          labPanel: ManualLabPanelDraft(
            panelName: 'Manual blood panel',
            results: [
              ManualLabResultDraft(
                analyteName: 'Glucose',
                value: '120',
                unit: 'mg/dL',
                refMin: 70,
                refMax: 99,
                abnormalFlag: true,
              ),
            ],
          ),
        ),
      );

      final detail = await vault.fetchDocumentDetailForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );

      expect(detail.title, 'Updated report');
      expect(detail.documentType, 'lab_report');
      expect(detail.ocrText, 'Glucose 120 mg/dL 70 - 99');
      expect(detail.labPanels, hasLength(1));
      expect(detail.labPanels.single.panelName, 'Manual blood panel');
      expect(detail.labPanels.single.results, hasLength(1));
      expect(detail.labPanels.single.results.single.analyteName, 'Glucose');
      expect(detail.labPanels.single.results.single.abnormalFlag, isTrue);
      expect(parser.callCount, 0);

      final secondRead = await vault.fetchDocumentDetailForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      expect(secondRead.labPanels, hasLength(1));
      expect(secondRead.labPanels.single.panelName, 'Manual blood panel');
    },
  );

  test(
    'local vault flags lab reports without local text as review required',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'clindiary-local-vault-review-required-test',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final vault = LocalDocumentVaultService(rootDirectory: root);
      const userScopeId = 'user-review-required';
      const profileScopeId = 'profile-review-required';

      final uploaded = await vault.uploadDocumentForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        file: const SelectedUploadDocument(
          name: 'blood-report.pdf',
          bytes: [37, 80, 68, 70],
          mimeType: 'application/pdf',
        ),
        fields: const {
          'title': 'Blood panel from phone',
          'document_type': 'lab_report',
        },
      );

      final archive = await vault.fetchArchiveForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      final summary = archive.documents.firstWhere(
        (item) => item.id == uploaded.id,
      );
      expect(summary.parsedStatus, 'review_required');
      expect(summary.processingError, isNotNull);

      final detail = await vault.fetchDocumentDetailForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );
      expect(detail.parsedStatus, 'review_required');
      expect(detail.processingError, isNotNull);
    },
  );

  test(
    'local vault parses lab ranges locally without blocking the UI',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'clindiary-local-vault-parse-test',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      const reportText = '''
    Hemoglobin 11.2 g/dL 12.0 - 16.0 L
    Leukocytes 7.4 x10^3/uL 4.0 - 10.0
    CRP 12 mg/L < 5
''';

      final vault = LocalDocumentVaultService(rootDirectory: root);
      const userScopeId = 'user-parse';
      const profileScopeId = 'profile-parse';

      final uploaded = await vault.uploadDocumentForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        file: SelectedUploadDocument(
          name: 'local-labs.txt',
          bytes: utf8.encode(reportText),
          mimeType: 'text/plain',
        ),
        fields: const {
          'title': 'Local blood tests',
          'document_type': 'lab_report',
        },
      );

      final detail = await vault.fetchDocumentDetailForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );

      expect(detail.parsedStatus, 'parsed');
      expect(detail.labPanels, isNotEmpty);
      final results = detail.labPanels.first.results;

      final hemoglobin = results.firstWhere(
        (item) => item.analyteName.toLowerCase().contains('hemoglobin'),
      );
      final leukocytes = results.firstWhere(
        (item) => item.analyteName.toLowerCase().contains('leukocytes'),
      );
      final crp = results.firstWhere(
        (item) => item.analyteName.toLowerCase().contains('crp'),
      );

      expect(hemoglobin.abnormalFlag, isTrue);
      expect(leukocytes.abnormalFlag, isFalse);
      expect(crp.abnormalFlag, isTrue);
    },
  );

  test(
    'local vault auto-promotes generic blood result uploads to structured labs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'clindiary-local-vault-auto-lab-test',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      const reportText =
          'Esame Risultato Unita Valori di riferimento '
          'Glicemia 109 mg/dL 70 - 100 '
          'Colesterolo LDL 138 mg/dL < 115';

      final vault = LocalDocumentVaultService(rootDirectory: root);
      const userScopeId = 'user-auto-lab';
      const profileScopeId = 'profile-auto-lab';

      final uploaded = await vault.uploadDocumentForScope(
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
        file: SelectedUploadDocument(
          name: 'blood-results.txt',
          bytes: utf8.encode(reportText),
          mimeType: 'text/plain',
        ),
        fields: const {'title': 'Uploaded blood results'},
      );

      final detail = await vault.fetchDocumentDetailForScope(
        uploaded.id,
        userScopeId: userScopeId,
        profileScopeId: profileScopeId,
      );

      expect(detail.documentType, 'lab_report');
      expect(detail.parsedStatus, 'parsed');
      expect(detail.labPanels, hasLength(1));
      final ldl = detail.labPanels.single.results.firstWhere(
        (item) => item.analyteName == 'Colesterolo LDL',
      );
      expect(ldl.abnormalFlag, isTrue);
    },
  );

  test('document query streaming falls back when Gemma times out', () async {
    final root = await Directory.systemTemp.createTemp(
      'clindiary-document-query-fallback-test',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const userScopeId = 'user-query-fallback';
    const profileScopeId = 'profile-query-fallback';
    await database.putCache(key: activeUserIdCacheKey, payload: userScopeId);
    await database.putCache(
      key: activeProfileIdCacheKey,
      payload: profileScopeId,
    );

    final vault = LocalDocumentVaultService(rootDirectory: root);
    await vault.uploadDocumentForScope(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
      file: SelectedUploadDocument(
        name: 'ldl-results.txt',
        bytes: utf8.encode('Colesterolo LDL 138 mg/dL < 115'),
        mimeType: 'text/plain',
      ),
      fields: const {'title': 'LDL follow-up', 'document_type': 'lab_report'},
    );

    final repository = DocumentsRepository(
      localDatabase: database,
      localVaultService: vault,
      onDeviceAiService: _TimingOutAiService(),
    );

    final streamResult = await repository.queryDocumentsStream(
      question: 'Which LDL values are out of range?',
    );

    final streamedAnswer = (await streamResult.answerStream.toList()).join();
    final result = await streamResult.result;

    expect(streamedAnswer, contains('LDL follow-up'));
    expect(result.usedFallback, isTrue);
    expect(result.citations, hasLength(1));
    expect(result.answer, streamedAnswer);
  });
}

class _TimingOutAiService extends OnDeviceAiService {
  @override
  Future<List<double>> generateEmbedding({required String text}) async {
    return const [];
  }

  @override
  Stream<String> generateTextStream({
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    throw Exception('timed out');
  }
}

class _SpyLabTextParser extends LocalLabTextParser {
  int callCount = 0;
  final StreamController<int> _callCountStream =
      StreamController<int>.broadcast();

  @override
  Future<LocalStructuredParseResult> parse({
    required String documentId,
    required String documentType,
    required String title,
    String? examDateIso,
    required String text,
  }) async {
    callCount += 1;
    _callCountStream.add(callCount);
    return const LocalStructuredParseResult.empty();
  }

  Future<void> waitForFirstCall() {
    return waitForCallCount(1);
  }

  Future<void> waitForCallCount(int expected) async {
    if (callCount >= expected) {
      return;
    }
    await _callCountStream.stream
        .firstWhere((value) => value >= expected)
        .timeout(const Duration(seconds: 2));
  }

  Future<void> dispose() async {
    await _callCountStream.close();
  }
}
