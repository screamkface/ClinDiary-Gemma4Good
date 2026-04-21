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
  static const _localShadowUntilKey = '_local_shadow_until';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<DailyEntry>> fetchEntries() async {
    try {
      final response = await _apiClient.getJsonList('/api/v1/daily-entries');
      final remoteEntries = response
          .map(
            (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
          )
          .toList();
      final cachedEntries =
          await _readCachedEntriesJson() ?? const <Map<String, dynamic>>[];
      final mergedEntries = _mergeRemoteWithCachedEntries(
        remoteEntries: remoteEntries,
        cachedEntries: cachedEntries,
      );
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _cacheKey),
        payload: jsonEncode(mergedEntries),
      );
      return _decodeEntries(mergedEntries);
    } on ApiException catch (error) {
      final cached = await _readCachedEntriesJson();
      if (cached == null) {
        if (_isLocalOnlyError(error)) {
          return const <DailyEntry>[];
        }
        rethrow;
      }
      return _decodeEntries(cached);
    } catch (_) {
      final cached = await _readCachedEntriesJson();
      if (cached == null) rethrow;
      return _decodeEntries(cached);
    }
  }

  Future<DailyEntry> createEntry(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.postJson(
        '/api/v1/daily-entries',
        body: payload,
      );
      await _upsertEntryInCache({
        ...response,
        _localShadowUntilKey: _buildLocalShadowUntilIso(),
      });
      return DailyEntry.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      final pendingEntry = _buildPendingEntry(payload);
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: '/api/v1/daily-entries',
          body: payload,
          lastError: error.message,
        );
      }
      await _upsertEntryInCache(pendingEntry);
      return DailyEntry.fromJson(pendingEntry);
    } catch (error) {
      final pendingEntry = _buildPendingEntry(payload);
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: '/api/v1/daily-entries',
        body: payload,
        lastError: error.toString(),
      );
      await _upsertEntryInCache(pendingEntry);
      return DailyEntry.fromJson(pendingEntry);
    }
  }

  Future<void> addSymptom({
    required String entryId,
    required Map<String, dynamic> payload,
  }) async {
    final path = '/api/v1/daily-entries/$entryId/symptoms';
    try {
      final response = await _apiClient.postJson(path, body: payload);
      await _upsertSymptomInCache(entryId, response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error) && !_isPendingId(entryId)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: payload,
          lastError: error.message,
        );
      }
      await _upsertSymptomInCache(entryId, _buildPendingSymptom(payload));
    } catch (error) {
      if (!_isPendingId(entryId)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: payload,
          lastError: error.toString(),
        );
      }
      await _upsertSymptomInCache(entryId, _buildPendingSymptom(payload));
    }
  }

  Future<void> addVital({
    required String entryId,
    required Map<String, dynamic> payload,
  }) async {
    final path = '/api/v1/daily-entries/$entryId/vitals';
    try {
      final response = await _apiClient.postJson(path, body: payload);
      await _upsertVitalInCache(entryId, response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error) && !_isPendingId(entryId)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: payload,
          lastError: error.message,
        );
      }
      await _upsertVitalInCache(entryId, _buildPendingVital(payload));
    } catch (error) {
      if (!_isPendingId(entryId)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: payload,
          lastError: error.toString(),
        );
      }
      await _upsertVitalInCache(entryId, _buildPendingVital(payload));
    }
  }

  Future<void> deleteEntry({required String entryId}) async {
    final removedEntry = await _removeEntryFromCache(entryId);
    final removedEntryDate = removedEntry?['entry_date']?.toString();
    final profileScope = await activeProfileCacheScope(_localDatabase);

    if (_isPendingId(entryId)) {
      await _discardMatchingPendingCreates(
        entryDate: removedEntryDate,
        profileScope: profileScope,
      );
      return;
    }

    final path = '/api/v1/daily-entries/$entryId';
    try {
      await _apiClient.delete(path);
      await _discardMatchingPendingCreates(
        entryDate: removedEntryDate,
        profileScope: profileScope,
      );
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        if (removedEntry != null) {
          await _upsertEntryInCache(removedEntry);
        }
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'DELETE',
          path: path,
          body: const <String, dynamic>{},
          lastError: error.message,
          replaceExisting: true,
        );
      }
      await _discardMatchingPendingCreates(
        entryDate: removedEntryDate,
        profileScope: profileScope,
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'DELETE',
        path: path,
        body: const <String, dynamic>{},
        lastError: error.toString(),
        replaceExisting: true,
      );
      await _discardMatchingPendingCreates(
        entryDate: removedEntryDate,
        profileScope: profileScope,
      );
    }
  }

  Future<void> _upsertEntryInCache(Map<String, dynamic> entry) async {
    final entries = await _readCachedEntriesJson() ?? <Map<String, dynamic>>[];
    final normalized = _normalizeEntry(entry);
    final entryId = normalized['id'].toString();
    final index = entries.indexWhere(
      (item) => item['id']?.toString() == entryId,
    );
    if (index == -1) {
      entries.add(normalized);
    } else {
      entries[index] = normalized;
    }
    _sortEntriesDescending(entries);
    await _writeCachedEntriesJson(entries);
  }

  List<Map<String, dynamic>> _mergeRemoteWithCachedEntries({
    required List<Map<String, dynamic>> remoteEntries,
    required List<Map<String, dynamic>> cachedEntries,
  }) {
    final merged = remoteEntries.map(_normalizeEntry).toList();
    final seenIds = merged
        .map((entry) => entry['id']?.toString())
        .whereType<String>()
        .toSet();
    final nowUtc = DateTime.now().toUtc();

    for (final cachedEntry in cachedEntries) {
      final normalized = _normalizeEntry(cachedEntry);
      final id = normalized['id']?.toString();
      if (id == null || id.isEmpty || seenIds.contains(id)) {
        continue;
      }
      if (_shouldKeepCachedEntry(normalized, nowUtc)) {
        merged.add(normalized);
        seenIds.add(id);
      }
    }

    _sortEntriesDescending(merged);
    return merged;
  }

  bool _shouldKeepCachedEntry(Map<String, dynamic> entry, DateTime nowUtc) {
    final entryId = entry['id']?.toString() ?? '';
    if (_isPendingId(entryId) || entry['pending_sync'] == true) {
      return true;
    }

    final shadowUntilRaw = entry[_localShadowUntilKey]?.toString();
    if (shadowUntilRaw == null || shadowUntilRaw.trim().isEmpty) {
      return false;
    }
    final shadowUntil = DateTime.tryParse(shadowUntilRaw.trim());
    if (shadowUntil == null) {
      return false;
    }
    return shadowUntil.toUtc().isAfter(nowUtc);
  }

  Future<void> _upsertSymptomInCache(
    String entryId,
    Map<String, dynamic> symptom,
  ) async {
    final entries = await _readCachedEntriesJson() ?? <Map<String, dynamic>>[];
    final index = entries.indexWhere(
      (item) => item['id']?.toString() == entryId,
    );
    final normalizedSymptom = _normalizeSymptom(symptom);

    if (index == -1) {
      final syntheticEntry = _buildPendingEntry({
        'entry_date': _todayIsoDate(),
      });
      syntheticEntry['id'] = entryId;
      syntheticEntry['symptoms'] = <Map<String, dynamic>>[normalizedSymptom];
      entries.add(syntheticEntry);
    } else {
      final current = _normalizeEntry(entries[index]);
      final symptoms = _normalizeSymptomList(current['symptoms']);
      final symptomIndex = symptoms.indexWhere(
        (item) => item['id']?.toString() == normalizedSymptom['id']?.toString(),
      );
      if (symptomIndex == -1) {
        symptoms.add(normalizedSymptom);
      } else {
        symptoms[symptomIndex] = normalizedSymptom;
      }
      current['symptoms'] = symptoms;
      entries[index] = current;
    }

    _sortEntriesDescending(entries);
    await _writeCachedEntriesJson(entries);
  }

  Future<void> _upsertVitalInCache(
    String entryId,
    Map<String, dynamic> vital,
  ) async {
    final entries = await _readCachedEntriesJson() ?? <Map<String, dynamic>>[];
    final index = entries.indexWhere(
      (item) => item['id']?.toString() == entryId,
    );
    final normalizedVital = _normalizeVital(vital);

    if (index == -1) {
      final syntheticEntry = _buildPendingEntry({
        'entry_date': _todayIsoDate(),
      });
      syntheticEntry['id'] = entryId;
      syntheticEntry['vitals'] = <Map<String, dynamic>>[normalizedVital];
      entries.add(syntheticEntry);
    } else {
      final current = _normalizeEntry(entries[index]);
      final vitals = _normalizeVitalList(current['vitals']);
      final vitalIndex = vitals.indexWhere(
        (item) => item['id']?.toString() == normalizedVital['id']?.toString(),
      );
      if (vitalIndex == -1) {
        vitals.add(normalizedVital);
      } else {
        vitals[vitalIndex] = normalizedVital;
      }
      current['vitals'] = vitals;
      entries[index] = current;
    }

    _sortEntriesDescending(entries);
    await _writeCachedEntriesJson(entries);
  }

  Future<Map<String, dynamic>?> _removeEntryFromCache(String entryId) async {
    final entries = await _readCachedEntriesJson();
    if (entries == null) {
      return null;
    }

    final index = entries.indexWhere(
      (item) => item['id']?.toString() == entryId,
    );
    if (index < 0) {
      return null;
    }

    final removed = _normalizeEntry(entries.removeAt(index));
    await _writeCachedEntriesJson(entries);
    return removed;
  }

  Future<void> _discardMatchingPendingCreates({
    required String? entryDate,
    required String? profileScope,
  }) async {
    if (entryDate == null || entryDate.trim().isEmpty) {
      return;
    }

    final queued = await _localDatabase.listPendingOperations(limit: 500);
    for (final operation in queued) {
      if (operation.method.toUpperCase() != 'POST' ||
          operation.path != '/api/v1/daily-entries') {
        continue;
      }
      if (!_sameProfileScope(operation.profileId, profileScope)) {
        continue;
      }

      final payload = operation.payload;
      if (payload == null || payload.trim().isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) {
          continue;
        }
        final pendingDate = decoded['entry_date']?.toString().trim();
        if (pendingDate == null || pendingDate.isEmpty) {
          continue;
        }
        if (pendingDate == entryDate.trim()) {
          await _localDatabase.markPendingOperationSynced(operation.id);
        }
      } catch (_) {
        // Best effort cleanup for orphaned pending create operations.
      }
    }
  }

  bool _sameProfileScope(String? left, String? right) {
    final normalizedLeft = left?.trim();
    final normalizedRight = right?.trim();
    final leftEmpty = normalizedLeft == null || normalizedLeft.isEmpty;
    final rightEmpty = normalizedRight == null || normalizedRight.isEmpty;
    if (leftEmpty && rightEmpty) {
      return true;
    }
    return normalizedLeft == normalizedRight;
  }

  List<DailyEntry> _decodeEntries(List<Map<String, dynamic>> entries) {
    return entries.map(DailyEntry.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>?> _readCachedEntriesJson() async {
    final cached = await readProfileScopedCache(_localDatabase, _cacheKey);
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeCachedEntriesJson(
    List<Map<String, dynamic>> entries,
  ) async {
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, _cacheKey),
      payload: jsonEncode(entries),
    );
  }

  void _sortEntriesDescending(List<Map<String, dynamic>> entries) {
    entries.sort((a, b) {
      final aDate = _tryParseDate(a['entry_date']?.toString());
      final bDate = _tryParseDate(b['entry_date']?.toString());
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
  }

  Map<String, dynamic> _normalizeEntry(Map<String, dynamic> entry) {
    final normalized = Map<String, dynamic>.from(entry);
    normalized['id'] = normalized['id']?.toString() ?? _pendingId('entry');
    normalized['entry_date'] = _normalizeEntryDate(normalized['entry_date']);
    normalized['sleep_hours'] = _asDouble(normalized['sleep_hours']);
    normalized['sleep_quality'] = _asInt(normalized['sleep_quality']);
    normalized['energy_level'] = _asInt(normalized['energy_level']);
    normalized['mood_level'] = _asInt(normalized['mood_level']);
    normalized['stress_level'] = _asInt(normalized['stress_level']);
    normalized['appetite_level'] = _asInt(normalized['appetite_level']);
    normalized['hydration_level'] = _asInt(normalized['hydration_level']);
    normalized['general_pain'] = _asInt(normalized['general_pain']);
    normalized['general_notes'] = normalized['general_notes']?.toString();
    normalized['symptoms'] = _normalizeSymptomList(normalized['symptoms']);
    normalized['vitals'] = _normalizeVitalList(normalized['vitals']);
    if (normalized.containsKey(_localShadowUntilKey)) {
      normalized[_localShadowUntilKey] = _normalizeDateTime(
        normalized[_localShadowUntilKey],
      );
    }
    return normalized;
  }

  List<Map<String, dynamic>> _normalizeSymptomList(dynamic raw) {
    final list = raw as List<dynamic>? ?? const <dynamic>[];
    return list
        .map(
          (item) => _normalizeSymptom(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  List<Map<String, dynamic>> _normalizeVitalList(dynamic raw) {
    final list = raw as List<dynamic>? ?? const <dynamic>[];
    return list
        .map((item) => _normalizeVital(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Map<String, dynamic> _normalizeSymptom(Map<String, dynamic> symptom) {
    final normalized = Map<String, dynamic>.from(symptom);
    normalized['id'] = normalized['id']?.toString() ?? _pendingId('symptom');
    normalized['symptom_code'] =
        normalized['symptom_code']?.toString() ?? 'custom';
    normalized['severity'] = _asInt(normalized['severity']);
    normalized['duration_minutes'] = _asInt(normalized['duration_minutes']);
    normalized['body_location'] = normalized['body_location']?.toString();
    normalized['metadata_json'] = _normalizeMetadata(
      normalized['metadata_json'],
    );
    return normalized;
  }

  Map<String, dynamic> _normalizeVital(Map<String, dynamic> vital) {
    final normalized = Map<String, dynamic>.from(vital);
    normalized['id'] = normalized['id']?.toString() ?? _pendingId('vital');
    normalized['type'] = normalized['type']?.toString() ?? 'generic';
    normalized['value'] = normalized['value']?.toString() ?? '';
    normalized['unit'] = normalized['unit']?.toString();
    normalized['measured_at'] =
        _normalizeDateTime(normalized['measured_at']) ??
        DateTime.now().toUtc().toIso8601String();
    return normalized;
  }

  Map<String, dynamic> _buildPendingEntry(Map<String, dynamic> payload) {
    return _normalizeEntry({
      'id': _pendingId('entry'),
      'entry_date': payload['entry_date'] ?? _todayIsoDate(),
      'sleep_hours': payload['sleep_hours'],
      'sleep_quality': payload['sleep_quality'],
      'energy_level': payload['energy_level'],
      'mood_level': payload['mood_level'],
      'stress_level': payload['stress_level'],
      'appetite_level': payload['appetite_level'],
      'hydration_level': payload['hydration_level'],
      'general_pain': payload['general_pain'],
      'general_notes': payload['general_notes'],
      'symptoms': const <Map<String, dynamic>>[],
      'vitals': const <Map<String, dynamic>>[],
      'pending_sync': true,
    });
  }

  Map<String, dynamic> _buildPendingSymptom(Map<String, dynamic> payload) {
    return _normalizeSymptom({
      'id': _pendingId('symptom'),
      'symptom_code': payload['symptom_code'],
      'severity': payload['severity'],
      'duration_minutes': payload['duration_minutes'],
      'body_location': payload['body_location'],
      'metadata_json': payload['metadata_json'],
      'pending_sync': true,
    });
  }

  Map<String, dynamic> _buildPendingVital(Map<String, dynamic> payload) {
    return _normalizeVital({
      'id': _pendingId('vital'),
      'type': payload['type'],
      'value': payload['value'],
      'unit': payload['unit'],
      'measured_at': payload['measured_at'],
      'pending_sync': true,
    });
  }

  Map<String, dynamic> _normalizeMetadata(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(entry.key.toString(), entry.value),
        ),
      );
    }
    if (value is String && value.trim().isNotEmpty) {
      return <String, dynamic>{'notes': value.trim()};
    }
    return const <String, dynamic>{};
  }

  String _normalizeEntryDate(dynamic value) {
    final parsed = _tryParseDate(value?.toString());
    if (parsed != null) {
      return parsed.toIso8601String().split('T').first;
    }
    return _todayIsoDate();
  }

  String? _normalizeDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(text);
    return parsed?.toUtc().toIso8601String() ?? text;
  }

  DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.trim());
  }

  String _todayIsoDate() {
    return DateTime.now().toUtc().toIso8601String().split('T').first;
  }

  String _buildLocalShadowUntilIso({
    Duration ttl = const Duration(minutes: 10),
  }) {
    return DateTime.now().toUtc().add(ttl).toIso8601String();
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  bool _isPendingId(String value) => value.startsWith('pending-');

  bool _isLocalOnlyError(ApiException error) => error.code == 'local_only_mode';

  String _pendingId(String prefix) {
    return 'pending-$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
}
