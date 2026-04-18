import 'dart:convert';

import 'package:clindiary/app/core/json/json_deep_copy.dart';
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
  static const _profileBundleCacheKey = 'profile_bundle';

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
    } on ApiException catch (error) {
      final cached = await _readCachedLogs();
      if (cached == null) {
        if (_isLocalOnlyError(error)) {
          return const <MedicationLogItem>[];
        }
        rethrow;
      }
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
        enqueueOperation: !_isLocalOnlyError(error),
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
    bool enqueueOperation = true,
  }) async {
    if (enqueueOperation) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: '/api/v1/medications/$medicationId/log',
        body: payload,
        lastError: lastError,
      );
    }
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
    final path = '/api/v1/medications/$medicationId/schedules/$scheduleId';
    try {
      await _apiClient.putJson(path, body: body);
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: body,
        ),
      );
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'PUT',
          path: path,
          body: body,
          lastError: error.message,
          replaceExisting: true,
        );
      }
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: body,
        ),
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'PUT',
        path: path,
        body: body,
        lastError: error.toString(),
        replaceExisting: true,
      );
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: body,
        ),
      );
    }
  }

  Future<void> pauseSchedule({
    required String medicationId,
    required String scheduleId,
    required DateTime pausedUntil,
  }) async {
    final path =
        '/api/v1/medications/$medicationId/schedules/$scheduleId/pause';
    final payload = {
      'paused_until': pausedUntil.toIso8601String().split('T').first,
    };
    try {
      await _apiClient.postJson(path, body: payload);
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: payload,
        ),
      );
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: payload,
          lastError: error.message,
          replaceExisting: true,
        );
      }
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: payload,
        ),
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: path,
        body: payload,
        lastError: error.toString(),
        replaceExisting: true,
      );
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: payload,
        ),
      );
    }
  }

  Future<void> resumeSchedule({
    required String medicationId,
    required String scheduleId,
  }) async {
    final path =
        '/api/v1/medications/$medicationId/schedules/$scheduleId/resume';
    const payload = <String, dynamic>{};
    try {
      await _apiClient.postJson(path, body: payload);
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: const {'paused_until': null},
        ),
      );
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: payload,
          lastError: error.message,
          replaceExisting: true,
        );
      }
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: const {'paused_until': null},
        ),
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: path,
        body: payload,
        lastError: error.toString(),
        replaceExisting: true,
      );
      await _patchProfileBundle(
        (bundle) => _updateScheduleInBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
          payload: const {'paused_until': null},
        ),
      );
    }
  }

  Future<void> deleteSchedule({
    required String medicationId,
    required String scheduleId,
  }) async {
    final path = '/api/v1/medications/$medicationId/schedules/$scheduleId';
    try {
      await _apiClient.delete(path);
      await _patchProfileBundle(
        (bundle) => _removeScheduleFromBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
        ),
      );
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'DELETE',
          path: path,
          body: const {},
          lastError: error.message,
          replaceExisting: true,
        );
      }
      await _patchProfileBundle(
        (bundle) => _removeScheduleFromBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
        ),
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'DELETE',
        path: path,
        body: const {},
        lastError: error.toString(),
        replaceExisting: true,
      );
      await _patchProfileBundle(
        (bundle) => _removeScheduleFromBundle(
          bundle,
          medicationId: medicationId,
          scheduleId: scheduleId,
        ),
      );
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    final path = '/api/v1/profile/medications/$medicationId';
    try {
      await _apiClient.delete(path);
      await _patchProfileBundle(
        (bundle) => _removeMedicationFromBundle(bundle, medicationId),
      );
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'DELETE',
          path: path,
          body: const {},
          lastError: error.message,
          replaceExisting: true,
        );
      }
      await _patchProfileBundle(
        (bundle) => _removeMedicationFromBundle(bundle, medicationId),
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'DELETE',
        path: path,
        body: const {},
        lastError: error.toString(),
        replaceExisting: true,
      );
      await _patchProfileBundle(
        (bundle) => _removeMedicationFromBundle(bundle, medicationId),
      );
    }
  }

  Future<void> _patchProfileBundle(
    void Function(Map<String, dynamic> bundle) patch,
  ) async {
    final cached = await _readCachedProfileBundleJson();
    if (cached == null) {
      return;
    }
    final cloned = deepCopyJsonMap(cached);
    patch(cloned);
    await _writeCachedProfileBundleJson(cloned);
  }

  Future<Map<String, dynamic>?> _readCachedProfileBundleJson() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      _profileBundleCacheKey,
    );
    if (cached == null) {
      return null;
    }
    return Map<String, dynamic>.from(
      jsonDecode(cached) as Map<String, dynamic>,
    );
  }

  Future<void> _writeCachedProfileBundleJson(
    Map<String, dynamic> bundle,
  ) async {
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, _profileBundleCacheKey),
      payload: jsonEncode(bundle),
    );
  }

  void _updateScheduleInBundle(
    Map<String, dynamic> bundle, {
    required String medicationId,
    required String scheduleId,
    required Map<String, dynamic> payload,
  }) {
    final medications = _medicationsFromBundle(bundle);
    final medicationIndex = medications.indexWhere(
      (item) => item['id']?.toString() == medicationId,
    );
    if (medicationIndex == -1) {
      return;
    }

    final medication = Map<String, dynamic>.from(medications[medicationIndex]);
    final schedules = _schedulesFromMedication(medication);
    final scheduleIndex = schedules.indexWhere(
      (item) => item['id']?.toString() == scheduleId,
    );
    if (scheduleIndex == -1) {
      return;
    }

    final updatedSchedule = Map<String, dynamic>.from(schedules[scheduleIndex]);
    for (final key in const [
      'scheduled_time',
      'start_date',
      'end_date',
      'cycle_days_on',
      'cycle_days_off',
      'paused_until',
      'instructions',
      'active',
    ]) {
      if (payload.containsKey(key)) {
        updatedSchedule[key] = payload[key];
      }
    }
    if (payload.containsKey('days_of_week')) {
      updatedSchedule['days_of_week'] = _normalizeDaysOfWeek(
        payload['days_of_week'],
      );
    }

    schedules[scheduleIndex] = updatedSchedule;
    medication['schedules'] = schedules;
    medication['pending_sync'] = true;
    medications[medicationIndex] = medication;
    bundle['medications'] = medications;
  }

  void _removeScheduleFromBundle(
    Map<String, dynamic> bundle, {
    required String medicationId,
    required String scheduleId,
  }) {
    final medications = _medicationsFromBundle(bundle);
    final medicationIndex = medications.indexWhere(
      (item) => item['id']?.toString() == medicationId,
    );
    if (medicationIndex == -1) {
      return;
    }

    final medication = Map<String, dynamic>.from(medications[medicationIndex]);
    final schedules = _schedulesFromMedication(medication)
      ..removeWhere((item) => item['id']?.toString() == scheduleId);
    medication['schedules'] = schedules;
    medication['pending_sync'] = true;
    medications[medicationIndex] = medication;
    bundle['medications'] = medications;
  }

  void _removeMedicationFromBundle(Map<String, dynamic> bundle, String id) {
    final medications = _medicationsFromBundle(bundle)
      ..removeWhere((item) => item['id']?.toString() == id);
    bundle['medications'] = medications;
  }

  List<Map<String, dynamic>> _medicationsFromBundle(
    Map<String, dynamic> bundle,
  ) {
    final raw = bundle['medications'] as List<dynamic>? ?? const <dynamic>[];
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  List<Map<String, dynamic>> _schedulesFromMedication(
    Map<String, dynamic> medication,
  ) {
    final raw = medication['schedules'] as List<dynamic>? ?? const <dynamic>[];
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  List<int> _normalizeDaysOfWeek(dynamic raw) {
    final values = raw as List<dynamic>? ?? const <dynamic>[];
    return values
        .map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toList();
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

  bool _isLocalOnlyError(ApiException error) => error.code == 'local_only_mode';

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
}
