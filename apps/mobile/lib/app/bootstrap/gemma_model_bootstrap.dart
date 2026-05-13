import 'dart:async';
import 'dart:io';

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
    if (_running) {
      return;
    }
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
    if (_running) {
      return;
    }
    _running = true;
    try {
      final service = ref.read(onDeviceAiServiceProvider);
      final status = await service.fetchStatus();
      final modelDirectory = status.defaultModelDirectory;
      final modelPath = status.modelPath?.trim();
      final modelFileExists =
          modelPath != null &&
          modelPath.isNotEmpty &&
          await File(modelPath).exists();

      final embeddingModelPath =
          '${modelDirectory ?? ''}/embeddinggemma-300m.tflite';
      final embeddingModelExists = await File(embeddingModelPath).exists();
      final activeGemmaDownload = await service.fetchGemma4DownloadProgress();

      if (activeGemmaDownload != null) {
        state = GemmaModelBootstrapState.downloading(
          message: 'Downloading Gemma 4 E2B...',
          modelDirectory: modelDirectory,
          downloadedBytes: activeGemmaDownload.downloadedBytes,
          totalBytes: activeGemmaDownload.totalBytes,
        );

        await service.downloadGemma4Model(
          onProgress: (receivedBytes, totalBytes) {
            state = GemmaModelBootstrapState.downloading(
              message: 'Downloading Gemma 4 E2B...',
              modelDirectory: modelDirectory,
              downloadedBytes: receivedBytes,
              totalBytes: totalBytes,
            );
          },
        );
      }

      if (!status.isSupported) {
        state = GemmaModelBootstrapState.ready(
          message: 'On-device AI is not available on this platform.',
          modelDirectory: modelDirectory,
          modelPath: modelPath,
        );
        return;
      }

      if (!forceDownload &&
          status.isReady &&
          modelFileExists &&
          embeddingModelExists) {
        state = GemmaModelBootstrapState.ready(
          message: 'On-device AI models are ready.',
          modelDirectory: modelDirectory,
          modelPath: modelPath,
        );
        return;
      }

      if (modelFileExists && embeddingModelExists && !forceDownload) {
        state = GemmaModelBootstrapState.checking(
          message: 'Models are already present. Verifying the runtime...',
          modelDirectory: modelDirectory,
          modelPath: modelPath,
        );
        await service.resetRuntime();
        final refreshedStatus = await service.fetchStatus();
        final refreshedModelPath = refreshedStatus.modelPath?.trim();
        final refreshedModelFileExists =
            refreshedModelPath != null &&
            refreshedModelPath.isNotEmpty &&
            await File(refreshedModelPath).exists();
        if (refreshedStatus.isReady && refreshedModelFileExists) {
          state = GemmaModelBootstrapState.ready(
            message: 'On-device AI models are ready.',
            modelDirectory: refreshedStatus.defaultModelDirectory,
            modelPath: refreshedModelPath,
          );
          return;
        }

        state = GemmaModelBootstrapState.error(
          message:
              'Models are installed, but LiteRT-LM could not load them. You can retry the download or continue to the app.',
          modelDirectory:
              refreshedStatus.defaultModelDirectory ?? modelDirectory,
          modelPath: refreshedModelPath,
          lastError:
              refreshedStatus.lastError ?? 'Runtime initialization failed.',
        );
        return;
      }

      String? installedPath = modelPath;

      if (!modelFileExists || forceDownload) {
        state = GemmaModelBootstrapState.downloading(
          message: 'Downloading Gemma 4 E2B from Hugging Face...',
          modelDirectory: modelDirectory,
        );

        installedPath = await service.downloadGemma4Model(
          onProgress: (receivedBytes, totalBytes) {
            state = GemmaModelBootstrapState.downloading(
              message: totalBytes == null || totalBytes <= 0
                  ? 'Downloading Gemma 4 E2B...'
                  : 'Downloading Gemma 4 E2B...',
              modelDirectory: modelDirectory,
              downloadedBytes: receivedBytes,
              totalBytes: totalBytes,
            );
          },
        );
      }

      if (!embeddingModelExists || forceDownload) {
        state = GemmaModelBootstrapState.downloading(
          message: 'Downloading EmbeddingGemma 300M from Hugging Face...',
          modelDirectory: modelDirectory,
        );
        await service.downloadEmbeddingModel(
          onProgress: (receivedBytes, totalBytes) {
            state = GemmaModelBootstrapState.downloading(
              message: totalBytes == null || totalBytes <= 0
                  ? 'Downloading EmbeddingGemma 300M...'
                  : 'Downloading EmbeddingGemma 300M...',
              modelDirectory: modelDirectory,
              downloadedBytes: receivedBytes,
              totalBytes: totalBytes,
            );
          },
        );
      }

      final refreshedStatus = await service.fetchStatus();
      final refreshedModelPath =
          refreshedStatus.modelPath?.trim().isNotEmpty == true
          ? refreshedStatus.modelPath!.trim()
          : installedPath;

      if (refreshedStatus.isReady) {
        state = GemmaModelBootstrapState.ready(
          message: 'On-device AI models are ready.',
          modelDirectory:
              refreshedStatus.defaultModelDirectory ?? modelDirectory,
          modelPath: refreshedModelPath,
        );
        return;
      }

      state = GemmaModelBootstrapState.error(
        message:
            'The models have been downloaded, but LiteRT-LM still could not initialize. You can continue to the app and try again from the model screen.',
        modelDirectory: refreshedStatus.defaultModelDirectory ?? modelDirectory,
        modelPath: refreshedModelPath,
        lastError: refreshedStatus.lastError,
        allowAppAccess: false,
      );
    } catch (error) {
      state = GemmaModelBootstrapState.error(
        message: 'Model download failed.',
        lastError: error.toString(),
        modelDirectory: state.modelDirectory,
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
    required this.allowAppAccess,
    this.message,
    this.modelDirectory,
    this.modelPath,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.lastError,
  });

  const GemmaModelBootstrapState.checking({
    this.message,
    this.modelDirectory,
    this.modelPath,
  }) : phase = GemmaModelBootstrapPhase.checking,
       allowAppAccess = false,
       downloadedBytes = 0,
       totalBytes = null,
       lastError = null;

  const GemmaModelBootstrapState.downloading({
    this.message,
    this.modelDirectory,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.lastError,
  }) : phase = GemmaModelBootstrapPhase.downloading,
       allowAppAccess = false,
       modelPath = null;

  const GemmaModelBootstrapState.ready({
    this.message,
    this.modelDirectory,
    this.modelPath,
  }) : phase = GemmaModelBootstrapPhase.ready,
       allowAppAccess = true,
       downloadedBytes = 0,
       totalBytes = null,
       lastError = null;

  const GemmaModelBootstrapState.error({
    this.message,
    this.modelDirectory,
    this.modelPath,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.lastError,
    this.allowAppAccess = false,
  }) : phase = GemmaModelBootstrapPhase.error;

  final GemmaModelBootstrapPhase phase;
  final bool allowAppAccess;
  final String? message;
  final String? modelDirectory;
  final String? modelPath;
  final int downloadedBytes;
  final int? totalBytes;
  final String? lastError;

  bool get isChecking => phase == GemmaModelBootstrapPhase.checking;

  bool get isDownloading => phase == GemmaModelBootstrapPhase.downloading;

  bool get isReady => phase == GemmaModelBootstrapPhase.ready;

  bool get hasError => phase == GemmaModelBootstrapPhase.error;

  double? get progressFraction {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return downloadedBytes / total;
  }
}

