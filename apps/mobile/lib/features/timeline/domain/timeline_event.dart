class TimelineEventItem {
  const TimelineEventItem({
    required this.id,
    required this.eventType,
    required this.title,
    required this.description,
    required this.eventDate,
    this.severity,
  });

  final String id;
  final String eventType;
  final String title;
  final String description;
  final DateTime eventDate;
  final String? severity;

  factory TimelineEventItem.fromJson(Map<String, dynamic> json) =>
      TimelineEventItem(
        id: json['id'].toString(),
        eventType: json['event_type'].toString(),
        title: json['title'].toString(),
        description: json['description'].toString(),
        eventDate: DateTime.parse(json['event_date'].toString()),
        severity: json['severity'] as String?,
      );
}
