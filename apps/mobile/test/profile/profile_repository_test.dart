import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/network/session_expiry_notifier.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/profile/data/profile_repository.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class FakeApiClient extends ApiClient {
  FakeApiClient({required LocalDatabase localDatabase})
    : this._(http.Client(), localDatabase: localDatabase);

  FakeApiClient._(this._client, {required LocalDatabase localDatabase})
    : super(
        client: _client,
        config: defaultAppConfig,
        tokenStorage: SecureTokenStorage(const FlutterSecureStorage()),
        sessionExpiryNotifier: SessionExpiryNotifier(),
        localDatabase: localDatabase,
      );

  final http.Client _client;
  int flushResult = 0;
  Map<String, dynamic>? profileResponse;
  Object? nextPutError;
  Object? nextPatchError;
  Object? nextPostError;
  Object? nextDeleteError;

  void dispose() {
    _client.close();
  }

  @override
  Future<int> flushPendingOperations({int limit = 20}) async {
    return flushResult;
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    if (path == '/api/v1/profile/me' && profileResponse != null) {
      return profileResponse!;
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = true,
  }) async {
    if (nextPutError != null) {
      throw nextPutError!;
    }
    return profileResponse ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = true,
  }) async {
    if (nextPatchError != null) {
      throw nextPatchError!;
    }
    return profileResponse ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    if (nextPostError != null) {
      throw nextPostError!;
    }
    return profileResponse ?? <String, dynamic>{};
  }

  @override
  Future<void> delete(String path, {bool authenticated = true}) async {
    if (nextDeleteError != null) {
      throw nextDeleteError!;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileRepository offline queue', () {
    test('fetchProfile flushes pending operations before refresh', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      apiClient.flushResult = 1;
      apiClient.profileResponse = _sampleBundleJson();
      addTearDown(database.close);
      addTearDown(apiClient.dispose);

      final repository = ProfileRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      final bundle = await repository.fetchProfile();
      expect(bundle.profile.firstName, 'Anna');
    });

    test('fetchProfile falls back to cached data on transport error', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      addTearDown(database.close);
      addTearDown(apiClient.dispose);

      await database.putCache(
        key: 'profile_bundle',
        payload: _encodeBundle(_sampleBundleJson()),
      );

      final repository = ProfileRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      final bundle = await repository.fetchProfile();
      expect(bundle.profile.firstName, 'Anna');
    });

    test(
      'fetchManagedProfiles returns the additional profiles from the bundle',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.profileResponse = _sampleBundleJson()
          ..['managed_profiles'] = [
            {
              'id': 'profile-2',
              'user_id': 'user-1',
              'is_primary': false,
              'first_name': 'Luca',
              'last_name': 'Bianchi',
              'birth_date': '2015-01-01',
              'biological_sex': 'male',
              'height_cm': null,
              'weight_kg': null,
              'smoker': false,
              'alcohol_use': null,
              'activity_level': null,
              'region_code': 'IT-LOM',
              'relationship_label': 'figlio',
              'occupation': null,
              'exercise_habits': null,
              'sleep_pattern': null,
              'symptom_triggers': null,
              'functional_limitations': null,
            },
          ];
        addTearDown(database.close);
        addTearDown(apiClient.dispose);

        final repository = ProfileRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        final profiles = await repository.fetchManagedProfiles();
        expect(profiles, hasLength(1));
        expect(profiles.single.firstName, 'Luca');
        expect(profiles.single.relationshipLabel, 'figlio');
        expect(profiles.single.isPrimary, isFalse);
      },
    );

    test('setActiveProfileId persists the active profile selection', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      addTearDown(database.close);
      addTearDown(apiClient.dispose);

      final repository = ProfileRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      await repository.setActiveProfileId('profile-2');
      expect(await repository.getActiveProfileId(), 'profile-2');
    });

    test(
      'updateProfile queues offline and patches the cached bundle',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.nextPutError = ApiException('offline', statusCode: 503);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);

        await database.putCache(
          key: 'profile_bundle',
          payload: _encodeBundle(_sampleBundleJson()),
        );

        final payload = <String, dynamic>{
          'first_name': 'Maria',
          'occupation': 'Studio clinico',
          'region_code': 'IT-LOM',
        };

        final repository = ProfileRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        await repository.setActiveProfileId('profile-1');
        final bundle = await repository.updateProfile(payload);
        final queued = await database.listPendingOperations();

        expect(bundle.profile.firstName, 'Maria');
        expect(bundle.profile.occupation, 'Studio clinico');
        expect(bundle.profile.regionCode, 'IT-LOM');
        expect(queued, hasLength(1));
        expect(queued.single.path, '/api/v1/profile/me');

        final cached = await database.readCache('profile_bundle::profile-1');
        final decoded = ProfileBundle.fromJson(_decodeBundle(cached!));
        expect(decoded.profile.firstName, 'Maria');
        expect(decoded.profile.occupation, 'Studio clinico');
        expect(decoded.profile.regionCode, 'IT-LOM');
      },
    );

    test(
      'updateProfile replaces older pending operations for the same endpoint',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.nextPutError = ApiException('offline', statusCode: 503);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);

        await database.putCache(
          key: 'profile_bundle',
          payload: _encodeBundle(_sampleBundleJson()),
        );

        final repository = ProfileRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        await repository.setActiveProfileId('profile-1');
        await repository.updateProfile({'first_name': 'Anna'});
        await repository.updateProfile({'first_name': 'Giulia'});

        final queued = await database.listPendingOperations();
        final cached = await database.readCache('profile_bundle::profile-1');
        final decoded = ProfileBundle.fromJson(_decodeBundle(cached!));

        expect(queued, hasLength(1));
        expect(queued.single.path, '/api/v1/profile/me');
        expect(decoded.profile.firstName, 'Giulia');
      },
    );

    test(
      'updateAiPrivacyConsent queues offline and patches the cached bundle',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.nextPatchError = ApiException('offline', statusCode: 503);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);

        await database.putCache(
          key: 'profile_bundle',
          payload: _encodeBundle(_sampleBundleJson()),
        );

        final repository = ProfileRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        await repository.setActiveProfileId('profile-1');
        final bundle = await repository.updateAiPrivacyConsent(true);
        final queued = await database.listPendingOperations();
        final cached = await database.readCache('profile_bundle::profile-1');
        final decoded = ProfileBundle.fromJson(_decodeBundle(cached!));

        expect(bundle.onboarding.aiExternalConsent, isTrue);
        expect(bundle.onboarding.aiExternalConsentedAt, isNotNull);
        expect(queued, hasLength(1));
        expect(queued.single.method, 'PATCH');
        expect(queued.single.path, '/api/v1/profile/privacy/ai');
        expect(decoded.onboarding.aiExternalConsent, isTrue);
        expect(decoded.onboarding.aiExternalConsentedAt, isNotNull);
      },
    );

    test(
      'addVaccination queues offline and marks the record as pending',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.nextPostError = ApiException('offline', statusCode: 503);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);

        await database.putCache(
          key: 'profile_bundle',
          payload: _encodeBundle(_sampleBundleJson()),
        );

        final payload = <String, dynamic>{
          'vaccine_name': 'Influenza',
          'administered_on': '2026-03-25',
          'dose_number': 1,
          'next_due_date': '2026-09-25',
          'provider_name': 'Medico di base',
          'notes': 'Richiamo stagionale',
        };

        final repository = ProfileRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        await repository.setActiveProfileId('profile-1');
        final bundle = await repository.addVaccination(payload);
        final queued = await database.listPendingOperations();

        expect(bundle.vaccinations, hasLength(1));
        expect(bundle.vaccinations.single.vaccineName, 'Influenza');
        expect(bundle.vaccinations.single.pendingSync, isTrue);
        expect(queued, hasLength(1));
        expect(queued.single.path, '/api/v1/profile/vaccinations');
      },
    );

    test(
      'deleteVaccination queues offline and removes cached record',
      () async {
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final apiClient = FakeApiClient(localDatabase: database);
        apiClient.nextDeleteError = ApiException('offline', statusCode: 503);
        addTearDown(database.close);
        addTearDown(apiClient.dispose);

        final baseBundle = _sampleBundleJson();
        baseBundle['vaccinations'] = [
          {
            'id': 'vac-1',
            'vaccine_name': 'Influenza',
            'administered_on': '2026-03-20',
            'dose_number': 1,
            'next_due_date': null,
            'provider_name': 'Medico di base',
            'notes': null,
          },
        ];
        await database.putCache(
          key: 'profile_bundle',
          payload: _encodeBundle(baseBundle),
        );

        final repository = ProfileRepository(
          apiClient: apiClient,
          localDatabase: database,
        );

        await repository.setActiveProfileId('profile-1');
        await repository.deleteVaccination('vac-1');
        final queued = await database.listPendingOperations();
        final cached = await database.readCache('profile_bundle::profile-1');
        final decoded = ProfileBundle.fromJson(_decodeBundle(cached!));

        expect(queued, hasLength(1));
        expect(queued.single.path, '/api/v1/profile/vaccinations/vac-1');
        expect(decoded.vaccinations, isEmpty);
      },
    );
  });
}

