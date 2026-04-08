import 'dart:async';
import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/network/session_expiry_notifier.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _InMemoryTokenStorage extends SecureTokenStorage {
  _InMemoryTokenStorage(AuthSession? session)
      : _session = session,
        super(const FlutterSecureStorage());

  AuthSession? _session;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

class _TestClient extends http.BaseClient {
  _TestClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

http.StreamedResponse _jsonResponse(Object body, int statusCode) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

AuthSession _buildSession({
  required String accessToken,
  required DateTime accessExpiresAt,
  required String refreshToken,
  required DateTime refreshExpiresAt,
}) {
  return AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiresAt: accessExpiresAt,
    refreshTokenExpiresAt: refreshExpiresAt,
    user: const UserSummary(
      id: 'user-1',
      email: 'patient@example.com',
      role: 'patient',
      onboardingCompleted: true,
      healthDataConsent: true,
      authProvider: 'password',
    ),
  );
}

void main() {
  test(
    'refreshSession is shared across concurrent authenticated requests',
    () async {
      final sessionExpiryNotifier = SessionExpiryNotifier();
      addTearDown(sessionExpiryNotifier.dispose);

      final storage = _InMemoryTokenStorage(
        _buildSession(
          accessToken: 'expired-access',
          accessExpiresAt: DateTime.utc(2025, 1, 1),
          refreshToken: 'refresh-token',
          refreshExpiresAt: DateTime.utc(2099, 1, 1),
        ),
      );

      final refreshRelease = Completer<void>();
      var refreshCalls = 0;
      final client = _TestClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls += 1;
          if (refreshCalls == 1 && !refreshRelease.isCompleted) {
            await refreshRelease.future;
          }
          return _jsonResponse(
            {
              'access_token': 'fresh-access',
              'refresh_token': 'fresh-refresh',
              'access_token_expires_at': '2099-01-01T00:00:00.000Z',
              'refresh_token_expires_at': '2099-01-02T00:00:00.000Z',
              'user': {
                'id': 'user-1',
                'email': 'patient@example.com',
                'role': 'patient',
                'onboarding_completed': true,
                'health_data_consent': true,
                'auth_provider': 'password',
              },
            },
            200,
          );
        }

        if (request.url.path == '/api/v1/documents') {
          final authorization =
              request.headers['authorization'] ?? request.headers['Authorization'];
          expect(authorization, 'Bearer fresh-access');
          return _jsonResponse([{'id': 'doc-1'}], 200);
        }

        throw StateError('Unexpected request ${request.method} ${request.url}');
      });

      final apiClient = ApiClient(
        client: client,
        config: const AppConfig(apiBaseUrl: 'http://example.com'),
        tokenStorage: storage,
        sessionExpiryNotifier: sessionExpiryNotifier,
      );

      final firstRequest = apiClient.getJsonList('/api/v1/documents');
      final secondRequest = apiClient.getJsonList('/api/v1/documents');

      await Future<void>.delayed(Duration.zero);
      expect(refreshCalls, 1);

      refreshRelease.complete();
      final results = await Future.wait([firstRequest, secondRequest]);

      expect(results, hasLength(2));
      expect(refreshCalls, 1);

      final savedSession = await storage.readSession();
      expect(savedSession?.accessToken, 'fresh-access');
    },
  );

  test('expired refresh session is cleared and notifies listeners', () async {
    final sessionExpiryNotifier = SessionExpiryNotifier();
    addTearDown(sessionExpiryNotifier.dispose);

    var sessionExpiredSignals = 0;
    sessionExpiryNotifier.addListener(() {
      sessionExpiredSignals += 1;
    });

    final storage = _InMemoryTokenStorage(
      _buildSession(
        accessToken: 'expired-access',
        accessExpiresAt: DateTime.utc(2025, 1, 1),
        refreshToken: 'expired-refresh',
        refreshExpiresAt: DateTime.utc(2025, 1, 1),
      ),
    );

    var networkCalls = 0;
    final client = _TestClient((request) async {
      networkCalls += 1;
      throw StateError('Unexpected network call ${request.method} ${request.url}');
    });

    final apiClient = ApiClient(
      client: client,
      config: const AppConfig(apiBaseUrl: 'http://example.com'),
      tokenStorage: storage,
      sessionExpiryNotifier: sessionExpiryNotifier,
    );

    await expectLater(
      apiClient.refreshSession(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Sessione scaduta'),
        ),
      ),
    );

    expect(networkCalls, 0);
    expect(sessionExpiredSignals, 1);
    expect(await storage.readSession(), isNull);
  });
}