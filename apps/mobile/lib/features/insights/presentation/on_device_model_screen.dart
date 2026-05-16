import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OnDeviceModelScreen extends ConsumerStatefulWidget {
  const OnDeviceModelScreen({super.key});

  @override
  ConsumerState<OnDeviceModelScreen> createState() =>
      _OnDeviceModelScreenState();
}

class _OnDeviceModelScreenState extends ConsumerState<OnDeviceModelScreen> {
  bool _isPreparing = false;
  bool _isImporting = false;
  bool _isRemoving = false;
  bool _isResetting = false;
  bool _isRunningTestPrompt = false;
  String? _testPromptResult;
  String? _testPromptError;
  Duration? _testPromptLatency;

  Future<void> _prepareModel() async {
    if (_isPreparing) {
      return;
    }
    setState(() => _isPreparing = true);
    try {
      final status = await ref
          .read(onDeviceAiServiceProvider)
          .ensureModelReady(forceInstall: true);
      ref.invalidate(onDeviceAiStatusProvider);
      if (!mounted) {
        return;
      }
      if (!status.isReady) {
        throw Exception(status.lastError ?? status.message);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Local Gemma model ready at ${status.modelPath ?? 'the app-owned path'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Model setup failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isPreparing = false);
      }
    }
  }

