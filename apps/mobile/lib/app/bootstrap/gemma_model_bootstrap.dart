import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/domain/ai_bootstrap_status.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gemmaModelBootstrapProvider =
    NotifierProvider<GemmaModelBootstrapController, AiBootstrapStatus>(
      GemmaModelBootstrapController.new,
    );

class GemmaModelBootstrap extends ConsumerWidget {
  const GemmaModelBootstrap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gemmaModelBootstrapProvider);
    final controller = ref.read(gemmaModelBootstrapProvider.notifier);

    if (state.allowAppAccess || state.isReady) {
      return child;
    }

    return _GemmaModelBootstrapView(
      state: state,
      onRetryDownload: controller.retryDownload,
      onContinueAnyway: controller.allowAppAccess,
    );
  }
}

class GemmaModelBootstrapController extends Notifier<AiBootstrapStatus> {
  bool _started = false;
  bool _running = false;

  @override
  AiBootstrapStatus build() {
    if (!_started) {
      _started = true;
      unawaited(_ensureModelReady());
    }
    return const AiBootstrapStatus.notStarted(
      modelName: OnDeviceAiService.expectedModelName,
      runtime: OnDeviceAiService.expectedRuntime,
      provider: OnDeviceAiService.expectedProvider,
      message: 'Preparing local Gemma model...',
    );
  }

  Future<void> retryDownload() async {
    if (_running) return;
    state = const AiBootstrapStatus(
      phase: AiBootstrapPhase.checkingAppOwnedModelState,
      modelName: OnDeviceAiService.expectedModelName,
      runtime: OnDeviceAiService.expectedRuntime,
      provider: OnDeviceAiService.expectedProvider,
      mode: 'local',
      message: 'Retrying local Gemma model setup...',
    );
    await _ensureModelReady(forceInstall: true);
  }

  void allowAppAccess() {
    state = state.copyWith(allowAppAccess: true);
  }

  Future<void> _ensureModelReady({bool forceInstall = false}) async {
    if (_running) return;
    _running = true;
    try {
      final service = ref.read(onDeviceAiServiceProvider);
      final result = await service.ensureModelReady(
        forceInstall: forceInstall,
        onStatus: (status) => state = status,
      );
      if (!result.isReady) {
        state = result;
      }
    } catch (error) {
      state = AiBootstrapStatus(
        phase: AiBootstrapPhase.failed,
        modelName: OnDeviceAiService.expectedModelName,
        runtime: OnDeviceAiService.expectedRuntime,
        provider: OnDeviceAiService.expectedProvider,
        mode: 'unavailable',
        message:
            'Local Gemma setup failed. You can retry or continue without AI.',
        lastError: error.toString(),
      );
    } finally {
      _running = false;
    }
  }
}

class _GemmaModelBootstrapView extends StatelessWidget {
  const _GemmaModelBootstrapView({
    required this.state,
    required this.onRetryDownload,
    required this.onContinueAnyway,
  });

  final AiBootstrapStatus state;
  final VoidCallback onRetryDownload;
  final VoidCallback onContinueAnyway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = state.progressPercent;
    final showProgress = state.isBusy;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: ClinDiaryLogo(size: 64)),
                      const SizedBox(height: 24),
                      Text(
                        'Preparing local Gemma model',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The model is prepared locally so ClinDiary can generate private summaries.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _BootstrapChip(label: 'Step: ${state.stepLabel}'),
                          _BootstrapChip(label: 'Model: ${state.modelName}'),
                          _BootstrapChip(label: 'Provider: ${state.provider}'),
                          _BootstrapChip(label: 'Runtime: ${state.runtime}'),
                          _BootstrapChip(label: 'Mode: ${state.mode}'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        state.message,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showProgress) ...[
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: progress == null ? null : progress / 100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progress == null
                              ? 'Progress is being prepared...'
                              : '$progress%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (state.modelDirectory != null) ...[
                        const SizedBox(height: 18),
                        _InfoLine(
                          label: 'App-owned model directory',
                          value: state.modelDirectory!,
                        ),
                      ],
                      if (state.modelPath != null) ...[
                        const SizedBox(height: 8),
                        _InfoLine(label: 'Model path', value: state.modelPath!),
                      ],
                      if (state.phase == AiBootstrapPhase.failed) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            state.lastError ??
                                'Gemma setup failed. Retry when network and storage are available.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: onRetryDownload,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextButton(
                                onPressed: onContinueAnyway,
                                child: const Text('Continue without AI'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapChip extends StatelessWidget {
  const _BootstrapChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.18)),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
