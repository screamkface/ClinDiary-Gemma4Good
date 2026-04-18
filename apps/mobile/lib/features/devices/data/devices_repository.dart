import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/devices/domain/device_hub.dart';

class DevicesRepository {
  DevicesRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _overviewCacheKey = 'devices_overview';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<DeviceOverview> fetchOverview() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson('/api/v1/devices/overview');
      await _writeOverviewCache(response);
      return DeviceOverview.fromJson(response);
    } on ApiException catch (error) {
      final cached = await _readOverviewCacheJson();
      if (cached != null) {
        return DeviceOverview.fromJson(cached);
      }
      if (_isLocalOnlyError(error)) {
        final empty = _emptyOverviewJson();
        await _writeOverviewCache(empty);
        return DeviceOverview.fromJson(empty);
      }
      rethrow;
    } catch (_) {
      final cached = await _readOverviewCacheJson();
      if (cached != null) {
        return DeviceOverview.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<DeviceLinkResult> linkProvider({
    required String providerCode,
    Map<String, dynamic> payload = const {},
  }) async {
    final path = '/api/v1/devices/providers/$providerCode/link';
    try {
      final response = await _apiClient.postJson(path, body: payload);
      await _applyLinkResponseToCache(response);
      return DeviceLinkResult.fromJson(response);
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
      return _buildLocalLinkResult(
        providerCode: providerCode,
        payload: payload,
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: path,
        body: payload,
        lastError: error.toString(),
        replaceExisting: true,
      );
      return _buildLocalLinkResult(
        providerCode: providerCode,
        payload: payload,
      );
    }
  }

  Future<void> disconnectConnection(String connectionId) async {
    final path = '/api/v1/devices/connections/$connectionId';
    try {
      await _apiClient.delete(path);
      await _removeConnectionFromCache(connectionId);
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
      await _removeConnectionFromCache(connectionId);
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'DELETE',
        path: path,
        body: const {},
        lastError: error.toString(),
        replaceExisting: true,
      );
      await _removeConnectionFromCache(connectionId);
    }
  }

  Future<DeviceSyncResult> syncConnection(String connectionId) async {
    final path = '/api/v1/devices/connections/$connectionId/sync';
    try {
      final response = await _apiClient.postJson(path, body: const {});
      await _applySyncResponseToCache(response, connectionId: connectionId);
      return DeviceSyncResult.fromJson(response);
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      if (!_isLocalOnlyError(error)) {
        await _apiClient.enqueueJsonOperation(
          method: 'POST',
          path: path,
          body: const {},
          lastError: error.message,
          replaceExisting: true,
        );
      }
      return _buildLocalSyncResult(connectionId);
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: path,
        body: const {},
        lastError: error.toString(),
        replaceExisting: true,
      );
      return _buildLocalSyncResult(connectionId);
    }
  }

  Future<int> ingestMeasurements({
    required String connectionId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) {
      return 0;
    }

    final path = '/api/v1/devices/connections/$connectionId/measurements';
    final payload = {'items': items};
    try {
      final response = await _apiClient.postJson(path, body: payload);
      final createdCount = response['created_count'] as int? ?? items.length;
      await _appendMeasurementsToCache(
        connectionId: connectionId,
        items: items,
      );
      return createdCount;
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
        );
      }
      return _appendMeasurementsToCache(
        connectionId: connectionId,
        items: items,
      );
    } catch (error) {
      await _apiClient.enqueueJsonOperation(
        method: 'POST',
        path: path,
        body: payload,
        lastError: error.toString(),
      );
      return _appendMeasurementsToCache(
        connectionId: connectionId,
        items: items,
      );
    }
  }

  Future<Map<String, dynamic>?> _readOverviewCacheJson() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      _overviewCacheKey,
    );
    if (cached == null) {
      return null;
    }
    return Map<String, dynamic>.from(
      jsonDecode(cached) as Map<String, dynamic>,
    );
  }

  Future<void> _writeOverviewCache(Map<String, dynamic> overview) async {
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, _overviewCacheKey),
      payload: jsonEncode(overview),
    );
  }

  Future<void> _applyLinkResponseToCache(Map<String, dynamic> response) async {
    final overview = await _readOverviewCacheJson() ?? _emptyOverviewJson();
    final providers = _providersFromOverview(overview);
    final provider = Map<String, dynamic>.from(
      response['provider'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
    );
    if (provider.isNotEmpty) {
      _upsertById(providers, provider, idKey: 'code');
      overview['providers'] = providers;
    }

    final connection = response['connection'];
    if (connection is Map<String, dynamic>) {
      final connections = _connectionsFromOverview(overview);
      _upsertById(
        connections,
        Map<String, dynamic>.from(connection),
        idKey: 'id',
      );
      overview['connections'] = connections;
    }

    await _writeOverviewCache(overview);
  }

  Future<DeviceLinkResult> _buildLocalLinkResult({
    required String providerCode,
    required Map<String, dynamic> payload,
  }) async {
    final overview = await _readOverviewCacheJson() ?? _emptyOverviewJson();
    final provider = _resolveProvider(overview, providerCode);
    final connection = _buildPendingConnection(provider, payload);

    final connections = _connectionsFromOverview(overview);
    _upsertById(connections, connection, idKey: 'id');
    overview['connections'] = connections;

    final providers = _providersFromOverview(overview);
    _upsertById(providers, provider, idKey: 'code');
    overview['providers'] = providers;
    await _writeOverviewCache(overview);

    return DeviceLinkResult.fromJson({
      'message': 'Connector saved locally.',
      'provider': provider,
      'connection': connection,
      'next_step': 'sync_when_ready',
      'required_fields': const <String>[],
      'documentation_url': provider['docs_url'],
    });
  }

  Future<void> _removeConnectionFromCache(String connectionId) async {
    final overview = await _readOverviewCacheJson();
    if (overview == null) {
      return;
    }
    final connections = _connectionsFromOverview(overview)
      ..removeWhere((item) => item['id']?.toString() == connectionId);
    overview['connections'] = connections;
    await _writeOverviewCache(overview);
  }

  Future<void> _applySyncResponseToCache(
    Map<String, dynamic> response, {
    required String connectionId,
  }) async {
    final overview = await _readOverviewCacheJson() ?? _emptyOverviewJson();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final jobs = _jobsFromOverview(overview);
    final job = Map<String, dynamic>.from(
      response['job'] as Map<String, dynamic>? ??
          {
            'id': 'local-job-${DateTime.now().microsecondsSinceEpoch}',
            'provider_code': _providerCodeForConnection(overview, connectionId),
            'status': 'succeeded',
            'started_at': nowIso,
            'connection_id': connectionId,
            'completed_at': nowIso,
            'item_count': response['imported_count'] as int? ?? 0,
            'summary': 'Sync completed',
            'error_message': null,
          },
    );
    _upsertById(jobs, job, idKey: 'id');
    overview['recent_jobs'] = jobs.take(10).toList();

    final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
    if (items.isNotEmpty) {
      final measurements = _measurementsFromOverview(overview);
      measurements.insertAll(0, items);
      overview['recent_measurements'] = measurements.take(25).toList();
    }

    final connections = _connectionsFromOverview(overview);
    final connectionIndex = connections.indexWhere(
      (item) => item['id']?.toString() == connectionId,
    );
    if (connectionIndex != -1) {
      final connection = Map<String, dynamic>.from(
        connections[connectionIndex],
      );
      connection['last_synced_at'] = nowIso;
      connection['status'] = 'connected';
      if (items.isNotEmpty) {
        connection['latest_measurement'] = items.first;
      }
      final importedCount = response['imported_count'] as int? ?? items.length;
      connection['measurement_count'] =
          (connection['measurement_count'] as int? ?? 0) + importedCount;
      connections[connectionIndex] = connection;
      overview['connections'] = connections;
    }

    await _writeOverviewCache(overview);
  }

  Future<DeviceSyncResult> _buildLocalSyncResult(String connectionId) async {
    final overview = await _readOverviewCacheJson() ?? _emptyOverviewJson();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final providerCode = _providerCodeForConnection(overview, connectionId);
    final job = <String, dynamic>{
      'id': 'local-job-${DateTime.now().microsecondsSinceEpoch}',
      'provider_code': providerCode,
      'status': 'succeeded',
      'started_at': nowIso,
      'connection_id': connectionId,
      'completed_at': nowIso,
      'item_count': 0,
      'summary': 'Local sync completed',
      'error_message': null,
    };

    final jobs = _jobsFromOverview(overview);
    jobs.insert(0, job);
    overview['recent_jobs'] = jobs.take(10).toList();

    final connections = _connectionsFromOverview(overview);
    final connectionIndex = connections.indexWhere(
      (item) => item['id']?.toString() == connectionId,
    );
    if (connectionIndex != -1) {
      final connection = Map<String, dynamic>.from(
        connections[connectionIndex],
      );
      connection['last_synced_at'] = nowIso;
      connection['status'] = 'connected';
      connections[connectionIndex] = connection;
      overview['connections'] = connections;
    }
    await _writeOverviewCache(overview);

    return DeviceSyncResult.fromJson({
      'message': 'Local sync completed.',
      'job': job,
      'imported_count': 0,
      'items': const <Map<String, dynamic>>[],
    });
  }

  Future<int> _appendMeasurementsToCache({
    required String connectionId,
    required List<Map<String, dynamic>> items,
  }) async {
    final overview = await _readOverviewCacheJson() ?? _emptyOverviewJson();
    final providerCode = _providerCodeForConnection(overview, connectionId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final measurements = _measurementsFromOverview(overview);

    final built = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final primary = _asDouble(item['primary_value']);
      final secondary = _asDouble(item['secondary_value']);
      final tertiary = _asDouble(item['tertiary_value']);
      final unit = item['unit']?.toString();
      final metricType = item['metric_type']?.toString() ?? 'measurement';
      built.add({
        'id': 'local-measurement-${DateTime.now().microsecondsSinceEpoch}-$i',
        'provider_code': providerCode,
        'metric_type': metricType,
        'measured_at': item['measured_at']?.toString() ?? nowIso,
        'connection_id': connectionId,
        'source_device_model': item['source_device_model'],
        'unit': unit,
        'primary_value': primary,
        'secondary_value': secondary,
        'tertiary_value': tertiary,
        'notes': item['notes'],
        'display_title': _metricLabel(metricType),
        'display_value': _measurementDisplayValue(
          primary: primary,
          secondary: secondary,
          tertiary: tertiary,
          unit: unit,
        ),
      });
    }

    measurements.insertAll(0, built);
    overview['recent_measurements'] = measurements.take(25).toList();

    final connections = _connectionsFromOverview(overview);
    final connectionIndex = connections.indexWhere(
      (item) => item['id']?.toString() == connectionId,
    );
    if (connectionIndex != -1) {
      final connection = Map<String, dynamic>.from(
        connections[connectionIndex],
      );
      connection['last_synced_at'] = nowIso;
      connection['status'] = 'connected';
      connection['measurement_count'] =
          (connection['measurement_count'] as int? ?? 0) + built.length;
      if (built.isNotEmpty) {
        connection['latest_measurement'] = built.first;
      }
      connections[connectionIndex] = connection;
      overview['connections'] = connections;
    }

    await _writeOverviewCache(overview);
    return built.length;
  }

  Map<String, dynamic> _resolveProvider(
    Map<String, dynamic> overview,
    String providerCode,
  ) {
    final providers = _providersFromOverview(overview);
    final existing = providers
        .where((item) => item['code']?.toString() == providerCode)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;
    if (existing != null) {
      return existing;
    }
    return <String, dynamic>{
      'code': providerCode,
      'display_name': providerCode.toUpperCase(),
      'summary': 'Local connector',
      'category': 'clinical_device',
      'integration_kind': 'sdk_bridge',
      'connection_flow': 'partner_setup',
      'docs_url': '',
      'capabilities': const <String>[],
      'setup_notes': const <String>[],
      'is_wave_one': false,
      'requires_vendor_contract': false,
      'provider_configured': true,
      'supports_live_sync': true,
      'supports_manual_ingest': true,
      'priority': 999,
    };
  }

  Map<String, dynamic> _buildPendingConnection(
    Map<String, dynamic> provider,
    Map<String, dynamic> payload,
  ) {
    return {
      'id': 'pending-connection-${DateTime.now().microsecondsSinceEpoch}',
      'provider_code': provider['code'],
      'provider_name': provider['display_name'],
      'integration_kind': provider['integration_kind'],
      'connection_flow': provider['connection_flow'],
      'status': 'connected',
      'account_label': payload['account_label'],
      'external_user_id': payload['external_user_id'],
      'token_expires_at': null,
      'last_synced_at': DateTime.now().toUtc().toIso8601String(),
      'last_error': null,
      'measurement_count': 0,
      'latest_measurement': null,
      'supports_live_sync': provider['supports_live_sync'] as bool? ?? true,
      'supports_manual_ingest':
          provider['supports_manual_ingest'] as bool? ?? true,
    };
  }

  List<Map<String, dynamic>> _providersFromOverview(Map<String, dynamic> json) {
    return _mapsFromList(json['providers']);
  }

  List<Map<String, dynamic>> _connectionsFromOverview(
    Map<String, dynamic> json,
  ) {
    return _mapsFromList(json['connections']);
  }

  List<Map<String, dynamic>> _measurementsFromOverview(
    Map<String, dynamic> json,
  ) {
    return _mapsFromList(json['recent_measurements']);
  }

  List<Map<String, dynamic>> _jobsFromOverview(Map<String, dynamic> json) {
    return _mapsFromList(json['recent_jobs']);
  }

  List<Map<String, dynamic>> _mapsFromList(dynamic raw) {
    final list = raw as List<dynamic>? ?? const <dynamic>[];
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  void _upsertById(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> item, {
    required String idKey,
  }) {
    final id = item[idKey]?.toString();
    if (id == null || id.isEmpty) {
      items.insert(0, item);
      return;
    }
    final index = items.indexWhere(
      (current) => current[idKey]?.toString() == id,
    );
    if (index == -1) {
      items.insert(0, item);
    } else {
      items[index] = item;
    }
  }

  String _providerCodeForConnection(
    Map<String, dynamic> overview,
    String connectionId,
  ) {
    final connection = _connectionsFromOverview(
      overview,
    ).where((item) => item['id']?.toString() == connectionId).firstOrNull;
    return connection?['provider_code']?.toString() ?? 'local';
  }

  String _metricLabel(String metricType) {
    switch (metricType) {
      case 'blood_pressure':
        return 'Blood pressure';
      case 'heart_rate':
        return 'Heart rate';
      case 'glucose':
        return 'Glucose';
      case 'weight':
        return 'Weight';
      case 'oxygen_saturation':
        return 'SpO2';
      case 'temperature':
        return 'Temperature';
      default:
        return metricType.replaceAll('_', ' ');
    }
  }

  String _measurementDisplayValue({
    required double? primary,
    required double? secondary,
    required double? tertiary,
    required String? unit,
  }) {
    final unitLabel = (unit == null || unit.trim().isEmpty) ? '' : ' $unit';
    String fmt(double value) {
      final rounded = value.roundToDouble();
      if (rounded == value) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(1);
    }

    if (primary != null && secondary != null) {
      return '${fmt(primary)}/${fmt(secondary)}$unitLabel';
    }
    if (primary != null && tertiary != null) {
      return '${fmt(primary)} • ${fmt(tertiary)}$unitLabel';
    }
    if (primary != null) {
      return '${fmt(primary)}$unitLabel';
    }
    return unitLabel.trim().isEmpty ? 'Recorded' : unitLabel.trim();
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

  Map<String, dynamic> _emptyOverviewJson() {
    return {
      'providers': const <Map<String, dynamic>>[],
      'connections': const <Map<String, dynamic>>[],
      'recent_measurements': const <Map<String, dynamic>>[],
      'recent_jobs': const <Map<String, dynamic>>[],
    };
  }

  bool _isLocalOnlyError(ApiException error) => error.code == 'local_only_mode';

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;
}
