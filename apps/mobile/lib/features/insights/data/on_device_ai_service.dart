import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:clindiary/features/insights/domain/ai_bootstrap_status.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OnDeviceAiService {
  static const _modelName = 'gemma-4-E2B-it.litertlm';
  static const _provider = 'on_device_litertlm';
  static const _providerLabel = 'Gemma local';
  static const _runtime = 'flutter_gemma (LiteRT-LM)';
  static const _modelDownloadUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true';
  static const _geckoModelUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/gecko-110m-en.tflite';
  static const _geckoTokenizerUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/tokenizer.model';
  static const _chatSetupTimeout = Duration(seconds: 30);
  static const _modelOpenTimeout = Duration(seconds: 45);
  static const _modelActivationTimeout = Duration(seconds: 20);
  static const _firstVisibleTokenTimeout = Duration(seconds: 45);
  static const _streamIdleTimeout = Duration(seconds: 75);
  static const _fullGenerationTimeout = Duration(seconds: 150);
  static const _emptyResponseMessage =
      'The on-device model returned an empty response. Open AI Settings and try CPU/GPU again.';
  static const _gemma4Temperature = 1.0;
  static const _gemma4TopK = 64;
  static const _gemma4TopP = 0.95;
  static const _gemma4TokenBuffer = 256;
  static const _minimumModelSizeBytes = 100 * 1024 * 1024;

  static bool _initialized = false;

  InferenceModel? _currentModel;
  EmbeddingModel? _currentEmbedder;
  PreferredBackend _preferredBackend = PreferredBackend.gpu;
  bool _enableSpeculativeDecoding = true;
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

  Future<void> _closePluginCachedModel() async {
    try {
      final cached = FlutterGemmaPlugin.instance.initializedModel;
      if (cached != null) await cached.close();
    } catch (_) {}
  }

  Future<bool> checkNpuAvailability() async {
    await _ensureInitialized();
    _lastNpuCheckError = null;
    try {
      final plugin = FlutterGemmaPlugin.instance;
      final manager = plugin.modelManager;

      final tempSpec = InferenceModelSpec.fromLegacyUrl(
        name: '_npu_check',
        modelUrl: _modelDownloadUrl,
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
        replacePolicy: ModelReplacePolicy.replace,
      );

      await _closePluginCachedModel();
      _currentModel = null;
      manager.setActiveModel(tempSpec);

      final model = await plugin.createModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
        maxTokens: 1,
        preferredBackend: PreferredBackend.npu,
      );
      await model.close();
      _npuAvailable = true;
      _lastNpuCheckError = null;
      return true;
    } catch (error) {
      _npuAvailable = false;
      _lastNpuCheckError = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      await _closePluginCachedModel();
      _currentModel = null;
      if (!FlutterGemma.hasActiveModel()) {
        try {
          await _ensureActiveModelReady();
        } catch (_) {
          // Best effort restore after the NPU probe.
        }
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await FlutterGemma.initialize();
      _initialized = true;
    }
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
      final expectedFile = await _expectedModelFile();
      final validation = await _validateExpectedModelFile(expectedFile);
      if (!validation.isValid) {
        return OnDeviceAiStatus(
          isSupported: true,
          isReady: false,
          runtime: _runtime,
          provider: _provider,
          activeProviderLabel: 'Gemma local unavailable',
          backendPreference: _preferredBackend.name.toUpperCase(),
          modelName: _modelName,
          defaultModelDirectory: expectedFile.parent.path,
          lastError: validation.message ?? _lastBootstrapError,
          isCloudBypassedForThisRequest: true,
        );
      }

      await _activateExpectedModelFromFile(expectedFile.path);

      return OnDeviceAiStatus(
        isSupported: true,
        isReady: true,
        runtime: _runtime,
        provider: _provider,
        activeProviderLabel: _providerLabel,
        backendPreference: _preferredBackend.name.toUpperCase(),
        backendResolved: _preferredBackend.name.toUpperCase(),
        modelName: _modelName,
        modelPath: expectedFile.path,
        modelFileSizeBytes: await expectedFile.length(),
        modelLastModifiedAt: await expectedFile.lastModified(),
        defaultModelDirectory: expectedFile.parent.path,
        lastVerifiedAt: _lastVerifiedAt,
        lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
        isCloudBypassedForThisRequest: true,
      );
    } catch (e) {
      _lastBootstrapError = e.toString();
      final expectedFile = await _expectedModelFileOrNull();
      return OnDeviceAiStatus(
        isSupported: true,
        isReady: false,
        runtime: _runtime,
        provider: _provider,
        activeProviderLabel: 'Gemma local unavailable',
        backendPreference: _preferredBackend.name.toUpperCase(),
        modelName: _modelName,
        modelPath: expectedFile?.path,
        defaultModelDirectory: expectedFile?.parent.path,
        lastError: e.toString(),
        lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
        isCloudBypassedForThisRequest: true,
      );
    }
  }

  Future<File> _expectedModelFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final directoryPath = Platform.isAndroid
        ? directory.path.replaceFirst('/data/user/0/', '/data/data/')
        : directory.path;
    return File(p.join(directoryPath, _modelName));
  }

  Future<File?> _expectedModelFileOrNull() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }
    try {
      return await _expectedModelFile();
    } catch (_) {
      return null;
    }
  }

  Future<_ModelFileValidation> _validateExpectedModelFile(File file) async {
    try {
      if (!await file.exists()) {
        return const _ModelFileValidation(
          isValid: false,
          exists: false,
          message: 'Expected app-owned Gemma model file is missing.',
        );
      }

      final size = await file.length();
      if (size < _minimumModelSizeBytes) {
        return _ModelFileValidation(
          isValid: false,
          exists: true,
          message:
              'Expected Gemma model file is too small ($size bytes). It will be reinstalled.',
        );
      }

      return const _ModelFileValidation(isValid: true, exists: true);
    } catch (error) {
      return _ModelFileValidation(
        isValid: false,
        exists: false,
        message: 'Could not validate the app-owned Gemma model file: $error',
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
      message: 'Checking the app-owned Gemma model artifact...',
    );
    onStatus?.call(initial);

    if (!Platform.isAndroid && !Platform.isIOS) {
      final failed = initial.copyWith(
        phase: AiBootstrapPhase.failed,
        mode: 'unavailable',
        message: 'Local Gemma is unavailable on this platform.',
        lastError: 'Build and run the Android APK to install Gemma locally.',
      );
      onStatus?.call(failed);
      return failed;
    }

    try {
      await _ensureInitialized();
      var expectedFile = await _expectedModelFile();
      var validation = await _validateExpectedModelFile(expectedFile);

      if (forceInstall || !validation.isValid) {
        await _resetRuntime();
        await _clearStaleModelState(deleteInvalidFile: validation.exists);
        onStatus?.call(
          initial.copyWith(
            phase: AiBootstrapPhase.installingOrDownloading,
            modelPath: expectedFile.path,
            modelDirectory: expectedFile.parent.path,
            message: 'Downloading Gemma 4 E2B to ClinDiary storage...',
          ),
        );

        await FlutterGemma.installModel(
          modelType: ModelType.gemma4,
          fileType: ModelFileType.litertlm,
        ).fromNetwork(_modelDownloadUrl, foreground: true).withProgress((
          progress,
        ) {
          onStatus?.call(
            initial.copyWith(
              phase: AiBootstrapPhase.installingOrDownloading,
              modelPath: expectedFile.path,
              modelDirectory: expectedFile.parent.path,
              progressPercent: progress,
              message: 'Downloading Gemma 4 E2B to ClinDiary storage...',
            ),
          );
        }).install();

        expectedFile = await _expectedModelFile();
        validation = await _validateExpectedModelFile(expectedFile);
      }

      onStatus?.call(
        initial.copyWith(
          phase: AiBootstrapPhase.verifying,
          modelPath: expectedFile.path,
          modelDirectory: expectedFile.parent.path,
          message: 'Verifying the local Gemma runtime...',
        ),
      );

      if (!validation.isValid) {
        await _clearStaleModelState(deleteInvalidFile: validation.exists);
        throw Exception(validation.message ?? 'Gemma model validation failed.');
      }

      await _activateExpectedModelFromFile(expectedFile.path);
      await _verifyRuntimeCanOpen();
      _lastBootstrapError = null;
      _lastVerifiedAt = DateTime.now().toUtc();

      final ready = AiBootstrapStatus(
        phase: AiBootstrapPhase.ready,
        modelName: _modelName,
        runtime: _runtime,
        provider: _provider,
        mode: 'local',
        modelPath: expectedFile.path,
        modelDirectory: expectedFile.parent.path,
        message: 'Local Gemma model is ready.',
        allowAppAccess: true,
        lastInferenceLatencyMillis: _lastInferenceLatency?.inMilliseconds,
        lastVerifiedAt: _lastVerifiedAt,
      );
      onStatus?.call(ready);
      unawaited(installGeckoEmbedding());
      return ready;
    } catch (error) {
      await _resetRuntime();
      _lastBootstrapError = error.toString();
      final expectedFile = await _expectedModelFileOrNull();
      final failed = AiBootstrapStatus(
        phase: AiBootstrapPhase.failed,
        modelName: _modelName,
        runtime: _runtime,
        provider: _provider,
        mode: 'unavailable',
        modelPath: expectedFile?.path,
        modelDirectory: expectedFile?.parent.path,
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
    } catch (e) {
      throw Exception('On-device generation failed: $e');
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
    } catch (e) {
      throw Exception('On-device generation failed: $e');
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
      () =>
          _streamForPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt),
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

    final expectedFile = await _copyModelIntoAppStorage(File(path));
    final validation = await _validateExpectedModelFile(expectedFile);
    if (!validation.isValid) {
      await _clearStaleModelState(deleteInvalidFile: validation.exists);
      throw Exception(
        validation.message ?? 'Imported model validation failed.',
      );
    }
    await _activateExpectedModelFromFile(expectedFile.path);
    await _resetRuntime();
    return expectedFile.path;
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
    return status.modelPath ?? '';
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
    await _removeModelFiles();
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
            yield '[thinking]${response.content}[/thinking]';
          }
        }
      }

      streamEnded = true;
      if (!emittedText) {
        throw Exception(_emptyResponseMessage);
      }
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
      completed = true;
      if (content.isEmpty) {
        throw Exception(_emptyResponseMessage);
      }
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
          isThinking: true,
          modelType: ModelType.gemma4,
        )
        .timeout(
          _chatSetupTimeout,
          onTimeout: () => throw Exception(
            'The on-device model could not open a chat in time. Open AI Settings and retry with CPU or GPU.',
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
    } catch (_) {}
  }

  Future<void> _closeChat(InferenceChat? chat) async {
    if (chat == null) return;
    try {
      await chat.close().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<InferenceModel> _getOrCreateModel() async {
    if (_currentModel != null) return _currentModel!;
    await _ensureActiveModelReady();
    final model =
        await FlutterGemma.getActiveModel(
          maxTokens: 4096,
          preferredBackend: _preferredBackend,
          enableSpeculativeDecoding: _enableSpeculativeDecoding,
        ).timeout(
          _modelOpenTimeout,
          onTimeout: () => throw Exception(
            'The on-device model could not be opened in time. Open AI Settings and retry with CPU or GPU.',
          ),
        );
    _currentModel = model;
    return model;
  }

  Future<void> _ensureActiveModelReady() async {
    await _ensureInitialized();
    final expectedFile = await _expectedModelFile();
    final validation = await _validateExpectedModelFile(expectedFile);
    if (!validation.isValid) {
      await _clearStaleModelState(deleteInvalidFile: validation.exists);
      throw Exception(validation.message ?? 'The Gemma model is not ready.');
    }

    await _activateExpectedModelFromFile(expectedFile.path);

    if (!FlutterGemma.hasActiveModel()) {
      throw Exception(
        'The app-owned Gemma model is valid but not active. Retry model setup.',
      );
    }
  }

  Future<File> _copyModelIntoAppStorage(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw Exception('Selected model file does not exist.');
    }

    final expectedFile = await _expectedModelFile();
    await expectedFile.parent.create(recursive: true);

    final sourcePath = p.normalize(sourceFile.path);
    final expectedPath = p.normalize(expectedFile.path);
    await _resetRuntime();
    await _clearStaleModelState(deleteInvalidFile: sourcePath != expectedPath);
    if (sourcePath == expectedPath) {
      return expectedFile;
    }

    final tempFile = File('${expectedFile.path}.import');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    await sourceFile.copy(tempFile.path);
    if (await expectedFile.exists()) {
      await expectedFile.delete();
    }
    await tempFile.rename(expectedFile.path);
    return expectedFile;
  }

  Future<void> _activateExpectedModelFromFile(String modelPath) async {
    await FlutterGemma.installModel(
          modelType: ModelType.gemma4,
          fileType: ModelFileType.litertlm,
        )
        .fromFile(modelPath)
        .install()
        .timeout(
          _modelActivationTimeout,
          onTimeout: () => throw Exception(
            'The Gemma model could not be activated from ClinDiary storage in time. Retry model setup.',
          ),
        );
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
          'Gemma runtime verification failed. ${originalBackend.name.toUpperCase()} error: $primaryError. CPU fallback error: $fallbackError',
        );
      }
    }
  }

  Future<void> _openAndCloseModelForBackend(PreferredBackend backend) async {
    await _closePluginCachedModel();
    _currentModel = null;
    final model =
        await FlutterGemma.getActiveModel(
          maxTokens: 1,
          preferredBackend: backend,
          enableSpeculativeDecoding: _enableSpeculativeDecoding,
        ).timeout(
          _modelOpenTimeout,
          onTimeout: () => throw Exception(
            'The local Gemma runtime did not open with ${backend.name.toUpperCase()} in time.',
          ),
        );
    await model.close().timeout(const Duration(seconds: 5));
    await _closePluginCachedModel();
  }

  Future<void> _clearStaleModelState({required bool deleteInvalidFile}) async {
    try {
      await FlutterGemma.uninstallModel(_modelName);
    } catch (_) {}

    if (!deleteInvalidFile) {
      return;
    }

    final expectedFile = await _expectedModelFileOrNull();
    if (expectedFile == null) {
      return;
    }

    for (final file in [
      expectedFile,
      File('${expectedFile.path}.download'),
      File('${expectedFile.path}.import'),
    ]) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
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
        .withModelProgress((p) => onProgress?.call(p))
        .withTokenizerProgress((_) {})
        .install();
  }

  Future<EmbeddingModel> _getOrCreateEmbedder() async {
    if (_currentEmbedder != null) return _currentEmbedder!;
    if (FlutterGemma.hasActiveEmbedder()) {
      final embedder = await FlutterGemma.getActiveEmbedder(
        preferredBackend: PreferredBackend.gpu,
      );
      _currentEmbedder = embedder;
      return embedder;
    }
    await FlutterGemma.installEmbedder()
        .modelFromNetwork(_geckoModelUrl)
        .tokenizerFromNetwork(_geckoTokenizerUrl)
        .install();
    final embedder = await FlutterGemma.getActiveEmbedder(
      preferredBackend: PreferredBackend.gpu,
    );
    _currentEmbedder = embedder;
    return embedder;
  }

  Future<void> _resetRuntime() async {
    try {
      await _currentModel?.close();
    } catch (_) {}
    _currentModel = null;
    await _closePluginCachedModel();
    try {
      await _currentEmbedder?.close();
    } catch (_) {}
    _currentEmbedder = null;
  }

  Future<void> _removeModelFiles() async {
    await _resetRuntime();
    await _clearStaleModelState(deleteInvalidFile: true);
  }
}

class _ModelFileValidation {
  const _ModelFileValidation({
    required this.isValid,
    required this.exists,
    this.message,
  });

  final bool isValid;
  final bool exists;
  final String? message;
}
