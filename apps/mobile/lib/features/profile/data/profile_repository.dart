import 'dart:convert';

import 'package:clindiary/app/core/json/json_deep_copy.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';

class ProfileRepository {
  ProfileRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _cacheKey = 'profile_bundle';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<ProfileBundle> fetchProfile() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson('/api/v1/profile/me');
      await _ensureActiveProfileSelection(response);
      await _writeBundle(response);
      return ProfileBundle.fromJson(response);
    } on ApiException {
      final cached = await _readCachedBundleJson();
      if (cached == null) rethrow;
      return ProfileBundle.fromJson(cached);
    } catch (error) {
      final cached = await _readCachedBundleJson();
      if (cached == null) rethrow;
      return ProfileBundle.fromJson(cached);
    }
  }

  Future<ProfileBundle> completeOnboarding({
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.postJson(
        '/api/v1/profile/onboarding/complete',
        body: payload,
      );
      await _ensureActiveProfileSelection(response);
      await _writeBundle(response);
      return ProfileBundle.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/onboarding/complete',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _applyOnboardingPatch(bundle, payload),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/onboarding/complete',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _applyOnboardingPatch(bundle, payload),
      );
    }
  }

  Future<ProfileBundle> updateProfile(Map<String, dynamic> payload) async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.putJson(
        '/api/v1/profile/me',
        body: payload,
      );
      await _writeBundle(response);
      return ProfileBundle.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'PUT',
        path: '/api/v1/profile/me',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _applyProfilePatch(bundle, payload),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'PUT',
        path: '/api/v1/profile/me',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _applyProfilePatch(bundle, payload),
      );
    }
  }

  Future<ProfileBundle> updateAiPrivacyConsent(bool enabled) async {
    final payload = {'ai_external_consent': enabled};
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.patchJson(
        '/api/v1/profile/privacy/ai',
        body: payload,
      );
      await _writeBundle(response);
      return ProfileBundle.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'PATCH',
        path: '/api/v1/profile/privacy/ai',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _applyAiPrivacyPatch(bundle, payload),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'PATCH',
        path: '/api/v1/profile/privacy/ai',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _applyAiPrivacyPatch(bundle, payload),
      );
    }
  }

  Future<ProfileBundle> createManagedProfile(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _apiClient.postJson('/api/v1/profile/profiles', body: payload);
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/profiles',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _appendManagedProfile(bundle, payload),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/profiles',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _appendManagedProfile(bundle, payload),
      );
    }
  }

  Future<List<PatientProfile>> fetchManagedProfiles() async {
    final bundle = await fetchProfile();
    return bundle.managedProfiles;
  }

  Future<void> setActiveProfileId(String profileId) {
    return _localDatabase.putCache(
      key: activeProfileIdCacheKey,
      payload: profileId,
    );
  }

  Future<String?> getActiveProfileId() {
    return _localDatabase.readCache(activeProfileIdCacheKey);
  }

  Future<ProfileBundle> addAllergy(Map<String, dynamic> payload) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.postJson('/api/v1/profile/allergies', body: payload);
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/allergies',
        body: payload,
        lastError: error.message,
        patch: (bundle) =>
            _appendResource(bundle, 'allergies', _buildPendingAllergy(payload)),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/allergies',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) =>
            _appendResource(bundle, 'allergies', _buildPendingAllergy(payload)),
      );
    }
  }

  Future<ProfileBundle> addCondition(Map<String, dynamic> payload) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.postJson('/api/v1/profile/conditions', body: payload);
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/conditions',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _appendResource(
          bundle,
          'medical_conditions',
          _buildPendingCondition(payload),
        ),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/conditions',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _appendResource(
          bundle,
          'medical_conditions',
          _buildPendingCondition(payload),
        ),
      );
    }
  }

  Future<ProfileBundle> addMedication(Map<String, dynamic> payload) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.postJson('/api/v1/profile/medications', body: payload);
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/medications',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _appendResource(
          bundle,
          'medications',
          _buildPendingMedication(payload),
        ),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/medications',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _appendResource(
          bundle,
          'medications',
          _buildPendingMedication(payload),
        ),
      );
    }
  }

  Future<ProfileBundle> addFamilyHistory(Map<String, dynamic> payload) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.postJson(
        '/api/v1/profile/family-history',
        body: payload,
      );
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/family-history',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _appendResource(
          bundle,
          'family_history',
          _buildPendingFamilyHistory(payload),
        ),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/family-history',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _appendResource(
          bundle,
          'family_history',
          _buildPendingFamilyHistory(payload),
        ),
      );
    }
  }

  Future<ProfileBundle> addVaccination(Map<String, dynamic> payload) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.postJson('/api/v1/profile/vaccinations', body: payload);
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/vaccinations',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _appendResource(
          bundle,
          'vaccinations',
          _buildPendingVaccination(payload),
        ),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/vaccinations',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _appendResource(
          bundle,
          'vaccinations',
          _buildPendingVaccination(payload),
        ),
      );
    }
  }

  Future<ProfileBundle> addClinicalEpisode(Map<String, dynamic> payload) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.postJson('/api/v1/profile/problems', body: payload);
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/problems',
        body: payload,
        lastError: error.message,
        patch: (bundle) => _appendResource(
          bundle,
          'clinical_episodes',
          _buildPendingClinicalEpisode(payload),
        ),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'POST',
        path: '/api/v1/profile/problems',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) => _appendResource(
          bundle,
          'clinical_episodes',
          _buildPendingClinicalEpisode(payload),
        ),
      );
    }
  }

  Future<ProfileBundle> updateVaccination(
    String vaccinationId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.putJson(
        '/api/v1/profile/vaccinations/$vaccinationId',
        body: payload,
      );
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'PUT',
        path: '/api/v1/profile/vaccinations/$vaccinationId',
        body: payload,
        lastError: error.message,
        patch: (bundle) =>
            _upsertVaccinationResource(bundle, vaccinationId, payload),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'PUT',
        path: '/api/v1/profile/vaccinations/$vaccinationId',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) =>
            _upsertVaccinationResource(bundle, vaccinationId, payload),
      );
    }
  }

  Future<ProfileBundle> updateClinicalEpisode(
    String episodeId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.putJson(
        '/api/v1/profile/problems/$episodeId',
        body: payload,
      );
      return fetchProfile();
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueBundleMutation(
        method: 'PUT',
        path: '/api/v1/profile/problems/$episodeId',
        body: payload,
        lastError: error.message,
        patch: (bundle) =>
            _upsertClinicalEpisodeResource(bundle, episodeId, payload),
      );
    } catch (error) {
      return _queueBundleMutation(
        method: 'PUT',
        path: '/api/v1/profile/problems/$episodeId',
        body: payload,
        lastError: error.toString(),
        patch: (bundle) =>
            _upsertClinicalEpisodeResource(bundle, episodeId, payload),
      );
    }
  }

  Future<void> deleteAllergy(String allergyId) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.delete('/api/v1/profile/allergies/$allergyId');
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/allergies/$allergyId',
        body: const {},
        lastError: error.message,
        patch: (bundle) => _removeResource(bundle, 'allergies', allergyId),
      );
    } catch (error) {
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/allergies/$allergyId',
        body: const {},
        lastError: error.toString(),
        patch: (bundle) => _removeResource(bundle, 'allergies', allergyId),
      );
    }
  }

  Future<void> deleteCondition(String conditionId) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.delete('/api/v1/profile/conditions/$conditionId');
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/conditions/$conditionId',
        body: const {},
        lastError: error.message,
        patch: (bundle) =>
            _removeResource(bundle, 'medical_conditions', conditionId),
      );
    } catch (error) {
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/conditions/$conditionId',
        body: const {},
        lastError: error.toString(),
        patch: (bundle) =>
            _removeResource(bundle, 'medical_conditions', conditionId),
      );
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.delete('/api/v1/profile/medications/$medicationId');
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/medications/$medicationId',
        body: const {},
        lastError: error.message,
        patch: (bundle) => _removeResource(bundle, 'medications', medicationId),
      );
    } catch (error) {
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/medications/$medicationId',
        body: const {},
        lastError: error.toString(),
        patch: (bundle) => _removeResource(bundle, 'medications', medicationId),
      );
    }
  }

  Future<void> deleteFamilyHistory(String familyHistoryId) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.delete(
        '/api/v1/profile/family-history/$familyHistoryId',
      );
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/family-history/$familyHistoryId',
        body: const {},
        lastError: error.message,
        patch: (bundle) =>
            _removeResource(bundle, 'family_history', familyHistoryId),
      );
    } catch (error) {
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/family-history/$familyHistoryId',
        body: const {},
        lastError: error.toString(),
        patch: (bundle) =>
            _removeResource(bundle, 'family_history', familyHistoryId),
      );
    }
  }

  Future<void> deleteVaccination(String vaccinationId) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.delete('/api/v1/profile/vaccinations/$vaccinationId');
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/vaccinations/$vaccinationId',
        body: const {},
        lastError: error.message,
        patch: (bundle) =>
            _removeResource(bundle, 'vaccinations', vaccinationId),
      );
    } catch (error) {
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/vaccinations/$vaccinationId',
        body: const {},
        lastError: error.toString(),
        patch: (bundle) =>
            _removeResource(bundle, 'vaccinations', vaccinationId),
      );
    }
  }

  Future<void> deleteClinicalEpisode(String episodeId) async {
    try {
      await _apiClient.flushPendingOperations();
      await _apiClient.delete('/api/v1/profile/problems/$episodeId');
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/problems/$episodeId',
        body: const {},
        lastError: error.message,
        patch: (bundle) =>
            _removeResource(bundle, 'clinical_episodes', episodeId),
      );
    } catch (error) {
      await _queueBundleMutation(
        method: 'DELETE',
        path: '/api/v1/profile/problems/$episodeId',
        body: const {},
        lastError: error.toString(),
        patch: (bundle) =>
            _removeResource(bundle, 'clinical_episodes', episodeId),
      );
    }
  }

  Future<void> _writeBundle(Map<String, dynamic> bundle) {
    return _localDatabase.putCache(
      key: _cacheKeyForActiveProfile(bundle),
      payload: jsonEncode(bundle),
    );
  }

  Future<void> _ensureActiveProfileSelection(
    Map<String, dynamic> bundle,
  ) async {
    final current = await getActiveProfileId();
    if (current != null && current.trim().isNotEmpty) {
      return;
    }
    final profile = bundle['profile'] as Map<String, dynamic>?;
    final profileId = profile?['id']?.toString();
    if (profileId != null && profileId.isNotEmpty) {
      await setActiveProfileId(profileId);
    }
  }

  Future<Map<String, dynamic>?> _readCachedBundleJson() async {
    final activeProfileId = await getActiveProfileId();
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      final scopedCache = await _localDatabase.readCache(
        _cacheKeyForProfileId(normalizedActiveId),
      );
      if (scopedCache != null) {
        return Map<String, dynamic>.from(
          jsonDecode(scopedCache) as Map<String, dynamic>,
        );
      }
      final legacyCache = await _localDatabase.readCache(_cacheKey);
      if (legacyCache != null) {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(legacyCache) as Map<String, dynamic>,
        );
        final cachedProfileId = decoded['profile'] is Map<String, dynamic>
            ? (decoded['profile'] as Map<String, dynamic>)['id']?.toString()
            : null;
        if (cachedProfileId == normalizedActiveId) {
          return decoded;
        }
      }
      return null;
    }
    final cached = await _localDatabase.readCache(_cacheKey);
    if (cached == null) {
      return null;
    }
    return Map<String, dynamic>.from(
      jsonDecode(cached) as Map<String, dynamic>,
    );
  }

  Future<ProfileBundle> _queueBundleMutation({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required String lastError,
    required Map<String, dynamic> Function(Map<String, dynamic> bundle) patch,
  }) async {
    await _apiClient.enqueueJsonOperation(
      method: method,
      path: path,
      body: body,
      lastError: lastError,
      replaceExisting: true,
    );
    final cached = await _readCachedBundleJson();
    final updated = patch(
      cached == null ? _bundleTemplateJson() : _cloneBundleJson(cached),
    );
    await _writeBundle(updated);
    return ProfileBundle.fromJson(updated);
  }

  Map<String, dynamic> _cloneBundleJson(Map<String, dynamic> bundle) {
    return deepCopyJsonMap(bundle);
  }

  Map<String, dynamic> _bundleTemplateJson() {
    return {
      'profile': _templateProfileJson(),
      'onboarding': _templateOnboardingJson(),
      'allergies': <Map<String, dynamic>>[],
      'medical_conditions': <Map<String, dynamic>>[],
      'medications': <Map<String, dynamic>>[],
      'family_history': <Map<String, dynamic>>[],
      'vaccinations': <Map<String, dynamic>>[],
      'clinical_episodes': <Map<String, dynamic>>[],
    };
  }

  String _cacheKeyForProfileId(String profileId) {
    return '$_cacheKey::$profileId';
  }

  String _cacheKeyForActiveProfile(Map<String, dynamic> bundle) {
    final profile = bundle['profile'] as Map<String, dynamic>?;
    final profileId = profile?['id']?.toString();
    if (profileId != null && profileId.isNotEmpty) {
      return _cacheKeyForProfileId(profileId);
    }
    return _cacheKey;
  }

  Map<String, dynamic> _templateProfileJson() {
    return {
      'id': 'pending-profile',
      'user_id': 'pending-user',
      'first_name': null,
      'last_name': null,
      'birth_date': null,
      'biological_sex': null,
      'height_cm': null,
      'weight_kg': null,
      'smoker': false,
      'former_smoker': false,
      'smoking_pack_years': null,
      'years_since_quitting': null,
      'alcohol_use': null,
      'activity_level': null,
      'postmenopausal': false,
      'fragility_fracture_history': false,
      'falls_last_year': null,
      'feels_unsteady': false,
      'sexually_active': null,
      'new_or_multiple_partners': false,
      'partner_with_sti': false,
      'sex_with_men': false,
      'sti_or_exposure_concerns': false,
      'trying_to_conceive': false,
      'currently_pregnant': false,
      'taking_folic_acid': false,
      'region_code': null,
      'occupation': null,
      'exercise_habits': null,
      'sleep_pattern': null,
      'symptom_triggers': null,
      'functional_limitations': null,
    };
  }

  Map<String, dynamic> _templateOnboardingJson() {
    return {
      'health_data_consent': false,
      'consented_at': null,
      'ai_external_consent': false,
      'ai_external_consented_at': null,
      'onboarding_completed_at': null,
    };
  }

  Map<String, dynamic> _applyProfilePatch(
    Map<String, dynamic> bundle,
    Map<String, dynamic> payload,
  ) {
    final profile = Map<String, dynamic>.from(
      bundle['profile'] as Map<String, dynamic>? ?? _templateProfileJson(),
    );
    for (final key in const [
      'first_name',
      'last_name',
      'birth_date',
      'biological_sex',
      'height_cm',
      'weight_kg',
      'smoker',
      'former_smoker',
      'smoking_pack_years',
      'years_since_quitting',
      'alcohol_use',
      'activity_level',
      'postmenopausal',
      'fragility_fracture_history',
      'falls_last_year',
      'feels_unsteady',
      'sexually_active',
      'new_or_multiple_partners',
      'partner_with_sti',
      'sex_with_men',
      'sti_or_exposure_concerns',
      'trying_to_conceive',
      'currently_pregnant',
      'taking_folic_acid',
      'region_code',
      'occupation',
      'exercise_habits',
      'sleep_pattern',
      'symptom_triggers',
      'functional_limitations',
    ]) {
      if (payload.containsKey(key)) {
        profile[key] = payload[key];
      }
    }
    bundle['profile'] = profile;
    return bundle;
  }

  Map<String, dynamic> _applyOnboardingPatch(
    Map<String, dynamic> bundle,
    Map<String, dynamic> payload,
  ) {
    _applyProfilePatch(bundle, payload);
    final onboarding = Map<String, dynamic>.from(
      bundle['onboarding'] as Map<String, dynamic>? ??
          _templateOnboardingJson(),
    );
    onboarding['health_data_consent'] =
        payload['health_data_consent'] as bool? ?? true;
    onboarding['ai_external_consent'] =
        payload['ai_external_consent'] as bool? ?? false;
    final now = DateTime.now().toUtc().toIso8601String();
    onboarding['consented_at'] = now;
    if (onboarding['ai_external_consent'] == true) {
      onboarding['ai_external_consented_at'] = now;
    }
    onboarding['onboarding_completed_at'] = now;
    bundle['onboarding'] = onboarding;
    return bundle;
  }

  Map<String, dynamic> _applyAiPrivacyPatch(
    Map<String, dynamic> bundle,
    Map<String, dynamic> payload,
  ) {
    final onboarding = Map<String, dynamic>.from(
      bundle['onboarding'] as Map<String, dynamic>? ??
          _templateOnboardingJson(),
    );
    final enabled = payload['ai_external_consent'] as bool? ?? false;
    onboarding['ai_external_consent'] = enabled;
    if (enabled) {
      onboarding['ai_external_consented_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    }
    bundle['onboarding'] = onboarding;
    return bundle;
  }

  Map<String, dynamic> _appendResource(
    Map<String, dynamic> bundle,
    String key,
    Map<String, dynamic> item,
  ) {
    final items = _readResourceList(bundle, key)..add(item);
    bundle[key] = items;
    return bundle;
  }

  Map<String, dynamic> _appendManagedProfile(
    Map<String, dynamic> bundle,
    Map<String, dynamic> payload,
  ) {
    final managed =
        (bundle['managed_profiles'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    managed.add(_buildPendingManagedProfile(bundle, payload));
    bundle['managed_profiles'] = managed;
    return bundle;
  }

  Map<String, dynamic> _buildPendingManagedProfile(
    Map<String, dynamic> bundle,
    Map<String, dynamic> payload,
  ) {
    final activeProfile = Map<String, dynamic>.from(
      bundle['profile'] as Map<String, dynamic>? ?? _templateProfileJson(),
    );
    return {
      'id': _pendingId('managed-profile'),
      'user_id': activeProfile['user_id'] ?? 'pending-user',
      'is_primary': false,
      'first_name': payload['first_name'],
      'last_name': payload['last_name'],
      'birth_date': payload['birth_date'],
      'biological_sex': payload['biological_sex'],
      'height_cm': payload['height_cm'],
      'weight_kg': payload['weight_kg'],
      'smoker': payload['smoker'] as bool? ?? false,
      'former_smoker': payload['former_smoker'] as bool? ?? false,
      'postmenopausal': payload['postmenopausal'] as bool? ?? false,
      'fragility_fracture_history':
          payload['fragility_fracture_history'] as bool? ?? false,
      'feels_unsteady': payload['feels_unsteady'] as bool? ?? false,
      'new_or_multiple_partners':
          payload['new_or_multiple_partners'] as bool? ?? false,
      'partner_with_sti': payload['partner_with_sti'] as bool? ?? false,
      'sex_with_men': payload['sex_with_men'] as bool? ?? false,
      'sti_or_exposure_concerns':
          payload['sti_or_exposure_concerns'] as bool? ?? false,
      'trying_to_conceive': payload['trying_to_conceive'] as bool? ?? false,
      'currently_pregnant': payload['currently_pregnant'] as bool? ?? false,
      'taking_folic_acid': payload['taking_folic_acid'] as bool? ?? false,
      'region_code': payload['region_code'] ?? activeProfile['region_code'],
      'relationship_label':
          payload['relationship_label'] ?? payload['relationship'],
      'occupation': payload['occupation'],
      'exercise_habits': payload['exercise_habits'],
      'sleep_pattern': payload['sleep_pattern'],
      'symptom_triggers': payload['symptom_triggers'],
      'functional_limitations': payload['functional_limitations'],
      'pending_sync': true,
    };
  }

  Map<String, dynamic> _removeResource(
    Map<String, dynamic> bundle,
    String key,
    String id,
  ) {
    final items = _readResourceList(bundle, key)
      ..removeWhere((existing) => existing['id'].toString() == id);
    bundle[key] = items;
    return bundle;
  }

  Map<String, dynamic> _upsertVaccinationResource(
    Map<String, dynamic> bundle,
    String vaccinationId,
    Map<String, dynamic> payload,
  ) {
    final items = _readResourceList(bundle, 'vaccinations');
    final index = items.indexWhere(
      (existing) => existing['id'].toString() == vaccinationId,
    );
    final current = index == -1
        ? <String, dynamic>{'id': vaccinationId}
        : items[index];
    final updated = Map<String, dynamic>.from(current);
    updated['id'] = vaccinationId;
    for (final key in const [
      'vaccine_name',
      'administered_on',
      'dose_number',
      'next_due_date',
      'provider_name',
      'notes',
    ]) {
      if (payload.containsKey(key)) {
        updated[key] = payload[key];
      }
    }
    updated['pending_sync'] = true;
    if (index == -1) {
      items.add(updated);
    } else {
      items[index] = updated;
    }
    bundle['vaccinations'] = items;
    return bundle;
  }

  Map<String, dynamic> _upsertClinicalEpisodeResource(
    Map<String, dynamic> bundle,
    String episodeId,
    Map<String, dynamic> payload,
  ) {
    final items = _readResourceList(bundle, 'clinical_episodes');
    final index = items.indexWhere(
      (existing) => existing['id'].toString() == episodeId,
    );
    final current = index == -1
        ? <String, dynamic>{'id': episodeId}
        : items[index];
    final updated = Map<String, dynamic>.from(current);
    updated['id'] = episodeId;
    for (final key in const [
      'title',
      'summary',
      'status',
      'onset_date',
      'resolved_date',
      'next_review_date',
      'notes',
    ]) {
      if (payload.containsKey(key)) {
        updated[key] = payload[key];
      }
    }
    updated['pending_sync'] = true;
    if (index == -1) {
      items.add(updated);
    } else {
      items[index] = updated;
    }
    bundle['clinical_episodes'] = items;
    return bundle;
  }

  List<Map<String, dynamic>> _readResourceList(
    Map<String, dynamic> bundle,
    String key,
  ) {
    final rawItems = bundle[key] as List<dynamic>? ?? const <dynamic>[];
    return rawItems
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _buildPendingAllergy(Map<String, dynamic> payload) {
    return {
      'id': _pendingId('allergy'),
      'allergen': payload['allergen'],
      'severity': payload['severity'],
      'notes': payload['notes'],
      'pending_sync': true,
    };
  }

  Map<String, dynamic> _buildPendingCondition(Map<String, dynamic> payload) {
    return {
      'id': _pendingId('condition'),
      'name': payload['name'],
      'diagnosis_date': payload['diagnosis_date'],
      'status': payload['status'],
      'notes': payload['notes'],
      'pending_sync': true,
    };
  }

  Map<String, dynamic> _buildPendingMedication(Map<String, dynamic> payload) {
    final schedules =
        (payload['schedules'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) => _buildPendingMedicationSchedule(
                Map<String, dynamic>.from(item as Map<String, dynamic>),
              ),
            )
            .toList();
    return {
      'id': _pendingId('medication'),
      'name': payload['name'],
      'dosage': payload['dosage'],
      'frequency': payload['frequency'],
      'route': payload['route'],
      'start_date': payload['start_date'],
      'end_date': payload['end_date'],
      'active': payload['active'] as bool? ?? true,
      'notes': payload['notes'],
      'schedules': schedules,
      'pending_sync': true,
    };
  }

  Map<String, dynamic> _buildPendingMedicationSchedule(
    Map<String, dynamic> payload,
  ) {
    final daysOfWeek =
        (payload['days_of_week'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => int.tryParse(value.toString()) ?? 0)
            .toList();
    return {
      'id': _pendingId('schedule'),
      'scheduled_time': payload['scheduled_time'],
      'days_of_week': daysOfWeek,
      'start_date': payload['start_date'],
      'end_date': payload['end_date'],
      'cycle_days_on': payload['cycle_days_on'],
      'cycle_days_off': payload['cycle_days_off'],
      'paused_until': payload['paused_until'],
      'instructions': payload['instructions'],
      'active': payload['active'] as bool? ?? true,
    };
  }

  Map<String, dynamic> _buildPendingFamilyHistory(
    Map<String, dynamic> payload,
  ) {
    return {
      'id': _pendingId('family-history'),
      'relation': payload['relation'],
      'condition_name': payload['condition_name'],
      'notes': payload['notes'],
      'pending_sync': true,
    };
  }

  Map<String, dynamic> _buildPendingClinicalEpisode(
    Map<String, dynamic> payload,
  ) {
    return {
      'id': _pendingId('clinical-episode'),
      'title': payload['title'],
      'summary': payload['summary'],
      'status': payload['status'],
      'onset_date': payload['onset_date'],
      'resolved_date': payload['resolved_date'],
      'next_review_date': payload['next_review_date'],
      'notes': payload['notes'],
      'pending_sync': true,
    };
  }

  Map<String, dynamic> _buildPendingVaccination(
    Map<String, dynamic> payload, {
    String? id,
  }) {
    return {
      'id': id ?? _pendingId('vaccination'),
      'vaccine_name': payload['vaccine_name'],
      'administered_on': payload['administered_on'],
      'dose_number': payload['dose_number'],
      'next_due_date': payload['next_due_date'],
      'provider_name': payload['provider_name'],
      'notes': payload['notes'],
      'pending_sync': true,
    };
  }

  String _pendingId(String prefix) {
    return 'pending-$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
}
