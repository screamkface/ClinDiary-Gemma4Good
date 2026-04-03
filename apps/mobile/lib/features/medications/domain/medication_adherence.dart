class MedicationLogItem {
  const MedicationLogItem({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    this.medicationDosage,
    required this.scheduledAt,
    this.takenAt,
    required this.status,
    this.notes,
    this.pendingSync = false,
  });

  final String id;
  final String medicationId;
  final String medicationName;
  final String? medicationDosage;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final String status;
  final String? notes;
  final bool pendingSync;

  factory MedicationLogItem.fromJson(Map<String, dynamic> json) {
    return MedicationLogItem(
      id: json['id'].toString(),
      medicationId: json['medication_id'].toString(),
      medicationName: json['medication_name'].toString(),
      medicationDosage: json['medication_dosage'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'].toString()),
      takenAt: json['taken_at'] == null
          ? null
          : DateTime.parse(json['taken_at'].toString()),
      status: json['status'].toString(),
      notes: json['notes'] as String?,
      pendingSync: json['pending_sync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medication_id': medicationId,
      'medication_name': medicationName,
      'medication_dosage': medicationDosage,
      'scheduled_at': scheduledAt.toIso8601String(),
      'taken_at': takenAt?.toIso8601String(),
      'status': status,
      'notes': notes,
      'pending_sync': pendingSync,
    };
  }
}
