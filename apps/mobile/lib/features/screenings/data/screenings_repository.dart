import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/screenings/domain/screening.dart';

class ScreeningsRepository {
  ScreeningsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _catalogCacheKey = 'screenings_catalog';
  static const _statusCacheKey = 'screenings_me';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<ScreeningCatalogItem>> fetchCatalog({String? regionCode}) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJsonList(
        _screeningsPath('/api/v1/screenings/catalog', resolvedRegionCode),
      );
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(
          _localDatabase,
          _catalogCacheKeyForRegion(resolvedRegionCode),
        ),
        payload: jsonEncode(response),
      );
      return _decodeCatalogItems(response);
    } on ApiException {
      final cached = await _readCatalogCache(resolvedRegionCode);
      if (cached == null) rethrow;
      return _decodeCatalogCache(jsonDecode(cached) as List<dynamic>);
    } catch (_) {
      final cached = await _readCatalogCache(resolvedRegionCode);
      if (cached == null) rethrow;
      return _decodeCatalogCache(jsonDecode(cached) as List<dynamic>);
    }
  }

  Future<List<PatientScreeningStatusItem>> fetchMyScreenings({
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJsonList(
        _screeningsPath('/api/v1/screenings/me', resolvedRegionCode),
      );
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(
          _localDatabase,
          _statusCacheKeyForRegion(resolvedRegionCode),
        ),
        payload: jsonEncode(response),
      );
      return _decodeStatusItems(response);
    } on ApiException {
      final cached = await _readStatusCache(resolvedRegionCode);
      if (cached == null) rethrow;
      return _decodeStatusItems(jsonDecode(cached) as List<dynamic>);
    } catch (_) {
      final cached = await _readStatusCache(resolvedRegionCode);
      if (cached == null) rethrow;
      return _decodeStatusItems(jsonDecode(cached) as List<dynamic>);
    }
  }

  Future<List<PatientScreeningStatusItem>> recompute({
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final response = await _apiClient.postJson(
      _screeningsPath('/api/v1/screenings/recompute', resolvedRegionCode),
    );
    final items = _decodeStatusItems(response['items'] as List<dynamic>);
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(
        _localDatabase,
        _statusCacheKeyForRegion(resolvedRegionCode),
      ),
      payload: jsonEncode(response['items']),
    );
    return items;
  }

  Future<PatientScreeningStatusItem> markDone(
    String screeningId, {
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final response = await _apiClient.postJson(
      _screeningsPath(
        '/api/v1/screenings/$screeningId/mark-done',
        resolvedRegionCode,
      ),
      body: const {},
    );
    return PatientScreeningStatusItem.fromJson(response);
  }

  Future<PatientScreeningStatusItem> clearCurrentYearCompletion(
    String screeningId, {
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final response = await _apiClient.deleteJson(
      _screeningsPath(
        '/api/v1/screenings/$screeningId/current-year-completion',
        resolvedRegionCode,
      ),
    );
    return PatientScreeningStatusItem.fromJson(response);
  }

  String _screeningsPath(String path, String regionCode) {
    return '$path?region_code=${Uri.encodeQueryComponent(regionCode)}';
  }

  String _normalizedRegionCode(String? regionCode) {
    final value = regionCode?.trim();
    if (value == null || value.isEmpty) {
      return 'IT';
    }
    return value.toUpperCase();
  }

  String _catalogCacheKeyForRegion(String regionCode) {
    return '$_catalogCacheKey::${regionCode.toUpperCase()}';
  }

  String _statusCacheKeyForRegion(String regionCode) {
    return '$_statusCacheKey::${regionCode.toUpperCase()}';
  }

  Future<String?> _readCatalogCache(String regionCode) async {
    final scope = await activeProfileCacheScope(_localDatabase);
    if (scope != null) {
      return _localDatabase.readCache(
        scopedCacheKey(_catalogCacheKeyForRegion(regionCode), scope),
      );
    }
    final cached = await _localDatabase.readCache(
      _catalogCacheKeyForRegion(regionCode),
    );
    if (cached != null) {
      return cached;
    }
    if (regionCode.toUpperCase() == 'IT') {
      return _localDatabase.readCache(_catalogCacheKey);
    }
    return null;
  }

  Future<String?> _readStatusCache(String regionCode) async {
    final scope = await activeProfileCacheScope(_localDatabase);
    if (scope != null) {
      return _localDatabase.readCache(
        scopedCacheKey(_statusCacheKeyForRegion(regionCode), scope),
      );
    }
    final cached = await _localDatabase.readCache(
      _statusCacheKeyForRegion(regionCode),
    );
    if (cached != null) {
      return cached;
    }
    if (regionCode.toUpperCase() == 'IT') {
      return _localDatabase.readCache(_statusCacheKey);
    }
    return null;
  }

  List<ScreeningCatalogItem> _decodeCatalogCache(List<dynamic> items) {
    return items
        .map(
          (item) => ScreeningCatalogItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  List<ScreeningCatalogItem> _decodeCatalogItems(List<dynamic> items) {
    return _decodeCatalogCache(items);
  }

  List<PatientScreeningStatusItem> _decodeStatusItems(List<dynamic> items) {
    return items
        .map(
          (item) =>
              PatientScreeningStatusItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
