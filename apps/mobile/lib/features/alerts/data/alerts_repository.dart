import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';

class AlertsRepository {
  AlertsRepository({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  static const _alertsCacheKey = 'alerts_list';

  final LocalDatabase _localDatabase;

  Future<List<ClinicalAlert>> fetchAlerts() async {
    final cached = await _readCachedAlertsJson();
    if (cached == null) {
      return const <ClinicalAlert>[];
    }
    return cached.map(ClinicalAlert.fromJson).toList();
  }

  Future<ClinicalAlert> resolveAlert(
    String alertId, {
    String? resolutionNotes,
  }) async {
    final updated = await _upsertResolvedAlertInCache(
      alertId: alertId,
      resolutionNotes: resolutionNotes,
    );
    return ClinicalAlert.fromJson(updated);
  }

  Future<List<Map<String, dynamic>>?> _readCachedAlertsJson() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      _alertsCacheKey,
    );
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeCachedAlertsJson(List<Map<String, dynamic>> alerts) async {
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, _alertsCacheKey),
      payload: jsonEncode(alerts),
    );
  }

  Future<Map<String, dynamic>> _upsertResolvedAlertInCache({
    required String alertId,
    String? resolutionNotes,
    Map<String, dynamic>? serverAlert,
  }) async {
    final alerts = await _readCachedAlertsJson() ?? <Map<String, dynamic>>[];

    if (serverAlert != null) {
      final normalized = Map<String, dynamic>.from(serverAlert);
      final index = alerts.indexWhere(
        (item) => item['id']?.toString() == normalized['id']?.toString(),
      );
      if (index == -1) {
        alerts.insert(0, normalized);
      } else {
        alerts[index] = normalized;
      }
      await _writeCachedAlertsJson(alerts);
      return normalized;
    }

    final index = alerts.indexWhere(
      (item) => item['id']?.toString() == alertId,
    );
    if (index != -1) {
      final updated = Map<String, dynamic>.from(alerts[index]);
      updated['status'] = 'resolved';
      updated['resolved_at'] = DateTime.now().toUtc().toIso8601String();
      if (resolutionNotes != null && resolutionNotes.isNotEmpty) {
        updated['resolution_notes'] = resolutionNotes;
      }
      alerts[index] = updated;
      await _writeCachedAlertsJson(alerts);
      return updated;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final fallback = <String, dynamic>{
      'id': alertId,
      'severity': 'info',
      'alert_type': 'manual',
      'title': 'Alert resolved locally',
      'description': 'Resolved in local-only mode.',
      'status': 'resolved',
      'triggered_at': nowIso,
      'resolved_at': nowIso,
      'resolution_notes': resolutionNotes,
    };
    alerts.insert(0, fallback);
    await _writeCachedAlertsJson(alerts);
    return fallback;
  }
}
