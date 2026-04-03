class ClinicalReport {
  const ClinicalReport({
    required this.id,
    required this.reportType,
    required this.status,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
    this.summaryExcerpt,
    required this.contentText,
    required this.generatedAt,
    this.processingError,
    this.downloadUrl,
  });

  final String id;
  final String reportType;
  final String status;
  final String title;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? summaryExcerpt;
  final String contentText;
  final DateTime generatedAt;
  final String? processingError;
  final String? downloadUrl;

  factory ClinicalReport.fromJson(Map<String, dynamic> json) => ClinicalReport(
    id: json['id'].toString(),
    reportType: json['report_type'].toString(),
    status: json['status'].toString(),
    title: json['title'].toString(),
    periodStart: DateTime.parse(json['period_start'].toString()),
    periodEnd: DateTime.parse(json['period_end'].toString()),
    summaryExcerpt: json['summary_excerpt'] as String?,
    contentText: json['content_text'].toString(),
    generatedAt: DateTime.parse(json['generated_at'].toString()),
    processingError: json['processing_error'] as String?,
    downloadUrl: json['download_url'] as String?,
  );
}
