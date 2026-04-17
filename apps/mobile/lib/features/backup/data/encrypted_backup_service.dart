import 'dart:convert';
import 'dart:typed_data';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/documents/data/local_document_vault_cipher.dart';
import 'package:clindiary/features/dossier/data/dossier_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class EncryptedBackupUploadResult {
  const EncryptedBackupUploadResult({
    required this.fileId,
    required this.fileName,
    required this.modifiedAt,
    required this.encryptedBytes,
  });

  final String fileId;
  final String fileName;
  final DateTime modifiedAt;
  final int encryptedBytes;
}

class EncryptedBackupRestoreResult {
  const EncryptedBackupRestoreResult({
    required this.fileId,
    required this.fileName,
    required this.modifiedAt,
    required this.encryptedBytes,
  });

  final String fileId;
  final String fileName;
  final DateTime modifiedAt;
  final int encryptedBytes;
}

class EncryptedBackupService {
  EncryptedBackupService({
    required AppConfig appConfig,
    required DossierRepository dossierRepository,
    required LocalDatabase localDatabase,
    required FlutterSecureStorage secureStorage,
    required http.Client httpClient,
  }) : _appConfig = appConfig,
       _dossierRepository = dossierRepository,
       _localDatabase = localDatabase,
       _httpClient = httpClient,
       _cipher = LocalDocumentVaultCipher(secureStorage: secureStorage),
       _googleAuthClientId = appConfig.googleAuthClientId.trim();

  static const String _driveScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const String _backupPrefix = 'clindiary-backup';
  static const String _backupContext = 'backup:v1';

  final AppConfig _appConfig;
  final DossierRepository _dossierRepository;
  final LocalDatabase _localDatabase;
  final http.Client _httpClient;
  final LocalDocumentVaultCipher _cipher;
  final String _googleAuthClientId;

  Future<void>? _googleSignInInitialization;

  Future<EncryptedBackupUploadResult> uploadEncryptedSnapshotToDrive() async {
    _ensureBackupAllowed();
    final accessToken = await _requestDriveAccessToken();
    final activeUserId =
        await _localDatabase.readCache(activeUserIdCacheKey) ?? 'anonymous';
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );

