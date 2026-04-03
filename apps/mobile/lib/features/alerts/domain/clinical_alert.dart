class ClinicalAlert {
  const ClinicalAlert({
    required this.id,
    required this.severity,
    required this.alertType,
    this.ruleCode,
    required this.title,
    required this.description,
    required this.status,
    this.sourceType,
    this.sourceId,
    required this.triggeredAt,
    this.resolvedAt,
    this.resolutionNotes,
  });

  final String id;
  final String severity;
  final String alertType;
  final String? ruleCode;
  final String title;
  final String description;
  final String status;
  final String? sourceType;
  final String? sourceId;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  bool get isResolved => status == 'resolved';

  factory ClinicalAlert.fromJson(Map<String, dynamic> json) => ClinicalAlert(
    id: json['id'].toString(),
    severity: json['severity'].toString(),
    alertType: json['alert_type'].toString(),
    ruleCode: json['rule_code'] as String?,
    title: json['title'].toString(),
    description: json['description'].toString(),
    status: json['status'].toString(),
    sourceType: json['source_type'] as String?,
    sourceId: json['source_id']?.toString(),
    triggeredAt: DateTime.parse(json['triggered_at'].toString()),
    resolvedAt: json['resolved_at'] == null
        ? null
        : DateTime.parse(json['resolved_at'].toString()),
    resolutionNotes: json['resolution_notes'] as String?,
  );
}
