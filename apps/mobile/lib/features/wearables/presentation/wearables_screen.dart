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
      final status = await ref
          .read(wearableHealthServiceProvider)
          .requestAccess();
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
                      ? 'Wearable access enabled. Synced $syncedCount days.'
                      : 'Wearable access enabled. No new data to sync right now.')
                : (status.message ?? 'Wearable permissions not granted.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
            'Opening the store to install or update Health Connect.',
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
      final opened = await ref
          .read(wearableHealthServiceProvider)
          .openProviderSettings();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Health settings opened.'
                : 'Unable to open health settings from ClinDiary.',
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
      final collected = await ref
          .read(wearableHealthServiceProvider)
          .collectDailySummaries(days: 30);
      final syncedCount = await ref
          .read(wearablesRepositoryProvider)
          .syncDailySummaries(collected);
      ref.invalidate(wearableSyncStatusProvider);
      ref.invalidate(wearableDailySummariesProvider);
      ref.invalidate(historyDayProvider);
      ref.invalidate(insightSummaryProvider);
      if (mounted && showFeedback) {
        final message = collected.isEmpty
            ? 'No wearable data available in the last 30 days.'
            : 'Synced $syncedCount wearable days.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return syncedCount;
    } catch (error) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
      const SnackBar(
        content: Text('Wearable diagnostics copied to clipboard.'),
      ),
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
    final dateFormat = DateFormat('dd MMM', 'en_US');

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
                  title: 'Health connection',
                  subtitle: 'Connect the provider and sync daily summaries.',
                  action: TextButton(
                    onPressed: _syncing ? null : _syncWearables,
                    child: Text(_syncing ? 'Syncing...' : 'Sync'),
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
                              status.isAvailable
                                  ? status.providerName
                                  : 'Provider unavailable',
                            ),
                          ),
                          Chip(
                            label: Text(
                              status.permissionGranted
                                  ? 'Permissions OK'
                                  : 'Permissions missing',
                            ),
                          ),
                          if (status.isAndroid)
                            Chip(
                              label: Text(
                                status.hasHealthPermissions
                                    ? 'Health Connect OK'
                                    : 'Health Connect denied',
                              ),
                            ),
                          if (status.isAndroid)
                            Chip(
                              label: Text(
                                status.hasActivityRecognition
                                    ? 'Activity recognition OK'
                                    : 'Activity recognition denied',
                              ),
                            ),
                          Chip(
                            label: Text(
                              status.historyAccessGranted
                                  ? 'History OK'
                                  : 'History limited',
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
                              ? 'ClinDiary only uses aggregated daily summaries.'
                              : 'Wearable sync is not available on this platform.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status.needsProviderInstall)
                            FilledButton.tonalIcon(
                              onPressed: _installingProvider
                                  ? null
                                  : _installProvider,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Install provider'),
                            ),
                          if (status.needsPermission)
                            FilledButton.tonalIcon(
                              onPressed: _requestingAccess
                                  ? null
                                  : _requestAccess,
                              icon: const Icon(
                                Icons.health_and_safety_outlined,
                              ),
                              label: const Text('Connect'),
                            ),
                          if (status.needsPermission)
                            OutlinedButton.icon(
                              onPressed: _openingProviderSettings
                                  ? null
                                  : _openProviderSettings,
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Open permissions'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _syncing ? null : _syncWearables,
                            icon: const Icon(Icons.sync_outlined),
                            label: const Text('Sync 30 days'),
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
                  title: 'Quick check',
                  subtitle: 'Shows where the connection breaks down.',
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
                          'Detected sources',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _detectedSources(
                            recentSummaries,
                          ).map((source) => Chip(label: Text(source))).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Recently found metrics',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _availableMetricLabels(recentSummaries).isEmpty
                            ? const [Chip(label: Text('No recent metrics'))]
                            : _availableMetricLabels(recentSummaries)
                                  .map((label) => Chip(label: Text(label)))
                                  .toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Metrics still missing',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _missingMetricLabels(
                          recentSummaries,
                        ).map((label) => Chip(label: Text(label))).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Wearable diagnostics',
                  subtitle: 'Useful only for support and debugging.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recentSummaries.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last sync: ${DateFormat('dd MMM yyyy', 'en_US').format(recentSummaries.first.summaryDate)}',
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
                        label: const Text('Copy diagnostics'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const SectionCard(
              title: 'Health connection',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Health connection',
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Wearable history',
            subtitle: 'Latest synced daily summaries.',
            child: summariesAsync.when(
              data: (summaries) {
                if (summaries.isEmpty) {
                  return const Text('No synced data yet.');
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
                                  : '${summary.stepsCount} steps',
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
    parts.add('sleep ${(summary.sleepMinutes! / 60).toStringAsFixed(1)}h');
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
    parts.add(
      'distance ${(summary.distanceMeters! / 1000).toStringAsFixed(1)} km',
    );
  }
  if (summary.exerciseMinutes != null) {
    parts.add('activity ${summary.exerciseMinutes!.toStringAsFixed(0)} min');
  }
  if (parts.isEmpty) {
    return _displaySourceName(summary.sourceName) ?? 'Synced aggregated data';
  }
  return parts.join(' | ');
}

List<String> _detectedSources(List<WearableDaySummary> summaries) {
  final values =
      summaries
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
    labels.add('Steps');
  }
  if (hasSleep) {
    labels.add('Sleep');
  }
  if (hasHeartRate) {
    labels.add('Heart rate');
  }
  if (hasRestingHeartRate) {
    labels.add('Resting HR');
  }
  if (hasOxygen) {
    labels.add('SpO2');
  }
  if (hasExercise) {
    labels.add('Activity');
  }
  if (hasDistance) {
    labels.add('Distance');
  }
  if (hasHrv) {
    labels.add('HRV');
  }

  return labels;
}

List<String> _missingMetricLabels(List<WearableDaySummary> summaries) {
  final available = _availableMetricLabels(summaries).toSet();
  const ordered = [
    'Steps',
    'Sleep',
    'Heart rate',
    'Resting HR',
    'SpO2',
    'Activity',
    'Distance',
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
      available.difference({'Steps', 'Distance', 'Activity'}).isEmpty;
  final onlyGoogleFit =
      sources.isNotEmpty && sources.every((source) => source == 'Google Fit');

  if (onlyGoogleFit && onlyActivityMetrics) {
    return 'Health Connect is exposing only activity data from Google Fit to ClinDiary '
        '(steps, distance, or intensity). Sleep, heart rate, and SpO2 are not '
        'available in the device health repository.';
  }
  if (onlyActivityMetrics) {
    return 'The data available from Health Connect is only partial. '
        'ClinDiary is receiving mostly activity metrics, while '
        'sleep, heart rate, and SpO2 are still not exposed.';
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