    final snapshotBytes = await _dossierRepository.exportDossierJson();
    final snapshotMap = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(snapshotBytes)) as Map<String, dynamic>,
    );

    final now = DateTime.now().toUtc();
    final envelope = <String, dynamic>{
      'version': 1,
      'created_at': now.toIso8601String(),
      'profile_id': activeProfileId,
      'snapshot': snapshotMap,
      'source': 'clindiary_local_only',
    };

    final encryptedBytes = await _cipher.encryptBytes(
      utf8.encode(jsonEncode(envelope)),
      userScopeId: activeUserId,
      context: _backupContext,
    );

    final fileName = _buildBackupFileName(activeProfileId, now);
    final metadata = await _uploadEncryptedFile(
      accessToken: accessToken,
      fileName: fileName,
      encryptedBytes: encryptedBytes,
    );

    return EncryptedBackupUploadResult(
      fileId: metadata.id,
      fileName: metadata.name,
      modifiedAt: metadata.modifiedAt,
      encryptedBytes: encryptedBytes.length,
    );
  }

  Future<EncryptedBackupRestoreResult> restoreLatestEncryptedSnapshotFromDrive({
    bool replaceExisting = true,
  }) async {
    _ensureBackupAllowed();
    final accessToken = await _requestDriveAccessToken();
    final activeUserId =
        await _localDatabase.readCache(activeUserIdCacheKey) ?? 'anonymous';

    final latest = await _findLatestBackup(accessToken);
    if (latest == null) {
      throw ApiException(
        'No encrypted backup found in Google Drive app data folder.',
        statusCode: 404,
      );
    }

    final encryptedBytes = await _downloadBackupBytes(
      accessToken: accessToken,
      fileId: latest.id,
    );
    final decryptedBytes = await _cipher.decryptBytes(
      encryptedBytes,
      userScopeId: activeUserId,
      context: _backupContext,
    );

    final decoded = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>,
    );
    final snapshot = decoded['snapshot'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(decoded['snapshot'] as Map<String, dynamic>)
        : decoded;

    await _dossierRepository.importDossier(
      snapshot: snapshot,
      replaceExisting: replaceExisting,
    );

    return EncryptedBackupRestoreResult(
      fileId: latest.id,
      fileName: latest.name,
      modifiedAt: latest.modifiedAt,
      encryptedBytes: encryptedBytes.length,
    );
  }

  void _ensureBackupAllowed() {
    if (!_appConfig.localOnlyMode) {
      throw ApiException(
        'Encrypted Drive backup is available only while local-only mode is active.',
        statusCode: 409,
      );
    }
    if (_googleAuthClientId.isEmpty) {
      throw ApiException(
        'Google authentication is not configured. Missing GOOGLE_AUTH_CLIENT_ID.',
        statusCode: 400,
      );
    }
  }

  Future<String> _requestDriveAccessToken() async {
    await _ensureGoogleSignInInitialized();

    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'openid', 'profile'],
      );
      final authorization =
          await account.authorizationClient.authorizationForScopes(const [
            _driveScope,
          ]) ??
          await account.authorizationClient.authorizeScopes(const [
            _driveScope,
          ]);
      final accessToken = authorization.accessToken;
      if (accessToken.isEmpty) {
        throw ApiException(
          'Unable to obtain a Google Drive access token. Re-authenticate and try again.',
          statusCode: 401,
        );
      }
      return accessToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw ApiException('Google sign-in canceled by user.', statusCode: 400);
      }
      throw ApiException(
        'Google sign-in failed: ${error.description ?? error.code.name}.',
        statusCode: 401,
      );
    }
  }

  Future<void> _ensureGoogleSignInInitialized() {
    final existing = _googleSignInInitialization;
    if (existing != null) {
      return existing;
    }
    _googleSignInInitialization = GoogleSignIn.instance.initialize(
      serverClientId: _googleAuthClientId,
    );
    return _googleSignInInitialization!;
  }

  Future<_DriveFileMetadata> _uploadEncryptedFile({
    required String accessToken,
    required String fileName,
    required List<int> encryptedBytes,
  }) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,modifiedTime,size',
    );
    final boundary =
        'clindiary_backup_${DateTime.now().millisecondsSinceEpoch}';

    final metadata = jsonEncode(<String, dynamic>{
      'name': fileName,
      'parents': const ['appDataFolder'],
      'mimeType': 'application/octet-stream',
    });

    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(
        utf8.encode(
          'Content-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n',
        ),
      )
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'))
      ..add(encryptedBytes)
      ..add(utf8.encode('\r\n--$boundary--'));

    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Content-Type'] = 'multipart/related; boundary=$boundary'
      ..bodyBytes = body.takeBytes();

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Drive upload failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = Map<String, dynamic>.from(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return _DriveFileMetadata.fromJson(json);
  }

  Future<_DriveFileMetadata?> _findLatestBackup(String accessToken) async {
    final query = "name contains '$_backupPrefix-' and trashed = false";
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': query,
      'orderBy': 'modifiedTime desc',
      'pageSize': '1',
      'fields': 'files(id,name,modifiedTime,size)',
    });

    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Drive list failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final payload = Map<String, dynamic>.from(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    final files = (payload['files'] as List<dynamic>? ?? const []);
    if (files.isEmpty) {
      return null;
    }
    return _DriveFileMetadata.fromJson(
      Map<String, dynamic>.from(files.first as Map),
    );
  }

  Future<List<int>> _downloadBackupBytes({
    required String accessToken,
    required String fileId,
  }) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
    );
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Drive download failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  String _buildBackupFileName(String? profileId, DateTime timestampUtc) {
    final normalizedProfile = (profileId ?? 'default').replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return '$_backupPrefix-$normalizedProfile-${timestampUtc.millisecondsSinceEpoch}.cdbk';
  }
}

class _DriveFileMetadata {
  const _DriveFileMetadata({
    required this.id,
    required this.name,
    required this.modifiedAt,
  });

  final String id;
  final String name;
  final DateTime modifiedAt;

  factory _DriveFileMetadata.fromJson(Map<String, dynamic> json) {
    return _DriveFileMetadata(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'backup.cdbk',
      modifiedAt:
          DateTime.tryParse(json['modifiedTime']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}
