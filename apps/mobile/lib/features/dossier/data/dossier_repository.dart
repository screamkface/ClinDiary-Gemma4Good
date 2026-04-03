import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';

class DossierRepository {
  DossierRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _cacheKey = 'health_dossier';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<HealthDossier> fetchDossier() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson('/api/v1/dossier');
      await _localDatabase.putCache(
        key: await _cacheKeyForCurrentProfile(),
        payload: jsonEncode(response),
      );
      return HealthDossier.fromJson(response);
    } on ApiException {
      final cached = await _readCachedDossier();
      if (cached == null) rethrow;
      return HealthDossier.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    } catch (error) {
      final cached = await _readCachedDossier();
      if (cached == null) rethrow;
      return HealthDossier.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  Future<List<int>> exportDossier() {
    return _apiClient.getBytes('/api/v1/dossier/export');
  }

  Future<List<int>> exportDossierJson() {
    return _apiClient.getBytes('/api/v1/dossier/export/json');
  }

  Future<List<int>> exportEmergencyDossier() {
    return _apiClient.getBytes('/api/v1/dossier/export/emergency');
  }

  Future<HealthDossier> importDossier({
    required Map<String, dynamic> snapshot,
    bool replaceExisting = true,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/dossier/import',
      body: {
        'snapshot': snapshot,
        'replace_existing': replaceExisting,
      },
    );
    final dossier = HealthDossier.fromJson(response);
    await _localDatabase.putCache(
      key: await _cacheKeyForCurrentProfile(),
      payload: jsonEncode(response),
    );
    return dossier;
  }

  Future<List<DossierShareLinkItem>> fetchShareLinks() async {
    final response = await _apiClient.getJson('/api/v1/dossier/share-links');
    return (response as List<dynamic>)
        .map((item) => DossierShareLinkItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DossierShareLinkItem> createShareLink({
    required String scope,
    String? label,
    int expiresInDays = 7,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/dossier/share-links',
      body: {
        'scope': scope,
        'label': label,
        'expires_in_days': expiresInDays,
      },
    );
    return DossierShareLinkItem.fromJson(response);
  }

  Future<void> revokeShareLink(String shareLinkId) async {
    await _apiClient.delete('/api/v1/dossier/share-links/$shareLinkId');
  }

  Future<String?> _readCachedDossier() async {
    final activeProfileId = await _localDatabase.readCache(activeProfileIdCacheKey);
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return _localDatabase.readCache('$_cacheKey::$normalizedActiveId');
    }
    return _localDatabase.readCache(_cacheKey);
  }

  Future<String> _cacheKeyForCurrentProfile() async {
    final activeProfileId = await _localDatabase.readCache(activeProfileIdCacheKey);
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return '$_cacheKey::$normalizedActiveId';
    }
    return _cacheKey;
  }
}
