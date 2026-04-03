import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SecureTokenStorage tokenStorage,
    required LocalDatabase localDatabase,
    required AppConfig appConfig,
    required LocalDocumentVaultService localDocumentVaultService,
    required LocalMedicationReminderService localMedicationReminderService,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage,
       _localDatabase = localDatabase,
       _googleAuthClientId = appConfig.googleAuthClientId.trim(),
       _localDocumentVaultService = localDocumentVaultService,
       _localMedicationReminderService = localMedicationReminderService;

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;
  final LocalDatabase _localDatabase;
  final String _googleAuthClientId;
  final LocalDocumentVaultService _localDocumentVaultService;
  final LocalMedicationReminderService _localMedicationReminderService;
  Future<void>? _googleSignInInitialization;

  Future<AuthSession?> restoreSession() async {
    final session = await _tokenStorage.readSession();
    if (session != null) {
      await _persistSessionContext(session);
    }
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/auth/login',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(response);
    await _tokenStorage.saveSession(session);
    await _persistSessionContext(session);
    return session;
  }

  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final response = await _apiClient.postJson(
      '/api/v1/auth/google',
      authenticated: false,
      body: {'id_token': idToken},
    );
    final session = AuthSession.fromJson(response);
    await _tokenStorage.saveSession(session);
    await _persistSessionContext(session);
    return session;
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/auth/register',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(response);
    await _tokenStorage.saveSession(session);
    await _persistSessionContext(session);
    return session;
  }

  Future<void> logout() async {
    final session = await _tokenStorage.readSession();
    try {
      if (session != null && session.user.authProvider == 'google') {
        await _disconnectGoogleSession();
      }
      if (session != null) {
        await _apiClient.postJson(
          '/api/v1/auth/logout',
          authenticated: false,
          body: {'refresh_token': session.refreshToken},
        );
      }
    } catch (_) {
      // Logout best-effort: we still clear the local session below.
    } finally {
      await _localMedicationReminderService.cancelAllMedicationReminders();
      await _tokenStorage.clear();
      await _localDatabase.clearPendingOperations();
      await _localDatabase.clearCache();
      await _localDatabase.clearRequestTraces();
    }
  }

  Future<void> deleteAccount({required String confirmationText}) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      return;
    }

    await _apiClient.postJson(
      '/api/v1/auth/account/delete',
      body: {'confirmation_text': confirmationText},
    );

    try {
      if (session.user.authProvider == 'google') {
        await _disconnectGoogleSession();
      }
    } catch (_) {
      // Continue local cleanup even if provider disconnect fails.
    }

    await _localMedicationReminderService.cancelAllMedicationReminders();
    await _localDocumentVaultService.deleteAllForUserScope(session.user.id);
    await _tokenStorage.clear();
    await _localDatabase.clearPendingOperations();
    await _localDatabase.clearCache();
    await _localDatabase.clearRequestTraces();
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
    final response = await _apiClient.postJson(
      '/api/v1/auth/password-reset/request',
      authenticated: false,
      body: {'email': email},
    );
    return response['preview_token'] as String?;
  }

  Future<void> _disconnectGoogleSession() async {
    if (_googleAuthClientId.isEmpty) {
      return;
    }
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore Google sign-out failures during app logout.
      }
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

  Future<void> _persistSessionContext(AuthSession session) {
    return _localDatabase.putCache(
      key: activeUserIdCacheKey,
      payload: session.user.id,
    );
  }
}
