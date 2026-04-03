import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalDocumentVaultCipher {
  LocalDocumentVaultCipher({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage;

  static const String _magic = 'CDV1';
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const String _keyPrefix = 'clindiary.local_vault_key';

  final FlutterSecureStorage? _secureStorage;
  final Random _random = Random.secure();
  final Cipher _cipher = AesGcm.with256bits();
  final Map<String, String> _memoryKeys = <String, String>{};

  bool isEncrypted(List<int> bytes) {
    if (bytes.length < _magic.length + _nonceLength + _macLength) {
      return false;
    }
    return ascii.decode(bytes.sublist(0, _magic.length), allowInvalid: true) ==
        _magic;
  }

  Future<List<int>> encryptState(
    String plainText, {
    required String userScopeId,
    String? profileScopeId,
  }) {
    return encryptBytes(
      utf8.encode(plainText),
      userScopeId: userScopeId,
      context: 'state:${profileScopeId ?? 'default'}',
    );
  }

  Future<String> decryptState(
    List<int> bytes, {
    required String userScopeId,
    String? profileScopeId,
  }) async {
    final decrypted = await decryptBytes(
      bytes,
      userScopeId: userScopeId,
      context: 'state:${profileScopeId ?? 'default'}',
    );
    return utf8.decode(decrypted);
  }

  Future<List<int>> encryptDocument(
    List<int> bytes, {
    required String userScopeId,
    required String documentId,
    String? profileScopeId,
  }) {
    return encryptBytes(
      bytes,
      userScopeId: userScopeId,
      context: 'document:${profileScopeId ?? 'default'}:$documentId',
    );
  }

  Future<List<int>> decryptDocument(
    List<int> bytes, {
    required String userScopeId,
    required String documentId,
    String? profileScopeId,
  }) {
    return decryptBytes(
      bytes,
      userScopeId: userScopeId,
      context: 'document:${profileScopeId ?? 'default'}:$documentId',
    );
  }

  Future<void> deleteKeyForUserScope(String userScopeId) async {
    final storageKey = '$_keyPrefix::$userScopeId';
    if (_secureStorage != null) {
      try {
        await _secureStorage.delete(key: storageKey);
        return;
      } catch (_) {
        _memoryKeys.remove(storageKey);
        return;
      }
    }
    _memoryKeys.remove(storageKey);
  }

  Future<List<int>> encryptBytes(
    List<int> plainBytes, {
    required String userScopeId,
    required String context,
  }) async {
    final key = await _getOrCreateKey(userScopeId);
    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _cipher.encrypt(
      plainBytes,
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(context),
    );

    return Uint8List.fromList([
      ...ascii.encode(_magic),
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ]);
  }

  Future<List<int>> decryptBytes(
    List<int> storedBytes, {
    required String userScopeId,
    required String context,
  }) async {
    if (!isEncrypted(storedBytes)) {
      return storedBytes;
    }

    final key = await _getOrCreateKey(userScopeId);
    final headerLength = _magic.length;
    final nonceStart = headerLength;
    final macStart = nonceStart + _nonceLength;
    final cipherStart = macStart + _macLength;
    final nonce = storedBytes.sublist(nonceStart, macStart);
    final mac = storedBytes.sublist(macStart, cipherStart);
    final cipherText = storedBytes.sublist(cipherStart);

    return _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
      aad: utf8.encode(context),
    );
  }

  Future<SecretKey> _getOrCreateKey(String userScopeId) async {
    final storageKey = '$_keyPrefix::$userScopeId';
    final existing = await _readKey(storageKey);
    if (existing != null && existing.isNotEmpty) {
      return SecretKey(base64Decode(existing));
    }

    final freshBytes = _randomBytes(32);
    await _writeKey(storageKey, base64Encode(freshBytes));
    return SecretKey(freshBytes);
  }

  Future<String?> _readKey(String key) async {
    if (_secureStorage != null) {
      try {
        return _secureStorage.read(key: key);
      } catch (_) {
        return _memoryKeys[key];
      }
    }
    return _memoryKeys[key];
  }

  Future<void> _writeKey(String key, String value) async {
    if (_secureStorage != null) {
      try {
        await _secureStorage.write(key: key, value: value);
        return;
      } catch (_) {
        _memoryKeys[key] = value;
        return;
      }
    }
    _memoryKeys[key] = value;
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}
