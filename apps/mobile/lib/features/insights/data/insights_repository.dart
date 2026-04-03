import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:intl/intl.dart';

class InsightsRepository {
  InsightsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<InsightSummary> fetchSummary(InsightSummaryQuery query) async {
    final fullPath = _buildPath(query);

    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson(fullPath);
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _cacheKey(query)),
        payload: jsonEncode(response),
      );
      return InsightSummary.fromJson(response);
    } on ApiException {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(query),
      );
      if (cached == null) rethrow;
      return InsightSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    } catch (_) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(query),
      );
      if (cached == null) rethrow;
      return InsightSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
  }

  Future<InsightSummary> regenerateSummary(InsightSummaryQuery query) async {
    final response = await _apiClient.postJson(
      _buildPath(query, regenerate: true),
    );
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, _cacheKey(query)),
      payload: jsonEncode(response),
    );
    return InsightSummary.fromJson(response);
  }

  String _buildPath(InsightSummaryQuery query, {bool regenerate = false}) {
    final summaryType = query.summaryType;
    final basePath = switch (summaryType) {
      'daily' => '/api/v1/insights/daily',
      'weekly' => '/api/v1/insights/weekly',
      'monthly' => '/api/v1/insights/monthly',
      _ => '/api/v1/insights/pre-visit',
    };
    final path = regenerate ? '$basePath/regenerate' : basePath;
    return query.referenceDate == null
        ? path
        : '$path?reference_date=${DateFormat('yyyy-MM-dd').format(query.referenceDate!)}';
  }

  static String _cacheKey(InsightSummaryQuery query) {
    final suffix = query.referenceDate == null
        ? 'latest'
        : DateFormat('yyyy-MM-dd').format(query.referenceDate!);
    return 'insight_${query.summaryType}_$suffix';
  }
}