  Future<void> _importModel() async {
    if (_isImporting) {
      return;
    }
    setState(() => _isImporting = true);
    try {
      final installedPath = await ref
          .read(onDeviceAiServiceProvider)
          .importModelFromPicker();
      ref.invalidate(onDeviceAiStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            installedPath == null
                ? 'Import canceled.'
                : 'Model copied to $installedPath',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _removeModel() async {
    if (_isRemoving) {
      return;
    }
    setState(() => _isRemoving = true);
    try {
      await ref.read(onDeviceAiServiceProvider).removeInstalledModels();
      ref.invalidate(onDeviceAiStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('On-device model removed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Model removal failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  Future<void> _resetRuntime() async {
    if (_isResetting) {
      return;
    }
    setState(() => _isResetting = true);
    try {
      await ref.read(onDeviceAiServiceProvider).resetRuntime();
      ref.invalidate(onDeviceAiStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('On-device runtime reset.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Runtime reset failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _runTestPrompt() async {
    if (_isRunningTestPrompt) {
      return;
    }
    setState(() {
      _isRunningTestPrompt = true;
      _testPromptError = null;
      _testPromptResult = null;
      _testPromptLatency = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final status = await ref
          .read(onDeviceAiServiceProvider)
          .ensureModelReady();
      if (!status.isReady) {
        throw Exception(status.lastError ?? status.message);
      }
      final result = await ref
          .read(onDeviceAiServiceProvider)
          .generateText(
            systemPrompt:
                "You are ClinDiary's private diary summarizer. You summarize user-provided health diary context conservatively. You are not a doctor. Do not diagnose, prescribe, change medication, or provide emergency triage. Highlight patterns, uncertainties, and questions the user may discuss with a qualified clinician. Keep the tone clear, calm, and non-alarming.",
            userPrompt:
                'Summarize this demo diary entry in 3 cautious bullet points. Do not diagnose. Demo diary: Mild headache in the afternoon, slept 6 hours, walked 4200 steps, took usual medication as recorded, no fever documented.',
          );
      stopwatch.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _testPromptResult = result.trim().isEmpty
            ? 'Gemma returned an empty response.'
            : result.trim();
        _testPromptLatency = stopwatch.elapsed;
      });
      ref.invalidate(onDeviceAiStatusProvider);
    } catch (error) {
      stopwatch.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _testPromptError = error.toString();
        _testPromptLatency = stopwatch.elapsed;
      });
    } finally {
      if (mounted) {
        setState(() => _isRunningTestPrompt = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(onDeviceAiStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('On-device model')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Manage the LiteRT-LM model used for on-device recaps.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          statusAsync.when(
            data: (status) => _StatusCard(status: status),
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(error: error.toString()),
          ),
          const SizedBox(height: 16),
          statusAsync.maybeWhen(
            data: (status) => _ActionsCard(
              status: status,
              isPreparing: _isPreparing,
              isImporting: _isImporting,
              isRemoving: _isRemoving,
              isResetting: _isResetting,
              onPrepareModel: _prepareModel,
              onImportModel: _importModel,
              onRemoveModel: _removeModel,
              onResetRuntime: _resetRuntime,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          statusAsync.maybeWhen(
            data: (status) => _LocalAiDebugCard(
              status: status,
              isRunning: _isRunningTestPrompt,
              result: _testPromptResult,
              error: _testPromptError,
              latency: _testPromptLatency,
              onRunTestPrompt: _runTestPrompt,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          const _HintCard(),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final OnDeviceAiStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');
    final fileSizeLabel = status.modelFileSizeBytes == null
        ? '-'
        : _formatBytes(status.modelFileSizeBytes!);
    final updatedAtLabel = status.modelLastModifiedAt == null
        ? '-'
        : dateFormat.format(status.modelLastModifiedAt!.toLocal());
    final verifiedAtLabel = status.lastVerifiedAt == null
        ? '-'
        : dateFormat.format(status.lastVerifiedAt!.toLocal());
    final latencyLabel = status.lastInferenceLatencyMillis == null
        ? '-'
        : '${status.lastInferenceLatencyMillis} ms';

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stato runtime',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(label: 'Provider: ${status.activeProviderLabel}'),
                _StatusChip(label: 'Runtime: ${status.runtime}'),
                _StatusChip(
                  label: 'Backend used: ${status.backendResolved ?? '-'}',
                ),
                _StatusChip(
                  label: 'Status: ${status.isReady ? 'Ready' : 'Not ready'}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(label: 'Model', value: status.modelName ?? '-'),
            _InfoLine(label: 'App-owned path', value: status.modelPath ?? '-'),
            _InfoLine(
              label: 'Expected directory',
              value: status.defaultModelDirectory ?? '-',
            ),
            _InfoLine(label: 'File size', value: fileSizeLabel),
            _InfoLine(label: 'Last modified', value: updatedAtLabel),
            _InfoLine(
              label: 'Last runtime verification',
              value: verifiedAtLabel,
            ),
            _InfoLine(label: 'Last inference latency', value: latencyLabel),
            if (status.lastError != null &&
                status.lastError!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                status.lastError!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.status,
    required this.isPreparing,
    required this.isImporting,
    required this.isRemoving,
    required this.isResetting,
    required this.onPrepareModel,
    required this.onImportModel,
    required this.onRemoveModel,
    required this.onResetRuntime,
  });

  final OnDeviceAiStatus status;
  final bool isPreparing;
  final bool isImporting;
  final bool isRemoving;
  final bool isResetting;
  final Future<void> Function() onPrepareModel;
  final Future<void> Function() onImportModel;
  final Future<void> Function() onRemoveModel;
  final Future<void> Function() onResetRuntime;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isPreparing ? null : () => onPrepareModel(),
              icon: isPreparing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_for_offline_outlined),
              label: Text(
                isPreparing
                    ? 'Preparing model...'
                    : status.isReady
                    ? 'Verify/reinstall Gemma'
                    : 'Prepare/download Gemma',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: isImporting ? null : () => onImportModel(),
              icon: isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      status.isReady
                          ? Icons.sync_alt_outlined
                          : Icons.upload_file_outlined,
                    ),
              label: Text(
                isImporting
                    ? 'Importing model...'
                    : status.isReady
                    ? 'Replace model'
                    : 'Import .litertlm model',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isRemoving ? null : () => onRemoveModel(),
              icon: isRemoving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(isRemoving ? 'Removing model...' : 'Remove model'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isResetting ? null : () => onResetRuntime(),
              icon: isResetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restart_alt_outlined),
              label: Text(
                isResetting ? 'Resetting runtime...' : 'Reset runtime',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalAiDebugCard extends StatelessWidget {
  const _LocalAiDebugCard({
    required this.status,
    required this.isRunning,
    required this.result,
    required this.error,
    required this.latency,
    required this.onRunTestPrompt,
  });

  final OnDeviceAiStatus status;
  final bool isRunning;
  final String? result;
  final String? error;
  final Duration? latency;
  final Future<void> Function() onRunTestPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local AI status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _InfoLine(label: 'Provider', value: status.activeProviderLabel),
            _InfoLine(label: 'Model', value: status.modelName ?? '-'),
            _InfoLine(label: 'Model path', value: status.modelPath ?? '-'),
            _InfoLine(
              label: 'Bootstrap status',
              value: status.isReady ? 'ready' : 'not ready',
            ),
            _InfoLine(
              label: 'Last inference latency',
              value: latency == null ? '-' : '${latency!.inMilliseconds} ms',
            ),
            if (error != null && error!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            if (result != null && result!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(result!),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isRunning ? null : () => onRunTestPrompt(),
              icon: isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_outlined),
              label: Text(
                isRunning ? 'Running test prompt...' : 'Run test prompt',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Practical notes'),
            SizedBox(height: 10),
            Text(
              'Use a .litertlm file compatible with LiteRT-LM on Android. For the on-device recap demo, the target remains Gemma 4 E2B.',
            ),
            SizedBox(height: 8),
            Text(
              'If you import a new model, ClinDiary copies it into the app-owned model path before runtime activation.',
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card.outlined(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Checking model status...')),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Model status load error: $error'),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index += 1;
  }
  final decimals = index == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[index]}';
}