class _GemmaModelBootstrapView extends StatelessWidget {
  const _GemmaModelBootstrapView({
    required this.state,
    required this.onRetryDownload,
    required this.onContinueAnyway,
  });

  final GemmaModelBootstrapState state;
  final Future<void> Function() onRetryDownload;
  final VoidCallback onContinueAnyway;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final progressFraction = state.progressFraction;
    final totalBytesLabel = state.totalBytes == null
        ? null
        : _formatBytes(state.totalBytes!);
    final downloadedBytesLabel = _formatBytes(state.downloadedBytes);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ClinDiaryLogo(size: 88),
                      const SizedBox(height: 20),
                      Text(
                        'Preparing Gemma 4 E2B',
                        style: theme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message ??
                            'ClinDiary is setting up the on-device model for the demo.',
                        style: theme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (state.isDownloading) ...[
                        LinearProgressIndicator(value: progressFraction),
                        const SizedBox(height: 12),
                        Text(
                          totalBytesLabel == null
                              ? 'Downloaded $downloadedBytesLabel'
                              : 'Downloaded $downloadedBytesLabel of $totalBytesLabel',
                          style: theme.labelMedium,
                          textAlign: TextAlign.center,
                        ),
                      ] else if (state.isChecking) ...[
                        const CircularProgressIndicator(),
                      ] else ...[
                        const Icon(Icons.memory_outlined, size: 44),
                      ],
                      if (state.modelDirectory != null) ...[
                        const SizedBox(height: 16),
                        _BootstrapInfoLine(
                          label: 'Model directory',
                          value: state.modelDirectory!,
                        ),
                      ],
                      if (state.modelPath != null) ...[
                        const SizedBox(height: 10),
                        _BootstrapInfoLine(
                          label: 'Model file',
                          value: state.modelPath!,
                        ),
                      ],
                      if (state.hasError && state.lastError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          state.lastError!,
                          style: theme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (state.hasError)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: () => onRetryDownload(),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Retry download'),
                            ),
                            OutlinedButton.icon(
                              onPressed: onContinueAnyway,
                              icon: const Icon(Icons.arrow_forward_outlined),
                              label: const Text('Continue to app'),
                            ),
                          ],
                        )
                      else
                        const Text(
                          'Do not close the app while the model is being prepared.',
                          textAlign: TextAlign.center,
                        ),
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

class _BootstrapInfoLine extends StatelessWidget {
  const _BootstrapInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        SelectableText(value, style: theme.bodySmall),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
