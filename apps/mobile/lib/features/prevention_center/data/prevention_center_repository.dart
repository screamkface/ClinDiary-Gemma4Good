import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';

class PreventionCenterRepository {
  PreventionCenterRepository({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  static const _cacheKey = 'prevention_center';

  final LocalDatabase _localDatabase;

  Future<PreventionCenterData> fetchCenter({String? regionCode}) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final cached = await _readCachedCenter(resolvedRegionCode);
    if (cached == null) {
      return PreventionCenterData(
        generatedAt: DateTime.now().toUtc(),
        displayName: 'Clinical profile',
        regionCode: resolvedRegionCode,
        regionName: resolvedRegionCode == 'IT' ? 'Italy' : resolvedRegionCode,
        overview: const PreventionCenterOverview(
          actionableScreenings: 0,
          vaccineReviews: 0,
          vaccineRegistryItems: 0,
          pregnancyItems: 0,
          sharedDecisionItems: 0,
          seasonalChecks: 0,
          followUpItems: 0,
        ),
        annualVisit: null,
        visitsAndControls: const <PreventionRecommendationItem>[],
        vaccines: const <PreventionRecommendationItem>[],
        seasonalChecks: const <PreventionRecommendationItem>[],
        followUpReminders: const <PreventionRecommendationItem>[],
      );
    }
    return PreventionCenterData.fromJson(
      jsonDecode(cached) as Map<String, dynamic>,
    );
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
