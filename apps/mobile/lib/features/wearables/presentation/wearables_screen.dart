import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class WearablesScreen extends ConsumerStatefulWidget {
  const WearablesScreen({super.key});

  @override
  ConsumerState<WearablesScreen> createState() => _WearablesScreenState();
}

class _WearablesScreenState extends ConsumerState<WearablesScreen> {
  bool _syncing = false;
  bool _requestingAccess = false;
  bool _installingProvider = false;
  bool _openingProviderSettings = false;

  Future<void> _requestAccess() async {
    setState(() => _requestingAccess = true);
    try {
      final status = await ref.read(wearableHealthServiceProvider).requestAccess();
      ref.invalidate(wearableSyncStatusProvider);
      var syncedCount = 0;
      if (status.permissionGranted) {
        syncedCount = await _syncWearables(showFeedback: false);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.permissionGranted
                ? (syncedCount > 0
                      ? 'Accesso wearable attivato. Sincronizzate $syncedCount giornate.'
                      : 'Accesso wearable attivato. Nessun nuovo dato da sincronizzare adesso.')
                : (status.message ?? 'Permessi wearable non concessi.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _requestingAccess = false);
      }
    }
  }

  Future<void> _installProvider() async {
    setState(() => _installingProvider = true);
    try {
      await ref.read(wearableHealthServiceProvider).installProvider();
      ref.invalidate(wearableSyncStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Apertura store per installare o aggiornare Health Connect.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _installingProvider = false);
      }
    }
  }

