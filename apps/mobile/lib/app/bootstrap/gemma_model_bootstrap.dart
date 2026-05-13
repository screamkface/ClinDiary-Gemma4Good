import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gemmaModelBootstrapProvider =
    NotifierProvider<GemmaModelBootstrapController, GemmaModelBootstrapState>(
      GemmaModelBootstrapController.new,
    );

class GemmaModelBootstrap extends ConsumerWidget {
  const GemmaModelBootstrap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gemmaModelBootstrapProvider);
    final controller = ref.read(gemmaModelBootstrapProvider.notifier);

    if (state.allowAppAccess || state.phase == GemmaModelBootstrapPhase.ready) {
      return child;
    }

    return _GemmaModelBootstrapView(
      state: state,
      onRetryDownload: controller.retryDownload,
      onContinueAnyway: controller.allowAppAccess,
    );
  }
}

class GemmaModelBootstrapController extends Notifier<GemmaModelBootstrapState> {
  bool _started = false;
  bool _running = false;

  @override
  GemmaModelBootstrapState build() {
    if (!_started) {
      _started = true;
      state = const GemmaModelBootstrapState.checking(
        message: 'Checking whether Gemma 4 E2B is already installed...',
      );
      unawaited(_ensureModelReady());
    }
    return state;
  }

  Future<void> retryDownload() async {
    if (_running) return;
    state = const GemmaModelBootstrapState.checking(
      message: 'Retrying Gemma 4 E2B model setup...',
    );
    await _ensureModelReady(forceDownload: true);
  }

  void allowAppAccess() {
    state = GemmaModelBootstrapState(
      phase: GemmaModelBootstrapPhase.error,
      allowAppAccess: true,
      message: state.message,
      modelDirectory: state.modelDirectory,
      modelPath: state.modelPath,
      downloadedBytes: state.downloadedBytes,
      totalBytes: state.totalBytes,
      lastError: state.lastError,
    );
  }

  Future<void> _ensureModelReady({bool forceDownload = false}) async {
    if (_running) return;
    _running = true;
    try {
      final service = ref.read(onDeviceAiServiceProvider);
      final status = await service.fetchStatus();

      if (!status.isSupported) {
        state = GemmaModelBootstrapState.ready(
          message: 'On-device AI is not available on this platform.',
          modelDirectory: status.defaultModelDirectory,
          modelPath: status.modelPath,
        );
        return;
      }

      if (!forceDownload && status.isReady) {
        state = GemmaModelBootstrapState.ready(
          message: 'On-device AI models are ready.',
          modelDirectory: status.defaultModelDirectory,
          modelPath: status.modelPath,
        );
        return;
      }

      state = GemmaModelBootstrapState.downloading(
        message: 'Downloading Gemma 4 E2B from Hugging Face...',
        modelDirectory: status.defaultModelDirectory,
      );

      await service.downloadGemma4Model(
        onProgress: (receivedBytes, totalBytes) {
          state = GemmaModelBootstrapState.downloading(
            message: 'Downloading Gemma 4 E2B...',
            modelDirectory: status.defaultModelDirectory,
            downloadedBytes: receivedBytes,
            totalBytes: totalBytes,
          );
        },
      );

      final refreshedStatus = await service.fetchStatus();
      if (refreshedStatus.isReady) {
        state = GemmaModelBootstrapState.ready(
          message: 'On-device AI models are ready.',
          modelDirectory: refreshedStatus.defaultModelDirectory,
          modelPath: refreshedStatus.modelPath,
        );
        unawaited(service.installGeckoEmbedding());
        return;
      }

      state = GemmaModelBootstrapState.error(
        message:
            'The model was downloaded but the runtime could not initialize.',
        modelDirectory: refreshedStatus.defaultModelDirectory,
        modelPath: refreshedStatus.modelPath,
        lastError: refreshedStatus.lastError,
        allowAppAccess: false,
      );
    } catch (error) {
      state = GemmaModelBootstrapState.error(
        message: 'Model download failed.',
        lastError: error.toString(),
        allowAppAccess: false,
      );
    } finally {
      _running = false;
    }
  }
}

enum GemmaModelBootstrapPhase { checking, downloading, ready, error }

class GemmaModelBootstrapState {
  const GemmaModelBootstrapState({
    required this.phase,
    this.allowAppAccess = false,
    this.message = '',
    this.modelDirectory,
    this.modelPath,
    this.downloadedBytes,
    this.totalBytes,
    this.lastError,
  });

  const GemmaModelBootstrapState.checking({
    this.message = '',
    this.modelDirectory,
    this.modelPath,
  }) : phase = GemmaModelBootstrapPhase.checking,
       allowAppAccess = false,
       downloadedBytes = null,
       totalBytes = null,
       lastError = null;

  const GemmaModelBootstrapState.downloading({
    this.message = '',
    this.modelDirectory,
    this.downloadedBytes,
    this.totalBytes,
  }) : phase = GemmaModelBootstrapPhase.downloading,
       allowAppAccess = false,
       modelPath = null,
       lastError = null;

  const GemmaModelBootstrapState.ready({
    this.message = '',
    this.modelDirectory,
    this.modelPath,
  }) : phase = GemmaModelBootstrapPhase.ready,
       allowAppAccess = true,
       downloadedBytes = null,
       totalBytes = null,
       lastError = null;

  const GemmaModelBootstrapState.error({
    this.message = '',
    this.lastError,
    this.allowAppAccess = false,
    this.modelDirectory,
    this.modelPath,
  }) : phase = GemmaModelBootstrapPhase.error,
       downloadedBytes = null,
       totalBytes = null;

  final GemmaModelBootstrapPhase phase;
  final bool allowAppAccess;
  final String message;
  final String? modelDirectory;
  final String? modelPath;
  final int? downloadedBytes;
  final int? totalBytes;
  final String? lastError;
}

class _GemmaModelBootstrapView extends StatelessWidget {
  const _GemmaModelBootstrapView({
    required this.state,
    required this.onRetryDownload,
    required this.onContinueAnyway,
  });

  final GemmaModelBootstrapState state;
  final VoidCallback onRetryDownload;
  final VoidCallback onContinueAnyway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ClinDiaryLogo(size: 64),
              const SizedBox(height: 24),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (state.phase == GemmaModelBootstrapPhase.downloading) ...[
                const SizedBox(height: 24),
                if (state.downloadedBytes != null && state.totalBytes != null)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: state.totalBytes! > 0
                            ? state.downloadedBytes! / state.totalBytes!
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.downloadedBytes}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  )
                else
                  const CircularProgressIndicator(),
              ],
              if (state.phase == GemmaModelBootstrapPhase.error) ...[
                const SizedBox(height: 16),
                Text(
                  state.lastError ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetryDownload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onContinueAnyway,
                  child: const Text('Continue without AI'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
