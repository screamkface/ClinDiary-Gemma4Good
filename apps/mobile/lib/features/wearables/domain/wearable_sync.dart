import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class WearableSyncStatus {
  const WearableSyncStatus({
    required this.isSupported,
    required this.platformLabel,
    required this.providerName,
    required this.isAvailable,
    required this.permissionGranted,
    required this.canInstallProvider,
    required this.historyAccessGranted,
    this.healthPermissionsGranted,
    this.activityRecognitionGranted,
    this.message,
  });

  const WearableSyncStatus.unsupported({this.message})
    : isSupported = false,
      platformLabel = 'unsupported',
      providerName = 'wearable',
      isAvailable = false,
      permissionGranted = false,
      canInstallProvider = false,
      historyAccessGranted = false,
      healthPermissionsGranted = false,
      activityRecognitionGranted = false;

  final bool isSupported;
  final String platformLabel;
  final String providerName;
  final bool isAvailable;
  final bool permissionGranted;
  final bool canInstallProvider;
  final bool historyAccessGranted;
  final bool? healthPermissionsGranted;
  final bool? activityRecognitionGranted;
  final String? message;

  bool get needsPermission => isSupported && isAvailable && !permissionGranted;
  bool get needsProviderInstall =>
      isSupported && !isAvailable && canInstallProvider;
  bool get isAndroid => platformLabel.toLowerCase() == 'android';
  bool get hasHealthPermissions =>
      healthPermissionsGranted ?? permissionGranted;
  bool get hasActivityRecognition =>
      !isAndroid || (activityRecognitionGranted ?? permissionGranted);
  bool get needsHealthPermission =>
      isSupported && isAvailable && !hasHealthPermissions;
  bool get needsActivityPermission =>
      isSupported && isAvailable && isAndroid && !hasActivityRecognition;

  WearableSyncStatus copyWith({
    bool? isSupported,
    String? platformLabel,
    String? providerName,
    bool? isAvailable,
    bool? permissionGranted,
    bool? canInstallProvider,
    bool? historyAccessGranted,
    bool? healthPermissionsGranted,
    bool? activityRecognitionGranted,
    String? message,
  }) {
    return WearableSyncStatus(
      isSupported: isSupported ?? this.isSupported,
      platformLabel: platformLabel ?? this.platformLabel,
      providerName: providerName ?? this.providerName,
      isAvailable: isAvailable ?? this.isAvailable,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      canInstallProvider: canInstallProvider ?? this.canInstallProvider,
      historyAccessGranted: historyAccessGranted ?? this.historyAccessGranted,
      healthPermissionsGranted:
          healthPermissionsGranted ?? this.healthPermissionsGranted,
      activityRecognitionGranted:
          activityRecognitionGranted ?? this.activityRecognitionGranted,
      message: message ?? this.message,
    );
  }

  List<String> diagnosticChecklist({
    List<WearableDaySummary> recentSummaries = const [],
  }) {
    if (!isSupported) {
      return const ['Wearable sync disponibile solo su Android e iPhone.'];
    }
    if (!isAvailable) {
      return const [
        'Install or update Health Connect before attempting synchronization.',
      ];
    }

    final steps = <String>[];
    if (!hasHealthPermissions) {
      steps.add(
        'Open Health Connect permissions and enable data access for ClinDiary.',
      );
    }
    if (!hasActivityRecognition) {
      steps.add(
        'Grant Android activity recognition permission, otherwise steps and movement stay blocked.',
      );
    }
    if (hasHealthPermissions &&
        hasActivityRecognition &&
        recentSummaries.isEmpty) {
      steps.add(
        'ClinDiary has permissions, but no recent days are found: verify that Xiaomi Fitness / Mi Fitness is actually writing to Health Connect.',
      );
      steps.add(
        'In Health Connect, check App permissions and verify that Xiaomi Fitness has write access for steps, sleep, heart rate, and SpO2.',
      );
    }
    if (!historyAccessGranted) {
      steps.add(
        'History access may be limited: also enable historical data access in health permissions.',
      );
    }
    if (steps.isEmpty) {
      steps.add(
        'Wearable connection ready. If some metrics are still missing, check which data types Xiaomi Fitness is exporting to Health Connect.',
      );
    }
    return steps;
  }

  String toDiagnosticText({
    List<WearableDaySummary> recentSummaries = const [],
  }) {
    final lines = <String>[
      'Wearable diagnostics',
      'Supported: ${_boolLabel(isSupported)}',
      'Platform: $platformLabel',
      'Provider: $providerName',
      'Available: ${_boolLabel(isAvailable)}',
      'Read permission: ${_boolLabel(permissionGranted)}',
      'Provider installable: ${_boolLabel(canInstallProvider)}',
      'History accessible: ${_boolLabel(historyAccessGranted)}',
    ];
    if (isAndroid) {
      lines.add(
        'Health Connect permissions: ${_boolLabel(hasHealthPermissions)}',
      );
      lines.add(
        'Activity recognition permission: ${_boolLabel(hasActivityRecognition)}',
      );
    }

    final cleanedMessage = message?.trim();
    if (cleanedMessage != null && cleanedMessage.isNotEmpty) {
      lines.add('Message: $cleanedMessage');
    }

    if (recentSummaries.isEmpty) {
      lines.add('Wearable sync: no recent day saved.');
    } else {
      lines.add('Wearable sync: ${recentSummaries.length} recent days.');
      for (final summary in recentSummaries.take(3)) {
        lines.add(summary.toDiagnosticText());
      }
    }

    final checklist = diagnosticChecklist(recentSummaries: recentSummaries);
    if (checklist.isNotEmpty) {
      lines.add('Recommended checks:');
      for (var index = 0; index < checklist.length; index++) {
        lines.add('${index + 1}. ${checklist[index]}');
      }
    }

    return lines.join('\n');
  }

  static String _boolLabel(bool value) => value ? 'yes' : 'no';
}

class WearableSyncResult {
  const WearableSyncResult({
    required this.collectedCount,
    required this.syncedCount,
    this.message,
  });

  final int collectedCount;
  final int syncedCount;
  final String? message;
}

class WearableSyncException implements Exception {
  const WearableSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
