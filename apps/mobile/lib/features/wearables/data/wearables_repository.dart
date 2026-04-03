import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class WearablesRepository {
  WearablesRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<WearableDaySummary>> fetchDailySummaries({int days = 30}) async {
    final safeDays = days.clamp(1, 90);
    final path = '/api/v1/wearables/daily-summaries?days=$safeDays';

    try {
      final response = await _apiClient.getJsonList(path);
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _cacheKey(safeDays)),
        payload: jsonEncode(response),
      );
      return response
          .map(
            (item) => WearableDaySummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on ApiException {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(safeDays),
      );
      if (cached == null) {
        rethrow;
      }
      final payload = jsonDecode(cached) as List<dynamic>;
      return payload
          .map(
            (item) => WearableDaySummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(safeDays),
      );
      if (cached == null) {
        rethrow;
      }
      final payload = jsonDecode(cached) as List<dynamic>;
      return payload
          .map(
            (item) => WearableDaySummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
  }

  Future<int> syncDailySummaries(List<WearableDaySummary> items) async {
    if (items.isEmpty) {
      return 0;
    }
    final response = await _apiClient.postJson(
      '/api/v1/wearables/sync-daily',
      body: {'items': items.map((item) => item.toSyncJson()).toList()},
    );
    return response['synced_count'] as int? ?? items.length;
  }

  static String _cacheKey(int days) => 'wearables_recent_$days';
}
