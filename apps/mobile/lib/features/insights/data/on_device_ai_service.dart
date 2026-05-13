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

  static bool _initialized = false;

  InferenceModel? _currentModel;
  EmbeddingModel? _currentEmbedder;
  PreferredBackend _preferredBackend = PreferredBackend.gpu;
  bool _enableSpeculativeDecoding = true;
  bool? _npuAvailable;

  PreferredBackend get preferredBackend => _preferredBackend;
  bool get enableSpeculativeDecoding => _enableSpeculativeDecoding;
  bool? get npuAvailable => _npuAvailable;

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
      return true;
    } catch (_) {
      _npuAvailable = false;
      return false;
    } finally {
      await _closePluginCachedModel();
      _currentModel = null;
      if (!FlutterGemma.hasActiveModel()) {
        await FlutterGemma.installModel(
          modelType: ModelType.gemma4,
          fileType: ModelFileType.litertlm,
        ).fromNetwork(_modelDownloadUrl).install();
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
      if (!isInstalled) {
        return const OnDeviceAiStatus(
          isSupported: true,
          isReady: false,
          runtime: 'flutter_gemma (LiteRT-LM)',
          provider: 'on_device_litertlm',
          activeProviderLabel: 'On-device non configurato',
          backendPreference: 'GPU',
          isCloudBypassedForThisRequest: true,
        );
      }

      // After app restart the active model spec is null because
      // it's held in-memory by flutter_gemma and only set during install().
      // Call install() to re-establish the spec (skips download when model exists).
      if (!FlutterGemma.hasActiveModel()) {
        await FlutterGemma.installModel(
          modelType: ModelType.gemma4,
          fileType: ModelFileType.litertlm,
        ).fromNetwork(_modelDownloadUrl).install();
      }

      return OnDeviceAiStatus(
        isSupported: true,
        isReady: true,
        runtime: 'flutter_gemma (LiteRT-LM)',
        provider: 'on_device_litertlm',
        activeProviderLabel: 'Gemma 4 On-device',
        backendPreference: _preferredBackend.name.toUpperCase(),
        modelName: _modelName,
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

  Future<InsightSummary> generateDailyRecap({
    required OnDeviceRecapPrompt prompt,
  }) async {
    await _ensureInitialized();
    try {
      final content = await _generateText(
        systemPrompt: prompt.systemPrompt,
        userPrompt: prompt.userPrompt,
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
      return await _generateText(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
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
    return _streamForPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt);
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
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    await _ensureInitialized();

    String? installedPath;

    final preInstalledFile = File(
      '/sdcard/Android/data/it.clindiary.clindiary/files/models/$_modelName',
    );
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
        onProgress?.call(progress, 100);
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
    final model = await _getOrCreateModel();
    final chat = await model.createChat(
      systemInstruction: systemPrompt,
      tools: tools,
      supportsFunctionCalls: true,
      toolChoice: ToolChoice.required,
    );
    await chat.addQueryChunk(Message.text(text: userMessage, isUser: true));
    final responses = await chat.generateChatResponseAsync().toList();
    for (final response in responses) {
      if (response is FunctionCallResponse) {
        return response.args;
      }
      if (response is ParallelFunctionCallResponse) {
        if (response.calls.isNotEmpty) {
          return response.calls.first.args;
        }
      }
    }
    throw Exception('Model did not return a function call.');
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
  }) {
    final controller = StreamController<String>();

    _getOrCreateModel()
        .then((model) async {
          dev.log('[GemmaTest] model obtained, creating chat...');
          final chat = await model.createChat(systemInstruction: systemPrompt);
          dev.log('[GemmaTest] chat created, adding query...');
          await chat.addQueryChunk(
            Message.text(text: userPrompt, isUser: true),
          );
          dev.log('[GemmaTest] query added, generating...');

          var subscription = chat.generateChatResponseAsync().listen(
            (response) {
              if (response is TextResponse) {
                controller.add(response.token);
              } else if (response is ThinkingResponse) {
                controller.add('[thinking]${response.content}[/thinking]');
              }
            },
            onDone: () {
              unawaited(controller.close());
            },
            onError: (e) {
              if (!controller.isClosed) {
                controller.addError(e);
              }
            },
            cancelOnError: false,
          );

          controller.onCancel = () {
            subscription.cancel();
          };
        })
        .catchError((e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        });

    return controller.stream;
  }

  Future<String> _generateText({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final model = await _getOrCreateModel();
    final chat = await model.createChat(systemInstruction: systemPrompt);
    await chat.addQueryChunk(Message.text(text: userPrompt, isUser: true));
    final response = await chat.generateChatResponse();
    final content = response.toString().trim();
    if (content.isEmpty) {
      throw Exception('Il modello on-device ha restituito una risposta vuota.');
    }
    return content;
  }

  Future<InferenceModel> _getOrCreateModel() async {
    if (_currentModel != null) return _currentModel!;
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 4096,
      preferredBackend: _preferredBackend,
      enableSpeculativeDecoding: _enableSpeculativeDecoding,
    );
    _currentModel = model;
    return model;
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
    try {
      await _currentEmbedder?.close();
    } catch (_) {}
    _currentEmbedder = null;
  }

  Future<void> _removeModelFiles() async {
    try {
      await _currentModel?.close();
    } catch (_) {}
    _currentModel = null;
    try {
      await _currentEmbedder?.close();
    } catch (_) {}
    _currentEmbedder = null;

    try {
      final dir = Directory(
        '/sdcard/Android/data/it.clindiary.clindiary/files/models',
      );
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
