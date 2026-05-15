import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class OnDeviceAiService {
  static const _modelName = 'gemma-4-E2B-it.litertlm';
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

  static bool _initialized = false;

  InferenceModel? _currentModel;
  EmbeddingModel? _currentEmbedder;
  PreferredBackend _preferredBackend = PreferredBackend.gpu;
  bool _enableSpeculativeDecoding = true;
  bool? _npuAvailable;
  String? _lastNpuCheckError;
  Future<void> _generationTail = Future.value();

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
    await _ensureInitialized();
    try {
      final isInstalled = await FlutterGemma.isModelInstalled(_modelName);
      final knownModelFile = await _knownModelFile();
      if (!isInstalled) {
        return OnDeviceAiStatus(
          isSupported: true,
          isReady: false,
          runtime: 'flutter_gemma (LiteRT-LM)',
          provider: 'on_device_litertlm',
          activeProviderLabel: 'On-device non configurato',
          backendPreference: 'GPU',
          modelName: _modelName,
          defaultModelDirectory: _defaultModelDirectory,
          isCloudBypassedForThisRequest: true,
        );
      }

      await _ensureActiveModelReady();

      return OnDeviceAiStatus(
        isSupported: true,
        isReady: true,
        runtime: 'flutter_gemma (LiteRT-LM)',
        provider: 'on_device_litertlm',
        activeProviderLabel: 'Gemma 4 On-device',
        backendPreference: _preferredBackend.name.toUpperCase(),
        backendResolved: _preferredBackend.name.toUpperCase(),
        modelName: _modelName,
        modelPath: knownModelFile?.path,
        modelFileSizeBytes: knownModelFile == null
            ? null
            : await knownModelFile.length(),
        modelLastModifiedAt: knownModelFile == null
            ? null
            : await knownModelFile.lastModified(),
        defaultModelDirectory: _defaultModelDirectory,
        isCloudBypassedForThisRequest: true,
      );
    } catch (e) {
      return OnDeviceAiStatus(
        isSupported: true,
        isReady: false,
        runtime: 'flutter_gemma (LiteRT-LM)',
        provider: 'on_device_litertlm',
        activeProviderLabel: 'On-device non pronto',
        backendPreference: 'GPU',
        lastError: e.toString(),
        isCloudBypassedForThisRequest: true,
      );
    }
  }

  static const _defaultModelDirectory =
      '/sdcard/Android/data/it.clindiary.clindiary/files/models';

  Future<File?> _knownModelFile() async {
    if (!Platform.isAndroid) {
      return null;
    }
    final file = File('$_defaultModelDirectory/$_modelName');
    return file.exists().then((exists) => exists ? file : null);
  }

  Future<InsightSummary> generateDailyRecap({
    required OnDeviceRecapPrompt prompt,
  }) async {
    await _ensureInitialized();
    try {
      final content = await _runExclusive(
        () => _generateText(
          systemPrompt: prompt.systemPrompt,
          userPrompt: prompt.userPrompt,
        ),
      );
      return InsightSummary(
        id: 'on-device-${DateTime.now().millisecondsSinceEpoch}',
        summaryType: prompt.summaryType,
        periodStart: prompt.periodStart,
        periodEnd: prompt.periodEnd,
        content: content,
        providerName: 'on_device_litertlm',
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
    try {
      return await _runExclusive(
        () => _generateText(systemPrompt: systemPrompt, userPrompt: userPrompt),
      );
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

    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(path).install();

    final installedPath = path;
    await _resetRuntime();
    return installedPath;
  }

  Future<String> downloadGemma4Model({
    void Function(int progressPercent)? onProgress,
  }) async {
    await _ensureInitialized();

    String? installedPath;

    final preInstalledFile = File('$_defaultModelDirectory/$_modelName');
    if (await preInstalledFile.exists()) {
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(preInstalledFile.path).install();
      installedPath = preInstalledFile.path;
    } else {
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(_modelDownloadUrl).withProgress((progress) {
        onProgress?.call(progress);
      }).install();
    }

    await _resetRuntime();
    return installedPath ?? '';
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
    if (FlutterGemma.hasActiveModel()) {
      return;
    }

    final knownModelFile = await _knownModelFile();
    if (knownModelFile != null) {
      await FlutterGemma.installModel(
            modelType: ModelType.gemma4,
            fileType: ModelFileType.litertlm,
          )
          .fromFile(knownModelFile.path)
          .install()
          .timeout(
            _modelActivationTimeout,
            onTimeout: () => throw Exception(
              'The Gemma model could not be activated from local storage in time. Open AI Settings and retry model setup.',
            ),
          );
    } else {
      final isInstalled = await FlutterGemma.isModelInstalled(_modelName);
      if (!isInstalled) {
        throw Exception('The Gemma on-device model is not installed yet.');
      }

      // Some flutter_gemma state is in-memory only after app restarts. If the
      // repository already has the file, re-arm the active spec without
      // starting a network installation from the prompt path.
      FlutterGemmaPlugin.instance.modelManager.setActiveModel(
        InferenceModelSpec.fromLegacyUrl(
          name: _modelName,
          modelUrl: _modelDownloadUrl,
          modelType: ModelType.gemma4,
          fileType: ModelFileType.litertlm,
          replacePolicy: ModelReplacePolicy.keep,
        ),
      );
    }

    if (!FlutterGemma.hasActiveModel()) {
      throw Exception(
        'The Gemma on-device model is installed but not active. Reopen Manage model and reinstall it.',
      );
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
    try {
      final dir = Directory(_defaultModelDirectory);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.litertlm')) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }
}
