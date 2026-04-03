import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/reports/domain/clinical_report.dart';

class ReportsRepository {
  ReportsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _lastReportCacheKey = 'reports_last_generated';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<ClinicalReport> generateReport({
    required String reportType,
    DateTime? referenceDate,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/reports/generate',
      body: {
        'report_type': reportType,
        if (referenceDate != null)
          'reference_date': referenceDate.toIso8601String().split('T').first,
      },
    );
    await _localDatabase.putCache(
      key: await _cacheKeyForCurrentProfile(),
      payload: jsonEncode(response),
    );
    return ClinicalReport.fromJson(response);
  }

  Future<ClinicalReport?> readCachedLatestReport() async {
    final activeProfileId = await _localDatabase.readCache(activeProfileIdCacheKey);
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      final cached = await _localDatabase.readCache(
        '$_lastReportCacheKey::$normalizedActiveId',
      );
      if (cached == null) {
        return null;
      }
      return ClinicalReport.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    final cached = await _localDatabase.readCache(_lastReportCacheKey);
    if (cached == null) {
      return null;
    }
    return ClinicalReport.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }

  Future<String> _cacheKeyForCurrentProfile() async {
    final activeProfileId = await _localDatabase.readCache(activeProfileIdCacheKey);
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return '$_lastReportCacheKey::$normalizedActiveId';
    }
    return _lastReportCacheKey;
  }
}
