class DeviceProviderItem {
  const DeviceProviderItem({
    required this.code,
    required this.displayName,
    required this.summary,
    required this.category,
    required this.integrationKind,
    required this.connectionFlow,
    required this.docsUrl,
    required this.capabilities,
    required this.setupNotes,
    required this.isWaveOne,
    required this.requiresVendorContract,
    required this.providerConfigured,
    required this.supportsLiveSync,
    required this.supportsManualIngest,
    required this.priority,
  });

  final String code;
  final String displayName;
  final String summary;
  final String category;
  final String integrationKind;
  final String connectionFlow;
  final String docsUrl;
  final List<String> capabilities;
  final List<String> setupNotes;
  final bool isWaveOne;
  final bool requiresVendorContract;
  final bool providerConfigured;
  final bool supportsLiveSync;
  final bool supportsManualIngest;
  final int priority;

  bool get isOauthFlow => connectionFlow == 'oauth2';
  bool get isApiKeyFlow => connectionFlow == 'api_key';
  bool get isPartnerSetup => connectionFlow == 'partner_setup';

  factory DeviceProviderItem.fromJson(Map<String, dynamic> json) =>
      DeviceProviderItem(
        code: json['code'].toString(),
        displayName: json['display_name'].toString(),
        summary: json['summary'].toString(),
        category: json['category'].toString(),
        integrationKind: json['integration_kind'].toString(),
        connectionFlow: json['connection_flow'].toString(),
        docsUrl: json['docs_url'].toString(),
        capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        setupNotes: (json['setup_notes'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        isWaveOne: json['is_wave_one'] as bool? ?? false,
        requiresVendorContract:
            json['requires_vendor_contract'] as bool? ?? false,
        providerConfigured: json['provider_configured'] as bool? ?? false,
        supportsLiveSync: json['supports_live_sync'] as bool? ?? false,
        supportsManualIngest:
            json['supports_manual_ingest'] as bool? ?? false,
        priority: json['priority'] as int? ?? 0,
      );
}

class DeviceMeasurementItem {
  const DeviceMeasurementItem({
    required this.id,
    required this.providerCode,
    required this.metricType,
    required this.measuredAt,
    this.connectionId,
    this.sourceDeviceModel,
    this.unit,
    this.primaryValue,
    this.secondaryValue,
    this.tertiaryValue,
    this.notes,
    required this.displayTitle,
    required this.displayValue,
  });

  final String id;
  final String providerCode;
  final String metricType;
  final DateTime measuredAt;
  final String? connectionId;
  final String? sourceDeviceModel;
  final String? unit;
  final double? primaryValue;
  final double? secondaryValue;
  final double? tertiaryValue;
  final String? notes;
  final String displayTitle;
  final String displayValue;

  factory DeviceMeasurementItem.fromJson(Map<String, dynamic> json) =>
      DeviceMeasurementItem(
        id: json['id'].toString(),
        providerCode: json['provider_code'].toString(),
        metricType: json['metric_type'].toString(),
        measuredAt: DateTime.parse(json['measured_at'].toString()),
        connectionId: json['connection_id']?.toString(),
        sourceDeviceModel: json['source_device_model'] as String?,
        unit: json['unit'] as String?,
        primaryValue: (json['primary_value'] as num?)?.toDouble(),
        secondaryValue: (json['secondary_value'] as num?)?.toDouble(),
        tertiaryValue: (json['tertiary_value'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        displayTitle: json['display_title'].toString(),
        displayValue: json['display_value'].toString(),
      );
}

class DeviceImportJobItem {
  const DeviceImportJobItem({
    required this.id,
    required this.providerCode,
    required this.status,
    required this.startedAt,
    this.connectionId,
    this.completedAt,
    required this.itemCount,
    this.summary,
    this.errorMessage,
  });

  final String id;
  final String providerCode;
  final String status;
  final DateTime startedAt;
  final String? connectionId;
  final DateTime? completedAt;
  final int itemCount;
  final String? summary;
  final String? errorMessage;

  factory DeviceImportJobItem.fromJson(Map<String, dynamic> json) =>
      DeviceImportJobItem(
        id: json['id'].toString(),
        providerCode: json['provider_code'].toString(),
        status: json['status'].toString(),
        startedAt: DateTime.parse(json['started_at'].toString()),
        connectionId: json['connection_id']?.toString(),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'].toString()),
        itemCount: json['item_count'] as int? ?? 0,
        summary: json['summary'] as String?,
        errorMessage: json['error_message'] as String?,
      );
}

class DeviceConnectionItem {
  const DeviceConnectionItem({
    required this.id,
    required this.providerCode,
    required this.providerName,
    required this.integrationKind,
    required this.connectionFlow,
    required this.status,
    this.accountLabel,
    this.externalUserId,
    this.tokenExpiresAt,
    this.lastSyncedAt,
    this.lastError,
    required this.measurementCount,
    this.latestMeasurement,
    required this.supportsLiveSync,
    required this.supportsManualIngest,
  });

  final String id;
  final String providerCode;
  final String providerName;
  final String integrationKind;
  final String connectionFlow;
  final String status;
  final String? accountLabel;
  final String? externalUserId;
  final DateTime? tokenExpiresAt;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final int measurementCount;
  final DeviceMeasurementItem? latestMeasurement;
  final bool supportsLiveSync;
  final bool supportsManualIngest;

  bool get isConnected => status == 'connected';
  bool get isPending => status == 'pending';

  factory DeviceConnectionItem.fromJson(Map<String, dynamic> json) =>
      DeviceConnectionItem(
        id: json['id'].toString(),
        providerCode: json['provider_code'].toString(),
        providerName: json['provider_name'].toString(),
        integrationKind: json['integration_kind'].toString(),
        connectionFlow: json['connection_flow'].toString(),
        status: json['status'].toString(),
        accountLabel: json['account_label'] as String?,
        externalUserId: json['external_user_id'] as String?,
        tokenExpiresAt: json['token_expires_at'] == null
            ? null
            : DateTime.parse(json['token_expires_at'].toString()),
        lastSyncedAt: json['last_synced_at'] == null
            ? null
            : DateTime.parse(json['last_synced_at'].toString()),
        lastError: json['last_error'] as String?,
        measurementCount: json['measurement_count'] as int? ?? 0,
        latestMeasurement: json['latest_measurement'] == null
            ? null
            : DeviceMeasurementItem.fromJson(
                json['latest_measurement'] as Map<String, dynamic>,
              ),
        supportsLiveSync: json['supports_live_sync'] as bool? ?? false,
        supportsManualIngest: json['supports_manual_ingest'] as bool? ?? false,
      );
}

class DeviceOverview {
  const DeviceOverview({
    required this.providers,
    required this.connections,
    required this.recentMeasurements,
    required this.recentJobs,
  });

  final List<DeviceProviderItem> providers;
  final List<DeviceConnectionItem> connections;
  final List<DeviceMeasurementItem> recentMeasurements;
  final List<DeviceImportJobItem> recentJobs;

  int get connectedCount =>
      connections.where((item) => item.status == 'connected').length;
  int get pendingCount =>
      connections.where((item) => item.status == 'pending').length;

  factory DeviceOverview.fromJson(Map<String, dynamic> json) => DeviceOverview(
    providers: (json['providers'] as List<dynamic>? ?? const [])
        .map((item) => DeviceProviderItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    connections: (json['connections'] as List<dynamic>? ?? const [])
        .map(
          (item) => DeviceConnectionItem.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    recentMeasurements:
        (json['recent_measurements'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  DeviceMeasurementItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
    recentJobs: (json['recent_jobs'] as List<dynamic>? ?? const [])
        .map((item) => DeviceImportJobItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class DeviceLinkResult {
  const DeviceLinkResult({
    required this.message,
    required this.provider,
    this.connection,
    this.nextStep,
    required this.requiredFields,
    this.documentationUrl,
  });

  final String message;
  final DeviceProviderItem provider;
  final DeviceConnectionItem? connection;
  final String? nextStep;
  final List<String> requiredFields;
  final String? documentationUrl;

  factory DeviceLinkResult.fromJson(Map<String, dynamic> json) =>
      DeviceLinkResult(
        message: json['message'].toString(),
        provider: DeviceProviderItem.fromJson(
          json['provider'] as Map<String, dynamic>,
        ),
        connection: json['connection'] == null
            ? null
            : DeviceConnectionItem.fromJson(
                json['connection'] as Map<String, dynamic>,
              ),
        nextStep: json['next_step'] as String?,
        requiredFields: (json['required_fields'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        documentationUrl: json['documentation_url'] as String?,
      );
}

class DeviceSyncResult {
  const DeviceSyncResult({
    required this.message,
    required this.job,
    required this.importedCount,
    required this.items,
  });

  final String message;
  final DeviceImportJobItem job;
  final int importedCount;
  final List<DeviceMeasurementItem> items;

  factory DeviceSyncResult.fromJson(Map<String, dynamic> json) =>
      DeviceSyncResult(
        message: json['message'].toString(),
        job: DeviceImportJobItem.fromJson(json['job'] as Map<String, dynamic>),
        importedCount: json['imported_count'] as int? ?? 0,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  DeviceMeasurementItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
