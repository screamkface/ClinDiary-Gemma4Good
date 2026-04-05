import 'package:flutter/foundation.dart';

enum InsightSummaryMode { standard, privateLocal, onDevice }

class InsightSummary {
  const InsightSummary({
    required this.id,
    required this.summaryType,
    required this.periodStart,
    required this.periodEnd,
    required this.content,
    this.providerName,
    this.modelName,
    required this.generatedAt,
  });

  final String id;
  final String summaryType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String content;
  final String? providerName;
  final String? modelName;
  final DateTime generatedAt;

  factory InsightSummary.fromJson(Map<String, dynamic> json) => InsightSummary(
    id: json['id'].toString(),
    summaryType: json['summary_type'].toString(),
    periodStart: DateTime.parse(json['period_start'].toString()),
    periodEnd: DateTime.parse(json['period_end'].toString()),
    content: json['content'].toString(),
    providerName: json['provider_name'] as String?,
    modelName: json['model_name'] as String?,
    generatedAt: DateTime.parse(json['generated_at'].toString()),
  );
}

@immutable
class InsightSummaryQuery {
  const InsightSummaryQuery({
    required this.summaryType,
    this.referenceDate,
    this.mode = InsightSummaryMode.standard,
  });

  final String summaryType;
  final DateTime? referenceDate;
  final InsightSummaryMode mode;

  @override
  bool operator ==(Object other) {
    return other is InsightSummaryQuery &&
        other.summaryType == summaryType &&
        other.referenceDate == referenceDate &&
        other.mode == mode;
  }

  @override
  int get hashCode => Object.hash(summaryType, referenceDate, mode);
}
