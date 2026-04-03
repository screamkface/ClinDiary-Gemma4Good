import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';

class DailyJournalRepository {
  DailyJournalRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _cacheKey = 'daily_entries';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<DailyEntry>> fetchEntries() async {
    try {
      final response = await _apiClient.getJsonList('/api/v1/daily-entries');
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _cacheKey),
        payload: jsonEncode(response),
      );
      return response
          .map((item) => DailyEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ApiException {
      final cached = await readProfileScopedCache(_localDatabase, _cacheKey);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map((item) => DailyEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await readProfileScopedCache(_localDatabase, _cacheKey);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map((item) => DailyEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    }
  }

  Future<DailyEntry> createEntry(Map<String, dynamic> payload) async {
    final response = await _apiClient.postJson(
      '/api/v1/daily-entries',
      body: payload,
    );
    return DailyEntry.fromJson(response);
  }

  Future<void> addSymptom({
    required String entryId,
    required Map<String, dynamic> payload,
  }) async {
    await _apiClient.postJson(
      '/api/v1/daily-entries/$entryId/symptoms',
      body: payload,
    );
  }

  Future<void> addVital({
    required String entryId,
    required Map<String, dynamic> payload,
  }) async {
    await _apiClient.postJson(
      '/api/v1/daily-entries/$entryId/vitals',
      body: payload,
    );
  }
}
