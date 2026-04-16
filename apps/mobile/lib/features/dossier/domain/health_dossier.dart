import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/reports/domain/clinical_report.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class DossierProfileFact {
  const DossierProfileFact({required this.label, required this.value});

  final String label;
  final String value;

  factory DossierProfileFact.fromJson(Map<String, dynamic> json) {
    return DossierProfileFact(
      label: json['label'].toString(),
      value: json['value'].toString(),
    );
  }
}

class DossierProvenanceFact {
  const DossierProvenanceFact({required this.label, required this.value});

  final String label;
  final String value;

  factory DossierProvenanceFact.fromJson(Map<String, dynamic> json) {
    return DossierProvenanceFact(
      label: json['label'].toString(),
      value: json['value'].toString(),
    );
  }
}

class DossierEmergencySummary {
  const DossierEmergencySummary({
    required this.generatedAt,
    required this.headline,
    required this.keyPoints,
    required this.activeProblems,
    required this.activeMedications,
    required this.allergies,
    required this.conditions,
    required this.openAlerts,
    this.latestWearableSummary,
    this.latestReportSummary,
  });

  DossierEmergencySummary.empty()
    : generatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      headline = 'Scheda emergenza ClinDiary',
      keyPoints = const [],
      activeProblems = const [],
      activeMedications = const [],
      allergies = const [],
      conditions = const [],
      openAlerts = const [],
      latestWearableSummary = null,
      latestReportSummary = null;

  final DateTime generatedAt;
  final String headline;
  final List<String> keyPoints;
  final List<String> activeProblems;
  final List<String> activeMedications;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> openAlerts;
  final String? latestWearableSummary;
  final String? latestReportSummary;

