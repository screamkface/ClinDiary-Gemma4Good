import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class HistoryDay {
  const HistoryDay({
    required this.targetDate,
    required this.dailyEntry,
    required this.dailySummary,
    required this.weeklySummary,
    required this.monthlySummary,
    this.wearableSummary,
    required this.documents,
    required this.timelineEvents,
  });

  final DateTime targetDate;
  final DailyEntry? dailyEntry;
  final InsightSummary? dailySummary;
  final InsightSummary? weeklySummary;
  final InsightSummary? monthlySummary;
  final WearableDaySummary? wearableSummary;
  final List<ClinicalDocumentSummary> documents;
  final List<TimelineEventItem> timelineEvents;

  factory HistoryDay.fromJson(Map<String, dynamic> json) => HistoryDay(
    targetDate: DateTime.parse(json['target_date'].toString()),
    dailyEntry: json['daily_entry'] == null
        ? null
        : DailyEntry.fromJson(json['daily_entry'] as Map<String, dynamic>),
    dailySummary: json['daily_summary'] == null
        ? null
        : InsightSummary.fromJson(
            json['daily_summary'] as Map<String, dynamic>,
          ),
    weeklySummary: json['weekly_summary'] == null
        ? null
        : InsightSummary.fromJson(
            json['weekly_summary'] as Map<String, dynamic>,
          ),
    monthlySummary: json['monthly_summary'] == null
        ? null
        : InsightSummary.fromJson(
            json['monthly_summary'] as Map<String, dynamic>,
          ),
    wearableSummary: json['wearable_summary'] == null
        ? null
        : WearableDaySummary.fromJson(
            json['wearable_summary'] as Map<String, dynamic>,
          ),
    documents: (json['documents'] as List<dynamic>)
        .map(
          (item) =>
              ClinicalDocumentSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    timelineEvents: (json['timeline_events'] as List<dynamic>)
        .map((item) => TimelineEventItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
