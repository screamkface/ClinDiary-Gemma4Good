import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';

class MedicationsRepository {
  MedicationsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _logsCacheKey = 'medication_logs';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<MedicationLogItem>> fetchLogs() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJsonList('/api/v1/medications/logs');
      final logs = response
          .map(
            (item) => MedicationLogItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      await _cacheLogs(logs);
      return logs;
    } on ApiException {
      final cached = await _readCachedLogs();
      if (cached == null) rethrow;
      return cached;
    } catch (_) {
      final cached = await _readCachedLogs();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<MedicationLogItem> logMedication({
    required String medicationId,
    required String medicationName,
    required String status,
    String? notes,
    String? medicationDosage,
  }) async {
    final payload = {
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    try {
      final response = await _apiClient.postJson(
        '/api/v1/medications/$medicationId/log',
        body: payload,
      );
      return MedicationLogItem.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueMedicationLog(
        medicationId: medicationId,
        medicationName: medicationName,
        medicationDosage: medicationDosage,
        status: status,
        notes: notes,
        lastError: error.message,
        payload: payload,
      );
    } catch (error) {
      return _queueMedicationLog(
        medicationId: medicationId,
        medicationName: medicationName,
        medicationDosage: medicationDosage,
        status: status,
        notes: notes,
        lastError: error.toString(),
        payload: payload,
      );
    }
  }

  Future<MedicationLogItem> _queueMedicationLog({
    required String medicationId,
    required String medicationName,
    required String status,
    required Map<String, dynamic> payload,
    String? notes,
    String? medicationDosage,
    String? lastError,
  }) async {
    await _apiClient.enqueueJsonOperation(
      method: 'POST',
      path: '/api/v1/medications/$medicationId/log',
      body: payload,
      lastError: lastError,
    );
    final pendingItem = MedicationLogItem(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      medicationId: medicationId,
      medicationName: medicationName,
      medicationDosage: medicationDosage,
      scheduledAt: DateTime.now().toUtc(),
      takenAt: status == 'taken' ? DateTime.now().toUtc() : null,
      status: status,
      notes: notes,
      pendingSync: true,
    );
    final cachedLogs = await _readCachedLogs() ?? <MedicationLogItem>[];
    await _cacheLogs([pendingItem, ...cachedLogs]);
    return pendingItem;
  }

  Future<void> updateSchedule({
    required String medicationId,
    required String scheduleId,
    required Map<String, dynamic> body,
  }) async {
    await _apiClient.putJson(
      '/api/v1/medications/$medicationId/schedules/$scheduleId',
      body: body,
    );
  }

  Future<void> pauseSchedule({
    required String medicationId,
    required String scheduleId,
    required DateTime pausedUntil,
  }) async {
    await _apiClient.postJson(
      '/api/v1/medications/$medicationId/schedules/$scheduleId/pause',
      body: {'paused_until': pausedUntil.toIso8601String().split('T').first},
    );
  }

  Future<void> resumeSchedule({
    required String medicationId,
    required String scheduleId,
  }) async {
    await _apiClient.postJson(
      '/api/v1/medications/$medicationId/schedules/$scheduleId/resume',
      body: const {},
    );
  }

  Future<void> deleteSchedule({
    required String medicationId,
    required String scheduleId,
  }) async {
    await _apiClient.delete(
      '/api/v1/medications/$medicationId/schedules/$scheduleId',
    );
  }

  Future<void> deleteMedication(String medicationId) async {
    await _apiClient.delete('/api/v1/profile/medications/$medicationId');
  }

  Future<void> _cacheLogs(List<MedicationLogItem> logs) async {
    await _localDatabase.putCache(
      key: await _scopedLogsCacheKey(),
      payload: jsonEncode(logs.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<MedicationLogItem>?> _readCachedLogs() async {
    final cached = await readProfileScopedCache(_localDatabase, _logsCacheKey);
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => MedicationLogItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> _scopedLogsCacheKey() {
    return profileScopedCacheKey(_localDatabase, _logsCacheKey);
  }

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
}
