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
        activeProviderLabel: 'On-device non disponibile',
        backendPreference: 'GPU',
        isCloudBypassedForThisRequest: true,
      );
    } on PlatformException catch (error) {
      return OnDeviceAiStatus(
        isSupported: true,
        isReady: false,
        runtime: 'LiteRT-LM Android',
        provider: 'on_device_litertlm',
        activeProviderLabel: 'On-device non pronto',
        backendPreference: 'GPU',
        lastError: error.message,
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
        throw Exception('Il runtime on-device non ha restituito una risposta.');
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
      throw Exception('Inferenza on-device disponibile solo su Android.');
    } on PlatformException catch (error) {
      throw Exception(error.message ?? 'Generazione on-device non riuscita.');
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
        throw Exception('Il runtime on-device non ha restituito una risposta.');
      }
      final content = response['content']?.toString().trim() ?? '';
      if (content.isEmpty) {
        throw Exception(
          'Il runtime on-device ha restituito un contenuto vuoto.',
        );
      }
      return content;
    } on MissingPluginException {
      throw Exception('Inferenza on-device disponibile solo su Android.');
    } on PlatformException catch (error) {
      throw Exception(error.message ?? 'Generazione on-device non riuscita.');
    }
  }

  Future<String?> importModelFromPicker() async {
    if (!Platform.isAndroid) {
      throw Exception('Importazione modello disponibile solo su Android.');
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
      throw Exception('Download modello disponibile solo su Android.');
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
        throw Exception(
          'Download modello fallito: HTTP ${response.statusCode}',
        );
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

    throw Exception('Directory modelli Android non disponibile.');
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

    throw Exception('Impossibile leggere il file selezionato.');
  }
}
