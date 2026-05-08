import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/demo_seed_data.dart';
import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';

class AuthRepository {
  AuthRepository({
    required SecureTokenStorage tokenStorage,
    required LocalDatabase localDatabase,
    required LocalDocumentVaultService localDocumentVaultService,
    required LocalMedicationReminderService localMedicationReminderService,
    required AppConfig appConfig,
  }) : _tokenStorage = tokenStorage,
       _localDatabase = localDatabase,
       _localDocumentVaultService = localDocumentVaultService,
       _localMedicationReminderService = localMedicationReminderService,
       _appConfig = appConfig;

  final SecureTokenStorage _tokenStorage;
  final LocalDatabase _localDatabase;
  final LocalDocumentVaultService _localDocumentVaultService;
  final LocalMedicationReminderService _localMedicationReminderService;
  final AppConfig _appConfig;

  Future<AuthSession?> restoreSession() async {
    return _appConfig.hackathonDemoMode
        ? _restoreOrCreateDemoSession()
        : _restoreOrCreateLocalSession();
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _appConfig.hackathonDemoMode
        ? _restoreOrCreateDemoSession()
        : _restoreOrCreateLocalSession();
  }

  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    return _appConfig.hackathonDemoMode
        ? _restoreOrCreateDemoSession()
        : _restoreOrCreateLocalSession();
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    return _appConfig.hackathonDemoMode
        ? _restoreOrCreateDemoSession()
        : _restoreOrCreateLocalSession();
  }

  Future<void> logout() async {
    await clearLocalSessionState();
  }

  Future<void> clearLocalSessionState() async {
    await _localMedicationReminderService.cancelAllMedicationReminders();
    await _tokenStorage.clear();
    await _localDatabase.clearPendingOperations();
    await _localDatabase.clearCache();
    await _localDatabase.clearRequestTraces();
  }

  Future<void> deleteAccount({required String confirmationText}) async {
    final session = await _tokenStorage.readSession();
    await clearLocalSessionState();
    if (session != null) {
      await _localDocumentVaultService.deleteAllForUserScope(session.user.id);
    }
  }

  Future<void> updateUser(UserSummary user) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      return;
    }
    await _tokenStorage.saveSession(session.copyWith(user: user));
    await _localDatabase.putCache(key: activeUserIdCacheKey, payload: user.id);
  }

  Future<String?> requestPasswordReset(String email) async {
    // No-op in local-only mode.
    return null;
  }

  Future<AuthSession> _restoreOrCreateDemoSession() async {
    final session =
        await _tokenStorage.readSession() ?? DemoSeedData.createDemoSession();
    await _tokenStorage.saveSession(session);
    await _persistSessionContext(session);
    await _localDatabase.putCache(
      key: activeProfileIdCacheKey,
      payload: DemoSeedData.primaryProfileId,
    );
    await DemoSeedData.ensureSeeded(
      _localDatabase,
      localDocumentVaultService: _localDocumentVaultService,
    );
    return session;
  }

  Future<AuthSession> _restoreOrCreateLocalSession() async {
    final restored = await _tokenStorage.readSession();
    final session = restored ?? await _createLocalSession();
    await _tokenStorage.saveSession(session);
    await _persistSessionContext(session);
    await _ensureActiveLocalProfile();
    return session;
  }

  Future<AuthSession> _createLocalSession() async {
    final now = DateTime.now().toUtc();
    final onboardingCompleted = await _hasCompletedLocalOnboarding();
    return AuthSession(
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
      accessTokenExpiresAt: now.add(const Duration(days: 3650)),
      refreshTokenExpiresAt: now.add(const Duration(days: 3650)),
      user: UserSummary(
        id: 'local-user-001',
        email: 'local@clindiary.app',
        role: 'patient',
        onboardingCompleted: onboardingCompleted,
        healthDataConsent: onboardingCompleted,
        authProvider: 'local_device',
      ),
    );
  }

  Future<bool> _hasCompletedLocalOnboarding() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    final candidates = <String>[
      if (activeProfileId != null && activeProfileId.trim().isNotEmpty)
        'profile_bundle::${activeProfileId.trim()}',
      'profile_bundle::pending-profile',
      'profile_bundle',
    ];

    for (final key in candidates) {
      final payload = await _localDatabase.readCache(key);
      if (payload == null || payload.trim().isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        final onboarding = decoded['onboarding'] as Map<String, dynamic>?;
        if (onboarding?['health_data_consent'] == true &&
            onboarding?['onboarding_completed_at'] != null) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<void> _ensureActiveLocalProfile() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    if (activeProfileId != null && activeProfileId.trim().isNotEmpty) {
      return;
    }
    await _localDatabase.putCache(
      key: activeProfileIdCacheKey,
      payload: 'pending-profile',
    );
  }

  Future<void> _persistSessionContext(AuthSession session) {
    return _localDatabase.putCache(
      key: activeUserIdCacheKey,
      payload: session.user.id,
    );
  }
}
