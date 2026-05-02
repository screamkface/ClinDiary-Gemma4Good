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
  }) : _tokenStorage = tokenStorage,
       _localDatabase = localDatabase,
       _localDocumentVaultService = localDocumentVaultService,
       _localMedicationReminderService = localMedicationReminderService;

  final SecureTokenStorage _tokenStorage;
  final LocalDatabase _localDatabase;
  final LocalDocumentVaultService _localDocumentVaultService;
  final LocalMedicationReminderService _localMedicationReminderService;

  Future<AuthSession?> restoreSession() async {
    return _restoreOrCreateBypassSession();
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _restoreOrCreateBypassSession();
  }

  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    return _restoreOrCreateBypassSession();
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    return _restoreOrCreateBypassSession();
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

  Future<AuthSession> _restoreOrCreateBypassSession() async {
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

  Future<void> _persistSessionContext(AuthSession session) {
    return _localDatabase.putCache(
      key: activeUserIdCacheKey,
      payload: session.user.id,
    );
  }
}
