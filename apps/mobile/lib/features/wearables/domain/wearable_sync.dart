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
      return const [
        'Wearable sync disponibile solo su Android e iPhone.',
      ];
    }
    if (!isAvailable) {
      return const [
        'Installa o aggiorna Health Connect prima di tentare la sincronizzazione.',
      ];
    }

    final steps = <String>[];
    if (!hasHealthPermissions) {
      steps.add(
        'Apri le autorizzazioni di Health Connect e abilita la lettura dati per ClinDiary.',
      );
    }
    if (!hasActivityRecognition) {
      steps.add(
        'Concedi ad Android il permesso Attività fisica, altrimenti passi e movimento restano bloccati.',
      );
    }
    if (hasHealthPermissions &&
        hasActivityRecognition &&
        recentSummaries.isEmpty) {
      steps.add(
        'ClinDiary ha i permessi, ma non trova giornate recenti: verifica che Xiaomi Fitness/Mi Fitness scriva davvero in Health Connect.',
      );
      steps.add(
        'In Health Connect controlla App permissions e verifica che Xiaomi Fitness abbia accesso in scrittura per passi, sonno, frequenza cardiaca e SpO2.',
      );
    }
    if (!historyAccessGranted) {
      steps.add(
        'Lo storico potrebbe essere limitato: abilita anche l’accesso ai dati storici nelle autorizzazioni salute.',
      );
    }
    if (steps.isEmpty) {
      steps.add(
        'Connessione wearable pronta. Se manca ancora qualche metrica, controlla quali tipi dati Xiaomi Fitness sta esportando in Health Connect.',
      );
    }
    return steps;
  }

  String toDiagnosticText({
    List<WearableDaySummary> recentSummaries = const [],
  }) {
    final lines = <String>[
      'Diagnostica wearable',
      'Supportato: ${_boolLabel(isSupported)}',
      'Piattaforma: $platformLabel',
      'Provider: $providerName',
      'Disponibile: ${_boolLabel(isAvailable)}',
      'Permesso lettura: ${_boolLabel(permissionGranted)}',
      'Provider installabile: ${_boolLabel(canInstallProvider)}',
      'Storico accessibile: ${_boolLabel(historyAccessGranted)}',
    ];
    if (isAndroid) {
      lines.add('Permessi Health Connect: ${_boolLabel(hasHealthPermissions)}');
      lines.add(
        'Permesso Attività fisica: ${_boolLabel(hasActivityRecognition)}',
      );
    }

    final cleanedMessage = message?.trim();
    if (cleanedMessage != null && cleanedMessage.isNotEmpty) {
      lines.add('Messaggio: $cleanedMessage');
    }

    if (recentSummaries.isEmpty) {
      lines.add('Sincronizzazione wearable: nessuna giornata recente salvata.');
    } else {
      lines.add(
        'Sincronizzazione wearable: ${recentSummaries.length} giornate recenti.',
      );
      for (final summary in recentSummaries.take(3)) {
        lines.add(summary.toDiagnosticText());
      }
    }

    final checklist = diagnosticChecklist(recentSummaries: recentSummaries);
    if (checklist.isNotEmpty) {
      lines.add('Controlli consigliati:');
      for (var index = 0; index < checklist.length; index++) {
        lines.add('${index + 1}. ${checklist[index]}');
      }
    }

    return lines.join('\n');
  }

  static String _boolLabel(bool value) => value ? 'sì' : 'no';
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
