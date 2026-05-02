import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';

class PreventionCenterRepository {
  PreventionCenterRepository({
    required LocalDatabase localDatabase,
  }) : _localDatabase = localDatabase;

  static const _cacheKey = 'prevention_center';

  final LocalDatabase _localDatabase;

  Future<PreventionCenterData> fetchCenter({String? regionCode}) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final cached = await _readCachedCenter(resolvedRegionCode);
    if (cached == null) {
      return PreventionCenterData(
        statusSummary: const PreventionStatusSummary(
          overallStatus: 'up_to_date',
          totalScreenings: 0,
          completedScreenings: 0,
          overdueScreenings: 0,
          recommendedScreenings: 0,
          nextScreeningDate: null,
          nextScreeningName: null,
        ),
        actions: const <PreventionActionItem>[],
        categories: const <PreventionCategorySummary>[],
      );
    }
    return PreventionCenterData.fromJson(
      jsonDecode(cached) as Map<String, dynamic>,
    );
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
