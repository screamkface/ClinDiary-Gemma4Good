import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:clindiary/features/insights/domain/ai_bootstrap_status.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class OnDeviceAiService {
  static const _modelName = 'gemma-4-E2B-it.litertlm';
  static const _provider = 'on_device_litertlm';
  static const _providerLabel = 'Gemma local';
  static const _runtime = 'flutter_gemma (LiteRT-LM)';
  static const _modelDownloadUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/b4f4f4df93418ddb4aa7da8bf33b584602a5b9f8/gemma-4-E2B-it.litertlm?download=true';
  static const _geckoModelUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/gecko-110m-en.tflite';
  static const _geckoTokenizerUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/tokenizer.model';

  static const _chatSetupTimeout = Duration(seconds: 30);
  static const _modelOpenTimeout = Duration(seconds: 45);
  static const _firstVisibleTokenTimeout = Duration(seconds: 45);
  static const _streamIdleTimeout = Duration(seconds: 75);
  static const _fullGenerationTimeout = Duration(seconds: 150);

  static const _emptyResponseMessage =
      'The on-device model returned an empty response. Open AI Settings and try CPU/GPU again.';

  static const _gemma4Temperature = 1.0;
  static const _gemma4TopK = 64;
  static const _gemma4TopP = 0.95;
  static const _gemma4TokenBuffer = 256;
  static const _gemma4ContextTokens = 4096;

  // Kept for backwards compatibility with screens/tests that may read these
  // constants. The service no longer validates the exact local file size
  // because flutter_gemma owns the model storage path in the modern API.
  static const _minimumModelSizeBytes = 100 * 1024 * 1024;
  static const _expectedModelSizeBytes = 2588147712;

  static bool _initialized = false;

  InferenceModel? _currentModel;
  EmbeddingModel? _currentEmbedder;

  // Stable hackathon default. Users can still switch to GPU from settings.
  // GPU/NPU are more sensitive to device, manifest and plugin version.
  PreferredBackend _preferredBackend = PreferredBackend.cpu;

  bool _enableSpeculativeDecoding = false;
  bool? _npuAvailable;
  String? _lastNpuCheckError;
  String? _lastBootstrapError;
  DateTime? _lastVerifiedAt;
  Duration? _lastInferenceLatency;
  Future<void> _generationTail = Future.value();
  Future<AiBootstrapStatus>? _bootstrapInFlight;

  static const expectedModelName = _modelName;
  static const expectedRuntime = _runtime;
  static const expectedProvider = _provider;
  static const minimumModelSizeBytes = _minimumModelSizeBytes;
  static const expectedModelSizeBytes = _expectedModelSizeBytes;

  PreferredBackend get preferredBackend => _preferredBackend;
  bool get enableSpeculativeDecoding => _enableSpeculativeDecoding;
  bool? get npuAvailable => _npuAvailable;
  String? get lastNpuCheckError => _lastNpuCheckError;

  Future<void> setPreferredBackend(PreferredBackend backend) async {
    if (_preferredBackend == backend) return;
    _preferredBackend = backend;
    _currentModel = null;
    await _closePluginCachedModel();
  }

  Future<void> setEnableSpeculativeDecoding(bool value) async {
    if (_enableSpeculativeDecoding == value) return;
    _enableSpeculativeDecoding = value;
    _currentModel = null;
    await _closePluginCachedModel();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await FlutterGemma.initialize(maxDownloadRetries: 10);
    _initialized = true;
  }

  Future<void> _closePluginCachedModel() async {
    try {
      final cached = FlutterGemmaPlugin.instance.initializedModel;
      if (cached != null) await cached.close();
    } catch (_) {
      // Best effort cleanup only.
    }
  }

  /// Intentionally non-invasive.
  ///
  /// The previous implementation changed the plugin active model to a temporary
  /// "_npu_check" spec. That is risky during bootstrap because it can leave the
  /// app without the real Gemma model active. For the hackathon build, keep NPU
  /// probing disabled and let users use CPU/GPU.
  Future<bool> checkNpuAvailability() async {
    await _ensureInitialized();
    _npuAvailable = false;
    _lastNpuCheckError =
        'NPU probing is disabled in this stable build. Use CPU first, then test GPU separately.';
    return false;
  }

  Future<OnDeviceAiStatus> fetchStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return OnDeviceAiStatus(
        isSupported: false,
        isReady: false,
        runtime: _runtime,
        provider: _provider,
        activeProviderLabel: 'Gemma local unavailable',
        backendPreference: _preferredBackend.name.toUpperCase(),
        modelName: _modelName,
        lastError: 'Local Gemma is available only in Android/iOS builds.',
        isCloudBypassedForThisRequest: true,
      );
    }

    await _ensureInitialized();

    try {
      final installed = await _isGemmaModelInstalled();
      final active = FlutterGemma.hasActiveModel();

      if (!installed && !active) {
        return OnDeviceAiStatus(
          isSupported: true,
          isReady: false,
          runtime: _runtime,
          provider: _provider,
          activeProviderLabel: 'Gemma local unavailable',
          backendPreference: _preferredBackend.name.toUpperCase(),
          modelName: _modelName,
          lastError:
              _lastBootstrapError ?? 'Gemma model is not installed yet.',
          lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
          isCloudBypassedForThisRequest: true,
        );
      }

      if (!active) {
        return OnDeviceAiStatus(
          isSupported: true,
          isReady: false,
          runtime: _runtime,
          provider: _provider,
          activeProviderLabel: 'Gemma local installed but inactive',
          backendPreference: _preferredBackend.name.toUpperCase(),
          modelName: _modelName,
          lastError:
              'Gemma is installed but not active. Tap setup/retry to reactivate it.',
          lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
          lastVerifiedAt: _lastVerifiedAt,
          isCloudBypassedForThisRequest: true,
        );
      }

      return OnDeviceAiStatus(
        isSupported: true,
        isReady: true,
        runtime: _runtime,
        provider: _provider,
        activeProviderLabel: _providerLabel,
        backendPreference: _preferredBackend.name.toUpperCase(),
        backendResolved: _preferredBackend.name.toUpperCase(),
        modelName: _modelName,
        lastVerifiedAt: _lastVerifiedAt,
        lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
        isCloudBypassedForThisRequest: true,
      );
    } catch (error) {
      _lastBootstrapError = error.toString();
      return OnDeviceAiStatus(
        isSupported: true,
        isReady: false,
        runtime: _runtime,
        provider: _provider,
        activeProviderLabel: 'Gemma local unavailable',
        backendPreference: _preferredBackend.name.toUpperCase(),
        modelName: _modelName,
        lastError: error.toString(),
        lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
        lastVerifiedAt: _lastVerifiedAt,
        isCloudBypassedForThisRequest: true,
      );
    }
  }

  Future<AiBootstrapStatus> ensureModelReady({
    bool forceInstall = false,
    void Function(AiBootstrapStatus status)? onStatus,
  }) {
    final inFlight = _bootstrapInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _ensureModelReadyInternal(
      forceInstall: forceInstall,
      onStatus: onStatus,
    );
    _bootstrapInFlight = future;

    return future.whenComplete(() {
      if (identical(_bootstrapInFlight, future)) {
        _bootstrapInFlight = null;
      }
    });
  }

  Future<AiBootstrapStatus> _ensureModelReadyInternal({
    required bool forceInstall,
    void Function(AiBootstrapStatus status)? onStatus,
  }) async {
    final initial = AiBootstrapStatus(
      phase: AiBootstrapPhase.checkingAppOwnedModelState,
      modelName: _modelName,
      runtime: _runtime,
      provider: _provider,
      mode: 'local',
      message: 'Checking local Gemma installation...',
    );
    onStatus?.call(initial);

    if (!Platform.isAndroid && !Platform.isIOS) {
      final failed = initial.copyWith(
        phase: AiBootstrapPhase.failed,
        mode: 'unavailable',
        message: 'Local Gemma is unavailable on this platform.',
        lastError: 'Build and run the Android APK on a real mobile device.',
      );
      onStatus?.call(failed);
      return failed;
    }

    try {
      await _ensureInitialized();

      final installed = await _isGemmaModelInstalled();
      final needsInstallOrActivation =
          forceInstall || !installed || !FlutterGemma.hasActiveModel();

      if (needsInstallOrActivation) {
        await _resetRuntime();

        if (forceInstall) {
          await _uninstallGemmaModelQuietly();
        }

        onStatus?.call(
          initial.copyWith(
            phase: AiBootstrapPhase.installingOrDownloading,
            message: 'Downloading or activating Gemma 4 E2B...',
            modelPath: _modelName,
          ),
        );

        await _installGemmaFromNetwork(
          onProgress: (progress) {
            onStatus?.call(
              initial.copyWith(
                phase: AiBootstrapPhase.installingOrDownloading,
                progressPercent: progress,
                message: 'Downloading or activating Gemma 4 E2B...',
                modelPath: _modelName,
              ),
            );
          },
        );
      }

      onStatus?.call(
        initial.copyWith(
          phase: AiBootstrapPhase.verifying,
          message: 'Opening local Gemma runtime...',
          modelPath: _modelName,
        ),
      );

      await _verifyRuntimeCanOpen();

      _lastBootstrapError = null;
      _lastVerifiedAt = DateTime.now().toUtc();

      final ready = AiBootstrapStatus(
        phase: AiBootstrapPhase.ready,
        modelName: _modelName,
        runtime: _runtime,
        provider: _provider,
        mode: 'local',
        modelPath: _modelName,
        message: 'Local Gemma model is ready.',
        allowAppAccess: true,
        lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
        lastVerifiedAt: _lastVerifiedAt,
      );
      onStatus?.call(ready);

      // Do NOT auto-install Gecko here. It starts another download/runtime setup
      // immediately after Gemma bootstrap and makes debugging much harder.
      return ready;
    } catch (error) {
      await _resetRuntime();
      _lastBootstrapError = error.toString();

      final failed = AiBootstrapStatus(
        phase: AiBootstrapPhase.failed,
        modelName: _modelName,
        runtime: _runtime,
        provider: _provider,
        mode: 'unavailable',
        modelPath: _modelName,
        message:
            'Local Gemma setup failed. You can retry or continue without AI.',
        lastError: error.toString(),
        lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
        lastVerifiedAt: _lastVerifiedAt,
      );
      onStatus?.call(failed);
      return failed;
    }
  }

  Future<InsightSummary> generateDailyRecap({
    required OnDeviceRecapPrompt prompt,
  }) async {
    await _ensureInitialized();
    final stopwatch = Stopwatch()..start();

    try {
      final content = await _runExclusive(
        () => _generateText(
          systemPrompt: prompt.systemPrompt,
          userPrompt: prompt.userPrompt,
        ),
      );
      _lastInferenceLatency = stopwatch.elapsed;

      return InsightSummary(
        id: 'on-device-${DateTime.now().millisecondsSinceEpoch}',
        summaryType: prompt.summaryType,
        periodStart: prompt.periodStart,
        periodEnd: prompt.periodEnd,
        content: content,
        providerName: _provider,
        modelName: _modelName,
        generatedAt: DateTime.now().toUtc(),
      );
    } catch (error) {
      throw Exception('On-device generation failed: $error');
    }
  }

  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
    String? modelPath,
  }) async {
    await _ensureInitialized();
    final stopwatch = Stopwatch()..start();

    try {
      final content = await _runExclusive(
        () => _generateText(systemPrompt: systemPrompt, userPrompt: userPrompt),
      );
      _lastInferenceLatency = stopwatch.elapsed;
      return content;
    } catch (error) {
      throw Exception('On-device generation failed: $error');
    }
  }

  Stream<String> generateTextStream({
    required String systemPrompt,
    required String userPrompt,
  }) {
    dev.log('[GemmaTest] generateTextStream called');
    dev.log('[GemmaTest] systemPrompt length=${systemPrompt.length}');
    dev.log('[GemmaTest] userPrompt length=${userPrompt.length}');

    return _runExclusiveStream(
      () => _streamForPrompt(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      ),
    );
  }

  Future<List<double>> generateEmbedding({required String text}) async {
    await _ensureInitialized();
    final embedder = await _getOrCreateEmbedder();
    return embedder.generateEmbedding(text, taskType: TaskType.retrievalQuery);
  }

  Future<String?> importModelFromPicker() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw Exception('Model import is available on mobile only.');
    }

    await _ensureInitialized();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['litertlm'],
      withReadStream: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final path = file.path?.trim();

    if (path == null || path.isEmpty) {
      throw Exception('Selected file has no valid path.');
    }

    final sourceFile = File(path);
    if (!await sourceFile.exists()) {
      throw Exception('Selected model file does not exist.');
    }

    final size = await sourceFile.length();
    if (size < _minimumModelSizeBytes) {
      throw Exception(
        'Selected model file is too small ($size bytes). Pick the full .litertlm file.',
      );
    }

    await _resetRuntime();
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(path).install();

    await _verifyRuntimeCanOpen();
    _lastBootstrapError = null;
    _lastVerifiedAt = DateTime.now().toUtc();

    return path;
  }

  Future<String> downloadGemma4Model({
    void Function(int progressPercent)? onProgress,
  }) async {
    final status = await ensureModelReady(
      forceInstall: true,
      onStatus: (status) {
        final progress = status.progressPercent;
        if (progress != null) onProgress?.call(progress);
      },
    );

    if (!status.isReady) {
      throw Exception(status.lastError ?? status.message);
    }

    return status.modelPath ?? _modelName;
  }

  Future<Map<String, dynamic>> callFunction({
    required String systemPrompt,
    required String userMessage,
    required List<Tool> tools,
  }) async {
    await _ensureInitialized();

    return _runExclusive(() async {
      InferenceChat? chat;
      var streamEnded = false;
      final startedAt = DateTime.now();

      try {
        final model = await _getOrCreateModel();
        chat = await _createChat(
          model: model,
          systemPrompt: systemPrompt,
          tools: tools,
          supportsFunctionCalls: true,
          toolChoice: ToolChoice.required,
        );

        await chat
            .addQueryChunk(Message.text(text: userMessage, isUser: true))
            .timeout(_chatSetupTimeout);

        await for (final response in chat.generateChatResponseAsync().timeout(
          _streamIdleTimeout,
          onTimeout: (sink) {
            unawaited(_stopChat(chat));
            sink.addError(
              Exception(
                'The on-device model did not emit a function call in time. Open AI Settings and try CPU/GPU again.',
              ),
            );
            sink.close();
          },
        )) {
          _checkStreamDeadlines(startedAt: startedAt, emittedText: false);

          if (response is FunctionCallResponse) {
            streamEnded = true;
            return response.args;
          }

          if (response is ParallelFunctionCallResponse) {
            if (response.calls.isNotEmpty) {
              streamEnded = true;
              return response.calls.first.args;
            }
          }
        }

        streamEnded = true;
        throw Exception('Model did not return a function call.');
      } finally {
        if (!streamEnded) {
          await _stopChat(chat);
          await _resetRuntime();
        } else {
          await _closeChat(chat);
        }
      }
    });
  }

  Future<void> resetRuntime() async {
    await _resetRuntime();
  }

  Future<void> removeInstalledModels() async {
    await _resetRuntime();
    await _uninstallGemmaModelQuietly();
  }

  Stream<String> _streamForPrompt({
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    InferenceChat? chat;
    var streamEnded = false;
    var emittedText = false;
    final startedAt = DateTime.now();

    try {
      final model = await _getOrCreateModel();
      dev.log('[GemmaTest] model obtained, creating chat...');

      chat = await _createChat(model: model, systemPrompt: systemPrompt);
      dev.log('[GemmaTest] chat created, adding query...');

      await chat
          .addQueryChunk(Message.text(text: userPrompt, isUser: true))
          .timeout(_chatSetupTimeout);
      dev.log('[GemmaTest] query added, generating...');

      final responses = chat.generateChatResponseAsync().timeout(
        _streamIdleTimeout,
        onTimeout: (sink) {
          unawaited(_stopChat(chat));
          sink.addError(
            Exception(
              'The on-device model did not emit a response in time. Open AI Settings and try CPU/GPU again.',
            ),
          );
          sink.close();
        },
      );

      await for (final response in responses) {
        _checkStreamDeadlines(startedAt: startedAt, emittedText: emittedText);

        if (response is TextResponse) {
          if (response.token.isEmpty) continue;
          emittedText = emittedText || response.token.trim().isNotEmpty;
          yield response.token;
        } else if (response is ThinkingResponse) {
          if (response.content.isNotEmpty) {
            dev.log('[GemmaTest] thinking chunk ignored for UI text output');
          }
        }
      }

      if (!emittedText) {
        throw Exception(_emptyResponseMessage);
      }

      streamEnded = true;
    } finally {
      if (!streamEnded) {
        await _stopChat(chat);
        await _resetRuntime();
      } else {
        await _closeChat(chat);
      }
    }
  }

  Future<String> _generateText({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    InferenceChat? chat;
    var completed = false;

    try {
      final model = await _getOrCreateModel();
      chat = await _createChat(model: model, systemPrompt: systemPrompt);

      await chat
          .addQueryChunk(Message.text(text: userPrompt, isUser: true))
          .timeout(_chatSetupTimeout);

      final response = await chat.generateChatResponse().timeout(
        _fullGenerationTimeout,
      );

      final content = _textFromResponse(response).trim();
      if (content.isEmpty) {
        throw Exception(_emptyResponseMessage);
      }

      completed = true;
      return content;
    } finally {
      if (!completed) {
        await _stopChat(chat);
        await _resetRuntime();
      } else {
        await _closeChat(chat);
      }
    }
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) async {
    final previous = _generationTail;
    final gate = Completer<void>();
    _generationTail = gate.future;

    try {
      await previous.catchError((_) {});
      return await action();
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }

  Stream<T> _runExclusiveStream<T>(Stream<T> Function() action) async* {
    final previous = _generationTail;
    final gate = Completer<void>();
    _generationTail = gate.future;

    try {
      await previous.catchError((_) {});
      yield* action();
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }

  Future<InferenceChat> _createChat({
    required InferenceModel model,
    required String systemPrompt,
    List<Tool> tools = const [],
    bool supportsFunctionCalls = false,
    ToolChoice toolChoice = ToolChoice.auto,
  }) {
    final backend = _preferredBackend;

    return model
        .createChat(
          systemInstruction: systemPrompt,
          temperature: _gemma4Temperature,
          topK: _gemma4TopK,
          topP: _gemma4TopP,
          tokenBuffer: _gemma4TokenBuffer,
          tools: tools,
          supportsFunctionCalls: supportsFunctionCalls,
          toolChoice: toolChoice,
          isThinking: false,
          modelType: ModelType.gemma4,
        )
        .timeout(
          _chatSetupTimeout,
          onTimeout: () => throw Exception(
            'The on-device model could not open a chat with ${backend.name.toUpperCase()} in time. Open AI Settings and retry with CPU.',
          ),
        );
  }

  String _textFromResponse(ModelResponse response) {
    if (response is TextResponse) return response.token;
    if (response is ThinkingResponse) return '';
    return '';
  }

  void _checkStreamDeadlines({
    required DateTime startedAt,
    required bool emittedText,
  }) {
    final elapsed = DateTime.now().difference(startedAt);

    if (elapsed > _fullGenerationTimeout) {
      throw Exception(
        'The on-device model took too long to finish. The runtime was reset; try again or switch CPU/GPU in AI Settings.',
      );
    }

    if (!emittedText && elapsed > _firstVisibleTokenTimeout) {
      throw Exception(
        'The on-device model kept thinking without producing an answer. The runtime was reset; try again or switch CPU/GPU in AI Settings.',
      );
    }
  }

  Future<void> _stopChat(InferenceChat? chat) async {
    if (chat == null) return;

    try {
      await chat.stopGeneration().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> _closeChat(InferenceChat? chat) async {
    if (chat == null) return;

    try {
      await chat.close().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best effort.
    }
  }

  Future<InferenceModel> _getOrCreateModel() async {
    if (_currentModel != null) return _currentModel!;

    await _ensureActiveModelReady();

    final backend = _preferredBackend;
    final model = await FlutterGemma.getActiveModel(
      maxTokens: _gemma4ContextTokens,
      preferredBackend: backend,
      enableSpeculativeDecoding: _shouldUseSpeculativeDecoding(backend),
    ).timeout(
      _modelOpenTimeout,
      onTimeout: () => throw Exception(
        'The on-device model could not be opened with ${backend.name.toUpperCase()} in time. Open AI Settings and retry with CPU.',
      ),
    );

    _currentModel = model;
    return model;
  }

  Future<void> _ensureActiveModelReady() async {
    await _ensureInitialized();

    if (FlutterGemma.hasActiveModel()) {
      return;
    }

    final status = await ensureModelReady(forceInstall: false);
    if (!status.isReady) {
      throw Exception(status.lastError ?? status.message);
    }

    if (!FlutterGemma.hasActiveModel()) {
      throw Exception(
        'Gemma appears installed, but flutter_gemma has no active model. Retry setup or reinstall the model.',
      );
    }
  }

  Future<void> _installGemmaFromNetwork({
    void Function(int progress)? onProgress,
  }) async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    )
        .fromNetwork(_modelDownloadUrl, foreground: true)
        .withProgress((progress) {
          onProgress?.call(progress);
        })
        .install();
  }

  Future<void> _verifyRuntimeCanOpen() async {
    try {
      await _openAndCloseModelForBackend(_preferredBackend);
    } catch (primaryError) {
      if (_preferredBackend == PreferredBackend.cpu) {
        rethrow;
      }

      final originalBackend = _preferredBackend;
      _preferredBackend = PreferredBackend.cpu;

      try {
        await _openAndCloseModelForBackend(PreferredBackend.cpu);
      } catch (fallbackError) {
        _preferredBackend = originalBackend;
        throw Exception(
          'Gemma runtime verification failed. '
          '${originalBackend.name.toUpperCase()} error: $primaryError. '
          'CPU fallback error: $fallbackError',
        );
      }
    }
  }

  Future<void> _openAndCloseModelForBackend(PreferredBackend backend) async {
    await _closePluginCachedModel();
    _currentModel = null;

    final model = await FlutterGemma.getActiveModel(
      maxTokens: _gemma4ContextTokens,
      preferredBackend: backend,
      enableSpeculativeDecoding: _shouldUseSpeculativeDecoding(backend),
    ).timeout(
      _modelOpenTimeout,
      onTimeout: () => throw Exception(
        'The local Gemma runtime did not open with ${backend.name.toUpperCase()} in time.',
      ),
    );

    try {
      await model.close().timeout(const Duration(seconds: 5));
    } finally {
      await _closePluginCachedModel();
      _currentModel = null;
    }
  }

  bool _shouldUseSpeculativeDecoding(PreferredBackend backend) {
    if (backend == PreferredBackend.npu) return false;
    return _enableSpeculativeDecoding;
  }

  Future<bool> _isGemmaModelInstalled() async {
    try {
      return await FlutterGemma.isModelInstalled(_modelName);
    } catch (error) {
      dev.log('[GemmaTest] isModelInstalled failed: $error');
      return FlutterGemma.hasActiveModel();
    }
  }

  Future<List<String>> _listInstalledModelsSafe() async {
    try {
      return await FlutterGemma.listInstalledModels();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _uninstallGemmaModelQuietly() async {
    try {
      await FlutterGemma.uninstallModel(_modelName);
    } catch (error) {
      dev.log('[GemmaTest] uninstallModel($_modelName) failed: $error');
    }

    final installedModels = await _listInstalledModelsSafe();
    for (final modelId in installedModels) {
      if (modelId == _modelName ||
          modelId.endsWith('/$_modelName') ||
          modelId.contains('gemma-4-E2B-it')) {
        try {
          await FlutterGemma.uninstallModel(modelId);
        } catch (_) {
          // Best effort cleanup only.
        }
      }
    }
  }

  Future<void> installGeckoEmbedding({
    void Function(int progress)? onProgress,
  }) async {
    await _ensureInitialized();

    if (FlutterGemma.hasActiveEmbedder()) return;

    await FlutterGemma.installEmbedder()
        .modelFromNetwork(_geckoModelUrl)
        .tokenizerFromNetwork(_geckoTokenizerUrl)
        .withModelProgress((progress) => onProgress?.call(progress))
        .withTokenizerProgress((_) {})
        .install();
  }

  Future<EmbeddingModel> _getOrCreateEmbedder() async {
    if (_currentEmbedder != null) return _currentEmbedder!;

    if (!FlutterGemma.hasActiveEmbedder()) {
      await FlutterGemma.installEmbedder()
          .modelFromNetwork(_geckoModelUrl)
          .tokenizerFromNetwork(_geckoTokenizerUrl)
          .install();
    }

    final embedder = await FlutterGemma.getActiveEmbedder(
      preferredBackend: PreferredBackend.cpu,
    );
    _currentEmbedder = embedder;
    return embedder;
  }

  Future<void> _resetRuntime() async {
    try {
      await _currentModel?.close();
    } catch (_) {
      // Best effort.
    }
    _currentModel = null;

    await _closePluginCachedModel();

    try {
      await _currentEmbedder?.close();
    } catch (_) {
      // Best effort.
    }
    _currentEmbedder = null;
  }
}
