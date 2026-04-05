class LocalAiStatus {
  const LocalAiStatus({
    required this.enabled,
    required this.provider,
    required this.activeProviderLabel,
    required this.runtimeMode,
    required this.backend,
    required this.modelName,
    required this.configuredBaseUrlPresent,
    required this.fallbackProvider,
    required this.isCloudBypassedForThisRequest,
  });

  final bool enabled;
  final String provider;
  final String activeProviderLabel;
  final String runtimeMode;
  final String? backend;
  final String? modelName;
  final bool configuredBaseUrlPresent;
  final String fallbackProvider;
  final bool isCloudBypassedForThisRequest;

  factory LocalAiStatus.fromJson(Map<String, dynamic> json) => LocalAiStatus(
    enabled: json['enabled'] as bool? ?? false,
    provider: json['provider']?.toString() ?? 'local_gemma4',
    activeProviderLabel:
        json['active_provider_label']?.toString() ?? 'Modalita privata locale',
    runtimeMode: json['runtime_mode']?.toString() ?? 'local',
    backend: json['backend']?.toString(),
    modelName: json['model_name']?.toString(),
    configuredBaseUrlPresent:
        json['configured_base_url_present'] as bool? ?? false,
    fallbackProvider: json['fallback_provider']?.toString() ?? 'rule_based',
    isCloudBypassedForThisRequest:
        json['is_cloud_bypassed_for_this_request'] as bool? ?? false,
  );
}
