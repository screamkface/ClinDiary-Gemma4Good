import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
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
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class OnDevicePromptBuilder {
  OnDevicePromptBuilder({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  Future<OnDeviceRecapPrompt?> buildDailyRecapPrompt({
    required DateTime referenceDate,
  }) async {
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
    final relevantTimeline = timelineEvents
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
        dossier?.deviceMeasurementSummaries.map((item) => item.summary).toList() ??
        const <String>[];
    final recentLabResults =
        dossier?.recentLabPanels.map(_labPanelLine).toList() ?? const <String>[];
    final recentImagingReports =
        dossier?.recentImagingReports.map(_imagingReportLine).toList() ??
        const <String>[];
    final timelineLines = relevantTimeline.map(_timelineLine).toList();
    final structuredDocumentLines =
        dossier?.recentDocuments.map(_documentLine).toList() ?? const <String>[];
    final recentDocumentLines = [
      ...timelineLines,
      ...structuredDocumentLines,
    ];
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
      '${entriesForDay.length} check-up locali',
      '${entriesForDay.fold<int>(0, (total, entry) => total + entry.symptoms.length)} sintomi',
      '${entriesForDay.fold<int>(0, (total, entry) => total + entry.vitals.length)} parametri vitali',
      '${relevantLogs.length} log terapia',
      '${relevantWearables.length} riepiloghi wearable',
      '${relevantTimeline.length} eventi timeline',
      '${openAlerts.length} alert aperti',
      '${deviceMeasurementSummaries.length} sintesi device',
      '${recentLabResults.length} pannelli lab recenti',
      '${recentImagingReports.length} referti imaging recenti',
      '${recentDocumentLines.length} documenti/eventi recenti',
      '${priorDailySummaries.length} recap precedenti',
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
      profileBundle?.medications.where((item) => item.active).map(_medicationLine),
      dossier?.medications.where((item) => item.active).map(_medicationLine),
    );
    final medicationAdherence = relevantLogs.map(_medicationLogLine).toList();
    final wearableLines = relevantWearables.map((item) => item.toDiagnosticText()).toList();
    final journalEntries = entriesForDay.map(_serializeEntry).toList();
    final observations = _buildObservations(entriesForDay, relevantWearables, relevantTimeline);
    final followUpReasons = _buildFollowUpReasons(entriesForDay, relevantWearables, openAlerts);
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
      'summary_label': 'riassunto giornaliero on-device',
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
      'device_measurement_summaries': deviceMeasurementSummaries.take(6).toList(),
      'journal_entries': journalEntries,
      'observations': observations,
      'recent_lab_results': recentLabResults.take(6).toList(),
      'recent_imaging_reports': recentImagingReports.take(4).toList(),
      'recent_documents': recentDocumentLines.take(8).toList(),
      'prior_daily_summaries': priorDailySummaries.take(4).toList(),
      'clinical_episodes': clinicalEpisodes,
      'open_alerts': openAlerts.take(5).map((item) => '${item.severity}: ${item.title}').toList(),
      'follow_up_reasons': followUpReasons,
      'missing_data': missingData,
    };

    return OnDeviceRecapPrompt(
      summaryType: 'daily',
      periodStart: targetDay,
      periodEnd: targetDay,
      systemPrompt: _systemPrompt(),
      userPrompt: _userPrompt(payload),
      providerName: 'on_device_litertlm',
      suggestedModelFamily: 'Gemma 4',
      isCloudBypassedForThisRequest: true,
    );
  }

  Future<OnDeviceTextPrompt?> buildClinicalQuestionPrompt({
    required String question,
    required DateTime referenceDate,
  }) async {
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
    );
    if (context == null) {
      return null;
    }

    final payload = <String, Object?>{
      ...context.payload,
      'task': 'clinical_question',
      'question': question.trim(),
    };

    return _buildTextPrompt(
      contextType: 'clinical_question',
      periodStart: context.periodStart,
      periodEnd: context.periodEnd,
      systemPrompt: _assistantSystemPrompt(),
      userPrompt: _questionUserPrompt(payload),
    );
  }

  Future<OnDeviceTextPrompt?> buildTrendExplanationPrompt({
    required DateTime referenceDate,
  }) async {
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
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
      systemPrompt: _assistantSystemPrompt(),
      userPrompt: _trendUserPrompt(payload),
    );
  }

  Future<OnDeviceTextPrompt?> buildPreVisitBriefPrompt({
    required DateTime referenceDate,
  }) async {
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
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
      systemPrompt: _assistantSystemPrompt(),
      userPrompt: _preVisitUserPrompt(payload),
    );
  }

  Future<OnDeviceTextPrompt?> buildDocumentSummaryPrompt({
    required ClinicalDocumentDetail detail,
  }) async {
    final referenceDate = detail.examDate ?? detail.uploadDate;
    final context = await _buildClinicalTextContext(
      referenceDate: referenceDate,
      lookbackDays: 30,
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
      systemPrompt: _assistantSystemPrompt(),
      userPrompt: _documentUserPrompt(payload),
    );
  }

  Future<ProfileBundle?> _readProfileBundle() async {
    final cached = await readProfileScopedCache(_localDatabase, 'profile_bundle');
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as Map<String, dynamic>;
    return ProfileBundle.fromJson(decoded);
  }

  Future<List<DailyEntry>> _readDailyEntries() async {
    final cached = await readProfileScopedCache(_localDatabase, 'daily_entries');
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
            (item) =>
                WearableDaySummary.fromJson(item as Map<String, dynamic>),
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
    final cached = await readProfileScopedCache(_localDatabase, 'health_dossier');
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as Map<String, dynamic>;
    return HealthDossier.fromJson(decoded);
  }

  Future<_ClinicalTextContext?> _buildClinicalTextContext({
    required DateTime referenceDate,
    required int lookbackDays,
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
      ...entries.where((entry) => _isWithinRange(entry.entryDate, periodStart, periodEnd)),
      if (entries.where((entry) => _isWithinRange(entry.entryDate, periodStart, periodEnd)).isEmpty &&
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
      if (wearableSummaries.where(
            (item) => _isWithinRange(item.summaryDate, periodStart, periodEnd),
          ).isEmpty &&
          dossier != null)
        ...dossier.wearableSummaries.where(
          (item) => _isWithinRange(item.summaryDate, periodStart, periodEnd),
        ),
    ];

    final timelineForPeriod = timelineEvents
        .where((item) => _isWithinRange(item.eventDate, periodStart, periodEnd))
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
      profileBundle?.medications.where((item) => item.active).map(_medicationLine),
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
        dossier?.deviceMeasurementSummaries.map((item) => item.summary).toList() ??
        const <String>[];
    final recentLabResults =
        dossier?.recentLabPanels.map(_labPanelLine).toList() ?? const <String>[];
    final recentImagingReports =
        dossier?.recentImagingReports.map(_imagingReportLine).toList() ??
        const <String>[];
    final recentDocuments =
        dossier?.recentDocuments.map(_documentLine).toList() ?? const <String>[];
    final priorDailySummaries =
        dossier?.recentInsights
            .where((item) => item.summaryType.toLowerCase() == 'daily')
            .map(_priorDailySummaryLine)
            .toList() ??
        const <String>[];
    final recentReports =
        dossier?.recentReports
            .map((item) {
              final parts = <String>[item.title];
              if (item.summaryExcerpt != null && item.summaryExcerpt!.trim().isNotEmpty) {
                parts.add(item.summaryExcerpt!.trim());
              }
              return parts.join(' - ');
            })
            .toList() ??
        const <String>[];
    final clinicalEpisodes = _mergeStrings(
      profileBundle?.clinicalEpisodes.map(_clinicalEpisodeLine),
      dossier?.clinicalEpisodes.map(_clinicalEpisodeLine),
    );

    final dataConsidered = <String>[
      '${entriesForPeriod.length} check-up locali',
      '${entriesForPeriod.fold<int>(0, (total, entry) => total + entry.symptoms.length)} sintomi',
      '${entriesForPeriod.fold<int>(0, (total, entry) => total + entry.vitals.length)} parametri vitali',
      '${logsForPeriod.length} log terapia',
      '${wearablesForPeriod.length} riepiloghi wearable',
      '${timelineForPeriod.length} eventi timeline',
      '${openAlerts.length} alert aperti',
      '${deviceMeasurementSummaries.length} sintesi device',
      '${recentLabResults.length} pannelli lab recenti',
      '${recentImagingReports.length} referti imaging recenti',
      '${recentDocuments.length} documenti/eventi recenti',
      '${recentReports.length} report recenti',
      '${priorDailySummaries.length} recap precedenti',
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
        'device_measurement_summaries': deviceMeasurementSummaries.take(6).toList(),
        'journal_entries': journalEntries.take(10).toList(),
        'observations': observations,
        'recent_lab_results': recentLabResults.take(6).toList(),
        'recent_imaging_reports': recentImagingReports.take(5).toList(),
        'recent_documents': recentDocuments.take(8).toList(),
        'prior_daily_summaries': priorDailySummaries.take(4).toList(),
        'recent_reports': recentReports.take(4).toList(),
        'clinical_episodes': clinicalEpisodes,
        'open_alerts': openAlerts.take(5).map((item) => '${item.severity}: ${item.title}').toList(),
        'follow_up_reasons': followUpReasons,
        'missing_data': missingData,
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

  static String _assistantSystemPrompt() {
    return '''
Sei Gemma 4 dentro ClinDiary.
Usa solo i dati presenti nel payload fornito.
Rispondi in italiano, con tono calmo e professionale.
Non fare diagnosi o prescrizioni.
Non inventare dati mancanti.
Se i dati sono insufficienti, dillo chiaramente.
Se trovi elementi rilevanti, segnala cosa monitorare o discutere con il medico senza allarmismo.
''';
  }

  static String _questionUserPrompt(Map<String, Object?> payload) {
    final serialized = const JsonEncoder.withIndent('  ').convert(payload);
    return '''
L'utente sta facendo una domanda sulla propria storia clinica.

Domanda:
${payload['question']}

Rispondi seguendo questa struttura:
1. Risposta diretta e sintetica
2. Cosa osservi nei dati disponibili
3. Limiti dei dati o informazioni mancanti
4. Se utile, 2-3 domande da portare al medico

Restituisci solo il testo finale, senza markdown superfluo.

DATI:
$serialized
''';
  }

  static String _trendUserPrompt(Map<String, Object?> payload) {
    final serialized = const JsonEncoder.withIndent('  ').convert(payload);
    return '''
Devi spiegare l'andamento clinico recente del paziente in modo prudente.

Rispondi seguendo questa struttura:
1. Andamento generale osservato
2. Pattern o cambiamenti nel tempo
3. Elementi che meritano attenzione o monitoraggio
4. Eventuali dati mancanti che limitano l'analisi
5. Nota finale che ricorda che non e una diagnosi

Non inventare causae. Se vedi solo associazioni deboli, dillo chiaramente.

DATI:
$serialized
''';
  }

  static String _preVisitUserPrompt(Map<String, Object?> payload) {
    final serialized = const JsonEncoder.withIndent('  ').convert(payload);
    return '''
Devi preparare una scheda pre-visita da portare al medico.

Rispondi seguendo questa struttura:
1. Riassunto rapido del periodo analizzato
2. Sintomi, trend e cambiamenti piu importanti
3. Esami, documenti e farmaci rilevanti da portare in visita
4. 3-5 domande utili da fare al medico
5. Segnali da monitorare prima della visita
6. Nota finale che ricorda che il testo non sostituisce il medico

Mantieni il tono pratico e ordinato.

DATI:
$serialized
''';
  }

  static String _documentUserPrompt(Map<String, Object?> payload) {
    final serialized = const JsonEncoder.withIndent('  ').convert(payload);
    return '''
Devi spiegare questo documento clinico in parole semplici.

Rispondi seguendo questa struttura:
1. Riassunto semplice del documento
2. Punti chiave o valori rilevanti
3. Cosa mostra di utile per il medico
4. 2-3 domande da fare se qualcosa non e chiaro
5. Nota finale che ricorda che non e una diagnosi

Se il documento contiene solo dati parziali, dillo chiaramente.

DATI:
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
      demographics.add('${dossier.age} anni');
    }
    if (dossier.biologicalSex != null && dossier.biologicalSex!.trim().isNotEmpty) {
      demographics.add('sesso biologico ${dossier.biologicalSex}');
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
    demographics.add('${_ageFromBirthDate(profile.birthDate!)} anni');
  }
  if (profile.biologicalSex != null && profile.biologicalSex!.trim().isNotEmpty) {
    demographics.add('sesso biologico ${profile.biologicalSex}');
  }
  if (demographics.isNotEmpty) {
    snapshot.add('${profile.displayName}: ${demographics.join(', ')}');
  } else {
    snapshot.add(profile.displayName);
  }
  snapshot.add(profile.smoker ? 'fumatore' : 'non fumatore');
  if (profile.heightCm != null) {
    snapshot.add('altezza ${profile.heightCm!.toStringAsFixed(0)} cm');
  }
  if (profile.weightKg != null) {
    snapshot.add('peso ${profile.weightKg!.toStringAsFixed(1)} kg');
  }
  if (profile.exerciseHabits != null && profile.exerciseHabits!.trim().isNotEmpty) {
    snapshot.add('attivita abituale: ${profile.exerciseHabits}');
  }
  if (profile.sleepPattern != null && profile.sleepPattern!.trim().isNotEmpty) {
    snapshot.add('sonno abituale: ${profile.sleepPattern}');
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
    'taken' => 'assunta',
    'missed' => 'mancata',
    'skipped' => 'saltata',
    _ => item.status,
  };
  return '${item.medicationName}: $takenLabel alle ${item.scheduledAt.toLocal().toIso8601String().substring(11, 16)}';
}

List<String> _buildObservations(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<TimelineEventItem> timeline,
) {
  final items = <String>[];
  if (entries.isEmpty) {
    items.add('Nel giorno selezionato non risultano check-up completi salvati in locale.');
  } else {
    final symptomLabels = <String, int>{};
    for (final entry in entries) {
      if (entry.energyLevel != null) {
        items.add('Energia riferita ${entry.energyLevel}/10.');
      }
      if (entry.stressLevel != null) {
        items.add('Stress riferito ${entry.stressLevel}/10.');
      }
      if (entry.generalPain != null) {
        items.add('Dolore generale ${entry.generalPain}/10.');
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
          'Parametro ${vital.type}: ${vital.value}${vital.unit == null ? '' : ' ${vital.unit}'}',
        );
      }
      if (entry.sleepHours != null) {
        items.add('Sonno riportato ${entry.sleepHours!.toStringAsFixed(1)} ore.');
      }
    }
    if (symptomLabels.isNotEmpty) {
      final top = symptomLabels.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      items.add(
        'Sintomi piu presenti: ${top.take(4).map((item) => '${item.key} (${item.value})').join(', ')}.',
      );
    }
  }

  for (final wearable in wearables) {
    if (wearable.stepsCount != null) {
      items.add('Wearable: ${wearable.stepsCount} passi.');
    }
    if (wearable.sleepMinutes != null) {
      items.add(
        'Wearable: sonno ${(wearable.sleepMinutes! / 60).toStringAsFixed(1)} ore.',
      );
    }
    if (wearable.heartRateAvgBpm != null) {
      items.add('Wearable: FC media ${wearable.heartRateAvgBpm!.toStringAsFixed(0)} bpm.');
    }
  }

  if (timeline.isNotEmpty) {
    items.add(
      'Timeline del giorno con ${timeline.length} eventi registrati.',
    );
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
      'Nel giorno selezionato risultano sintomi o dolore auto-riferiti intensi: se persistono o peggiorano, confrontati con il medico.',
    );
  }
  final veryLowSleep = wearables.any(
    (item) => item.sleepMinutes != null && item.sleepMinutes! < 240,
  );
  if (veryLowSleep) {
    reasons.add(
      'I dati wearable mostrano sonno molto ridotto nella giornata: se il pattern continua, e utile segnalarlo al medico.',
    );
  }
  if (openAlerts.isNotEmpty) {
    reasons.add(
      'Sono presenti alert deterministici aperti: vanno riportati al medico senza reinterpretarli automaticamente.',
    );
  }
  if (reasons.isEmpty) {
    reasons.add(
      'Se i sintomi persistono, peggiorano o compaiono nuovi segnali rilevanti, porta il riepilogo al medico.',
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
    missing.add('Profilo clinico non disponibile nella cache locale.');
  }
  if (entriesForDay.isEmpty) {
    missing.add('Nessun check-up locale registrato per il giorno selezionato.');
  }
  if (relevantWearables.isEmpty) {
    missing.add('Nessun dato wearable locale disponibile per il giorno selezionato.');
  }
  if (relevantLogs.isEmpty) {
    missing.add('Nessun log terapia locale disponibile per il giorno selezionato.');
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
  return {
    'date': entry.entryDate.toIso8601String().split('T').first,
    'sleep_hours': entry.sleepHours,
    'sleep_quality': entry.sleepQuality,
    'energy_level': entry.energyLevel,
    'mood_level': entry.moodLevel,
    'stress_level': entry.stressLevel,
    'general_pain': entry.generalPain,
    'general_notes': entry.generalNotes,
    'symptoms': entry.symptoms
        .map(
          (item) => {
            'code': item.symptomCode,
            'severity': item.severity,
            'duration_minutes': item.durationMinutes,
            'body_location': item.bodyLocation,
          },
        )
        .toList(),
    'vitals': entry.vitals
        .map(
          (item) => {
            'type': item.type,
            'value': item.value,
            'unit': item.unit,
          },
        )
        .toList(),
  };
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
    parts.add('${item.abnormalResultsCount} risultati fuori range');
  }
  return parts.join(' - ');
}

String _imagingReportLine(DossierImagingReportItem item) {
  final parts = <String>[
    if (item.examType != null && item.examType!.trim().isNotEmpty) item.examType!.trim(),
    if (item.bodyPart != null && item.bodyPart!.trim().isNotEmpty) item.bodyPart!.trim(),
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

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;

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

String _systemPrompt() {
  return "Segui rigorosamente le istruzioni dell'utente. Usa esclusivamente i dati presenti nel payload JSON senza aggiungere informazioni esterne.";
}

List<String> _buildWindowObservations(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<TimelineEventItem> timeline,
) {
  final items = <String>[];
  if (entries.isEmpty) {
    items.add('Nel periodo analizzato non risultano check-up locali completi salvati.');
  } else {
    final symptomLabels = <String, int>{};
    for (final entry in entries) {
      if (entry.energyLevel != null) {
        items.add('Energia riferita ${entry.energyLevel}/10.');
      }
      if (entry.stressLevel != null) {
        items.add('Stress riferito ${entry.stressLevel}/10.');
      }
      if (entry.generalPain != null) {
        items.add('Dolore generale ${entry.generalPain}/10.');
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
          'Parametro ${vital.type}: ${vital.value}${vital.unit == null ? '' : ' ${vital.unit}'}',
        );
      }
      if (entry.sleepHours != null) {
        items.add('Sonno riportato ${entry.sleepHours!.toStringAsFixed(1)} ore.');
      }
    }
    if (symptomLabels.isNotEmpty) {
      final top = symptomLabels.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      items.add(
        'Sintomi piu presenti: ${top.take(4).map((item) => '${item.key} (${item.value})').join(', ')}.',
      );
    }
  }

  for (final wearable in wearables) {
    if (wearable.stepsCount != null) {
      items.add('Wearable: ${wearable.stepsCount} passi.');
    }
    if (wearable.sleepMinutes != null) {
      items.add(
        'Wearable: sonno ${(wearable.sleepMinutes! / 60).toStringAsFixed(1)} ore.',
      );
    }
    if (wearable.heartRateAvgBpm != null) {
      items.add('Wearable: FC media ${wearable.heartRateAvgBpm!.toStringAsFixed(0)} bpm.');
    }
  }

  if (timeline.isNotEmpty) {
    items.add('Timeline del periodo con ${timeline.length} eventi registrati.');
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
      'Nel periodo analizzato compaiono sintomi o dolore auto-riferiti intensi: se persistono o peggiorano, confrontati con il medico.',
    );
  }
  final veryLowSleep = wearables.any(
    (item) => item.sleepMinutes != null && item.sleepMinutes! < 240,
  );
  if (veryLowSleep) {
    reasons.add(
      'I dati wearable mostrano sonno molto ridotto nel periodo: se il pattern continua, e utile segnalarlo al medico.',
    );
  }
  if (openAlerts.isNotEmpty) {
    reasons.add(
      'Sono presenti alert deterministici aperti: vanno riportati al medico senza reinterpretarli automaticamente.',
    );
  }
  if (reasons.isEmpty) {
    reasons.add(
      'Se i sintomi persistono, peggiorano o compaiono nuovi segnali rilevanti, porta il riepilogo al medico.',
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
    missing.add('Profilo clinico non disponibile nella cache locale.');
  }
  if (entriesForPeriod.isEmpty) {
    missing.add('Nessun check-up locale registrato nel periodo analizzato.');
  }
  if (relevantWearables.isEmpty) {
    missing.add('Nessun dato wearable locale disponibile nel periodo analizzato.');
  }
  if (relevantLogs.isEmpty) {
    missing.add('Nessun log terapia locale disponibile nel periodo analizzato.');
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

String _userPrompt(Map<String, Object?> payload) {
  final serialized = const JsonEncoder.withIndent('  ').convert(payload);
  return "Genera un riepilogo clinico prudente usando ESCLUSIVAMENTE i dati presenti nel payload JSON.\n\n"
      "OBIETTIVO\n"
      "Produrre un riepilogo chiaro, prudente e utile per il paziente e per il medico, evidenziando:\n"
      "- andamento temporale dei sintomi e dei parametri\n"
      "- eventuali pattern o correlazioni osservabili nei dati\n"
      "- esami o documenti recenti rilevanti\n"
      "- condizioni in cui e opportuno parlare con il medico\n\n"
      "VINCOLI GENERALI\n"
      "- Non inventare dati mancanti\n"
      "- Non formulare diagnosi\n"
      "- Non formulare prescrizioni\n"
      "- Non attribuire cause certe\n"
      "- Non usare linguaggio allarmistico\n"
      "- Se un dato non e presente o non e sufficiente, dichiararlo esplicitamente\n"
      "- Se esistono alert aperti, riportali fedelmente senza reinterpretarli\n"
      "- Le correlazioni devono essere descritte solo come osservazioni nei dati, non come causalita\n\n"
      "STRUTTURA OBBLIGATORIA DEL RISULTATO\n"
      "1. Periodo considerato e contesto del paziente\n"
      "2. Andamento osservato nel diario e nei dati registrati\n"
      "3. Eventi o documenti recenti rilevanti\n"
      "4. Quando e perche parlare con il medico\n"
      "5. Chiusura che ricorda esplicitamente che il testo non e una diagnosi o prescrizione\n\n"
      "OUTPUT\n"
      "Restituisci solo il riepilogo finale, in italiano, seguendo esattamente la struttura obbligatoria.\n\n"
      "DATI STRUTTURATI:\n$serialized";
}