  Future<void> _openProviderSettings() async {
    setState(() => _openingProviderSettings = true);
    try {
      final opened = await ref.read(wearableHealthServiceProvider).openProviderSettings();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Apertura impostazioni salute.'
                : 'Impossibile aprire le impostazioni salute da ClinDiary.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingProviderSettings = false);
      }
    }
  }

  Future<int> _syncWearables({bool showFeedback = true}) async {
    setState(() => _syncing = true);
    try {
      final collected = await ref.read(wearableHealthServiceProvider).collectDailySummaries(days: 30);
      final syncedCount = await ref.read(wearablesRepositoryProvider).syncDailySummaries(collected);
      ref.invalidate(wearableSyncStatusProvider);
      ref.invalidate(wearableDailySummariesProvider);
      ref.invalidate(historyDayProvider);
      ref.invalidate(insightSummaryProvider);
      if (mounted && showFeedback) {
        final message = collected.isEmpty
            ? 'Nessun dato wearable disponibile negli ultimi 30 giorni.'
            : 'Sincronizzate $syncedCount giornate wearable.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return syncedCount;
    } on ApiException catch (error) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
    return 0;
  }

  Future<void> _copyDiagnostics({
    required WearableSyncStatus status,
    required List<WearableDaySummary> recentSummaries,
  }) async {
    final text = status.toDiagnosticText(recentSummaries: recentSummaries);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostica wearable copiata negli appunti.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(wearableSyncStatusProvider);
    final summariesAsync = ref.watch(wearableDailySummariesProvider);
    final recentSummaries = summariesAsync.maybeWhen(
      data: (summaries) => summaries,
      orElse: () => const <WearableDaySummary>[],
    );
    final partialDataWarning = _buildPartialDataWarning(recentSummaries);
    final dateFormat = DateFormat('dd MMM', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smartwatch'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(wearableSyncStatusProvider);
              ref.invalidate(wearableDailySummariesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          statusAsync.when(
            data: (status) => Column(
              children: [
                SectionCard(
                  title: 'Connessione salute',
                  subtitle: 'Collega il provider e sincronizza i riepiloghi.',
                  action: TextButton(
                    onPressed: _syncing ? null : _syncWearables,
                    child: Text(_syncing ? 'Sync...' : 'Sincronizza'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_syncing ||
                          _requestingAccess ||
                          _installingProvider ||
                          _openingProviderSettings)
                        const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(status.platformLabel.toUpperCase())),
                          Chip(
                            label: Text(
                              status.isAvailable ? status.providerName : 'Provider assente',
                            ),
                          ),
                          Chip(
                            label: Text(
                              status.permissionGranted ? 'Permessi OK' : 'Permessi mancanti',
                            ),
                          ),
                          if (status.isAndroid)
                            Chip(
                              label: Text(
                                status.hasHealthPermissions
                                    ? 'Health Connect OK'
                                    : 'Health Connect negato',
                              ),
                            ),
                          if (status.isAndroid)
                            Chip(
                              label: Text(
                                status.hasActivityRecognition
                                    ? 'Attività fisica OK'
                                    : 'Attività fisica negata',
                              ),
                            ),
                          Chip(
                            label: Text(
                              status.historyAccessGranted ? 'Storico OK' : 'Storico limitato',
                            ),
                          ),
                        ],
                      ),
                      if (status.message != null) ...[
                        const SizedBox(height: 12),
                        Text(status.message!),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          status.isSupported
                              ? 'ClinDiary usa solo riepiloghi giornalieri aggregati.'
                              : 'Sync wearable non disponibile su questa piattaforma.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status.needsProviderInstall)
                            FilledButton.tonalIcon(
                              onPressed: _installingProvider ? null : _installProvider,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Installa provider'),
                            ),
                          if (status.needsPermission)
                            FilledButton.tonalIcon(
                              onPressed: _requestingAccess ? null : _requestAccess,
                              icon: const Icon(Icons.health_and_safety_outlined),
                              label: const Text('Connetti'),
                            ),
                          if (status.needsPermission)
                            OutlinedButton.icon(
                              onPressed: _openingProviderSettings ? null : _openProviderSettings,
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Apri autorizzazioni'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _syncing ? null : _syncWearables,
                            icon: const Icon(Icons.sync_outlined),
                            label: const Text('Sync 30 giorni'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (partialDataWarning != null) ...[
                  _WearableWarningCard(message: partialDataWarning),
                  const SizedBox(height: 12),
                ],
                SectionCard(
                  title: 'Verifica rapida',
                  subtitle: 'Ti dice dove si interrompe il collegamento.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...status
                          .diagnosticChecklist(recentSummaries: recentSummaries)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item)),
                                ],
                              ),
                            ),
                          ),
                      if (_detectedSources(recentSummaries).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sorgenti rilevate',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _detectedSources(recentSummaries)
                              .map((source) => Chip(label: Text(source)))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Metriche trovate di recente',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableMetricLabels(recentSummaries).isEmpty
                            ? const [
                                Chip(label: Text('Nessuna metrica recente')),
                              ]
                            : _availableMetricLabels(recentSummaries)
                                  .map((label) => Chip(label: Text(label)))
                                  .toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Metriche ancora assenti',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _missingMetricLabels(recentSummaries)
                            .map((label) => Chip(label: Text(label)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Diagnostica wearable',
                  subtitle: 'Utile solo per supporto e debug.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recentSummaries.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ultimo sync: ${DateFormat('dd MMM yyyy', 'it_IT').format(recentSummaries.first.summaryDate)}',
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _syncing
                            ? null
                            : () => _copyDiagnostics(
                                status: status,
                                recentSummaries: recentSummaries,
                              ),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copia diagnostica'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const SectionCard(
              title: 'Connessione salute',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Connessione salute',
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Storico wearable',
            subtitle: 'Ultimi riepiloghi giornalieri sincronizzati.',
            child: summariesAsync.when(
              data: (summaries) {
                if (summaries.isEmpty) {
                  return const Text(
                    'Ancora nessun dato sincronizzato.',
                  );
                }
                return Column(
                  children: summaries.take(10).map((summary) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateFormat.format(summary.summaryDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _metricsLine(summary),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              summary.stepsCount == null
                                  ? summary.sourcePlatform
                                  : '${summary.stepsCount} passi',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

String _metricsLine(WearableDaySummary summary) {
  final parts = <String>[];
  if (summary.sleepMinutes != null) {
    parts.add('sonno ${(summary.sleepMinutes! / 60).toStringAsFixed(1)}h');
  }
  if (summary.heartRateAvgBpm != null) {
    parts.add('FC ${summary.heartRateAvgBpm!.toStringAsFixed(0)} bpm');
  }
  if (summary.restingHeartRateBpm != null) {
    parts.add('riposo ${summary.restingHeartRateBpm!.toStringAsFixed(0)} bpm');
  }
  if (summary.bloodOxygenAvgPct != null) {
    parts.add('SpO2 ${summary.bloodOxygenAvgPct!.toStringAsFixed(0)}%');
  }
  if (summary.distanceMeters != null) {
    parts.add('distanza ${(summary.distanceMeters! / 1000).toStringAsFixed(1)} km');
  }
  if (summary.exerciseMinutes != null) {
    parts.add('attivita ${summary.exerciseMinutes!.toStringAsFixed(0)} min');
  }
  if (parts.isEmpty) {
    return _displaySourceName(summary.sourceName) ??
        'Dati aggregati sincronizzati';
  }
  return parts.join(' | ');
}

List<String> _detectedSources(List<WearableDaySummary> summaries) {
  final values = summaries
      .map((summary) => _displaySourceName(summary.sourceName))
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return values;
}

List<String> _availableMetricLabels(List<WearableDaySummary> summaries) {
  final labels = <String>[];
  final hasSteps = summaries.any((item) => item.stepsCount != null);
  final hasSleep = summaries.any((item) => item.sleepMinutes != null);
  final hasHeartRate = summaries.any((item) => item.heartRateAvgBpm != null);
  final hasRestingHeartRate = summaries.any(
    (item) => item.restingHeartRateBpm != null,
  );
  final hasOxygen = summaries.any((item) => item.bloodOxygenAvgPct != null);
  final hasExercise = summaries.any((item) => item.exerciseMinutes != null);
  final hasDistance = summaries.any((item) => item.distanceMeters != null);
  final hasHrv = summaries.any((item) => item.hrvSdnnMs != null);

  if (hasSteps) {
    labels.add('Passi');
  }
  if (hasSleep) {
    labels.add('Sonno');
  }
  if (hasHeartRate) {
    labels.add('Frequenza cardiaca');
  }
  if (hasRestingHeartRate) {
    labels.add('FC a riposo');
  }
  if (hasOxygen) {
    labels.add('SpO2');
  }
  if (hasExercise) {
    labels.add('Attività');
  }
  if (hasDistance) {
    labels.add('Distanza');
  }
  if (hasHrv) {
    labels.add('HRV');
  }

  return labels;
}

List<String> _missingMetricLabels(List<WearableDaySummary> summaries) {
  final available = _availableMetricLabels(summaries).toSet();
  const ordered = [
    'Passi',
    'Sonno',
    'Frequenza cardiaca',
    'FC a riposo',
    'SpO2',
    'Attività',
    'Distanza',
    'HRV',
  ];
  return ordered.where((item) => !available.contains(item)).toList();
}

String? _buildPartialDataWarning(List<WearableDaySummary> summaries) {
  if (summaries.isEmpty) {
    return null;
  }

  final available = _availableMetricLabels(summaries).toSet();
  final sources = _detectedSources(summaries);
  final onlyActivityMetrics =
      available.isNotEmpty &&
      available.difference({'Passi', 'Distanza', 'Attività'}).isEmpty;
  final onlyGoogleFit =
      sources.isNotEmpty && sources.every((source) => source == 'Google Fit');

  if (onlyGoogleFit && onlyActivityMetrics) {
    return 'Health Connect sta esponendo a ClinDiary solo dati attività da Google Fit '
        '(passi, distanza o intensità). Sonno, frequenza cardiaca e SpO2 non '
        'risultano disponibili nel repository salute del dispositivo.';
  }
  if (onlyActivityMetrics) {
    return 'I dati disponibili da Health Connect sono solo parziali. '
        'ClinDiary sta ricevendo soprattutto metriche di attività, mentre '
        'sonno, frequenza cardiaca e SpO2 non risultano ancora esposti.';
  }
  return null;
}

String? _displaySourceName(String? sourceName) {
  final cleaned = sourceName?.trim();
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  switch (cleaned) {
    case 'com.google.android.apps.fitness':
      return 'Google Fit';
    case 'com.mi.health':
    case 'com.xiaomi.wearable':
    case 'com.xiaomi.hm.health':
      return 'Xiaomi Fitness';
    default:
      return cleaned;
  }
}

class _WearableWarningCard extends StatelessWidget {
  const _WearableWarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
