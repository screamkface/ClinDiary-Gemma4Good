import 'dart:convert';

import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/core/storage/local_database.dart' hide DailyEntry;
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:clindiary/features/insights/domain/on_device_text_prompt.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center_engine.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class OnDevicePromptBuilder {
  OnDevicePromptBuilder({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  Future<OnDeviceRecapPrompt?> buildDailyRecapPrompt({
    required DateTime referenceDate,
  }) async {
    final languageCode = await readStoredAppLanguageCode(_localDatabase);
    final isItalian = isItalianLanguageCode(languageCode);
    final profileBundle = await _readProfileBundle();
    final dossier = await _readHealthDossier();
    final entries = await _readDailyEntries();
    final alerts = await _readAlerts();
    final medicationLogs = await _readMedicationLogs();
    final wearableSummaries = await _readWearableSummaries();
    final timelineEvents = await _readTimelineEvents();

    final targetDay = _dateOnly(referenceDate);
    final directEntriesForDay = entries
        .where((entry) => _sameDay(entry.entryDate, targetDay))
        .toList();
    final entriesForDay = [
      ...directEntriesForDay,
      if (dossier != null && directEntriesForDay.isEmpty)
        ...dossier.recentDailyEntries.where(
          (entry) => _sameDay(entry.entryDate, targetDay),
        ),
    ]..sort((a, b) => a.entryDate.compareTo(b.entryDate));
    final relevantLogs = medicationLogs.where((item) {
      final scheduledDay = _dateOnly(item.scheduledAt);
      return _sameDay(scheduledDay, targetDay);
    }).toList();
    final directWearablesForDay = wearableSummaries
        .where((item) => _sameDay(item.summaryDate, targetDay))
        .toList();
    final relevantWearables = [
      ...directWearablesForDay,
      if (dossier != null && directWearablesForDay.isEmpty)
        ...dossier.wearableSummaries.where(
          (item) => _sameDay(item.summaryDate, targetDay),
        ),
    ];
    final relevantTimeline =
        timelineEvents
            .where((item) => _sameDay(item.eventDate, targetDay))
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final directOpenAlerts = alerts.where((item) => !item.isResolved).toList();
    final openAlerts = [
      ...directOpenAlerts,
      if (dossier != null && directOpenAlerts.isEmpty)
        ...dossier.alerts.where((item) => !item.isResolved),
    ];
    final deviceMeasurementSummaries =
        dossier?.deviceMeasurementSummaries
            .map((item) => item.summary)
            .toList() ??
        const <String>[];
    final recentLabResults =
        dossier?.recentLabPanels.map(_labPanelLine).toList() ??
        const <String>[];
    final recentImagingReports =
        dossier?.recentImagingReports.map(_imagingReportLine).toList() ??
        const <String>[];
    final timelineLines = relevantTimeline.map(_timelineLine).toList();
    final structuredDocumentLines =
        dossier?.recentDocuments.map(_documentLine).toList() ??
        const <String>[];
    final recentDocumentLines = [...timelineLines, ...structuredDocumentLines];
    final priorDailySummaries =
        dossier?.recentInsights
            .where((item) => item.summaryType.toLowerCase() == 'daily')
            .map(_priorDailySummaryLine)
            .toList() ??
        const <String>[];

    final hasLocalContext =
        profileBundle != null ||
        dossier != null ||
        entriesForDay.isNotEmpty ||
        relevantLogs.isNotEmpty ||
        relevantWearables.isNotEmpty ||
        relevantTimeline.isNotEmpty ||
        openAlerts.isNotEmpty ||
        deviceMeasurementSummaries.isNotEmpty ||
        recentLabResults.isNotEmpty ||
        recentImagingReports.isNotEmpty ||
        recentDocumentLines.isNotEmpty ||
        priorDailySummaries.isNotEmpty;
    if (!hasLocalContext) {
      return null;
    }

    final hasSufficientClinicalContext =
        entriesForDay.isNotEmpty ||
        relevantWearables.isNotEmpty ||
        deviceMeasurementSummaries.isNotEmpty ||
        recentLabResults.isNotEmpty ||
        recentImagingReports.isNotEmpty ||
        structuredDocumentLines.isNotEmpty ||
        priorDailySummaries.isNotEmpty;
    if (!hasSufficientClinicalContext) {
      return null;
    }

    final dataConsidered = <String>[
      '${entriesForDay.length} local check-ins',
      '${entriesForDay.fold<int>(0, (total, entry) => total + entry.symptoms.length)} symptoms',
      '${entriesForDay.fold<int>(0, (total, entry) => total + entry.vitals.length)} vital signs',
      '${relevantLogs.length} medication logs',
      '${relevantWearables.length} wearable summaries',
      '${relevantTimeline.length} timeline events',
      '${openAlerts.length} open alerts',
      '${deviceMeasurementSummaries.length} device summaries',
      '${recentLabResults.length} recent lab panels',
      '${recentImagingReports.length} recent imaging reports',
      '${recentDocumentLines.length} recent documents/events',
      '${priorDailySummaries.length} previous recaps',
    ];

    final patientSnapshot = _patientSnapshot(profileBundle, dossier);
    final activeConditions = _mergeStrings(
      profileBundle?.medicalConditions.map((item) => item.name),
      dossier?.medicalConditions.map((item) => item.name),
    );
    final allergies = _mergeStrings(
      profileBundle?.allergies.map((item) => item.allergen),
      dossier?.allergies.map((item) => item.allergen),
    );
    final familyHistory = _mergeStrings(
      profileBundle?.familyHistory.map(
        (item) => '${item.relation}: ${item.conditionName}',
      ),
      dossier?.familyHistory.map(
        (item) => '${item.relation}: ${item.conditionName}',
      ),
    );
    final medications = _mergeStrings(
      profileBundle?.medications
          .where((item) => item.active)
          .map(_medicationLine),
      dossier?.medications.where((item) => item.active).map(_medicationLine),
    );
    final medicationAdherence = relevantLogs.map(_medicationLogLine).toList();
    final wearableLines = relevantWearables
        .map((item) => item.toDiagnosticText())
        .toList();
    final journalEntries = entriesForDay.map(_serializeEntry).toList();
    final observations = _buildObservations(
      entriesForDay,
      relevantWearables,
      relevantTimeline,
    );
    final followUpReasons = _buildFollowUpReasons(
      entriesForDay,
      relevantWearables,
      openAlerts,
    );
    final missingData = _buildMissingData(
      entriesForDay: entriesForDay,
      relevantWearables: relevantWearables,
      relevantLogs: relevantLogs,
      profileBundle: profileBundle,
      dossier: dossier,
    );
    final clinicalEpisodes = _mergeStrings(
      profileBundle?.clinicalEpisodes.map(_clinicalEpisodeLine),
      dossier?.clinicalEpisodes.map(_clinicalEpisodeLine),
    );

    final payload = <String, Object?>{
      'summary_type': 'daily',
      'summary_label': isItalian
          ? 'riepilogo giornaliero locale'
          : 'on-device daily summary',
      'period_start': targetDay.toIso8601String().split('T').first,
      'period_end': targetDay.toIso8601String().split('T').first,
      'data_considered': dataConsidered,
      'patient_snapshot': patientSnapshot,
      'active_conditions': activeConditions,
      'allergies': allergies,
      'family_history': familyHistory,
      'medications': medications,
      'medication_adherence': medicationAdherence,
      'wearable_daily_summaries': wearableLines,
      'device_measurement_summaries': deviceMeasurementSummaries
          .take(6)
          .toList(),
      'journal_entries': journalEntries,
      'observations': observations,
      'recent_lab_results': recentLabResults.take(6).toList(),
      'recent_imaging_reports': recentImagingReports.take(4).toList(),
      'recent_documents': recentDocumentLines.take(8).toList(),
      'prior_daily_summaries': priorDailySummaries.take(4).toList(),
      'clinical_episodes': clinicalEpisodes,
      'open_alerts': openAlerts
          .take(5)
          .map((item) => '${item.severity}: ${item.title}')
          .toList(),
      'follow_up_reasons': followUpReasons,
      'missing_data': missingData,
      if (profileBundle != null)
        'prevention_recommendations': _preventionLines(
          profileBundle,
          languageCode,
        ),
    };

    return OnDeviceRecapPrompt(
      summaryType: 'daily',
      periodStart: targetDay,
      periodEnd: targetDay,
      systemPrompt: _systemPrompt(languageCode),
      userPrompt: _userPrompt(payload, languageCode),
      providerName: 'on_device_litertlm',
      suggestedModelFamily: 'Gemma 4',
      isCloudBypassedForThisRequest: true,
    );
  }

  Future<OnDeviceTextPrompt?> buildClinicalQuestionPrompt({
    required String question,
    required DateTime referenceDate,
    ClinicalDocumentDetail? focusedDocument,
  }) async {
    final languageCode = await readStoredAppLanguageCode(_localDatabase);
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
      languageCode: languageCode,
    );
    if (context == null && focusedDocument == null) {
      return null;
    }

    final payload = <String, Object?>{
      if (context != null) ...context.payload,
      'task': 'clinical_question',
      'question': question.trim(),
      if (focusedDocument != null)
        'document': _documentPayload(focusedDocument),
      if (focusedDocument != null) 'document_focus': focusedDocument.title,
    };

    final promptReferenceDate =
        focusedDocument?.examDate ??
        focusedDocument?.uploadDate ??
        referenceDate;

    return _buildTextPrompt(
      contextType: 'clinical_question',
      periodStart: context?.periodStart ?? promptReferenceDate,
      periodEnd: context?.periodEnd ?? promptReferenceDate,
      systemPrompt: _assistantSystemPrompt(languageCode),
      userPrompt: _questionUserPrompt(payload, languageCode),
    );
  }

  Future<OnDeviceTextPrompt?> buildTrendExplanationPrompt({
    required DateTime referenceDate,
  }) async {
    final languageCode = await readStoredAppLanguageCode(_localDatabase);
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
      languageCode: languageCode,
    );
    if (context == null) {
      return null;
    }

    final payload = <String, Object?>{
      ...context.payload,
      'task': 'trend_explanation',
    };

    return _buildTextPrompt(
      contextType: 'trend_explanation',
      periodStart: context.periodStart,
      periodEnd: context.periodEnd,
      systemPrompt: _assistantSystemPrompt(languageCode),
      userPrompt: _trendUserPrompt(payload, languageCode),
    );
  }

  Future<OnDeviceTextPrompt?> buildPreVisitBriefPrompt({
    required DateTime referenceDate,
  }) async {
    final languageCode = await readStoredAppLanguageCode(_localDatabase);
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
      languageCode: languageCode,
    );
    if (context == null) {
      return null;
    }

    final payload = <String, Object?>{
      ...context.payload,
      'task': 'pre_visit_brief',
    };

    return _buildTextPrompt(
      contextType: 'pre_visit_brief',
      periodStart: context.periodStart,
      periodEnd: context.periodEnd,
      systemPrompt: _assistantSystemPrompt(languageCode),
      userPrompt: _preVisitUserPrompt(payload, languageCode),
    );
  }

  Future<OnDeviceTextPrompt?> buildDocumentSummaryPrompt({
    required ClinicalDocumentDetail detail,
  }) async {
    final languageCode = await readStoredAppLanguageCode(_localDatabase);
    final referenceDate = detail.examDate ?? detail.uploadDate;
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
      languageCode: languageCode,
    );

    final payload = <String, Object?>{
      'task': 'document_summary',
      'document': _documentPayload(detail),
      if (context != null) ...context.payload,
      'document_focus': detail.title,
    };

    return _buildTextPrompt(
      contextType: 'document_summary',
      periodStart: referenceDate,
      periodEnd: referenceDate,
      systemPrompt: _assistantSystemPrompt(languageCode),
      userPrompt: _documentUserPrompt(payload, languageCode),
    );
  }

  Future<ProfileBundle?> _readProfileBundle() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      'profile_bundle',
    );
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as Map<String, dynamic>;
    return ProfileBundle.fromJson(decoded);
  }

  Future<List<DailyEntry>> _readDailyEntries() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      'daily_entries',
    );
    if (cached == null) {
      return const <DailyEntry>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => DailyEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClinicalAlert>> _readAlerts() async {
    final cached = await readProfileScopedCache(_localDatabase, 'alerts_list');
    if (cached == null) {
      return const <ClinicalAlert>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => ClinicalAlert.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MedicationLogItem>> _readMedicationLogs() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      'medication_logs',
    );
    if (cached == null) {
      return const <MedicationLogItem>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => MedicationLogItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WearableDaySummary>> _readWearableSummaries() async {
    for (final days in const [30, 14, 7]) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        'wearables_recent_$days',
      );
      if (cached == null) {
        continue;
      }
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (item) => WearableDaySummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return const <WearableDaySummary>[];
  }

  Future<List<TimelineEventItem>> _readTimelineEvents() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      'timeline_events',
    );
    if (cached == null) {
      return const <TimelineEventItem>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => TimelineEventItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<HealthDossier?> _readHealthDossier() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      'health_dossier',
    );
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as Map<String, dynamic>;
    return HealthDossier.fromJson(decoded);
  }

  Future<_ClinicalTextContext?> _buildClinicalTextContext({
    required DateTime referenceDate,
    required int lookbackDays,
    required String languageCode,
  }) async {
    final profileBundle = await _readProfileBundle();
    final dossier = await _readHealthDossier();
    final entries = await _readDailyEntries();
    final alerts = await _readAlerts();
    final medicationLogs = await _readMedicationLogs();
    final wearableSummaries = await _readWearableSummaries();
    final timelineEvents = await _readTimelineEvents();

    final periodEnd = _dateOnly(referenceDate);
    final periodStart = _dateOnly(
      referenceDate.subtract(Duration(days: lookbackDays - 1)),
    );

    final entriesForPeriod = [
      ...entries.where(
        (entry) => _isWithinRange(entry.entryDate, periodStart, periodEnd),
      ),
      if (entries
              .where(
                (entry) =>
                    _isWithinRange(entry.entryDate, periodStart, periodEnd),
              )
              .isEmpty &&
          dossier != null)
        ...dossier.recentDailyEntries.where(
          (entry) => _isWithinRange(entry.entryDate, periodStart, periodEnd),
        ),
    ]..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    final logsForPeriod = medicationLogs.where((item) {
      final scheduledDay = _dateOnly(item.scheduledAt);
      return _isWithinRange(scheduledDay, periodStart, periodEnd);
    }).toList();

    final wearablesForPeriod = [
      ...wearableSummaries.where(
        (item) => _isWithinRange(item.summaryDate, periodStart, periodEnd),
      ),
      if (wearableSummaries
              .where(
                (item) =>
                    _isWithinRange(item.summaryDate, periodStart, periodEnd),
              )
              .isEmpty &&
          dossier != null)
        ...dossier.wearableSummaries.where(
          (item) => _isWithinRange(item.summaryDate, periodStart, periodEnd),
        ),
    ];

    final timelineForPeriod =
        timelineEvents
            .where(
              (item) => _isWithinRange(item.eventDate, periodStart, periodEnd),
            )
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    final openAlerts = [
      ...alerts.where((item) => !item.isResolved),
      if (alerts.where((item) => !item.isResolved).isEmpty && dossier != null)
        ...dossier.alerts.where((item) => !item.isResolved),
    ];

    final activeConditions = _mergeStrings(
      profileBundle?.medicalConditions.map((item) => item.name),
      dossier?.medicalConditions.map((item) => item.name),
    );
    final allergies = _mergeStrings(
      profileBundle?.allergies.map((item) => item.allergen),
      dossier?.allergies.map((item) => item.allergen),
    );
    final familyHistory = _mergeStrings(
      profileBundle?.familyHistory.map(
        (item) => '${item.relation}: ${item.conditionName}',
      ),
      dossier?.familyHistory.map(
        (item) => '${item.relation}: ${item.conditionName}',
      ),
    );
    final medications = _mergeStrings(
      profileBundle?.medications
          .where((item) => item.active)
          .map(_medicationLine),
      dossier?.medications.where((item) => item.active).map(_medicationLine),
    );
    final medicationAdherence = logsForPeriod.map(_medicationLogLine).toList();
    final wearableLines = wearablesForPeriod
        .map((item) => item.toDiagnosticText())
        .toList();
    final journalEntries = entriesForPeriod.map(_serializeEntry).toList();
    final observations = _buildWindowObservations(
      entriesForPeriod,
      wearablesForPeriod,
      timelineForPeriod,
    );
    final followUpReasons = _buildWindowFollowUpReasons(
      entriesForPeriod,
      wearablesForPeriod,
      openAlerts,
    );
    final missingData = _buildWindowMissingData(
      entriesForPeriod: entriesForPeriod,
      relevantWearables: wearablesForPeriod,
      relevantLogs: logsForPeriod,
      profileBundle: profileBundle,
      dossier: dossier,
    );
    final deviceMeasurementSummaries =
        dossier?.deviceMeasurementSummaries
            .map((item) => item.summary)
            .toList() ??
        const <String>[];
    final recentLabResults =
        dossier?.recentLabPanels.map(_labPanelLine).toList() ??
        const <String>[];
    final recentImagingReports =
        dossier?.recentImagingReports.map(_imagingReportLine).toList() ??
        const <String>[];
    final recentDocuments =
        dossier?.recentDocuments.map(_documentLine).toList() ??
        const <String>[];
    final priorDailySummaries =
        dossier?.recentInsights
            .where((item) => item.summaryType.toLowerCase() == 'daily')
            .map(_priorDailySummaryLine)
            .toList() ??
        const <String>[];
    final recentReports =
        dossier?.recentReports.map((item) {
          final parts = <String>[item.title];
          if (item.summaryExcerpt != null &&
              item.summaryExcerpt!.trim().isNotEmpty) {
            parts.add(item.summaryExcerpt!.trim());
          }
          return parts.join(' - ');
        }).toList() ??
        const <String>[];
    final clinicalEpisodes = _mergeStrings(
      profileBundle?.clinicalEpisodes.map(_clinicalEpisodeLine),
      dossier?.clinicalEpisodes.map(_clinicalEpisodeLine),
    );

    final dataConsidered = <String>[
      '${entriesForPeriod.length} local check-ins',
      '${entriesForPeriod.fold<int>(0, (total, entry) => total + entry.symptoms.length)} symptoms',
      '${entriesForPeriod.fold<int>(0, (total, entry) => total + entry.vitals.length)} vital signs',
      '${logsForPeriod.length} medication logs',
      '${wearablesForPeriod.length} wearable summaries',
      '${timelineForPeriod.length} timeline events',
      '${openAlerts.length} open alerts',
      '${deviceMeasurementSummaries.length} device summaries',
      '${recentLabResults.length} recent lab panels',
      '${recentImagingReports.length} recent imaging reports',
      '${recentDocuments.length} recent documents/events',
      '${recentReports.length} recent reports',
      '${priorDailySummaries.length} previous recaps',
    ];

    final hasClinicalContext =
        entriesForPeriod.isNotEmpty ||
        wearablesForPeriod.isNotEmpty ||
        deviceMeasurementSummaries.isNotEmpty ||
        recentLabResults.isNotEmpty ||
        recentImagingReports.isNotEmpty ||
        recentDocuments.isNotEmpty ||
        priorDailySummaries.isNotEmpty ||
        recentReports.isNotEmpty;

    if (!hasClinicalContext) {
      return null;
    }

    final patientSnapshot = _patientSnapshot(profileBundle, dossier);

    return _ClinicalTextContext(
      periodStart: periodStart,
      periodEnd: periodEnd,
      payload: <String, Object?>{
        'period_start': periodStart.toIso8601String().split('T').first,
        'period_end': periodEnd.toIso8601String().split('T').first,
        'data_considered': dataConsidered,
        'patient_snapshot': patientSnapshot,
        'active_conditions': activeConditions,
        'allergies': allergies,
        'family_history': familyHistory,
        'medications': medications,
        'medication_adherence': medicationAdherence,
        'wearable_daily_summaries': wearableLines.take(8).toList(),
        'device_measurement_summaries': deviceMeasurementSummaries
            .take(6)
            .toList(),
        'journal_entries': journalEntries.take(10).toList(),
        'observations': observations,
        'recent_lab_results': recentLabResults.take(6).toList(),
        'recent_imaging_reports': recentImagingReports.take(5).toList(),
        'recent_documents': recentDocuments.take(8).toList(),
        'prior_daily_summaries': priorDailySummaries.take(4).toList(),
        'recent_reports': recentReports.take(4).toList(),
        'clinical_episodes': clinicalEpisodes,
        'open_alerts': openAlerts
            .take(5)
            .map((item) => '${item.severity}: ${item.title}')
            .toList(),
        'follow_up_reasons': followUpReasons,
        'missing_data': missingData,
        if (profileBundle != null)
          'prevention_recommendations': _preventionLines(
            profileBundle,
            languageCode,
          ),
      },
    );
  }

  static Map<String, Object?> _documentPayload(ClinicalDocumentDetail detail) {
    return <String, Object?>{
      'id': detail.id,
      'title': detail.title,
      'document_type': detail.documentType,
      'upload_date': detail.uploadDate.toIso8601String(),
      'exam_date': detail.examDate?.toIso8601String(),
      'source': detail.source,
      'original_filename': detail.originalFilename,
      'mime_type': detail.mimeType,
      'file_size_bytes': detail.fileSizeBytes,
      'parsed_status': detail.parsedStatus,
      'context_status': detail.contextStatus,
      'classification_confidence': detail.classificationConfidence,
      'parsing_confidence': detail.parsingConfidence,
      'processing_error': detail.processingError,
      'ocr_text': detail.ocrText,
      'lab_panels': detail.labPanels
          .map(
            (panel) => {
              'id': panel.id,
              'panel_name': panel.panelName,
              'panel_date': panel.panelDate?.toIso8601String(),
              'results': panel.results
                  .map(
                    (result) => {
                      'id': result.id,
                      'analyte_name': result.analyteName,
                      'value': result.value,
                      'unit': result.unit,
                      'ref_min': result.refMin,
                      'ref_max': result.refMax,
                      'abnormal_flag': result.abnormalFlag,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'imaging_reports': detail.imagingReports
          .map(
            (report) => {
              'id': report.id,
              'exam_type': report.examType,
              'body_part': report.bodyPart,
              'report_text': report.reportText,
              'impression': report.impression,
            },
          )
          .toList(),
    };
  }

  static OnDeviceTextPrompt _buildTextPrompt({
    required String contextType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String systemPrompt,
    required String userPrompt,
  }) {
    return OnDeviceTextPrompt(
      contextType: contextType,
      periodStart: periodStart,
      periodEnd: periodEnd,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      providerName: 'on_device_litertlm',
      suggestedModelFamily: 'Gemma 4',
      isCloudBypassedForThisRequest: true,
    );
  }

  static String _assistantSystemPrompt(String languageCode) {
    final preventionGuidance = isItalianLanguageCode(languageCode)
        ? '''
Il payload contiene 'prevention_recommendations' con raccomandazioni deterministiche del Prevention Center (screening, vaccini, esami) calcolate in base a età, sesso e fattori di rischio.
Usa questi dati per rispondere a domande su screening mancanti o raccomandazioni preventive.
Non modificare le raccomandazioni: sono generate da regole deterministiche.
'''
        : '''
The payload includes 'prevention_recommendations' with deterministic Prevention Center recommendations (screenings, vaccines, exams) computed from age, sex and risk factors.
Use this data to answer questions about due or missed screenings and prevention recommendations.
Do not modify the recommendations: they are generated by deterministic rules.
''';
    if (isItalianLanguageCode(languageCode)) {
      return '''
Sei il riepilogatore privato di ClinDiary. Riassumi in modo prudente solo i dati presenti nel payload fornito.
Rispondi in italiano, con un tono calmo e professionale.
Non sei un medico. Non fare diagnosi, non prescrivere, non cambiare farmaci o dosaggi e non fare triage di emergenza.
Non inventare dati mancanti.
Se i dati non bastano, dillo chiaramente.
Evidenzia pattern, incertezze e domande da discutere con un professionista qualificato senza toni allarmistici.
$preventionGuidance
''';
    }
    return '''
You are ClinDiary's private diary summarizer. Summarize only the data present in the provided payload conservatively.
Respond in English, with a calm and professional tone.
You are not a doctor. Do not diagnose, prescribe, change medication or dosage, or provide emergency triage.
Do not invent missing data.
If the data are insufficient, say so clearly.
Highlight patterns, uncertainties, and questions the user may discuss with a qualified clinician without sounding alarmist.
$preventionGuidance
''';
  }

  static String _questionUserPrompt(
    Map<String, Object?> payload,
    String languageCode,
  ) {
    final serialized = jsonEncode(payload);
    if (isItalianLanguageCode(languageCode)) {
      return '''
L'utente sta facendo una domanda sulla propria storia clinica.

Domanda:
${payload['question']}

Rispondi usando questa struttura:
1. Risposta diretta e concisa
2. Cosa osservi nei dati disponibili
3. Limiti dei dati o informazioni mancanti
4. Se utile, 2-3 domande da portare al medico

Restituisci solo il testo finale, senza markdown inutile.

DATI:
$serialized
''';
    }
    return '''
The user is asking a question about their medical history.

Question:
${payload['question']}

Respond using this structure:
1. Direct and concise answer
2. What you observe in the available data
3. Data limits or missing information
4. If useful, 2-3 questions to bring to the doctor

Return only the final text, without unnecessary markdown.

DATA:
$serialized
''';
  }

  static String _trendUserPrompt(
    Map<String, Object?> payload,
    String languageCode,
  ) {
    final serialized = jsonEncode(payload);
    if (isItalianLanguageCode(languageCode)) {
      return '''
Devi spiegare con prudenza l'andamento clinico recente del paziente.

Rispondi usando questa struttura:
1. Andamento generale osservato
2. Pattern o cambiamenti nel tempo
3. Elementi che meritano attenzione o monitoraggio
4. Dati mancanti che limitano l'analisi
5. Nota finale che ricorda che non si tratta di una diagnosi

Non inventare cause. Se vedi solo associazioni deboli, dillo chiaramente.

DATI:
$serialized
''';
    }
    return '''
You must explain the patient's recent clinical trend in a careful way.

Respond using this structure:
1. Overall observed trend
2. Patterns or changes over time
3. Items that deserve attention or monitoring
4. Any missing data that limit the analysis
5. Final note reminding the reader that this is not a diagnosis

Do not invent causes. If you only see weak associations, say so clearly.

DATA:
$serialized
''';
  }

  static String _preVisitUserPrompt(
    Map<String, Object?> payload,
    String languageCode,
  ) {
    final serialized = jsonEncode(payload);
    if (isItalianLanguageCode(languageCode)) {
      return '''
Devi preparare una nota pre-visita da portare al medico.

Rispondi usando questa struttura:
1. Breve sintesi del periodo analizzato
2. Sintomi, cambiamenti e tendenze piu importanti
3. Esami, documenti e terapie rilevanti da portare alla visita
4. 3-5 domande utili da fare al medico
5. Segnali da monitorare prima della visita
6. Nota finale che ricorda che il testo non sostituisce il medico

Mantieni un tono pratico e ordinato.

DATI:
$serialized
''';
    }
    return '''
You must prepare a pre-visit brief to bring to the doctor.

Respond using this structure:
1. Quick summary of the analyzed period
2. Most important symptoms, trends and changes
3. Relevant tests, documents and medications to bring to the visit
4. 3-5 useful questions to ask the doctor
5. Signs to monitor before the visit
6. Final note reminding the reader that the text does not replace the doctor

Keep the tone practical and organized.

DATA:
$serialized
''';
  }

  static String _documentUserPrompt(
    Map<String, Object?> payload,
    String languageCode,
  ) {
    final serialized = jsonEncode(payload);
    if (isItalianLanguageCode(languageCode)) {
      return '''
Devi spiegare questo documento clinico con parole semplici.

Rispondi usando questa struttura:
1. Riassunto semplice del documento
2. Punti chiave o valori rilevanti
3. Cosa puo essere utile per il medico
4. 2-3 domande da fare se qualcosa non e chiaro
5. Nota finale che ricorda che non si tratta di una diagnosi

Se il documento contiene solo dati parziali, dillo chiaramente.

DATI:
$serialized
''';
    }
    return '''
You must explain this clinical document in simple terms.

Respond using this structure:
1. Simple summary of the document
2. Key points or relevant values
3. What is useful for the doctor
4. 2-3 questions to ask if something is unclear
5. Final note reminding the reader that this is not a diagnosis

If the document contains only partial data, say so clearly.

DATA:
$serialized
''';
  }
}

List<String> _patientSnapshot(ProfileBundle? bundle, HealthDossier? dossier) {
  if (bundle == null) {
    if (dossier == null) {
      return const <String>[];
    }
    final snapshot = <String>[dossier.displayName];
    final demographics = <String>[];
    if (dossier.age != null) {
      demographics.add('${dossier.age} years old');
    }
    if (dossier.biologicalSex != null &&
        dossier.biologicalSex!.trim().isNotEmpty) {
      demographics.add('biological sex ${dossier.biologicalSex}');
    }
    if (demographics.isNotEmpty) {
      snapshot[0] = '${dossier.displayName}: ${demographics.join(', ')}';
    }
    snapshot.addAll(
      dossier.profileFacts
          .take(6)
          .map((item) => '${item.label}: ${item.value}'),
    );
    return snapshot;
  }
  final profile = bundle.profile;
  final snapshot = <String>[];
  final demographics = <String>[];
  if (profile.birthDate != null) {
    demographics.add('${_ageFromBirthDate(profile.birthDate!)} years old');
  }
  if (profile.biologicalSex != null &&
      profile.biologicalSex!.trim().isNotEmpty) {
    demographics.add('biological sex ${profile.biologicalSex}');
  }
  if (demographics.isNotEmpty) {
    snapshot.add('${profile.displayName}: ${demographics.join(', ')}');
  } else {
    snapshot.add(profile.displayName);
  }
  snapshot.add(profile.smoker ? 'smoker' : 'non-smoker');
  if (profile.heightCm != null) {
    snapshot.add('height ${profile.heightCm!.toStringAsFixed(0)} cm');
  }
  if (profile.weightKg != null) {
    snapshot.add('weight ${profile.weightKg!.toStringAsFixed(1)} kg');
  }
  if (profile.exerciseHabits != null &&
      profile.exerciseHabits!.trim().isNotEmpty) {
    snapshot.add('usual activity: ${profile.exerciseHabits}');
  }
  if (profile.sleepPattern != null && profile.sleepPattern!.trim().isNotEmpty) {
    snapshot.add('usual sleep pattern: ${profile.sleepPattern}');
  }
  return snapshot;
}

String _medicationLine(MedicationItem item) {
  final parts = <String>[item.name];
  if (item.dosage != null && item.dosage!.trim().isNotEmpty) {
    parts.add(item.dosage!.trim());
  }
  if (item.frequency != null && item.frequency!.trim().isNotEmpty) {
    parts.add(item.frequency!.trim());
  }
  return parts.join(' - ');
}

String _medicationLogLine(MedicationLogItem item) {
  final takenLabel = switch (item.status) {
    'taken' => 'taken',
    'missed' => 'missed',
    'skipped' => 'skipped',
    _ => item.status,
  };
  return '${item.medicationName}: $takenLabel at ${item.scheduledAt.toLocal().toIso8601String().substring(11, 16)}';
}

List<String> _buildObservations(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<TimelineEventItem> timeline,
) {
  final items = <String>[];
  if (entries.isEmpty) {
    items.add('No complete local check-ins are saved for the selected day.');
  } else {
    final symptomLabels = <String, int>{};
    for (final entry in entries) {
      if (entry.energyLevel != null) {
        items.add('Self-reported energy ${entry.energyLevel}/10.');
      }
      if (entry.stressLevel != null) {
        items.add('Self-reported stress ${entry.stressLevel}/10.');
      }
      if (entry.generalPain != null) {
        items.add('General pain ${entry.generalPain}/10.');
      }
      for (final symptom in entry.symptoms) {
        symptomLabels.update(
          symptom.symptomCode.replaceAll('_', ' '),
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      for (final vital in entry.vitals.take(4)) {
        items.add(
          'Vital sign ${vital.type}: ${vital.value}${vital.unit == null ? '' : ' ${vital.unit}'}',
        );
      }
      if (entry.sleepHours != null) {
        items.add(
          'Reported sleep ${entry.sleepHours!.toStringAsFixed(1)} hours.',
        );
      }
    }
    if (symptomLabels.isNotEmpty) {
      final top = symptomLabels.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      items.add(
        'Most common symptoms: ${top.take(4).map((item) => '${item.key} (${item.value})').join(', ')}.',
      );
    }
  }

  for (final wearable in wearables) {
    if (wearable.stepsCount != null) {
      items.add('Wearable: ${wearable.stepsCount} steps.');
    }
    if (wearable.sleepMinutes != null) {
      items.add(
        'Wearable: sleep ${(wearable.sleepMinutes! / 60).toStringAsFixed(1)} hours.',
      );
    }
    if (wearable.heartRateAvgBpm != null) {
      items.add(
        'Wearable: average HR ${wearable.heartRateAvgBpm!.toStringAsFixed(0)} bpm.',
      );
    }
  }

  if (timeline.isNotEmpty) {
    items.add('Day timeline with ${timeline.length} recorded events.');
  }
  return items.take(10).toList();
}

List<String> _buildFollowUpReasons(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<ClinicalAlert> openAlerts,
) {
  final reasons = <String>[];
  final hasHighBurden = entries.any(
    (entry) =>
        (entry.generalPain ?? 0) >= 7 ||
        entry.symptoms.any((symptom) => (symptom.severity ?? 0) >= 7),
  );
  if (hasHighBurden) {
    reasons.add(
      'The selected day shows intense self-reported symptoms or pain: if they persist or worsen, discuss them with the doctor.',
    );
  }
  final veryLowSleep = wearables.any(
    (item) => item.sleepMinutes != null && item.sleepMinutes! < 240,
  );
  if (veryLowSleep) {
    reasons.add(
      'Wearable data show very short sleep on that day: if the pattern continues, it is useful to flag it to the doctor.',
    );
  }
  if (openAlerts.isNotEmpty) {
    reasons.add(
      'There are open deterministic alerts: they should be reported to the doctor without reinterpretation.',
    );
  }
  if (reasons.isEmpty) {
    reasons.add(
      'If symptoms persist, worsen or new relevant signals appear, bring the summary to the doctor.',
    );
  }
  return reasons;
}

List<String> _buildMissingData({
  required List<DailyEntry> entriesForDay,
  required List<WearableDaySummary> relevantWearables,
  required List<MedicationLogItem> relevantLogs,
  required ProfileBundle? profileBundle,
  required HealthDossier? dossier,
}) {
  final missing = <String>[];
  if (profileBundle == null && dossier == null) {
    missing.add('Clinical profile not available in the local cache.');
  }
  if (entriesForDay.isEmpty) {
    missing.add('No local check-ins recorded for the selected day.');
  }
  if (relevantWearables.isEmpty) {
    missing.add('No local wearable data available for the selected day.');
  }
  if (relevantLogs.isEmpty) {
    missing.add('No local medication log available for the selected day.');
  }
  return missing;
}

List<String> _mergeStrings(
  Iterable<String>? primary,
  Iterable<String>? secondary,
) {
  final merged = <String>[];
  for (final collection in [primary, secondary]) {
    if (collection == null) {
      continue;
    }
    for (final item in collection) {
      final normalized = item.trim();
      if (normalized.isEmpty || merged.contains(normalized)) {
        continue;
      }
      merged.add(normalized);
    }
  }
  return merged;
}

Map<String, Object?> _serializeEntry(DailyEntry entry) {
  final noteDigest = _digestText(entry.generalNotes);
  return {
    'date': entry.entryDate.toIso8601String().split('T').first,
    'sleep_hours': entry.sleepHours,
    'sleep_quality': entry.sleepQuality,
    'energy_level': entry.energyLevel,
    'mood_level': entry.moodLevel,
    'stress_level': entry.stressLevel,
    'general_pain': entry.generalPain,
    'general_notes':
        noteDigest.excerpt ??
        (noteDigest.tags.isEmpty
            ? null
            : 'tags: ${noteDigest.tags.join(', ')}'),
    if (noteDigest.tags.isNotEmpty) 'general_note_tags': noteDigest.tags,
    'symptoms': entry.symptoms.map(_serializeSymptom).toList(),
    'vitals': entry.vitals
        .map(
          (item) => {'type': item.type, 'value': item.value, 'unit': item.unit},
        )
        .toList(),
  };
}

Map<String, Object?> _serializeSymptom(SymptomEntry symptom) {
  final metadataDigest = _digestTextFromMetadata(symptom.metadataJson);
  return {
    'code': symptom.symptomCode,
    'severity': symptom.severity,
    'duration_minutes': symptom.durationMinutes,
    'body_location': symptom.bodyLocation,
    if (metadataDigest.flags.isNotEmpty) 'metadata_flags': metadataDigest.flags,
    if (metadataDigest.tags.isNotEmpty) 'note_tags': metadataDigest.tags,
    if (metadataDigest.excerpt != null) 'note_excerpt': metadataDigest.excerpt,
  };
}

_TextDigest _digestText(String? text) {
  final normalized = _normalizeText(text);
  if (normalized == null) {
    return const _TextDigest(tags: []);
  }

  final tags = _noteTags(normalized);
  if (tags.isNotEmpty) {
    return _TextDigest(tags: tags);
  }

  return _TextDigest(tags: const [], excerpt: _truncateText(normalized, 120));
}

_TextDigest _digestTextFromMetadata(Map<String, dynamic> metadataJson) {
  final rawText = _metadataText(metadataJson);
  final normalized = _normalizeText(rawText);
  final tags = _noteTags(normalized);
  final flags = <String>[];

  final temperature = metadataJson['temperature_c'];
  if (temperature is num) {
    flags.add('temperature_c=${temperature.toStringAsFixed(1)}');
  }
  final durationDays = metadataJson['duration_days'];
  if (durationDays is num) {
    flags.add('duration_days=${durationDays.round()}');
  } else if (durationDays is String && durationDays.trim().isNotEmpty) {
    flags.add('duration_days=${durationDays.trim()}');
  }
  for (final key in const ['with_nausea', 'with_aura', 'vomiting']) {
    if (metadataJson[key] == true) {
      flags.add('$key=true');
    }
  }

  return _TextDigest(
    tags: tags,
    flags: flags,
    excerpt: normalized != null && tags.isEmpty
        ? _truncateText(normalized, 80)
        : null,
  );
}

String? _metadataText(Map<String, dynamic> metadataJson) {
  for (final key in const [
    'notes',
    'note',
    'description',
    'comment',
    'text',
    'associated_symptoms',
  ]) {
    final value = metadataJson[key];
    final normalized = _normalizeText(value?.toString());
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}

List<String> _noteTags(String? text) {
  final folded = _foldText(text);
  if (folded.isEmpty) {
    return const [];
  }

  final tags = <String>[];
  void add(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
    }
  }

  const tagPatterns = <String, List<String>>{
    'work_stress': ['stress', 'lavor', 'uffic', 'turno', 'riunion', 'scaden'],
    'low_mood': [
      'giu di morale',
      'trist',
      'umore',
      'ansi',
      'preoccup',
      'demoral',
    ],
    'poor_sleep': ['sonn', 'dorm', 'insonn', 'risvegli', 'riposo'],
    'headache': ['cefale', 'mal di testa', 'headache'],
    'cough': ['toss', 'cough'],
    'fever': ['febbr', 'temperatur'],
    'nausea': ['nause', 'vomit'],
    'pain': ['dolor', 'pain'],
    'digestive': ['addom', 'stomac', 'gastr', 'diarr', 'intestin'],
    'respiratory': ['respir', 'fiat', 'dispn', 'saturaz'],
  };

  for (final entry in tagPatterns.entries) {
    if (entry.value.any(folded.contains)) {
      add(entry.key);
    }
    if (tags.length >= 4) {
      break;
    }
  }

  return tags;
}

String? _normalizeText(String? text) {
  if (text == null) {
    return null;
  }
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return compact.isEmpty ? null : compact;
}

String _foldText(String? text) {
  if (text == null || text.isEmpty) {
    return '';
  }
  final normalized = text
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôõö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'ç'), 'c')
      .replaceAll(RegExp(r'ñ'), 'n')
      .toLowerCase();
  return normalized;
}

String _truncateText(String text, int maxLength) {
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxLength) {
    return compact;
  }
  return '${compact.substring(0, maxLength - 3).trimRight()}...';
}

class _TextDigest {
  const _TextDigest({
    required this.tags,
    this.flags = const <String>[],
    this.excerpt,
  });

  final List<String> tags;
  final List<String> flags;
  final String? excerpt;
}

String _timelineLine(TimelineEventItem item) {
  return '${item.eventDate.toIso8601String().split('T').first} - ${item.title}: ${item.description}';
}

String _clinicalEpisodeLine(ClinicalEpisodeItem item) {
  final parts = <String>[item.title];
  if (item.status != null && item.status!.trim().isNotEmpty) {
    parts.add(item.status!.trim());
  }
  if (item.summary != null && item.summary!.trim().isNotEmpty) {
    parts.add(item.summary!.trim());
  }
  return parts.join(' - ');
}

String _documentLine(DossierDocumentItem item) {
  final parts = <String>[item.documentType, item.title];
  final referenceDate = item.examDate ?? item.uploadDate;
  parts.add(referenceDate.toIso8601String().split('T').first);
  if (item.source != null && item.source!.trim().isNotEmpty) {
    parts.add(item.source!.trim());
  }
  return parts.join(' - ');
}

String _labPanelLine(DossierLabPanelItem item) {
  final parts = <String>[item.panelName];
  if (item.panelDate != null) {
    parts.add(item.panelDate!.toIso8601String().split('T').first);
  }
  if (item.keyResults.isNotEmpty) {
    parts.add(item.keyResults.take(3).join(', '));
  }
  if (item.abnormalResultsCount > 0) {
    parts.add('${item.abnormalResultsCount} out-of-range results');
  }
  return parts.join(' - ');
}

String _imagingReportLine(DossierImagingReportItem item) {
  final parts = <String>[
    if (item.examType != null && item.examType!.trim().isNotEmpty)
      item.examType!.trim(),
    if (item.bodyPart != null && item.bodyPart!.trim().isNotEmpty)
      item.bodyPart!.trim(),
    if (item.documentTitle.trim().isNotEmpty) item.documentTitle.trim(),
  ];
  if (item.examDate != null) {
    parts.add(item.examDate!.toIso8601String().split('T').first);
  }
  if (item.impression != null && item.impression!.trim().isNotEmpty) {
    parts.add(item.impression!.trim());
  }
  return parts.join(' - ');
}

String _priorDailySummaryLine(InsightSummary item) {
  final day = item.periodEnd.toIso8601String().split('T').first;
  final compactContent = item.content.replaceAll(RegExp(r'\s+'), ' ').trim();
  final excerpt = compactContent.length <= 180
      ? compactContent
      : '${compactContent.substring(0, 177)}...';
  return '$day - $excerpt';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

bool _isWithinRange(DateTime value, DateTime start, DateTime end) {
  final day = _dateOnly(value);
  return (day.isAtSameMomentAs(start) || day.isAfter(start)) &&
      (day.isAtSameMomentAs(end) || day.isBefore(end));
}

int _ageFromBirthDate(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final birthdayThisYear = DateTime(now.year, birthDate.month, birthDate.day);
  if (birthdayThisYear.isAfter(now)) {
    age -= 1;
  }
  return age;
}

String _systemPrompt(String languageCode) {
  final preventionGuidance = isItalianLanguageCode(languageCode)
      ? 'Il payload contiene prevention_recommendations con screening e vaccini raccomandati. Usali se l\'utente chiede informazioni preventive.'
      : 'The payload includes prevention_recommendations with recommended screenings and vaccines. Use them if the user asks about prevention.';
  if (isItalianLanguageCode(languageCode)) {
    return 'Segui rigorosamente le istruzioni dell\'utente. Usa solo i dati presenti nel payload JSON e non aggiungere informazioni esterne. $preventionGuidance';
  }
  return "Follow the user's instructions strictly. Use only the data present in the JSON payload and do not add external information. $preventionGuidance";
}

List<String> _preventionLines(ProfileBundle bundle, String languageCode) {
  final engine = PreventionCenterEngine();
  final data = engine.build(bundle);
  final lines = <String>[];

  void addSection(List<PreventionRecommendationItem> items) {
    for (final item in items) {
      final statusIcon = switch (item.status) {
        'recommended' => '✓',
        'review' => '?',
        'shared_decision' => '⟷',
        'seasonal' => '~',
        _ => '·',
      };
      final cadence = item.cadenceLabel ?? '';
      final summary = cadence.isNotEmpty
          ? '$statusIcon ${item.title} ($cadence)'
          : '$statusIcon ${item.title}';
      if (!lines.contains(summary)) {
        lines.add(summary);
      }
    }
  }

  addSection(data.annualExams);
  addSection(data.visitsAndControls);
  addSection(data.vaccines);
  addSection(data.sharedDecisions);
  addSection(data.pregnancyAndPreconception);
  addSection(data.followUpReminders);

  if (lines.isEmpty) {
    if (isItalianLanguageCode(languageCode)) {
      lines.add('Nessuna raccomandazione preventiva disponibile.');
    } else {
      lines.add('No prevention recommendations available.');
    }
  }

  return lines;
}

List<String> _buildWindowObservations(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<TimelineEventItem> timeline,
) {
  final items = <String>[];
  if (entries.isEmpty) {
    items.add('No complete local check-ins are saved for the analyzed period.');
  } else {
    final symptomLabels = <String, int>{};
    for (final entry in entries) {
      if (entry.energyLevel != null) {
        items.add('Self-reported energy ${entry.energyLevel}/10.');
      }
      if (entry.stressLevel != null) {
        items.add('Self-reported stress ${entry.stressLevel}/10.');
      }
      if (entry.generalPain != null) {
        items.add('General pain ${entry.generalPain}/10.');
      }
      for (final symptom in entry.symptoms) {
        symptomLabels.update(
          symptom.symptomCode.replaceAll('_', ' '),
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      for (final vital in entry.vitals.take(4)) {
        items.add(
          'Vital sign ${vital.type}: ${vital.value}${vital.unit == null ? '' : ' ${vital.unit}'}',
        );
      }
      if (entry.sleepHours != null) {
        items.add(
          'Reported sleep ${entry.sleepHours!.toStringAsFixed(1)} hours.',
        );
      }
    }
    if (symptomLabels.isNotEmpty) {
      final top = symptomLabels.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      items.add(
        'Most common symptoms: ${top.take(4).map((item) => '${item.key} (${item.value})').join(', ')}.',
      );
    }
  }

  for (final wearable in wearables) {
    if (wearable.stepsCount != null) {
      items.add('Wearable: ${wearable.stepsCount} steps.');
    }
    if (wearable.sleepMinutes != null) {
      items.add(
        'Wearable: sleep ${(wearable.sleepMinutes! / 60).toStringAsFixed(1)} hours.',
      );
    }
    if (wearable.heartRateAvgBpm != null) {
      items.add(
        'Wearable: average HR ${wearable.heartRateAvgBpm!.toStringAsFixed(0)} bpm.',
      );
    }
  }

  if (timeline.isNotEmpty) {
    items.add('Period timeline with ${timeline.length} recorded events.');
  }
  return items.take(12).toList();
}

List<String> _buildWindowFollowUpReasons(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<ClinicalAlert> openAlerts,
) {
  final reasons = <String>[];
  final hasHighBurden = entries.any(
    (entry) =>
        (entry.generalPain ?? 0) >= 7 ||
        entry.symptoms.any((symptom) => (symptom.severity ?? 0) >= 7),
  );
  if (hasHighBurden) {
    reasons.add(
      'The analyzed period includes intense self-reported symptoms or pain: if they persist or worsen, discuss them with the doctor.',
    );
  }
  final veryLowSleep = wearables.any(
    (item) => item.sleepMinutes != null && item.sleepMinutes! < 240,
  );
  if (veryLowSleep) {
    reasons.add(
      'Wearable data show very short sleep during the period: if the pattern continues, it is useful to flag it to the doctor.',
    );
  }
  if (openAlerts.isNotEmpty) {
    reasons.add(
      'There are open deterministic alerts: they should be reported to the doctor without reinterpretation.',
    );
  }
  if (reasons.isEmpty) {
    reasons.add(
      'If symptoms persist, worsen or new relevant signals appear, bring the summary to the doctor.',
    );
  }
  return reasons;
}

List<String> _buildWindowMissingData({
  required List<DailyEntry> entriesForPeriod,
  required List<WearableDaySummary> relevantWearables,
  required List<MedicationLogItem> relevantLogs,
  required ProfileBundle? profileBundle,
  required HealthDossier? dossier,
}) {
  final missing = <String>[];
  if (profileBundle == null && dossier == null) {
    missing.add('Clinical profile not available in the local cache.');
  }
  if (entriesForPeriod.isEmpty) {
    missing.add('No local check-ins recorded in the analyzed period.');
  }
  if (relevantWearables.isEmpty) {
    missing.add('No local wearable data available in the analyzed period.');
  }
  if (relevantLogs.isEmpty) {
    missing.add('No local medication logs available in the analyzed period.');
  }
  return missing;
}

class _ClinicalTextContext {
  const _ClinicalTextContext({
    required this.periodStart,
    required this.periodEnd,
    required this.payload,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, Object?> payload;
}

String _userPrompt(Map<String, Object?> payload, String languageCode) {
  final serialized = jsonEncode(payload);
  if (isItalianLanguageCode(languageCode)) {
    return "Genera un riepilogo clinico prudente usando SOLO i dati presenti nel payload JSON.\n\n"
        "OBIETTIVO\n"
        "Produrre un riepilogo chiaro, prudente e utile per il paziente e per il medico, evidenziando:\n"
        "- l'andamento nel tempo di sintomi e misurazioni\n"
        "- eventuali pattern o correlazioni osservabili nei dati\n"
        "- esami o documenti recenti rilevanti\n"
        "- situazioni in cui e opportuno parlarne con il medico\n\n"
        "VINCOLI GENERALI\n"
        "- Non inventare dati mancanti\n"
        "- Non fare diagnosi\n"
        "- Non prescrivere\n"
        "- Non attribuire cause certe\n"
        "- Non usare linguaggio allarmistico\n"
        "- Se un dato manca o non e sufficiente, dichiaralo esplicitamente\n"
        "- Se esistono alert aperti, riportali fedelmente senza reinterpretarli\n"
        "- Le correlazioni devono essere descritte solo come osservazioni nei dati, non come causalita\n\n"
        "STRUTTURA RICHIESTA\n"
        "1. Periodo considerato e contesto del paziente\n"
        "2. Andamento osservato nel diario e nei dati registrati\n"
        "3. Eventi o documenti recenti rilevanti\n"
        "4. Quando e perche parlarne con il medico\n"
        "5. Nota finale che ricordi esplicitamente che non si tratta di una diagnosi o prescrizione\n\n"
        "OUTPUT\n"
        "Restituisci solo il riepilogo finale, in italiano, seguendo esattamente la struttura richiesta.\n\n"
        "DATI STRUTTURATI:\n$serialized";
  }
  return "Generate a cautious clinical summary using ONLY the data present in the JSON payload.\n\n"
      "GOAL\n"
      "Produce a clear, cautious and useful summary for the patient and the doctor, highlighting:\n"
      "- the time trend of symptoms and measurements\n"
      "- any patterns or correlations observable in the data\n"
      "- relevant recent tests or documents\n"
      "- situations in which it is appropriate to speak with the doctor\n\n"
      "GENERAL CONSTRAINTS\n"
      "- Do not invent missing data\n"
      "- Do not diagnose\n"
      "- Do not prescribe\n"
      "- Do not attribute certain causes\n"
      "- Do not use alarming language\n"
      "- If a data point is missing or insufficient, state it explicitly\n"
      "- If open alerts exist, report them faithfully without reinterpretation\n"
      "- Correlations must be described only as observations in the data, not as causation\n\n"
      "REQUIRED RESULT STRUCTURE\n"
      "1. Considered period and patient context\n"
      "2. Trend observed in the diary and recorded data\n"
      "3. Relevant recent events or documents\n"
      "4. When and why to speak with the doctor\n"
      "5. Closing note that explicitly reminds the reader that this is not a diagnosis or prescription\n\n"
      "OUTPUT\n"
      "Return only the final summary, in English, following the required structure exactly.\n\n"
      "STRUCTURED DATA:\n$serialized";
}
