import 'dart:io';

import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local vault salva, cerca e sposta documenti in cartelle locali', () async {
    final root = await Directory.systemTemp.createTemp('clindiary-local-vault-test');
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
      name: 'Esami sangue',
    );

    final uploaded = await vault.uploadDocumentForScope(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
      file: const SelectedUploadDocument(
        name: 'emocromo-marzo.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: {
        'title': 'Emocromo marzo',
        'source': 'Laboratorio locale',
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
    expect(archive.documents.single.title, 'Emocromo marzo');

    final search = await vault.fetchArchiveForScope(
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
      query: 'laboratorio',
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
  });

  test('local vault cifra file e indice sul dispositivo ma li apre con copia temporanea', () async {
    final root = await Directory.systemTemp.createTemp('clindiary-local-vault-encryption');
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
        name: 'segreto.pdf',
        bytes: clearBytes,
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Documento cifrato'},
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
    expect(String.fromCharCodes(stateBytes), isNot(contains('Documento cifrato')));

    final previewPath = await vault.prepareViewerFileForScope(
      uploaded.id,
      userScopeId: userScopeId,
      profileScopeId: profileScopeId,
    );
    final previewBytes = await File(previewPath).readAsBytes();
    expect(previewBytes, clearBytes);
  });

  test('local vault separa i documenti per utente e profilo', () async {
    final root = await Directory.systemTemp.createTemp('clindiary-local-vault-scope-test');
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
        name: 'utente-a.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Documento A'},
    );

    await vault.uploadDocumentForScope(
      userScopeId: 'user-b',
      profileScopeId: 'profile-b',
      file: const SelectedUploadDocument(
        name: 'utente-b.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Documento B'},
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
    expect(archiveA.documents.single.title, 'Documento A');
    expect(archiveB.documents, hasLength(1));
    expect(archiveB.documents.single.title, 'Documento B');
  });

  test('local vault puo cancellare tutti i documenti di un utente', () async {
    final root = await Directory.systemTemp.createTemp('clindiary-local-vault-delete-user');
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
        name: 'utente-a.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Documento A'},
    );
    await vault.uploadDocumentForScope(
      userScopeId: 'user-a',
      profileScopeId: 'profile-b',
      file: const SelectedUploadDocument(
        name: 'utente-a-2.pdf',
        bytes: [37, 80, 68, 70],
        mimeType: 'application/pdf',
      ),
      fields: const {'title': 'Documento B'},
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
}
