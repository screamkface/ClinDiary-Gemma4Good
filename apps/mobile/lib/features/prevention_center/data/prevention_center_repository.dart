import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';

class PreventionCenterRepository {
  PreventionCenterRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _cacheKey = 'prevention_center';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<PreventionCenterData> fetchCenter({String? regionCode}) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson(
        _preventionCenterPath(resolvedRegionCode),
      );
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(
          _localDatabase,
          _cacheKeyForRegion(resolvedRegionCode),
        ),
        payload: jsonEncode(response),
      );
      return PreventionCenterData.fromJson(response);
    } on ApiException {
      final cached = await _readCachedCenter(resolvedRegionCode);
      if (cached == null) rethrow;
      return PreventionCenterData.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    } catch (error) {
      final cached = await _readCachedCenter(resolvedRegionCode);
      if (cached == null) rethrow;
      return PreventionCenterData.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
  }

  String _preventionCenterPath(String regionCode) {
    return '/api/v1/prevention-center?region_code=${Uri.encodeQueryComponent(regionCode)}';
  }

  String _normalizedRegionCode(String? regionCode) {
    final value = regionCode?.trim();
    if (value == null || value.isEmpty) {
      return 'IT';
    }
    return value.toUpperCase();
  }

  String _cacheKeyForRegion(String regionCode) {
    return '$_cacheKey::${regionCode.toUpperCase()}';
  }

  Future<String?> _readCachedCenter(String regionCode) async {
    final scope = await activeProfileCacheScope(_localDatabase);
    if (scope != null) {
      return _localDatabase.readCache(
        scopedCacheKey(_cacheKeyForRegion(regionCode), scope),
      );
    }
    final cached = await _localDatabase.readCache(
      _cacheKeyForRegion(regionCode),
    );
    if (cached != null) {
      return cached;
    }
    if (regionCode.toUpperCase() == 'IT') {
      return _localDatabase.readCache(_cacheKey);
    }
    return null;
  }
}