  factory DossierEmergencySummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DossierEmergencySummary.empty();
    }
    return DossierEmergencySummary(
      generatedAt: DateTime.parse(json['generated_at'].toString()),
      headline: json['headline'].toString(),
      keyPoints: (json['key_points'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      activeProblems: (json['active_problems'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      activeMedications: (json['active_medications'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      allergies: (json['allergies'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      conditions: (json['conditions'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      openAlerts: (json['open_alerts'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      latestWearableSummary: json['latest_wearable_summary'] as String?,
      latestReportSummary: json['latest_report_summary'] as String?,
    );
  }

  String toShareText({required String displayName}) {
    final buffer = StringBuffer()
      ..writeln('ClinDiary - Scheda emergenza')
      ..writeln(displayName)
      ..writeln('Aggiornata: ${generatedAt.toLocal()}')
      ..writeln(headline);
    for (final point in keyPoints) {
      buffer.writeln('- $point');
    }
    if (activeProblems.isNotEmpty) {
      buffer.writeln('Problemi attivi: ${activeProblems.join(', ')}');
    }
    if (activeMedications.isNotEmpty) {
      buffer.writeln('Farmaci attivi: ${activeMedications.join(', ')}');
    }
    if (allergies.isNotEmpty) {
      buffer.writeln('Allergie: ${allergies.join(', ')}');
    }
    if (conditions.isNotEmpty) {
      buffer.writeln('Patologie: ${conditions.join(', ')}');
    }
    if (openAlerts.isNotEmpty) {
      buffer.writeln('Alert aperti: ${openAlerts.join(', ')}');
    }
    if (latestWearableSummary != null && latestWearableSummary!.isNotEmpty) {
      buffer.writeln('Wearable: $latestWearableSummary');
    }
    if (latestReportSummary != null && latestReportSummary!.isNotEmpty) {
      buffer.writeln('Report: $latestReportSummary');
    }
    return buffer.toString().trim();
  }
}

class DossierDocumentItem {
  const DossierDocumentItem({
    required this.id,
    required this.title,
    required this.documentType,
    required this.uploadDate,
    this.examDate,
    this.source,
    required this.parsedStatus,
    required this.contextStatus,
  });

  final String id;
  final String title;
  final String documentType;
  final DateTime uploadDate;
  final DateTime? examDate;
  final String? source;
  final String parsedStatus;
  final String contextStatus;

  factory DossierDocumentItem.fromJson(Map<String, dynamic> json) {
    return DossierDocumentItem(
      id: json['id'].toString(),
      title: json['title'].toString(),
      documentType: json['document_type'].toString(),
      uploadDate: DateTime.parse(json['upload_date'].toString()),
      examDate: json['exam_date'] == null
          ? null
          : DateTime.parse(json['exam_date'].toString()),
      source: json['source'] as String?,
      parsedStatus: json['parsed_status'].toString(),
      contextStatus: json['context_status'].toString(),
    );
  }
}

class DossierLabPanelItem {
  const DossierLabPanelItem({
    required this.documentId,
    required this.documentTitle,
    required this.panelName,
    this.panelDate,
    required this.abnormalResultsCount,
    required this.keyResults,
  });

  final String documentId;
  final String documentTitle;
  final String panelName;
  final DateTime? panelDate;
  final int abnormalResultsCount;
  final List<String> keyResults;

  factory DossierLabPanelItem.fromJson(Map<String, dynamic> json) {
    return DossierLabPanelItem(
      documentId: json['document_id'].toString(),
      documentTitle: json['document_title'].toString(),
      panelName: json['panel_name'].toString(),
      panelDate: json['panel_date'] == null
          ? null
          : DateTime.parse(json['panel_date'].toString()),
      abnormalResultsCount: json['abnormal_results_count'] as int? ?? 0,
      keyResults: (json['key_results'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class DossierImagingReportItem {
  const DossierImagingReportItem({
    required this.documentId,
    required this.documentTitle,
    this.examDate,
    this.examType,
    this.bodyPart,
    this.impression,
  });

  final String documentId;
  final String documentTitle;
  final DateTime? examDate;
  final String? examType;
  final String? bodyPart;
  final String? impression;

  factory DossierImagingReportItem.fromJson(Map<String, dynamic> json) {
    return DossierImagingReportItem(
      documentId: json['document_id'].toString(),
      documentTitle: json['document_title'].toString(),
      examDate: json['exam_date'] == null
          ? null
          : DateTime.parse(json['exam_date'].toString()),
      examType: json['exam_type'] as String?,
      bodyPart: json['body_part'] as String?,
      impression: json['impression'] as String?,
    );
  }
}

class DossierReportSummary {
  const DossierReportSummary({
    required this.id,
    required this.reportType,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    this.summaryExcerpt,
  });

  final String id;
  final String reportType;
  final String title;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final String? summaryExcerpt;

  factory DossierReportSummary.fromJson(Map<String, dynamic> json) {
    return DossierReportSummary(
      id: json['id'].toString(),
      reportType: json['report_type'].toString(),
      title: json['title'].toString(),
      periodStart: DateTime.parse(json['period_start'].toString()),
      periodEnd: DateTime.parse(json['period_end'].toString()),
      generatedAt: DateTime.parse(json['generated_at'].toString()),
      summaryExcerpt: json['summary_excerpt'] as String?,
    );
  }

  ClinicalReport toClinicalReport() {
    return ClinicalReport(
      id: id,
      reportType: reportType,
      status: 'generated',
      title: title,
      periodStart: periodStart,
      periodEnd: periodEnd,
      summaryExcerpt: summaryExcerpt,
      contentText: summaryExcerpt ?? '',
      generatedAt: generatedAt,
    );
  }
}

class DossierDeviceMeasurementSummary {
  const DossierDeviceMeasurementSummary({
    required this.providerCode,
    required this.providerName,
    required this.metricType,
    required this.metricLabel,
    required this.measurementCount,
    required this.latestMeasuredAt,
    required this.latestValue,
    this.trendLabel,
    this.concernLevel,
    this.concernNote,
    required this.summary,
  });

  final String providerCode;
  final String providerName;
  final String metricType;
  final String metricLabel;
  final int measurementCount;
  final DateTime latestMeasuredAt;
  final String latestValue;
  final String? trendLabel;
  final String? concernLevel;
  final String? concernNote;
  final String summary;

  factory DossierDeviceMeasurementSummary.fromJson(Map<String, dynamic> json) {
    return DossierDeviceMeasurementSummary(
      providerCode: json['provider_code'].toString(),
      providerName: json['provider_name'].toString(),
      metricType: json['metric_type'].toString(),
      metricLabel: json['metric_label'].toString(),
      measurementCount: json['measurement_count'] as int? ?? 0,
      latestMeasuredAt: DateTime.parse(json['latest_measured_at'].toString()),
      latestValue: json['latest_value']?.toString() ?? '',
      trendLabel: json['trend_label'] as String?,
      concernLevel: json['concern_level'] as String?,
      concernNote: json['concern_note'] as String?,
      summary: json['summary'].toString(),
    );
  }
}

class DossierShareLinkItem {
  const DossierShareLinkItem({
    required this.id,
    required this.scope,
    this.label,
    this.shareUrl,
    required this.filename,
    required this.mimeType,
    required this.expiresAt,
    this.revokedAt,
    this.lastAccessedAt,
    required this.createdAt,
  });

  final String id;
  final String scope;
  final String? label;
  final String? shareUrl;
  final String filename;
  final String mimeType;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime? lastAccessedAt;
  final DateTime createdAt;

  bool get isActive =>
      revokedAt == null && expiresAt.isAfter(DateTime.now().toUtc());

  factory DossierShareLinkItem.fromJson(Map<String, dynamic> json) {
    return DossierShareLinkItem(
      id: json['id'].toString(),
      scope: json['scope'].toString(),
      label: json['label'] as String?,
      shareUrl: json['share_url'] as String?,
      filename: json['filename']?.toString() ?? 'dossier.pdf',
      mimeType: json['mime_type']?.toString() ?? 'application/pdf',
      expiresAt: DateTime.parse(json['expires_at'].toString()),
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.parse(json['revoked_at'].toString()),
      lastAccessedAt: json['last_accessed_at'] == null
          ? null
          : DateTime.parse(json['last_accessed_at'].toString()),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

class HealthDossier {
  const HealthDossier({
    required this.generatedAt,
    required this.displayName,
    this.age,
    this.biologicalSex,
    required this.profileFacts,
    required this.provenanceFacts,
    required this.emergencySummary,
    required this.allergies,
    required this.medicalConditions,
    required this.medications,
    required this.familyHistory,
    required this.vaccinations,
    this.clinicalEpisodes = const <ClinicalEpisodeItem>[],
    required this.recentDailyEntries,
    required this.recentDocuments,
    required this.recentLabPanels,
    required this.recentImagingReports,
    required this.deviceMeasurementSummaries,
    required this.recentInsights,
    required this.recentReports,
    required this.alerts,
    required this.wearableSummaries,
  });

  final DateTime generatedAt;
  final String displayName;
  final int? age;
  final String? biologicalSex;
  final List<DossierProfileFact> profileFacts;
  final List<DossierProvenanceFact> provenanceFacts;
  final DossierEmergencySummary emergencySummary;
  final List<AllergyItem> allergies;
  final List<MedicalConditionItem> medicalConditions;
  final List<MedicationItem> medications;
  final List<FamilyHistoryItem> familyHistory;
  final List<VaccinationRecordItem> vaccinations;
  final List<ClinicalEpisodeItem> clinicalEpisodes;
  final List<DailyEntry> recentDailyEntries;
  final List<DossierDocumentItem> recentDocuments;
  final List<DossierLabPanelItem> recentLabPanels;
  final List<DossierImagingReportItem> recentImagingReports;
  final List<DossierDeviceMeasurementSummary> deviceMeasurementSummaries;
  final List<InsightSummary> recentInsights;
  final List<DossierReportSummary> recentReports;
  final List<ClinicalAlert> alerts;
  final List<WearableDaySummary> wearableSummaries;

  factory HealthDossier.fromJson(Map<String, dynamic> json) {
    return HealthDossier(
      generatedAt: DateTime.parse(json['generated_at'].toString()),
      displayName: json['display_name']?.toString() ?? 'Clinical profile',
      age: json['age'] as int?,
      biologicalSex: json['biological_sex'] as String?,
      profileFacts: (json['profile_facts'] as List<dynamic>? ?? [])
          .map(
            (item) => DossierProfileFact.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      provenanceFacts: (json['provenance_facts'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                DossierProvenanceFact.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      emergencySummary: DossierEmergencySummary.fromJson(
        json['emergency_summary'] as Map<String, dynamic>?,
      ),
      allergies: (json['allergies'] as List<dynamic>? ?? [])
          .map((item) => AllergyItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      medicalConditions: (json['medical_conditions'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                MedicalConditionItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      medications: (json['medications'] as List<dynamic>? ?? [])
          .map((item) => MedicationItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      familyHistory: (json['family_history'] as List<dynamic>? ?? [])
          .map(
            (item) => FamilyHistoryItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      vaccinations: (json['vaccinations'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                VaccinationRecordItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      clinicalEpisodes: (json['clinical_episodes'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                ClinicalEpisodeItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      recentDailyEntries: (json['recent_daily_entries'] as List<dynamic>? ?? [])
          .map((item) => DailyEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      recentDocuments: (json['recent_documents'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                DossierDocumentItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      recentLabPanels: (json['recent_lab_panels'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                DossierLabPanelItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      recentImagingReports:
          (json['recent_imaging_reports'] as List<dynamic>? ?? [])
              .map(
                (item) => DossierImagingReportItem.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      deviceMeasurementSummaries:
          (json['device_measurement_summaries'] as List<dynamic>? ?? [])
              .map(
                (item) => DossierDeviceMeasurementSummary.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      recentInsights: (json['recent_insights'] as List<dynamic>? ?? [])
          .map((item) => InsightSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      recentReports: (json['recent_reports'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                DossierReportSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map((item) => ClinicalAlert.fromJson(item as Map<String, dynamic>))
          .toList(),
      wearableSummaries: (json['wearable_summaries'] as List<dynamic>? ?? [])
          .map(
            (item) => WearableDaySummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
