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
    } on ApiException catch (error) {
      final cached = await _readStatusCache(resolvedRegionCode);
      if (cached == null) {
        if (_isLocalOnlyError(error)) {
          return const <PatientScreeningStatusItem>[];
        }
        rethrow;
      }
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
    final path = _screeningsPath(
      '/api/v1/screenings/recompute',
      resolvedRegionCode,
    );
    try {
      final response = await _apiClient.postJson(path);
      final items = _decodeStatusItems(response['items'] as List<dynamic>);
      await _writeStatusCacheJson(
        resolvedRegionCode,
        (response['items'] as List<dynamic>)
            .map(
              (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
            )
            .toList(),
      );
      return items;
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: const {},
          lastError: error.message,
          replaceExisting: true,
        );
      }
      final cached = await _readStatusCacheJson(resolvedRegionCode);
      if (cached == null) {
        return const <PatientScreeningStatusItem>[];
      }
      return _decodeStatusItems(cached);
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: path,
        body: const {},
        lastError: error.toString(),
        replaceExisting: true,
      );
      final cached = await _readStatusCacheJson(resolvedRegionCode);
      if (cached == null) {
        rethrow;
      }
      return _decodeStatusItems(cached);
    }
  }

  Future<PatientScreeningStatusItem> markDone(
    String screeningId, {
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final path = _screeningsPath(
      '/api/v1/screenings/$screeningId/mark-done',
      resolvedRegionCode,
    );
    try {
      final response = await _apiClient.postJson(path, body: const {});
      await _upsertStatusItemInCache(
        resolvedRegionCode,
        Map<String, dynamic>.from(response),
      );
      return PatientScreeningStatusItem.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: const {},
          lastError: error.message,
          replaceExisting: true,
        );
      }
      final fallback = await _markDoneInCache(resolvedRegionCode, screeningId);
      return PatientScreeningStatusItem.fromJson(fallback);
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: path,
        body: const {},
        lastError: error.toString(),
        replaceExisting: true,
      );
      final fallback = await _markDoneInCache(resolvedRegionCode, screeningId);
      return PatientScreeningStatusItem.fromJson(fallback);
    }
  }

  Future<PatientScreeningStatusItem> clearCurrentYearCompletion(
    String screeningId, {
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final path = _screeningsPath(
      '/api/v1/screenings/$screeningId/current-year-completion',
      resolvedRegionCode,
    );
    try {
      final response = await _apiClient.deleteJson(path);
      await _upsertStatusItemInCache(
        resolvedRegionCode,
        Map<String, dynamic>.from(response),
      );
      return PatientScreeningStatusItem.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'DELETE',
          path: path,
          body: const {},
          lastError: error.message,
          replaceExisting: true,
        );
      }
      final fallback = await _clearCurrentYearInCache(
        resolvedRegionCode,
        screeningId,
      );
      return PatientScreeningStatusItem.fromJson(fallback);
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'DELETE',
        path: path,
        body: const {},
        lastError: error.toString(),
        replaceExisting: true,
      );
      final fallback = await _clearCurrentYearInCache(
        resolvedRegionCode,
        screeningId,
      );
      return PatientScreeningStatusItem.fromJson(fallback);
    }
  }

  Future<List<Map<String, dynamic>>?> _readStatusCacheJson(
    String regionCode,
  ) async {
    final cached = await _readStatusCache(regionCode);
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeStatusCacheJson(
    String regionCode,
    List<Map<String, dynamic>> items,
  ) async {
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(
        _localDatabase,
        _statusCacheKeyForRegion(regionCode),
      ),
      payload: jsonEncode(items),
    );
  }

  Future<void> _upsertStatusItemInCache(
    String regionCode,
    Map<String, dynamic> item,
  ) async {
    final items =
        await _readStatusCacheJson(regionCode) ?? <Map<String, dynamic>>[];
    final index = items.indexWhere(
      (existing) => existing['id']?.toString() == item['id']?.toString(),
    );
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
    await _writeStatusCacheJson(regionCode, items);
  }

  Future<Map<String, dynamic>> _markDoneInCache(
    String regionCode,
    String screeningId,
  ) async {
    final items =
        await _readStatusCacheJson(regionCode) ?? <Map<String, dynamic>>[];
    final index = items.indexWhere(
      (item) => item['id']?.toString() == screeningId,
    );
    final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;

    final updated = index == -1
        ? _fallbackStatusItem(screeningId)
        : Map<String, dynamic>.from(items[index]);
    updated['completed_this_year'] = true;
    updated['current_year_last_completed_on'] = nowIso;
    updated['last_done_date'] = nowIso;
    updated['status'] = 'completed';

    if (index == -1) {
      items.add(updated);
    } else {
      items[index] = updated;
    }
    await _writeStatusCacheJson(regionCode, items);
    return updated;
  }

  Future<Map<String, dynamic>> _clearCurrentYearInCache(
    String regionCode,
    String screeningId,
  ) async {
    final items =
        await _readStatusCacheJson(regionCode) ?? <Map<String, dynamic>>[];
    final index = items.indexWhere(
      (item) => item['id']?.toString() == screeningId,
    );

    final updated = index == -1
        ? _fallbackStatusItem(screeningId)
        : Map<String, dynamic>.from(items[index]);
    updated['completed_this_year'] = false;
    updated['current_year_last_completed_on'] = null;
    if (updated['status']?.toString() == 'completed') {
      updated['status'] = 'recommended';
    }

    if (index == -1) {
      items.add(updated);
    } else {
      items[index] = updated;
    }
    await _writeStatusCacheJson(regionCode, items);
    return updated;
  }

  Map<String, dynamic> _fallbackStatusItem(String screeningId) {
    return <String, dynamic>{
      'id': screeningId,
      'screening_program_id': screeningId,
      'screening_code': 'custom',
      'screening_name': 'Manual screening item',
      'screening_category': 'prevention',
      'care_pathway': 'discuss_with_doctor',
      'recommendation_level': 'routine',
      'public_coverage_flag': false,
      'completed_this_year': false,
      'current_year_last_completed_on': null,
      'status': 'recommended',
      'regional_availability': const <Map<String, dynamic>>[],
    };
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

  bool _isLocalOnlyError(ApiException error) => error.code == 'local_only_mode';

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
}
