import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class WearablesRepository {
  WearablesRepository({
    required LocalDatabase localDatabase,
  }) : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  Future<List<WearableDaySummary>> fetchDailySummaries({int days = 30}) async {
    final safeDays = days.clamp(1, 90);
    final cached = await readProfileScopedCache(
      _localDatabase,
      _cacheKey(safeDays),
    );
    if (cached == null) {
      return const <WearableDaySummary>[];
    }
    final payload = jsonDecode(cached) as List<dynamic>;
    return payload
        .map(
          (item) => WearableDaySummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<int> syncDailySummaries(List<WearableDaySummary> items) async {
    if (items.isEmpty) {
      return 0;
    }
    await _mergeSummariesIntoCache(items, days: 30);
    return items.length;
  }

  Future<void> _mergeSummariesIntoCache(
    List<WearableDaySummary> incoming, {
    required int days,
  }) async {
    final cacheKey = _cacheKey(days);
    final cachedRaw = await readProfileScopedCache(_localDatabase, cacheKey);
    final existing = cachedRaw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(cachedRaw) as List<dynamic>)
              .map(
                (item) =>
                    Map<String, dynamic>.from(item as Map<String, dynamic>),
              )
              .toList();

    final merged = <String, Map<String, dynamic>>{};
    for (final item in existing) {
      merged[_summaryKey(item)] = item;
    }
    for (final summary in incoming) {
      final json = Map<String, dynamic>.from(summary.toSyncJson());
      if (summary.id != null) {
        json['id'] = summary.id;
      }
      if (summary.syncedAt != null) {
        json['synced_at'] = summary.syncedAt!.toUtc().toIso8601String();
      }
      merged[_summaryKey(json)] = json;
    }

    final mergedItems = merged.values.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['summary_date']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['summary_date']?.toString() ?? '');
        if (aDate == null && bDate == null) {
          return 0;
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });

    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, cacheKey),
      payload: jsonEncode(mergedItems.take(days).toList()),
    );
  }

  String _summaryKey(Map<String, dynamic> item) {
    final date = item['summary_date']?.toString() ?? '';
    final platform = item['source_platform']?.toString() ?? '';
    final source = item['source_name']?.toString() ?? '';
    return '$date|$platform|$source';
  }

  static String _cacheKey(int days) => 'wearables_recent_$days';
}
