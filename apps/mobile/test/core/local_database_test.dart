import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'auth session mantiene il payload tra serializzazione e parsing',
    () async {
      final session = AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        accessTokenExpiresAt: DateTime.utc(2026, 3, 20, 10),
        refreshTokenExpiresAt: DateTime.utc(2026, 3, 21, 10),
        user: const UserSummary(
          id: 'u1',
          email: 'patient@example.com',
          role: 'patient',
          onboardingCompleted: true,
          healthDataConsent: true,
          aiExternalConsent: true,
          authProvider: 'google',
        ),
      );

      final parsed = AuthSession.fromJson(session.toJson());

      expect(parsed.accessToken, 'a');
      expect(parsed.user.onboardingCompleted, isTrue);
      expect(parsed.user.email, 'patient@example.com');
      expect(parsed.user.authProvider, 'google');
      expect(parsed.user.aiExternalConsent, isTrue);
    },
  );

  test('auth session usa password come provider predefinito', () {
    final user = UserSummary.fromJson({
      'id': 'u1',
      'email': 'patient@example.com',
      'role': 'patient',
      'onboarding_completed': false,
      'health_data_consent': false,
    });

    expect(user.authProvider, 'password');
  });

  test('local database salva cache, queue offline e request traces', () async {
    try {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.putCache(key: 'profile', payload: '{"name":"Anna"}');
      await database.enqueuePendingOperation(
        method: 'POST',
        path: '/api/v1/medications/1/log',
        payload: '{"status":"taken"}',
        lastError: 'offline',
      );
      await database.recordTrace(
        method: 'GET',
        path: '/api/v1/profile/me',
        statusCode: 200,
        requestId: 'req-1',
        responseTimeMs: 42.5,
      );

      final cachedProfile = await database.readCache('profile');
      final queued = await database.listPendingOperations();
      final traces = await database.readRecentTraces();

      expect(cachedProfile, '{"name":"Anna"}');
      expect(queued, hasLength(1));
      expect(queued.first.path, '/api/v1/medications/1/log');
      expect(traces, hasLength(1));
      expect(traces.first.requestId, 'req-1');
      expect(traces.first.statusCode, 200);
    } on ArgumentError catch (error) {
      expect(error.toString(), contains('libsqlite3'));
      return;
    }
  });

  test('local database espone una migration strategy per upgrade schema', () {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.migration.onUpgrade, isNotNull);
    expect(database.migration.onCreate, isNotNull);
  });
}
