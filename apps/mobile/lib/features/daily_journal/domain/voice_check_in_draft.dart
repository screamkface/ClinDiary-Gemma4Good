import 'dart:convert';

class VoiceCheckInDraft {
  const VoiceCheckInDraft({
    this.entryDate,
    this.sleepHours,
    this.sleepQuality,
    this.energyLevel,
    this.moodLevel,
    this.stressLevel,
    this.appetiteLevel,
    this.hydrationLevel,
    this.generalPain,
    this.generalNotes,
    this.followUpQuestions = const [],
    this.symptoms = const [],
  });

  final DateTime? entryDate;
  final double? sleepHours;
  final int? sleepQuality;
  final int? energyLevel;
  final int? moodLevel;
  final int? stressLevel;
  final int? appetiteLevel;
  final int? hydrationLevel;
  final int? generalPain;
  final String? generalNotes;
  final List<String> followUpQuestions;
  final List<VoiceCheckInSymptomDraft> symptoms;

  bool get hasSymptoms => symptoms.isNotEmpty;

  bool get hasFollowUpQuestions => followUpQuestions.isNotEmpty;

  factory VoiceCheckInDraft.fromAiResponse(String response) {
    final payload = _decodeResponsePayload(response);
    return VoiceCheckInDraft.fromJson(payload);
  }

  factory VoiceCheckInDraft.fromJson(Map<String, dynamic> json) {
    return VoiceCheckInDraft(
      entryDate: _parseDate(json['entry_date']),
      sleepHours: _parseDouble(json['sleep_hours']),
      sleepQuality: _parseInt(json['sleep_quality']),
      energyLevel: _parseInt(json['energy_level']),
      moodLevel: _parseInt(json['mood_level']),
      stressLevel: _parseInt(json['stress_level']),
      appetiteLevel: _parseInt(json['appetite_level']),
      hydrationLevel: _parseInt(json['hydration_level']),
      generalPain: _parseInt(json['general_pain']),
      generalNotes: _parseString(json['general_notes']),
      followUpQuestions: _parseStringList(json['follow_up_questions']),
      symptoms: _parseSymptoms(json['symptoms']),
    );
  }

  Map<String, dynamic> toDailyEntryPayload(String fallbackEntryDate) {
    final effectiveEntryDate =
        entryDate ?? DateTime.tryParse(fallbackEntryDate);
    return <String, dynamic>{
      'entry_date': _formatDate(effectiveEntryDate),
      'sleep_hours': sleepHours,
      'sleep_quality': sleepQuality,
      'energy_level': energyLevel,
      'mood_level': moodLevel,
      'stress_level': stressLevel,
      'appetite_level': appetiteLevel,
      'hydration_level': hydrationLevel,
      'general_pain': generalPain,
      'general_notes': generalNotes,
    };
  }

  static Map<String, dynamic> _decodeResponsePayload(String response) {
    final trimmed = response.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty response from the model.');
    }

    final startIndex = trimmed.indexOf('{');
    if (startIndex < 0) {
      throw FormatException('Response is not JSON: $trimmed');
    }

    var depth = 0;
    for (var index = startIndex; index < trimmed.length; index++) {
      final character = trimmed[index];
      if (character == '{') {
        depth++;
      } else if (character == '}') {
        depth--;
        if (depth == 0) {
          final jsonText = trimmed.substring(startIndex, index + 1);
          final decoded = jsonDecode(jsonText);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          throw const FormatException(
            'The model did not return a JSON object.',
          );
        }
      }
    }

    throw const FormatException(
      'Incomplete JSON in the model response.',
    );
  }

  static DateTime? _parseDate(dynamic value) {
    final text = _parseString(value);
    if (text == null) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    final text = _parseString(value);
    if (text == null) {
      return null;
    }
    return double.tryParse(text.replaceAll(',', '.'));
  }

  static int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    final text = _parseString(value);
    if (text == null) {
      return null;
    }
    final parsedDouble = double.tryParse(text.replaceAll(',', '.'));
    return parsedDouble?.round();
  }

  static String? _parseString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  static List<VoiceCheckInSymptomDraft> _parseSymptoms(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<dynamic>()
        .map((item) {
          if (item is Map<String, dynamic>) {
            return VoiceCheckInSymptomDraft.fromJson(item);
          }
          if (item is Map) {
            return VoiceCheckInSymptomDraft.fromJson(
              item.map((key, dynamic value) => MapEntry(key.toString(), value)),
            );
          }
          return null;
        })
        .whereType<VoiceCheckInSymptomDraft>()
        .toList(growable: false);
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(_parseString)
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _formatDate(DateTime? dateTime) {
    final effectiveDate = dateTime ?? DateTime.now();
    return effectiveDate.toIso8601String().split('T').first;
  }
}

class VoiceCheckInSymptomDraft {
  const VoiceCheckInSymptomDraft({
    required this.symptomCode,
    this.severity,
    this.durationMinutes,
    this.bodyLocation,
    this.metadataJson = const <String, dynamic>{},
  });

  final String symptomCode;
  final int? severity;
  final int? durationMinutes;
  final String? bodyLocation;
  final Map<String, dynamic> metadataJson;

  factory VoiceCheckInSymptomDraft.fromJson(Map<String, dynamic> json) {
    return VoiceCheckInSymptomDraft(
      symptomCode: _cleanCode(json['symptom_code']) ?? 'custom_symptom',
      severity: VoiceCheckInDraft._parseInt(json['severity']),
      durationMinutes: VoiceCheckInDraft._parseInt(json['duration_minutes']),
      bodyLocation: VoiceCheckInDraft._parseString(json['body_location']),
      metadataJson: _parseMetadataJson(json['metadata_json']),
    );
  }

  Map<String, dynamic> toRequestPayload() {
    return <String, dynamic>{
      'symptom_code': symptomCode,
      'severity': severity,
      'duration_minutes': durationMinutes,
      'body_location': bodyLocation,
      'metadata_json': metadataJson.isEmpty ? null : metadataJson,
    };
  }

  static String? _cleanCode(dynamic value) {
    final text = VoiceCheckInDraft._parseString(value);
    if (text == null) {
      return null;
    }
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static Map<String, dynamic> _parseMetadataJson(dynamic value) {
    if (value == null) {
      return const <String, dynamic>{};
    }
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (entry) => MapEntry(entry.key.toString(), entry.value),
        ),
      );
    }
    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.fromEntries(
            decoded.entries.map(
              (entry) => MapEntry(entry.key.toString(), entry.value),
            ),
          );
        }
      } catch (_) {
        return <String, dynamic>{'notes': trimmed};
      }
    }
    return const <String, dynamic>{};
  }
}
