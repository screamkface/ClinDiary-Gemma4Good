import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';

class AlertsRepository {
  AlertsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _alertsCacheKey = 'alerts_list';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<ClinicalAlert>> fetchAlerts() async {
    try {
      final response = await _apiClient.getJsonList('/api/v1/alerts');
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _alertsCacheKey),
        payload: jsonEncode(response),
      );
      return response
          .map((item) => ClinicalAlert.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ApiException {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _alertsCacheKey,
      );
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map((item) => ClinicalAlert.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _alertsCacheKey,
      );
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map((item) => ClinicalAlert.fromJson(item as Map<String, dynamic>))
          .toList();
    }
  }

  Future<ClinicalAlert> resolveAlert(
    String alertId, {
    String? resolutionNotes,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/alerts/$alertId/resolve',
      body: {
        if (resolutionNotes != null && resolutionNotes.isNotEmpty)
          'resolution_notes': resolutionNotes,
      },
    );
    return ClinicalAlert.fromJson(response);
  }
}
