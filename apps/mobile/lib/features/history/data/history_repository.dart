import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/history/domain/history_day.dart';
import 'package:intl/intl.dart';

class HistoryRepository {
  HistoryRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<HistoryDay> fetchDay({
    required DateTime targetDate,
    bool includeRollups = false,
  }) async {
    final day = DateFormat('yyyy-MM-dd').format(targetDate);
    final path =
        '/api/v1/history/day?target_date=$day&include_rollups=${includeRollups ? 'true' : 'false'}';

    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson(path);
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(
          _localDatabase,
          _cacheKey(day, includeRollups),
        ),
        payload: jsonEncode(response),
      );
      return HistoryDay.fromJson(response);
    } on ApiException {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(day, includeRollups),
      );
      if (cached == null) rethrow;
      return HistoryDay.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    } catch (_) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(day, includeRollups),
      );
      if (cached == null) rethrow;
      return HistoryDay.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  Future<List<DateTime>> fetchActivityDates({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    final path =
        '/api/v1/history/activity-days?start_date=$start&end_date=$end';

    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson(path);
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(
          _localDatabase,
          _activityCacheKey(start, end),
        ),
        payload: jsonEncode(response),
      );
      return _decodeActivityDates(response);
    } on ApiException {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _activityCacheKey(start, end),
      );
      if (cached == null) rethrow;
      return _decodeActivityDates(jsonDecode(cached) as Map<String, dynamic>);
    } catch (_) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _activityCacheKey(start, end),
      );
      if (cached == null) rethrow;
      return _decodeActivityDates(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  static String _cacheKey(String day, bool includeRollups) =>
      'history_day_${includeRollups ? 'rollups' : 'base'}_$day';

  static String _activityCacheKey(String start, String end) =>
      'history_activity_${start}_$end';

  List<DateTime> _decodeActivityDates(Map<String, dynamic> response) {
    return (response['activity_dates'] as List<dynamic>? ?? const [])
        .map((item) => DateTime.parse(item.toString()))
        .toList();
  }
}
