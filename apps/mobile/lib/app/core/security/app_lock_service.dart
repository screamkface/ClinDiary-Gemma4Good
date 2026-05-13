import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockSettings {
  const AppLockSettings({
    required this.enabled,
    required this.pinSet,
    required this.biometricAvailable,
  });

  final bool enabled;
  final bool pinSet;
  final bool biometricAvailable;
}

class AppLockService {
  AppLockService({
    required FlutterSecureStorage secureStorage,
    LocalAuthentication? localAuthentication,
  }) : _secureStorage = secureStorage,
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const _enabledKey = 'app_lock_enabled';
  static const _pinSaltKey = 'app_lock_pin_salt';
  static const _pinHashKey = 'app_lock_pin_hash';

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuthentication;
  final Random _random = Random.secure();

  Future<AppLockSettings> readSettings() async {
    final enabled = await _secureStorage.read(key: _enabledKey) == 'true';
    final pinHash = await _secureStorage.read(key: _pinHashKey);
    return AppLockSettings(
      enabled: enabled,
      pinSet: pinHash != null && pinHash.isNotEmpty,
      biometricAvailable: await canUseBiometrics(),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await _secureStorage.write(key: _enabledKey, value: enabled.toString());
  }

  Future<void> setPin(String pin) async {
    _validatePin(pin);
    final salt = _randomBytes(16);
    final hash = await _hashPin(pin, salt);
    await _secureStorage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _secureStorage.write(key: _pinHashKey, value: base64Encode(hash));
    await setEnabled(true);
  }

  Future<bool> verifyPin(String pin) async {
    final saltPayload = await _secureStorage.read(key: _pinSaltKey);
    final hashPayload = await _secureStorage.read(key: _pinHashKey);
    if (saltPayload == null || hashPayload == null) {
      return false;
    }

    final salt = base64Decode(saltPayload);
    final expected = base64Decode(hashPayload);
    final actual = await _hashPin(pin, salt);
    return _constantTimeEquals(actual, expected);
  }

  Future<void> disable() async {
    await _secureStorage.delete(key: _enabledKey);
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
  }

  Future<bool> canUseBiometrics() async {
    try {
      final biometrics = await _localAuthentication.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return _localAuthentication.authenticate(
        localizedReason: 'Unlock ClinDiary to access local health data.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('Use a 6 digit PIN.');
    }
  }

  Future<List<int>> _hashPin(String pin, List<int> salt) async {
    final digest = await Sha256().hash([...salt, ...utf8.encode(pin)]);
    return digest.bytes;
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}
