class SymptomEntry {
  const SymptomEntry({
    required this.id,
    required this.symptomCode,
    this.severity,
    this.durationMinutes,
    this.bodyLocation,
  });

  final String id;
  final String symptomCode;
  final int? severity;
  final int? durationMinutes;
  final String? bodyLocation;

  factory SymptomEntry.fromJson(Map<String, dynamic> json) => SymptomEntry(
    id: json['id'].toString(),
    symptomCode: json['symptom_code'].toString(),
    severity: json['severity'] as int?,
    durationMinutes: json['duration_minutes'] as int?,
    bodyLocation: json['body_location'] as String?,
  );
}

class VitalSignEntry {
  const VitalSignEntry({
    required this.id,
    required this.type,
    required this.value,
    this.unit,
    required this.measuredAt,
  });

  final String id;
  final String type;
  final String value;
  final String? unit;
  final DateTime measuredAt;

  factory VitalSignEntry.fromJson(Map<String, dynamic> json) => VitalSignEntry(
    id: json['id'].toString(),
    type: json['type'].toString(),
    value: json['value'].toString(),
    unit: json['unit'] as String?,
    measuredAt: DateTime.parse(json['measured_at'].toString()),
  );
}

class DailyEntry {
  const DailyEntry({
    required this.id,
    required this.entryDate,
    this.sleepHours,
    this.sleepQuality,
    this.energyLevel,
    this.moodLevel,
    this.stressLevel,
    this.appetiteLevel,
    this.hydrationLevel,
    this.generalPain,
    this.generalNotes,
    required this.symptoms,
    required this.vitals,
  });

  final String id;
  final DateTime entryDate;
  final double? sleepHours;
  final int? sleepQuality;
  final int? energyLevel;
  final int? moodLevel;
  final int? stressLevel;
  final int? appetiteLevel;
  final int? hydrationLevel;
  final int? generalPain;
  final String? generalNotes;
  final List<SymptomEntry> symptoms;
  final List<VitalSignEntry> vitals;

  factory DailyEntry.fromJson(Map<String, dynamic> json) => DailyEntry(
    id: json['id'].toString(),
    entryDate: DateTime.parse(json['entry_date'].toString()),
    sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
    sleepQuality: json['sleep_quality'] as int?,
    energyLevel: json['energy_level'] as int?,
    moodLevel: json['mood_level'] as int?,
    stressLevel: json['stress_level'] as int?,
    appetiteLevel: json['appetite_level'] as int?,
    hydrationLevel: json['hydration_level'] as int?,
    generalPain: json['general_pain'] as int?,
    generalNotes: json['general_notes'] as String?,
    symptoms: (json['symptoms'] as List<dynamic>)
        .map((item) => SymptomEntry.fromJson(item as Map<String, dynamic>))
        .toList(),
    vitals: (json['vitals'] as List<dynamic>)
        .map((item) => VitalSignEntry.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
