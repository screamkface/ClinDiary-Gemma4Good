enum AiBootstrapPhase {
  notStarted,
  checkingAppOwnedModelState,
  installingOrDownloading,
  verifying,
  ready,
  failed,
}

class AiBootstrapStatus {
  const AiBootstrapStatus({
    required this.phase,
    required this.modelName,
    required this.runtime,
    required this.provider,
    required this.mode,
    this.message = '',
    this.modelPath,
    this.modelDirectory,
    this.progressPercent,
    this.lastError,
    this.allowAppAccess = false,
    this.lastInferenceLatencyMillis,
    this.lastVerifiedAt,
  });

  const AiBootstrapStatus.notStarted({
    required this.modelName,
    required this.runtime,
    required this.provider,
    this.mode = 'local',
    this.message = 'Model setup has not started yet.',
    this.modelPath,
    this.modelDirectory,
  }) : phase = AiBootstrapPhase.notStarted,
       progressPercent = null,
       lastError = null,
       allowAppAccess = false,
       lastInferenceLatencyMillis = null,
       lastVerifiedAt = null;

  final AiBootstrapPhase phase;
  final String modelName;
  final String runtime;
  final String provider;
  final String mode;
  final String message;
  final String? modelPath;
  final String? modelDirectory;
  final int? progressPercent;
  final String? lastError;
  final bool allowAppAccess;
  final int? lastInferenceLatencyMillis;
  final DateTime? lastVerifiedAt;

  bool get isReady => phase == AiBootstrapPhase.ready;

  bool get isBusy => switch (phase) {
    AiBootstrapPhase.checkingAppOwnedModelState ||
    AiBootstrapPhase.installingOrDownloading ||
    AiBootstrapPhase.verifying => true,
    AiBootstrapPhase.notStarted ||
    AiBootstrapPhase.ready ||
    AiBootstrapPhase.failed => false,
  };

  String get stepLabel => switch (phase) {
    AiBootstrapPhase.notStarted => 'not started',
    AiBootstrapPhase.checkingAppOwnedModelState => 'checking',
    AiBootstrapPhase.installingOrDownloading => 'downloading/installing',
    AiBootstrapPhase.verifying => 'verifying',
    AiBootstrapPhase.ready => 'ready',
    AiBootstrapPhase.failed => 'failed',
  };

  AiBootstrapStatus copyWith({
    AiBootstrapPhase? phase,
    String? modelName,
    String? runtime,
    String? provider,
    String? mode,
    String? message,
    String? modelPath,
    String? modelDirectory,
    int? progressPercent,
    String? lastError,
    bool? allowAppAccess,
    int? lastInferenceLatencyMillis,
    DateTime? lastVerifiedAt,
  }) {
    return AiBootstrapStatus(
      phase: phase ?? this.phase,
      modelName: modelName ?? this.modelName,
      runtime: runtime ?? this.runtime,
      provider: provider ?? this.provider,
      mode: mode ?? this.mode,
      message: message ?? this.message,
      modelPath: modelPath ?? this.modelPath,
      modelDirectory: modelDirectory ?? this.modelDirectory,
      progressPercent: progressPercent ?? this.progressPercent,
      lastError: lastError ?? this.lastError,
      allowAppAccess: allowAppAccess ?? this.allowAppAccess,
      lastInferenceLatencyMillis:
          lastInferenceLatencyMillis ?? this.lastInferenceLatencyMillis,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }
}