Map<String, dynamic> _sampleBundleJson() {
  return {
    'profile': {
      'id': 'profile-1',
      'user_id': 'user-1',
      'is_primary': true,
      'first_name': 'Anna',
      'last_name': 'Bianchi',
      'birth_date': '1990-01-01',
      'biological_sex': 'female',
      'height_cm': 168,
      'weight_kg': 62,
      'smoker': false,
      'alcohol_use': null,
      'activity_level': null,
      'occupation': null,
      'exercise_habits': null,
      'sleep_pattern': null,
      'symptom_triggers': null,
      'functional_limitations': null,
    },
    'onboarding': {
      'health_data_consent': true,
      'consented_at': '2026-03-24T10:00:00Z',
      'ai_external_consent': false,
      'ai_external_consented_at': null,
      'onboarding_completed_at': '2026-03-24T10:01:00Z',
    },
    'allergies': <Map<String, dynamic>>[],
    'medical_conditions': <Map<String, dynamic>>[],
    'medications': <Map<String, dynamic>>[],
    'family_history': <Map<String, dynamic>>[],
    'managed_profiles': <Map<String, dynamic>>[],
    'vaccinations': <Map<String, dynamic>>[],
  };
}

String _encodeBundle(Map<String, dynamic> bundle) {
  return jsonEncode(bundle);
}

Map<String, dynamic> _decodeBundle(String payload) {
  return Map<String, dynamic>.from(jsonDecode(payload) as Map);
}
