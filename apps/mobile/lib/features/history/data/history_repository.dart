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
    } on ApiException catch (error) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(day, includeRollups),
      );
      if (cached == null) {
        if (_isLocalOnlyError(error)) {
          return _buildLocalHistoryDay(
            targetDate: targetDate,
            includeRollups: includeRollups,
          );
        }
        rethrow;
      }
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
    } on ApiException catch (error) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _activityCacheKey(start, end),
      );
      if (cached == null) {
        if (_isLocalOnlyError(error)) {
          return _buildLocalActivityDates(
            startDate: startDate,
            endDate: endDate,
          );
        }
        rethrow;
      }
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

  Future<HistoryDay> _buildLocalHistoryDay({
    required DateTime targetDate,
    required bool includeRollups,
  }) async {
    final targetDay = DateFormat('yyyy-MM-dd').format(targetDate.toUtc());

    Map<String, dynamic>? dailyEntry;
    final dailyEntriesCache = await readProfileScopedCache(
      _localDatabase,
      'daily_entries',
    );
    if (dailyEntriesCache != null) {
      final entries = jsonDecode(dailyEntriesCache) as List<dynamic>;
      for (final raw in entries) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final itemDay = _normalizeToIsoDay(item['entry_date']?.toString());
        if (itemDay == targetDay) {
          dailyEntry = item;
          break;
        }
      }
    }

    Map<String, dynamic>? wearableSummary;
    final wearablesCache = await readProfileScopedCache(
      _localDatabase,
      'wearables_recent_30',
    );
    if (wearablesCache != null) {
      final summaries = jsonDecode(wearablesCache) as List<dynamic>;
      for (final raw in summaries) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final itemDay = _normalizeToIsoDay(item['summary_date']?.toString());
        if (itemDay == targetDay) {
          wearableSummary = item;
          break;
        }
      }
    }

    final timelineEvents = <Map<String, dynamic>>[];
    final timelineCache = await readProfileScopedCache(
      _localDatabase,
      'timeline_events',
    );
    if (timelineCache != null) {
      final events = jsonDecode(timelineCache) as List<dynamic>;
      for (final raw in events) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final itemDay = _normalizeToIsoDay(item['event_date']?.toString());
        if (itemDay == targetDay) {
          timelineEvents.add(item);
        }
      }
    }

    final payload = <String, dynamic>{
      'target_date': targetDate.toUtc().toIso8601String(),
      'daily_entry': dailyEntry,
      'daily_summary': null,
      'weekly_summary': null,
      'monthly_summary': null,
      'wearable_summary': wearableSummary,
      'documents': const <Map<String, dynamic>>[],
      'timeline_events': timelineEvents,
    };

    await _localDatabase.putCache(
      key: await profileScopedCacheKey(
        _localDatabase,
        _cacheKey(targetDay, includeRollups),
      ),
      payload: jsonEncode(payload),
    );

    return HistoryDay.fromJson(payload);
  }

  Future<List<DateTime>> _buildLocalActivityDates({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final days = <DateTime>{};

    final dailyEntriesCache = await readProfileScopedCache(
      _localDatabase,
      'daily_entries',
    );
    if (dailyEntriesCache != null) {
      final entries = jsonDecode(dailyEntriesCache) as List<dynamic>;
      for (final raw in entries) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final parsed = DateTime.tryParse(item['entry_date']?.toString() ?? '');
        if (parsed != null) {
          days.add(DateTime.utc(parsed.year, parsed.month, parsed.day));
        }
      }
    }

    final timelineCache = await readProfileScopedCache(
      _localDatabase,
      'timeline_events',
    );
    if (timelineCache != null) {
      final events = jsonDecode(timelineCache) as List<dynamic>;
      for (final raw in events) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final parsed = DateTime.tryParse(item['event_date']?.toString() ?? '');
        if (parsed != null) {
          days.add(DateTime.utc(parsed.year, parsed.month, parsed.day));
        }
      }
    }

    final filtered =
        days
            .where(
              (day) =>
                  !day.isBefore(
                    DateTime.utc(
                      startDate.year,
                      startDate.month,
                      startDate.day,
                    ),
                  ) &&
                  !day.isAfter(
                    DateTime.utc(endDate.year, endDate.month, endDate.day),
                  ),
            )
            .toList()
          ..sort((a, b) => a.compareTo(b));

    final payload = {
      'activity_dates': filtered.map((day) => day.toIso8601String()).toList(),
    };
    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(
        _localDatabase,
        _activityCacheKey(start, end),
      ),
      payload: jsonEncode(payload),
    );

    return filtered;
  }

  String _normalizeToIsoDay(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return value.split('T').first;
    }
    return DateFormat('yyyy-MM-dd').format(parsed.toUtc());
  }

  List<DateTime> _decodeActivityDates(Map<String, dynamic> response) {
    return (response['activity_dates'] as List<dynamic>? ?? const [])
        .map((item) => DateTime.parse(item.toString()))
        .toList();
  }

  bool _isLocalOnlyError(ApiException error) => error.code == 'local_only_mode';
}
