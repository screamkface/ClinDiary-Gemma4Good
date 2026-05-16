class OnDeviceAiStatus {
  const OnDeviceAiStatus({
    required this.isSupported,
    required this.isReady,
    required this.runtime,
    required this.provider,
    required this.activeProviderLabel,
    required this.backendPreference,
    this.backendResolved,
    this.modelName,
    this.modelPath,
    this.modelFileSizeBytes,
    this.modelLastModifiedAt,
    this.defaultModelDirectory,
    this.lastError,
    this.lastInferenceLatencyMillis,
    this.lastVerifiedAt,
    required this.isCloudBypassedForThisRequest,
  });

  final bool isSupported;
  final bool isReady;
  final String runtime;
  final String provider;
  final String activeProviderLabel;
  final String backendPreference;
  final String? backendResolved;
  final String? modelName;
  final String? modelPath;
  final int? modelFileSizeBytes;
  final DateTime? modelLastModifiedAt;
  final String? defaultModelDirectory;
  final String? lastError;
  final int? lastInferenceLatencyMillis;
  final DateTime? lastVerifiedAt;
  final bool isCloudBypassedForThisRequest;

  factory OnDeviceAiStatus.fromJson(Map<String, dynamic> json) {
    return OnDeviceAiStatus(
      isSupported: json['isSupported'] as bool? ?? false,
      isReady: json['isReady'] as bool? ?? false,
      runtime: json['runtime']?.toString() ?? 'LiteRT-LM Android',
      provider: json['provider']?.toString() ?? 'on_device_litertlm',
      activeProviderLabel:
          json['activeProviderLabel']?.toString() ?? 'On-device locale',
      backendPreference: json['backendPreference']?.toString() ?? 'GPU',
      backendResolved: json['backendResolved']?.toString(),
      modelName: json['modelName']?.toString(),
      modelPath: json['modelPath']?.toString(),
      modelFileSizeBytes: (json['modelFileSizeBytes'] as num?)?.toInt(),
      modelLastModifiedAt: json['modelLastModifiedAt'] == null
          ? null
          : DateTime.tryParse(json['modelLastModifiedAt'].toString()),
      defaultModelDirectory: json['defaultModelDirectory']?.toString(),
      lastError: json['lastError']?.toString(),
      lastInferenceLatencyMillis: (json['lastInferenceLatencyMillis'] as num?)
          ?.toInt(),
      lastVerifiedAt: json['lastVerifiedAt'] == null
          ? null
          : DateTime.tryParse(json['lastVerifiedAt'].toString()),
      isCloudBypassedForThisRequest:
          json['isCloudBypassedForThisRequest'] as bool? ?? true,
    );
  }
}
