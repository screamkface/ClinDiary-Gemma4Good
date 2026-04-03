import 'dart:convert';
import 'dart:io';

import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SecureTokenStorage {
  SecureTokenStorage(this._storage);

  static const _sessionKey = 'auth_session';
  static const _fallbackFileName = 'auth_session.json';

  final FlutterSecureStorage _storage;

  Future<AuthSession?> readSession() async {
    final payload = await _readPayload();
    if (payload == null || payload.isEmpty) {
      return null;
    }
    return AuthSession.fromJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  Future<void> saveSession(AuthSession session) async {
    final payload = jsonEncode(session.toJson());
    try {
      await _storage.write(key: _sessionKey, value: payload);
    } catch (_) {
      await _writeFallback(payload);
      return;
    }

    if (Platform.isLinux) {
      await _writeFallback(payload);
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {
      // Best-effort clear; fallback file is removed below.
    }
    await _deleteFallback();
  }

  Future<String?> _readPayload() async {
    try {
      final payload = await _storage.read(key: _sessionKey);
      if (payload != null && payload.isNotEmpty) {
        return payload;
      }
    } catch (_) {
      // Fall back to file-based storage on desktop runtimes without secret service.
    }
    return _readFallback();
  }

  Future<String?> _readFallback() async {
    final file = await _fallbackFile();
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> _writeFallback(String payload) async {
    final file = await _fallbackFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(payload, flush: true);
  }

  Future<void> _deleteFallback() async {
    final file = await _fallbackFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _fallbackFile() async {
    final directory = await _fallbackDirectory();
    return File(p.join(directory.path, _fallbackFileName));
  }

  Future<Directory> _fallbackDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return Directory.systemTemp.createTemp('clindiary-auth');
    }
  }
}
