import 'dart:io';

import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OnDeviceAiService {
  static const MethodChannel _channel = MethodChannel('clindiary/on_device_ai');

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
      final response = await _channel.invokeMapMethod<String, dynamic>(
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
        id: response['id']?.toString() ?? 'on-device-${DateTime.now().millisecondsSinceEpoch}',
        summaryType: prompt.summaryType,
        periodStart: prompt.periodStart,
        periodEnd: prompt.periodEnd,
        content: response['content']?.toString() ?? '',
        providerName: response['provider_name']?.toString() ?? 'on_device_litertlm',
        modelName: response['model_name']?.toString(),
        generatedAt: DateTime.parse(
          response['generated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
        ),
      );
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

  Future<void> _removeExistingModelFiles(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('.litertlm')) {
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
