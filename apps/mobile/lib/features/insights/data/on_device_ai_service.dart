import 'dart:io';

import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OnDeviceAiService {
  static const MethodChannel _channel = MethodChannel('clindiary/on_device_ai');
  static final Uri _gemma4ModelDownloadUri = Uri.parse(
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true',
  );
  static const String _gemma4ModelFileName = 'gemma-4-E2B-it.litertlm';

  static final Uri _embeddingModelDownloadUri = Uri.parse(
    'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq512_mixed-precision.tflite?download=true',
  );
  static const String _embeddingModelFileName = 'embeddinggemma-300m.tflite';

  Future<Map<String, dynamic>?> _invokePrompt(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    return _channel.invokeMapMethod<String, dynamic>(method, arguments);
  }

  Future<OnDeviceAiStatus> fetchStatus() async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      return OnDeviceAiStatus.fromJson(response ?? const {});
    } on MissingPluginException {
      return const OnDeviceAiStatus(
        isSupported: false,
        isReady: false,
        runtime: 'LiteRT-LM Android',
        provider: 'on_device_litertlm',
        activeProviderLabel: 'On-device unavailable',
        backendPreference: 'GPU',
        isCloudBypassedForThisRequest: true,
      );
    } on PlatformException catch (error) {
      return OnDeviceAiStatus(
        isSupported: true,
        isReady: false,
        runtime: 'LiteRT-LM Android',
        provider: 'on_device_litertlm',
        activeProviderLabel: 'On-device not ready',
        backendPreference: 'GPU',
        lastError: error.toString(),
        isCloudBypassedForThisRequest: true,
      );
    }
  }

  Future<InsightSummary> generateDailyRecap({
    required OnDeviceRecapPrompt prompt,
  }) async {
    try {
      final response = await _invokePrompt(
        'generateDailyRecap',
        <String, dynamic>{
          'systemPrompt': prompt.systemPrompt,
          'userPrompt': prompt.userPrompt,
        },
      );
      if (response == null) {
        throw Exception('The on-device runtime did not return a response.');
      }
      return InsightSummary(
        id:
            response['id']?.toString() ??
            'on-device-${DateTime.now().millisecondsSinceEpoch}',
        summaryType: prompt.summaryType,
        periodStart: prompt.periodStart,
        periodEnd: prompt.periodEnd,
        content: response['content']?.toString() ?? '',
        providerName:
            response['provider_name']?.toString() ?? 'on_device_litertlm',
        modelName: response['model_name']?.toString(),
        generatedAt: DateTime.parse(
          response['generated_at']?.toString() ??
              DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } on MissingPluginException {
      throw Exception('On-device inference is available on Android only.');
    } on PlatformException catch (error) {
      throw Exception(error.toString() ?? 'On-device generation failed.');
    }
  }

  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
    String? modelPath,
  }) async {
    try {
      final response = await _invokePrompt('generateText', <String, dynamic>{
        'systemPrompt': systemPrompt,
        'userPrompt': userPrompt,
        if (modelPath != null) 'modelPath': modelPath,
      });
      if (response == null) {
        throw Exception('The on-device runtime did not return a response.');
      }
      final content = response['content']?.toString().trim() ?? '';
      if (content.isEmpty) {
        throw Exception('The on-device runtime returned empty content.');
      }
      return content;
    } on MissingPluginException {
      throw Exception('On-device inference is available on Android only.');
    } on PlatformException catch (error) {
      throw Exception(error.toString() ?? 'On-device generation failed.');
    }
  }

  Future<List<double>> generateEmbedding({
    required String text,
    String? modelPath,
  }) async {
    try {
      final response = await _invokePrompt('generateEmbedding', <String, dynamic>{
        'text': text,
        if (modelPath != null) 'modelPath': modelPath,
      });
      if (response == null) {
        throw Exception('The on-device runtime did not return a response.');
      }
      final rawEmbedding = response['embedding'] as List<dynamic>?;
      if (rawEmbedding == null || rawEmbedding.isEmpty) {
        throw Exception('The on-device runtime returned empty embedding.');
      }
      return rawEmbedding.map((e) => (e as num).toDouble()).toList();
    } on MissingPluginException {
      throw Exception('On-device inference is available on Android only.');
    } on PlatformException catch (error) {
      throw Exception(error.toString() ?? 'On-device embedding generation failed.');
    }
  }

  Future<String?> importModelFromPicker() async {
    if (!Platform.isAndroid) {
      throw Exception('Model import is available on Android only.');
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['litertlm'],
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final targetDirectory = await _resolveModelDirectory();
    await targetDirectory.create(recursive: true);

    final sourcePath = file.path?.trim();
    if (sourcePath != null && sourcePath.isNotEmpty) {
      final sourceFile = File(sourcePath).absolute;
      if (p.equals(p.dirname(sourceFile.path), targetDirectory.absolute.path)) {
        await resetRuntime();
        return sourceFile.path;
      }
    }

    await _removeExistingModelFiles(targetDirectory);

    final targetPath = p.join(targetDirectory.path, file.name);
    await _copyPickedFile(file, targetPath);
    await resetRuntime();
    return targetPath;
  }

  Future<String> downloadGemma4Model({
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw Exception('Model download is available on Android only.');
    }

    final targetDirectory = await _resolveModelDirectory();
    await targetDirectory.create(recursive: true);

    final targetPath = p.join(targetDirectory.path, _gemma4ModelFileName);
    final targetFile = File(targetPath);
    final tempFile = File('$targetPath.download');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', _gemma4ModelDownloadUri)
        ..headers[HttpHeaders.userAgentHeader] = 'ClinDiary/1.0'
        ..headers[HttpHeaders.acceptHeader] = 'application/octet-stream';
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Model download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final totalBytes = contentLength != null && contentLength > 0
          ? contentLength
          : null;
      var receivedBytes = 0;
      final sink = tempFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, totalBytes);
        }
      } finally {
        await sink.close();
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      await tempFile.rename(targetFile.path);
      await _removeExistingModelFiles(
        targetDirectory,
        keepFileName: p.basename(targetFile.path),
      );
      await resetRuntime();
      return targetFile.path;
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<String> downloadEmbeddingModel({
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw Exception('Model download is available on Android only.');
    }

    final targetDirectory = await _resolveModelDirectory();
    await targetDirectory.create(recursive: true);

    final targetPath = p.join(targetDirectory.path, _embeddingModelFileName);
    final targetFile = File(targetPath);
    final tempFile = File('$targetPath.download');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', _embeddingModelDownloadUri)
        ..headers[HttpHeaders.userAgentHeader] = 'ClinDiary/1.0'
        ..headers[HttpHeaders.acceptHeader] = 'application/octet-stream';
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Embedding model download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final totalBytes = contentLength != null && contentLength > 0
          ? contentLength
          : null;
      var receivedBytes = 0;
      final sink = tempFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, totalBytes);
        }
      } finally {
        await sink.close();
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      await tempFile.rename(targetFile.path);
      await resetRuntime();
      return targetFile.path;
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> resetRuntime() async {
    try {
      await _channel.invokeMethod<void>('resetRuntime');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  Future<void> removeInstalledModels() async {
    final targetDirectory = await _resolveModelDirectory();
    await _removeExistingModelFiles(targetDirectory);
    await resetRuntime();
  }

  Future<Directory> _resolveModelDirectory() async {
    final status = await fetchStatus();
    final explicitDirectory = status.defaultModelDirectory?.trim();
    if (explicitDirectory != null && explicitDirectory.isNotEmpty) {
      return Directory(explicitDirectory);
    }

    final externalDirectory = await getExternalStorageDirectory();
    if (externalDirectory != null) {
      return Directory(p.join(externalDirectory.path, 'models'));
    }

    throw Exception('Android model directory unavailable.');
  }

  Future<void> _removeExistingModelFiles(
    Directory directory, {
    String? keepFileName,
  }) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.litertlm')) {
        if (keepFileName != null && p.basename(entity.path) == keepFileName) {
          continue;
        }
        await entity.delete();
      }
    }
  }

  Future<void> _copyPickedFile(PlatformFile file, String targetPath) async {
    if (file.readStream != null) {
      final targetFile = File(targetPath);
      final sink = targetFile.openWrite();
      try {
        await sink.addStream(file.readStream!);
      } finally {
        await sink.close();
      }
      return;
    }

    if (file.bytes != null) {
      await File(targetPath).writeAsBytes(file.bytes!, flush: true);
      return;
    }

    if (file.path != null && file.path!.trim().isNotEmpty) {
      await File(file.path!).copy(targetPath);
      return;
    }

    throw Exception('Unable to read the selected file.');
  }
}
