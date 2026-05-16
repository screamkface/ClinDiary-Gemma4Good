import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center_engine.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/screenings/domain/screening.dart';

class ScreeningsRepository {
  ScreeningsRepository({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  static const _catalogCacheKey = 'screenings_catalog';
  static const _statusCacheKey = 'screenings_me';

  final LocalDatabase _localDatabase;

  Future<List<ScreeningCatalogItem>> fetchCatalog({String? regionCode}) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final cached = await _readCatalogCache(resolvedRegionCode);

    if (cached == null) {
      return const <ScreeningCatalogItem>[];
    }

    return _decodeCatalogCache(jsonDecode(cached) as List<dynamic>);
  }

  Future<List<PatientScreeningStatusItem>> fetchMyScreenings({
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final cached = await _readStatusCache(resolvedRegionCode);

    if (cached == null) {
      return const <PatientScreeningStatusItem>[];
    }

    return _decodeStatusItems(jsonDecode(cached) as List<dynamic>);
  }

  /// Recomputes the personalized prevention/screening status from the current
  /// profile bundle instead of simply re-reading the existing cache.
  ///
  /// Existing completion state is preserved so a recalculation does not erase
  /// items already marked as completed by the user.
  Future<List<PatientScreeningStatusItem>> recompute({
    required ProfileBundle bundle,
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);

    final existingItems =
        await _readStatusCacheJson(resolvedRegionCode) ??
        <Map<String, dynamic>>[];

    final existingById = <String, Map<String, dynamic>>{
      for (final item in existingItems)
        if (item['id'] != null) item['id'].toString(): item,
    };

    final center = const PreventionCenterEngine().build(
      bundle,
      regionCode: resolvedRegionCode,
    );

    final recommendationItems = <PreventionRecommendationItem>[
      if (center.annualVisit != null) center.annualVisit!,
      ...center.annualExams,
      ...center.visitsAndControls,
      ...center.vaccines,
      ...center.vaccineRegistry,
      ...center.pregnancyAndPreconception,
      ...center.sharedDecisions,
      ...center.seasonalChecks,
      ...center.followUpReminders,
    ];

    final statusJson = recommendationItems
        .map<Map<String, dynamic>>(
          (item) => _statusJsonFromRecommendation(
            item,
            existingById[item.code],
          ),
        )
        .toList(growable: false);

    await _writeStatusCacheJson(resolvedRegionCode, statusJson);

    return _decodeStatusItems(statusJson);
  }

  Future<PatientScreeningStatusItem> markDone(
    String screeningId, {
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final updated = await _markDoneInCache(resolvedRegionCode, screeningId);
    return PatientScreeningStatusItem.fromJson(updated);
  }

  Future<PatientScreeningStatusItem> clearCurrentYearCompletion(
    String screeningId, {
    String? regionCode,
  }) async {
    final resolvedRegionCode = _normalizedRegionCode(regionCode);
    final updated = await _clearCurrentYearInCache(
      resolvedRegionCode,
      screeningId,
    );
    return PatientScreeningStatusItem.fromJson(updated);
  }

  Map<String, dynamic> _statusJsonFromRecommendation(
    PreventionRecommendationItem item,
    Map<String, dynamic>? existing,
  ) {
    final completedThisYear = existing?['completed_this_year'] as bool? ?? false;
    final currentYearLastCompletedOn =
        existing?['current_year_last_completed_on'];
    final lastDoneDate = existing?['last_done_date'];

    final computedStatus = _statusFromRecommendation(item);

    return <String, dynamic>{
      'id': item.code,
      'screening_program_id': item.code,
      'screening_code': item.code,
      'screening_name': item.title,
      'screening_category': item.category,
      'care_pathway': _carePathwayFromItem(item),
      'recommendation_level': _recommendationLevelFromItem(item),
      'public_coverage_flag': false,
      'completed_this_year': completedThisYear,
      'current_year_last_completed_on': currentYearLastCompletedOn,
      'last_done_date': lastDoneDate,
      'status': completedThisYear ? 'completed' : computedStatus,
      'regional_availability': const <Map<String, dynamic>>[],
      'cadence_label': item.cadenceLabel,
      'recommendation_reason': item.reason,
      'explanation': item.actionHint,
    };
  }

  String _statusFromRecommendation(PreventionRecommendationItem item) {
    switch (item.status) {
      case 'recommended':
        return 'recommended';
      case 'seasonal':
        return 'scheduled';
      case 'completed':
        return 'completed';
      case 'overdue':
        return 'overdue';
      case 'skipped':
        return 'skipped';
      default:
        return 'never_done';
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
        .toList(growable: false);
  }

  Future<void> _writeStatusCacheJson(
    String regionCode,
    List<Map<String, dynamic>> items,
  ) async {
    final scopedKey = await profileScopedCacheKey(
      _localDatabase,
      _statusCacheKeyForRegion(regionCode),
    );

    await _localDatabase.putCache(
      key: scopedKey,
      payload: jsonEncode(items),
    );
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
      'last_done_date': null,
      'status': 'recommended',
      'regional_availability': const <Map<String, dynamic>>[],
    };
  }

  String _carePathwayFromItem(PreventionRecommendationItem item) {
    switch (item.kind) {
      case 'visit':
        return 'annual_visit';
      case 'shared_decision':
        return 'shared_decision';
      default:
        return 'discuss_with_doctor';
    }
  }

  String _recommendationLevelFromItem(PreventionRecommendationItem item) {
    if (item.status == 'recommended' || item.priority == 'high') {
      return 'risk_based';
    }

    if (item.priority == 'low') {
      return 'not_routine';
    }

    return 'routine';
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
        .toList(growable: false);
  }

  List<PatientScreeningStatusItem> _decodeStatusItems(List<dynamic> items) {
    return items
        .map(
          (item) =>
              PatientScreeningStatusItem.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}