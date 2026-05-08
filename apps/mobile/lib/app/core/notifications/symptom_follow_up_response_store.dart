import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PendingSymptomFollowUpResponse {
  const PendingSymptomFollowUpResponse({
    required this.sourceEntryId,
    required this.sourceSymptomId,
    required this.response,
    required this.recordedAt,
  });

  final String sourceEntryId;
  final String sourceSymptomId;
  final String response;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() {
    return {
      'source_entry_id': sourceEntryId,
      'source_symptom_id': sourceSymptomId,
      'response': response,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };
  }

  factory PendingSymptomFollowUpResponse.fromJson(Map<String, dynamic> json) {
    return PendingSymptomFollowUpResponse(
      sourceEntryId: json['source_entry_id'].toString(),
      sourceSymptomId: json['source_symptom_id'].toString(),
      response: json['response'].toString(),
      recordedAt: DateTime.tryParse(json['recorded_at'].toString())?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

class SymptomFollowUpResponseStore {
  SymptomFollowUpResponseStore();

  static const _fileName = 'symptom_follow_up_responses.json';

  Future<void> enqueue(PendingSymptomFollowUpResponse item) async {
    final items = await _readAll();
    final byKey = <String, PendingSymptomFollowUpResponse>{
      for (final current in items) _key(current): current,
      _key(item): item,
    };
    await _writeAll(byKey.values.toList());
  }

  Future<List<PendingSymptomFollowUpResponse>> consumeAll() async {
    final items = await _readAll();
    final file = await _resolveFile();
    if (await file.exists()) {
      await file.delete();
    }
    items.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return items;
  }

  Future<List<PendingSymptomFollowUpResponse>> _readAll() async {
    final file = await _resolveFile();
    if (!await file.exists()) {
      return const <PendingSymptomFollowUpResponse>[];
    }
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return const <PendingSymptomFollowUpResponse>[];
      }
      final decoded = jsonDecode(content) as List<dynamic>;
      return decoded
          .map(
            (item) => PendingSymptomFollowUpResponse.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const <PendingSymptomFollowUpResponse>[];
    }
  }

  Future<void> _writeAll(List<PendingSymptomFollowUpResponse> items) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }

  Future<File> _resolveFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return File('${Directory.systemTemp.path}${Platform.pathSeparator}$_fileName');
    }
  }

  String _key(PendingSymptomFollowUpResponse item) {
    return '${item.sourceEntryId}|${item.sourceSymptomId}';
  }
}
