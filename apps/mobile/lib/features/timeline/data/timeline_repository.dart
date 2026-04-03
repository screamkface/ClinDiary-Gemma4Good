import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';

class TimelineRepository {
  TimelineRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _cacheKey = 'timeline_events';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<TimelineEventItem>> fetchEvents() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJsonList('/api/v1/timeline');
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _cacheKey),
        payload: jsonEncode(response),
      );
      return response
          .map(
            (item) => TimelineEventItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on ApiException {
      final cached = await readProfileScopedCache(_localDatabase, _cacheKey);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (item) => TimelineEventItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      final cached = await readProfileScopedCache(_localDatabase, _cacheKey);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (item) => TimelineEventItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
  }
}
