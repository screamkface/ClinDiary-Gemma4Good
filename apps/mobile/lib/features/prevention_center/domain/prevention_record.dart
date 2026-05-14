class PreventionRecord {
  final String code;
  final DateTime performedAt;
  final String? resultSummary;
  final String? sourceId;

  const PreventionRecord({
    required this.code,
    required this.performedAt,
    this.resultSummary,
    this.sourceId,
  });

  factory PreventionRecord.fromJson(Map<String, dynamic> json) {
    return PreventionRecord(
      code: json['code'].toString(),
      performedAt: DateTime.parse(json['performed_at'].toString()),
      resultSummary: json['result_summary'] as String?,
      sourceId: json['source_id']?.toString(),
    );
  }
}

/// [PreventionRecord] is now integrated into [ProfileBundle] as
/// `preventionRecords`. The engine currently ignores it; integrate
/// `_hasRecentRecord()` and `_hasEverRecord()` in the future to
/// suppress completed recommendations.
