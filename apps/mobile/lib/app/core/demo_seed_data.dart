import 'dart:convert';

import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart' hide DailyEntry;
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/billing/domain/billing_status.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/features/devices/domain/device_hub.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/history/domain/history_day.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/local_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_record.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/screenings/domain/screening.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';

class DemoSeedData {
  static const String demoUserId = 'demo-user-001';
  static const String primaryProfileId = 'profile-1';
  static const String childManagedProfileId = 'profile-2';
  static const String seniorManagedProfileId = 'profile-3';

  static const List<String> _demoProfileIds = [
    primaryProfileId,
    childManagedProfileId,
    seniorManagedProfileId,
  ];

  static const String _seedVersionKey = 'demo_seed_version';
  static const String _seedVersion = '2026-05-hackathon-v1';

  static AuthSession createDemoSession() {
    final now = DateTime.now().toUtc();
    return AuthSession(
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
      accessTokenExpiresAt: now.add(const Duration(days: 30)),
      refreshTokenExpiresAt: now.add(const Duration(days: 3650)),
      user: const UserSummary(
        id: demoUserId,
        email: 'demo@clindiary.app',
        role: 'patient',
        onboardingCompleted: true,
        healthDataConsent: true,
        aiExternalConsent: true,
        authProvider: 'demo',
      ),
    );
  }

  static Future<void> ensureSeeded(
    LocalDatabase database, {
    LocalDocumentVaultService? localDocumentVaultService,
  }) async {
    final currentVersion = await database.readCache(_seedVersionKey);
    if (currentVersion == _seedVersion) {
      return;
    }

    await database.putCache(key: activeUserIdCacheKey, payload: demoUserId);
    await database.putCache(
      key: activeProfileIdCacheKey,
      payload: primaryProfileId,
    );

    for (final profileId in _demoProfileIds) {
      await _seedProfileCaches(
        database,
        profileId,
        includeLegacyProfileBundle: profileId == primaryProfileId,
      );
    }

    final allNotifications = _demoProfileIds
        .expand(_notificationsJsonForProfile)
        .toList(growable: false);
    await database.putCache(
      key: 'family_notifications_list',
      payload: jsonEncode(allNotifications),
    );

    if (localDocumentVaultService != null) {
      await _seedLocalRagReports(localDocumentVaultService);
    }

    await database.putCache(key: 'document_storage_mode', payload: 'local');
    await database.putCache(key: _seedVersionKey, payload: _seedVersion);
  }

  static Future<void> resetAndReseed(
    LocalDatabase database, {
    LocalDocumentVaultService? localDocumentVaultService,
  }) async {
    await database.removeCache(_seedVersionKey);
    await ensureSeeded(
      database,
      localDocumentVaultService: localDocumentVaultService,
    );
  }

  static Future<void> _seedLocalRagReports(
    LocalDocumentVaultService localDocumentVaultService,
  ) async {
    try {
      await localDocumentVaultService.deleteAllForUserScope(demoUserId);

      for (final profileId in _demoProfileIds) {
        final reports = _localRagReportTemplates(profileId);
        for (var index = 0; index < reports.length; index++) {
          final report = reports[index];
          final textContent = report['content']!.trim();
          await localDocumentVaultService.uploadDocumentForScope(
            userScopeId: demoUserId,
            profileScopeId: profileId,
            file: SelectedUploadDocument(
              name: 'report-${profileId.replaceAll('_', '-')}-${index + 1}.txt',
              bytes: utf8.encode(textContent),
              mimeType: 'text/plain',
            ),
            fields: {
              'title': report['title']!,
              'document_type': report['document_type']!,
              'source': report['source']!,
              'exam_date': report['exam_date']!,
              // Keep a lightweight extracted text to make local RAG answers meaningful.
              'ocr_text': textContent,
            },
          );
        }
      }
    } catch (_) {
      // Keep demo boot resilient even if local file system seeding fails.
    }
  }

  static List<Map<String, String>> _localRagReportTemplates(String profileId) {
    switch (profileId) {
      case primaryProfileId:
        return const [
          {
            'title': 'May 2026 metabolic panel',
            'document_type': 'lab_report',
            'source': 'Milan Community Clinic',
            'exam_date': '2026-05-16',
            'content':
                'Patient: Marco Rossi\nMay 2026 metabolic panel\nCreatinine: 1.29 mg/dL (reference 0.67-1.17) [ABNORMAL]\neGFR: 71 mL/min/1.73m2 (reference > 90) [ABNORMAL]\nPotassium: 5.1 mmol/L (reference 3.5-5.0) [ABNORMAL]\nSodium: 139 mmol/L (reference 136-145)\nAST: 24 U/L (reference 0-40)\nALT: 27 U/L (reference 0-41)\nComment: Mild kidney marker variation compared with prior local report. Hydration and clinician discussion recommended.',
          },
          {
            'title': 'May 2026 lipid and glucose follow-up',
            'document_type': 'lab_report',
            'source': 'Milan Community Clinic',
            'exam_date': '2026-05-19',
            'content':
                'Patient: Marco Rossi\nMay 2026 lipid and glucose follow-up\nLDL cholesterol: 142 mg/dL (reference < 115) [ABNORMAL]\nHDL cholesterol: 47 mg/dL (reference > 40)\nTriglycerides: 168 mg/dL (reference < 150) [ABNORMAL]\nHbA1c: 5.8 % (reference 4.0-5.6) [ABNORMAL]\nFasting glucose: 103 mg/dL (reference 70-99) [ABNORMAL]\nComment: Borderline metabolic values. Review lifestyle measures and discuss follow-up timing with clinician.',
          },
          {
            'title': 'May 2026 blood pressure diary note',
            'document_type': 'clinical_note',
            'source': 'ClinDiary local note',
            'exam_date': '2026-05-10',
            'content':
                'May 2026 blood pressure diary note\nHome readings from May 6 to May 10: 134/86, 136/88, 135/84, 132/83, 131/82.\nContext: early month stress, poor sleep, and irregular hydration.\nPatient note: walked more on May 8 and May 9 and felt calmer afterwards.\nPlan for discussion: ask whether the home pattern is worth repeating or reviewing at the next visit.',
          },
          {
            'title': 'May 2026 allergy / inflammation check',
            'document_type': 'lab_report',
            'source': 'Poliambulatorio San Marco',
            'exam_date': '2026-05-22',
            'content':
                'Patient: Marco Rossi\nMay 2026 allergy / inflammation check\nEosinophils: 6.8 % (reference 0.0-6.0) [ABNORMAL]\nhs-CRP: 3.6 mg/L (reference < 3.0) [ABNORMAL]\nHemoglobin: 14.5 g/dL (reference 13.5-17.5)\nComment: Mild seasonal allergy and inflammation signal. Review together with symptoms, not as a diagnosis.',
          },
          {
            'title': 'May 2026 pre-visit summary note',
            'document_type': 'clinical_note',
            'source': 'ClinDiary local note',
            'exam_date': '2026-05-29',
            'content':
                'May 2026 pre-visit summary note\nTopics to discuss with clinician:\n1. Are creatinine and eGFR changes worth repeating soon?\n2. How should LDL, triglycerides, HbA1c, and fasting glucose be reviewed in context?\n3. Do the higher home blood pressure readings from May 6 to May 10 change the monitoring plan?\n4. Which values should be watched again before the next follow-up?\nPatient goal: leave the visit with a clear monitoring plan, not a diagnosis.',
          },
        ];
      case childManagedProfileId:
        return const [
          {
            'title': 'Pediatric CBC and ferritin - Apr 2026',
            'document_type': 'lab_report',
            'source': 'Pediatric Care Unit Milano',
            'exam_date': '2026-04-08',
            'content':
                'Patient: Giulia Rossi\nHemoglobin: 11.9 g/dL (reference 12.0-15.5) [OUT OF RANGE - low]\nFerritin: 14 ng/mL (reference 15-120) [OUT OF RANGE - low]\nEosinophils: 8.2% (reference 0-6) [OUT OF RANGE - high]\nComment: Findings coherent with allergic season and low iron stores. Recheck ferritin after nutritional intervention.',
          },
          {
            'title': 'Allergy panel and IgE - Mar 2026',
            'document_type': 'lab_report',
            'source': 'Pediatric Care Unit Milano',
            'exam_date': '2026-03-16',
            'content':
                'Patient: Giulia Rossi\nTotal IgE: 198 IU/mL (reference < 100) [OUT OF RANGE - high]\nAbsolute eosinophils: 0.62 x10^9/L (reference 0.05-0.45) [OUT OF RANGE - high]\nSpecific reactivity: grass pollen positive\nComment: Seasonal allergic rhinitis profile confirmed; values slightly higher than previous year peak.',
          },
          {
            'title': 'Vitamin D and iron status - Jan 2026',
            'document_type': 'lab_report',
            'source': 'Pediatric Care Unit Milano',
            'exam_date': '2026-01-21',
            'content':
                'Patient: Giulia Rossi\n25-OH Vitamin D: 22 ng/mL (reference 30-100) [OUT OF RANGE - low]\nTransferrin saturation: 15% (reference 20-45) [OUT OF RANGE - low]\nMCV: 78 fL (reference 80-96) [OUT OF RANGE - low]\nComment: Continue vitamin D3 1000 IU daily and iron-rich diet per pediatric plan.',
          },
          {
            'title': 'Previous CBC baseline - Nov 2025',
            'document_type': 'lab_report',
            'source': 'Pediatric Care Unit Milano',
            'exam_date': '2025-11-19',
            'content':
                'Patient: Giulia Rossi\nHemoglobin: 11.8 g/dL (reference 12.0-15.5) [OUT OF RANGE - low]\nFerritin: 16 ng/mL (reference 15-120)\nTotal IgE: 164 IU/mL (reference < 100) [OUT OF RANGE - high]\nComment: Baseline report showing persistent allergy signal and early iron depletion trend.',
          },
        ];
      case seniorManagedProfileId:
      default:
        return const [
          {
            'title': 'Renal and thyroid function - Apr 2026',
            'document_type': 'lab_report',
            'source': 'Centro Clinico San Carlo',
            'exam_date': '2026-04-11',
            'content':
                'Patient: Luisa Rossi\nCreatinine: 1.37 mg/dL (reference 0.60-1.10) [OUT OF RANGE - high]\neGFR: 48 mL/min/1.73m2 (reference > 60) [OUT OF RANGE - low]\nTSH: 6.1 mIU/L (reference 0.40-4.00) [OUT OF RANGE - high]\nComment: CKD stage 3 trend confirmed with persistent suboptimal thyroid control.',
          },
          {
            'title': 'HbA1c and glucose follow-up - Mar 2026',
            'document_type': 'lab_report',
            'source': 'Centro Clinico San Carlo',
            'exam_date': '2026-03-20',
            'content':
                'Patient: Luisa Rossi\nHbA1c: 6.6% (reference < 5.7) [OUT OF RANGE - high]\nFasting glucose: 126 mg/dL (reference 70-99) [OUT OF RANGE - high]\nPost-prandial glucose: 189 mg/dL (reference < 140) [OUT OF RANGE - high]\nComment: Dysglycemia worsened versus Jan 2026; diabetic threshold reached, treatment plan review advised.',
          },
          {
            'title': 'Lipid and renal microalbumin trend - Jan 2026',
            'document_type': 'lab_report',
            'source': 'Centro Clinico San Carlo',
            'exam_date': '2026-01-18',
            'content':
                'Patient: Luisa Rossi\nLDL cholesterol: 146 mg/dL (target < 100) [OUT OF RANGE - high]\nUrine albumin/creatinine ratio: 46 mg/g (reference < 30) [OUT OF RANGE - high]\nPotassium: 5.3 mmol/L (reference 3.5-5.1) [OUT OF RANGE - high]\nComment: Combined cardio-renal risk remains elevated; continue close monitoring.',
          },
          {
            'title': 'Thyroid baseline trend - Oct 2025',
            'document_type': 'lab_report',
            'source': 'Endocrinology Ambulatory Unit',
            'exam_date': '2025-10-22',
            'content':
                'Patient: Luisa Rossi\nTSH: 5.4 mIU/L (reference 0.40-4.00) [OUT OF RANGE - high]\nFree T4: 0.79 ng/dL (reference 0.80-1.80) [OUT OF RANGE - low]\nCreatinine: 1.29 mg/dL (reference 0.60-1.10) [OUT OF RANGE - high]\nComment: Historical baseline confirming long-standing thyroid and renal trend now seen in 2026 reports.',
          },
        ];
    }
  }

  static Future<void> _seedProfileCaches(
    LocalDatabase database,
    String profileId, {
    bool includeLegacyProfileBundle = false,
  }) async {
    final profileBundle = _profileBundleJsonForProfile(profileId);
    if (includeLegacyProfileBundle) {
      await database.putCache(
        key: 'profile_bundle',
        payload: jsonEncode(profileBundle),
      );
    }

    await database.putCache(
      key: _scopedFor('profile_bundle', profileId),
      payload: jsonEncode(profileBundle),
    );

    final dailyEntries = _dailyEntriesJsonForProfile(profileId);
    await database.putCache(
      key: _scopedFor('daily_entries', profileId),
      payload: jsonEncode(dailyEntries),
    );

    final alerts = _alertsJsonForProfile(profileId);
    await database.putCache(
      key: _scopedFor('alerts_list', profileId),
      payload: jsonEncode(alerts),
    );

    final timeline = _timelineJsonForProfile(profileId);
    await database.putCache(
      key: _scopedFor('timeline_events', profileId),
      payload: jsonEncode(timeline),
    );

    await database.putCache(
      key: _scopedFor('notifications_preferences', profileId),
      payload: jsonEncode(_notificationPreferencesJsonForProfile(profileId)),
    );

    await database.putCache(
      key: _scopedFor('medication_logs', profileId),
      payload: jsonEncode(_medicationLogsJsonForProfile(profileId)),
    );

    final wearables = _wearableSummariesJsonForProfile(profileId);
    await database.putCache(
      key: _scopedFor('wearables_recent_30', profileId),
      payload: jsonEncode(wearables),
    );
    await database.putCache(
      key: _scopedFor('wearables_recent_14', profileId),
      payload: jsonEncode(wearables.take(14).toList(growable: false)),
    );
    await database.putCache(
      key: _scopedFor('wearables_recent_7', profileId),
      payload: jsonEncode(wearables.take(7).toList(growable: false)),
    );

    final docs = _documentsJsonForProfile(profileId);
    await database.putCache(
      key: _scopedFor('documents_list', profileId),
      payload: jsonEncode(docs),
    );

    for (final doc in docs) {
      await database.putCache(
        key: _scopedFor('document_detail_${doc['id']}', profileId),
        payload: jsonEncode(
          _documentDetailJsonForProfile(profileId, doc['id'].toString()),
        ),
      );
    }

    final monthStart = _demoMonthStartUtc();
    final monthEnd = _demoMonthEndUtc();

    await database.putCache(
      key: _scopedFor(
        'history_activity_${_date(monthStart)}_${_date(monthEnd)}',
        profileId,
      ),
      payload: jsonEncode(
        _historyActivityJsonForProfile(profileId, monthStart, monthEnd),
      ),
    );

    for (final entry in dailyEntries) {
      final day = entry['entry_date'].toString();
      await database.putCache(
        key: _scopedFor('history_day_base_$day', profileId),
        payload: jsonEncode(
          _historyDayJsonForProfile(profileId, DateTime.parse(day)),
        ),
      );
      await database.putCache(
        key: _scopedFor('history_day_rollups_$day', profileId),
        payload: jsonEncode(
          _historyDayJsonForProfile(
            profileId,
            DateTime.parse(day),
            includeRollups: true,
          ),
        ),
      );
    }

    await database.putCache(
      key: _scopedFor('insight_daily_default_latest', profileId),
      payload: jsonEncode(
        _insightJsonForProfile(profileId, summaryType: 'daily'),
      ),
    );
    await database.putCache(
      key: _scopedFor('insight_weekly_default_latest', profileId),
      payload: jsonEncode(
        _insightJsonForProfile(profileId, summaryType: 'weekly'),
      ),
    );
    await database.putCache(
      key: _scopedFor('insight_monthly_default_latest', profileId),
      payload: jsonEncode(
        _insightJsonForProfile(profileId, summaryType: 'monthly'),
      ),
    );
    await database.putCache(
      key: _scopedFor('insight_daily_on_device_latest', profileId),
      payload: jsonEncode(
        _insightJsonForProfile(
          profileId,
          summaryType: 'daily',
          provider: 'on_device_litertlm',
        ),
      ),
    );

    const region = 'IT';
    await database.putCache(
      key: _scopedFor('screenings_catalog::$region', profileId),
      payload: jsonEncode(_screeningCatalogJsonForProfile(profileId)),
    );
    await database.putCache(
      key: _scopedFor('screenings_me::$region', profileId),
      payload: jsonEncode(_myScreeningsJsonForProfile(profileId)),
    );
    await database.putCache(
      key: _scopedFor('prevention_center::$region', profileId),
      payload: jsonEncode(_preventionCenterJsonForProfile(profileId)),
    );

    await database.putCache(
      key: _scopedFor('health_dossier', profileId),
      payload: jsonEncode(_healthDossierJsonForProfile(profileId)),
    );

    await database.putCache(
      key: _scopedFor('reports_last_generated', profileId),
      payload: jsonEncode(_latestReportJsonForProfile(profileId)),
    );

    await database.putCache(
      key: _scopedFor('dossier_share_links', profileId),
      payload: jsonEncode(_dossierShareLinksJsonForProfile(profileId)),
    );

    await database.putCache(
      key: _scopedFor('gemma_center_history', profileId),
      payload: jsonEncode(_gemmaCenterHistoryJsonForProfile(profileId)),
    );

    await database.putCache(
      key: _scopedFor('document_query_history', profileId),
      payload: jsonEncode(_documentQueryHistoryJsonForProfile(profileId)),
    );
  }

  static ProfileBundle demoProfileBundle() {
    return ProfileBundle.fromJson(_profileBundleJson());
  }

  static List<DailyEntry> demoDailyEntries() {
    return _dailyEntriesJson()
        .map((item) => DailyEntry.fromJson(item))
        .toList(growable: false);
  }

  static List<DailyEntry> demoDailyEntriesForMay2026() => demoDailyEntries();

  static BillingStatus demoBillingStatus() {
    return BillingStatus.fromJson(_billingStatusJson());
  }

  static DeviceOverview demoDeviceOverview() {
    return DeviceOverview.fromJson(_deviceOverviewJson());
  }

  static InsightSummary demoInsightSummary(InsightSummaryQuery query) {
    return InsightSummary.fromJson(
      _insightJson(
        summaryType: query.summaryType,
        referenceDate: query.referenceDate,
      ),
    );
  }

  static LocalAiStatus demoLocalAiStatus() {
    return LocalAiStatus.fromJson(_localAiStatusJson());
  }

  static OnDeviceAiStatus demoOnDeviceAiStatus() {
    return OnDeviceAiStatus.fromJson(_onDeviceAiStatusJson());
  }

  static HistoryDay demoHistoryDay(DateTime targetDate) {
    return HistoryDay.fromJson(_historyDayJson(targetDate));
  }

  static List<DateTime> demoHistoryActivityDates(DateTime monthAnchor) {
    final monthStart = DateTime(monthAnchor.year, monthAnchor.month, 1);
    final nextMonth = monthAnchor.month == 12
        ? DateTime(monthAnchor.year + 1, 1, 1)
        : DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
    final monthEnd = nextMonth.subtract(const Duration(days: 1));
    final payload = _historyActivityJson(monthStart, monthEnd);
    return (payload['activity_dates'] as List<dynamic>)
        .map((item) => DateTime.parse(item.toString()))
        .toList(growable: false);
  }

  static List<ClinicalAlert> demoAlerts() {
    return _alertsJson()
        .map((item) => ClinicalAlert.fromJson(item))
        .toList(growable: false);
  }

  static List<ScreeningCatalogItem> demoScreeningCatalog() {
    return _screeningCatalogJson()
        .map((item) => ScreeningCatalogItem.fromJson(item))
        .toList(growable: false);
  }

  static List<PatientScreeningStatusItem> demoMyScreenings() {
    return _myScreeningsJson()
        .map((item) => PatientScreeningStatusItem.fromJson(item))
        .toList(growable: false);
  }

  static PreventionCenterData demoPreventionCenter() {
    return PreventionCenterData.fromJson(_preventionCenterJson());
  }

  static HealthDossier demoHealthDossier() {
    return HealthDossier.fromJson(_healthDossierJson());
  }

  static List<DossierShareLinkItem> demoDossierShareLinks() {
    return _dossierShareLinksJson()
        .map((item) => DossierShareLinkItem.fromJson(item))
        .toList(growable: false);
  }

  static List<MedicationLogItem> demoMedicationLogs() {
    return _medicationLogsJson()
        .map((item) => MedicationLogItem.fromJson(item))
        .toList(growable: false);
  }

  static List<MedicationLogItem> demoMedicationLogsForMay2026() =>
      demoMedicationLogs();

  static List<AppNotificationItem> demoNotifications() {
    return _notificationsJson()
        .map((item) => AppNotificationItem.fromJson(item))
        .toList(growable: false);
  }

  static List<AppNotificationItem> demoNotificationsForMay2026() =>
      demoNotifications();

  static NotificationPreferences demoNotificationPreferences() {
    return NotificationPreferences.fromJson(_notificationPreferencesJson());
  }

  static WearableSyncStatus demoWearableSyncStatus() {
    return const WearableSyncStatus(
      isSupported: true,
      platformLabel: 'android',
      providerName: 'Health Connect',
      isAvailable: true,
      permissionGranted: true,
      canInstallProvider: false,
      historyAccessGranted: true,
      healthPermissionsGranted: true,
      activityRecognitionGranted: true,
      message: 'Demo mode: wearable provider simulated',
    );
  }

  static List<WearableDaySummary> demoWearableSummaries() {
    return _wearableSummariesJson()
        .map((item) => WearableDaySummary.fromJson(item))
        .toList(growable: false);
  }

  static List<WearableDaySummary> demoWearableSummariesForMay2026() =>
      demoWearableSummaries();

  static List<TimelineEventItem> demoTimelineEvents() {
    return _timelineJson()
        .map((item) => TimelineEventItem.fromJson(item))
        .toList(growable: false);
  }

  static List<TimelineEventItem> demoTimelineEventsForMay2026() =>
      demoTimelineEvents();

  static List<ClinicalDocumentSummary> demoDocuments() {
    return _documentsJson()
        .map((item) => ClinicalDocumentSummary.fromJson(item))
        .toList(growable: false);
  }

  static List<ClinicalDocumentSummary> demoDocumentsForMay2026() =>
      demoDocuments();

  static DocumentArchiveView demoDocumentArchive({
    String? folderId,
    String? query,
  }) {
    final allDocs = _documentsJson();
    final normalizedQuery = query?.trim().toLowerCase();
    final filtered = normalizedQuery == null || normalizedQuery.isEmpty
        ? allDocs
        : allDocs
              .where((doc) {
                final text = [
                  doc['title'],
                  doc['original_filename'],
                  doc['document_type'],
                  doc['source'],
                ].whereType<String>().join(' ').toLowerCase();
                return text.contains(normalizedQuery);
              })
              .toList(growable: false);

    final archiveMap = <String, dynamic>{
      'current_folder': folderId == null
          ? null
          : {
              'id': folderId,
              'name': 'Clinical Archive',
              'parent_folder_id': null,
              'path_label': 'Clinical Archive',
              'child_folder_count': 2,
              'document_count': filtered.length,
            },
      'breadcrumbs': <Map<String, dynamic>>[],
      'folders': _documentFoldersJson(),
      'documents': filtered,
      'legacy_cloud_documents': <Map<String, dynamic>>[],
      'query': query,
      'is_search': normalizedQuery != null && normalizedQuery.isNotEmpty,
      'storage_location': 'local',
    };

    return DocumentArchiveView.fromJson(archiveMap);
  }

  static List<DocumentFolderItem> demoDocumentFolders() {
    return _documentFoldersJson()
        .map((item) => DocumentFolderItem.fromJson(item))
        .toList(growable: false);
  }

  static ClinicalDocumentDetail demoDocumentDetail(String documentId) {
    return ClinicalDocumentDetail.fromJson(_documentDetailJson(documentId));
  }

  static ClinicalDocumentDetail demoDocumentDetailForMay2026(
    String documentId,
  ) {
    return demoDocumentDetail(documentId);
  }

  static List<PreventionRecord> demoPreventionRecordsForMay2026() {
    return _preventionRecordsJson()
        .map((item) => PreventionRecord.fromJson(item))
        .toList(growable: false);
  }

  static String _scopedFor(String baseKey, String profileId) {
    return scopedCacheKey(baseKey, profileId);
  }

  static String _date(DateTime date) => date.toIso8601String().split('T').first;

  static DateTime _demoMonthStartUtc() => DateTime.utc(2026, 5, 1);

  static DateTime _demoMonthEndUtc() => DateTime.utc(2026, 5, 31);

  static DateTime _demoDateUtc(int day, [int hour = 0, int minute = 0]) {
    return DateTime.utc(2026, 5, day, hour, minute);
  }

  static DateTime _demoGeneratedAtUtc() => _demoDateUtc(31, 18);

  static String _isoDay(int day) => _date(_demoDateUtc(day));

  static String _isoAt(int day, int hour, int minute) =>
      _demoDateUtc(day, hour, minute).toIso8601String();

  static List<Map<String, dynamic>> _preventionRecordsJson() {
    return [
      {
        'code': 'blood_pressure_review',
        'performed_at': _isoAt(10, 18, 0),
        'result_summary':
            'Home blood pressure diary reviewed before follow-up discussion.',
        'source_id': 'doc-bp-note-may-2026',
      },
      {
        'code': 'metabolic_panel_follow_up',
        'performed_at': _isoAt(16, 11, 30),
        'result_summary': 'Metabolic panel added locally for clinician review.',
        'source_id': 'doc-metabolic-may-2026',
      },
      {
        'code': 'pre_visit_preparation',
        'performed_at': _isoAt(29, 20, 15),
        'result_summary': 'Questions prepared for upcoming clinician visit.',
        'source_id': 'doc-previsit-may-2026',
      },
    ];
  }

  static List<Map<String, dynamic>> _dailyEntriesJson() {
    final rows = [
      {
        'day': 1,
        'sleep_hours': 6.1,
        'sleep_quality': 5,
        'energy_level': 4,
        'mood_level': 5,
        'stress_level': 7,
        'appetite_level': 6,
        'hydration_level': 5,
        'general_pain': 2,
        'general_notes':
            'Started the month feeling tired after poor sleep. Mild headache by late afternoon.',
        'symptoms': [
          _symptomSeed('fatigue', 4, 360, 'general', {'context': 'poor_sleep'}),
          _symptomSeed('headache', 2, 75, 'head', {'time': 'afternoon'}),
        ],
        'bp': '126/82',
        'hr': '74',
      },
      {
        'day': 2,
        'sleep_hours': 5.9,
        'sleep_quality': 4,
        'energy_level': 4,
        'mood_level': 5,
        'stress_level': 7,
        'appetite_level': 6,
        'hydration_level': 5,
        'general_pain': 2,
        'general_notes':
            'Stress remained high. Needed extra water reminders and felt mentally tired in the evening.',
        'symptoms': [
          _symptomSeed('fatigue', 4, 300, 'general', {
            'context': 'work_stress',
          }),
        ],
        'bp': '128/83',
        'hr': '75',
      },
      {
        'day': 3,
        'sleep_hours': 5.8,
        'sleep_quality': 4,
        'energy_level': 3,
        'mood_level': 4,
        'stress_level': 8,
        'appetite_level': 5,
        'hydration_level': 5,
        'general_pain': 3,
        'general_notes':
            'Felt tired after poor sleep. Mild headache in the afternoon and skipped the usual walk.',
        'symptoms': [
          _symptomSeed('fatigue', 5, 420, 'general', {
            'context': 'sleep_deprivation',
          }),
          _symptomSeed('headache', 3, 90, 'head', {'time': 'afternoon'}),
        ],
        'bp': '127/81',
        'hr': '76',
      },
      {
        'day': 4,
        'sleep_hours': 6.2,
        'sleep_quality': 5,
        'energy_level': 4,
        'mood_level': 5,
        'stress_level': 7,
        'appetite_level': 6,
        'hydration_level': 6,
        'general_pain': 2,
        'general_notes':
            'Still fatigued but a short evening walk helped a little. Keeping notes for the week.',
        'symptoms': [
          _symptomSeed('fatigue', 4, 240, 'general', {'context': 'recovering'}),
        ],
        'bp': '125/80',
        'hr': '73',
      },
      {
        'day': 5,
        'sleep_hours': 6.4,
        'sleep_quality': 6,
        'energy_level': 5,
        'mood_level': 5,
        'stress_level': 6,
        'appetite_level': 6,
        'hydration_level': 6,
        'general_pain': 2,
        'general_notes':
            'Sleep slightly better. Less headache, but still felt drained after work.',
        'symptoms': [
          _symptomSeed('fatigue', 3, 180, 'general', {'context': 'improving'}),
        ],
        'bp': '124/79',
        'hr': '72',
      },
      {
        'day': 6,
        'sleep_hours': 6.1,
        'sleep_quality': 5,
        'energy_level': 5,
        'mood_level': 5,
        'stress_level': 6,
        'appetite_level': 6,
        'hydration_level': 6,
        'general_pain': 2,
        'general_notes':
            'Checked home blood pressure after work and it was a bit higher than usual. Wants to keep monitoring.',
        'symptoms': [
          _symptomSeed('fatigue', 3, 120, 'general', {'context': 'after_work'}),
        ],
        'bp': '134/86',
        'hr': '74',
      },
      {
        'day': 7,
        'sleep_hours': 6.0,
        'sleep_quality': 5,
        'energy_level': 5,
        'mood_level': 5,
        'stress_level': 6,
        'appetite_level': 6,
        'hydration_level': 6,
        'general_pain': 2,
        'general_notes':
            'Missed the morning medication reminder and took it late. Blood pressure still slightly elevated at home.',
        'symptoms': [
          _symptomSeed('headache', 2, 45, 'head', {'context': 'bp_check_day'}),
        ],
        'bp': '136/88',
        'hr': '75',
      },
      {
        'day': 8,
        'sleep_hours': 6.3,
        'sleep_quality': 5,
        'energy_level': 5,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 6,
        'hydration_level': 6,
        'general_pain': 1,
        'general_notes':
            'Home BP slightly higher than usual. Walked 25 minutes and felt calmer after dinner.',
        'symptoms': [],
        'bp': '135/84',
        'hr': '73',
      },
      {
        'day': 9,
        'sleep_hours': 6.4,
        'sleep_quality': 6,
        'energy_level': 5,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 6,
        'hydration_level': 6,
        'general_pain': 1,
        'general_notes':
            'Repeated the home BP reading in the evening. Slightly better after hydration and a lighter day.',
        'symptoms': [],
        'bp': '132/83',
        'hr': '72',
      },
      {
        'day': 10,
        'sleep_hours': 6.6,
        'sleep_quality': 6,
        'energy_level': 5,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 1,
        'general_notes':
            'Added a local blood pressure diary note summarizing the first 10 days of home measurements.',
        'symptoms': [],
        'bp': '131/82',
        'hr': '71',
      },
      {
        'day': 11,
        'sleep_hours': 6.8,
        'sleep_quality': 6,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 1,
        'general_notes':
            'Started walking more regularly. Energy a little better and fewer afternoon symptoms.',
        'symptoms': [
          _symptomSeed('fatigue', 2, 90, 'general', {'context': 'improving'}),
        ],
        'bp': '129/81',
        'hr': '70',
      },
      {
        'day': 12,
        'sleep_hours': 6.9,
        'sleep_quality': 6,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 1,
        'general_notes':
            'Hydration reminders helped. Walked after work and felt less heavy than last week.',
        'symptoms': [],
        'bp': '128/80',
        'hr': '69',
      },
      {
        'day': 13,
        'sleep_hours': 7.1,
        'sleep_quality': 7,
        'energy_level': 6,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 1,
        'general_notes':
            'No headache today. Longer walk and noticeably lower stress by bedtime.',
        'symptoms': [],
        'bp': '127/79',
        'hr': '68',
      },
      {
        'day': 14,
        'sleep_hours': 7.0,
        'sleep_quality': 7,
        'energy_level': 6,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Kept the walking routine. Fatigue still present in the late evening but milder than early May.',
        'symptoms': [
          _symptomSeed('fatigue', 2, 60, 'general', {'time': 'evening'}),
        ],
        'bp': '126/78',
        'hr': '68',
      },
      {
        'day': 15,
        'sleep_hours': 7.2,
        'sleep_quality': 7,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Best day so far this month. More walking and steadier routine seem to be helping.',
        'symptoms': [],
        'bp': '124/78',
        'hr': '67',
      },
      {
        'day': 16,
        'sleep_hours': 7.0,
        'sleep_quality': 7,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Added metabolic panel document. Wants to ask the clinician about kidney markers and hydration.',
        'symptoms': [],
        'bp': '126/80',
        'hr': '69',
      },
      {
        'day': 17,
        'sleep_hours': 6.9,
        'sleep_quality': 6,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Reviewed the new report locally. Mild concern about creatinine trend but no acute symptoms.',
        'symptoms': [],
        'bp': '127/80',
        'hr': '69',
      },
      {
        'day': 18,
        'sleep_hours': 6.8,
        'sleep_quality': 6,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 1,
        'general_notes':
            'Forgot the morning medication dose today. Plans to keep reminders more visible after reading the report.',
        'symptoms': [],
        'bp': '129/82',
        'hr': '70',
      },
      {
        'day': 19,
        'sleep_hours': 6.9,
        'sleep_quality': 6,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 1,
        'general_notes':
            'Added lipid and glucose follow-up document. Wants a simple explanation of LDL and HbA1c values.',
        'symptoms': [],
        'bp': '128/81',
        'hr': '69',
      },
      {
        'day': 20,
        'sleep_hours': 7.0,
        'sleep_quality': 7,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Mild worry after reviewing labs, but the plan is to discuss them rather than self-interpret.',
        'symptoms': [
          _symptomSeed('fatigue', 2, 45, 'general', {'context': 'mild'}),
        ],
        'bp': '127/80',
        'hr': '68',
      },
      {
        'day': 21,
        'sleep_hours': 7.3,
        'sleep_quality': 7,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Sleep improved again. Medication back on time and energy more stable.',
        'symptoms': [],
        'bp': '125/79',
        'hr': '67',
      },
      {
        'day': 22,
        'sleep_hours': 7.1,
        'sleep_quality': 7,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Added allergy and inflammation check. Mild nasal symptoms but overall feeling more settled.',
        'symptoms': [
          _symptomSeed('nasal_congestion', 2, 50, 'nose', {'seasonal': true}),
        ],
        'bp': '124/78',
        'hr': '67',
      },
      {
        'day': 23,
        'sleep_hours': 7.4,
        'sleep_quality': 8,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 3,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'More rested. Morning walk felt easier and there were no significant symptoms today.',
        'symptoms': [],
        'bp': '123/77',
        'hr': '66',
      },
      {
        'day': 24,
        'sleep_hours': 7.5,
        'sleep_quality': 8,
        'energy_level': 7,
        'mood_level': 8,
        'stress_level': 3,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Better sleep and lower stress after regular walks. This felt like a much steadier day.',
        'symptoms': [],
        'bp': '122/76',
        'hr': '65',
      },
      {
        'day': 25,
        'sleep_hours': 7.2,
        'sleep_quality': 7,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 3,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Mostly consistent routine this week. No missed medication doses since the lab follow-up.',
        'symptoms': [],
        'bp': '123/77',
        'hr': '65',
      },
      {
        'day': 26,
        'sleep_hours': 7.1,
        'sleep_quality': 7,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Started drafting questions for the clinician visit, especially around blood pressure and lab follow-up.',
        'symptoms': [],
        'bp': '124/78',
        'hr': '66',
      },
      {
        'day': 27,
        'sleep_hours': 7.0,
        'sleep_quality': 7,
        'energy_level': 6,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 0,
        'general_notes':
            'Missed the morning dose while commuting, but otherwise felt stable and kept walking in the evening.',
        'symptoms': [],
        'bp': '125/78',
        'hr': '66',
      },
      {
        'day': 28,
        'sleep_hours': 7.2,
        'sleep_quality': 7,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Reviewed home measurements and medication notes before the upcoming visit preparation.',
        'symptoms': [],
        'bp': '124/77',
        'hr': '65',
      },
      {
        'day': 29,
        'sleep_hours': 7.4,
        'sleep_quality': 8,
        'energy_level': 7,
        'mood_level': 8,
        'stress_level': 3,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Added pre-visit summary note with questions about LDL, HbA1c, creatinine, and home blood pressure readings.',
        'symptoms': [],
        'bp': '123/76',
        'hr': '64',
      },
      {
        'day': 30,
        'sleep_hours': 7.6,
        'sleep_quality': 8,
        'energy_level': 7,
        'mood_level': 8,
        'stress_level': 3,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Looked over the month and noticed clearer improvement in sleep, stress, and walking consistency.',
        'symptoms': [],
        'bp': '122/76',
        'hr': '64',
      },
      {
        'day': 31,
        'sleep_hours': 7.8,
        'sleep_quality': 8,
        'energy_level': 8,
        'mood_level': 8,
        'stress_level': 3,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Preparing questions for clinician visit. Ended the month feeling more informed and less stressed than at the start.',
        'symptoms': [],
        'bp': '121/75',
        'hr': '63',
      },
    ];

    return rows
        .map((row) {
          final day = row['day'] as int;
          final vitals = <Map<String, dynamic>>[
            {
              'id': 'de-$day-bp',
              'type': 'blood_pressure',
              'value': row['bp'],
              'unit': 'mmHg',
              'measured_at': _isoAt(day, 8, 15),
            },
            {
              'id': 'de-$day-hr',
              'type': 'heart_rate',
              'value': row['hr'],
              'unit': 'bpm',
              'measured_at': _isoAt(day, 8, 15),
            },
          ];
          return {
            'id': 'de-may-2026-${day.toString().padLeft(2, '0')}',
            'entry_date': _isoDay(day),
            'sleep_hours': row['sleep_hours'],
            'sleep_quality': row['sleep_quality'],
            'energy_level': row['energy_level'],
            'mood_level': row['mood_level'],
            'stress_level': row['stress_level'],
            'appetite_level': row['appetite_level'],
            'hydration_level': row['hydration_level'],
            'general_pain': row['general_pain'],
            'general_notes': row['general_notes'],
            'symptoms': (row['symptoms'] as List<dynamic>)
                .asMap()
                .entries
                .map((entry) {
                  final symptom = Map<String, dynamic>.from(
                    entry.value as Map<String, dynamic>,
                  );
                  symptom['id'] = 'de-$day-sym-${entry.key + 1}';
                  return symptom;
                })
                .toList(growable: false),
            'vitals': vitals,
          };
        })
        .toList(growable: false);
  }

  static Map<String, dynamic> _profileBundleJson() {
    return {
      'profile': {
        'id': primaryProfileId,
        'user_id': demoUserId,
        'is_primary': true,
        'first_name': 'Marco',
        'last_name': 'Rossi',
        'birth_date': '1988-06-15',
        'biological_sex': 'male',
        'height_cm': 179,
        'weight_kg': 78,
        'smoker': false,
        'former_smoker': true,
        'smoking_pack_years': 4,
        'years_since_quitting': 7,
        'alcohol_use': 'moderate',
        'activity_level': 'moderate',
        'postmenopausal': false,
        'fragility_fracture_history': false,
        'falls_last_year': 0,
        'feels_unsteady': false,
        'sexually_active': true,
        'new_or_multiple_partners': false,
        'partner_with_sti': false,
        'sex_with_men': false,
        'sti_or_exposure_concerns': false,
        'trying_to_conceive': false,
        'currently_pregnant': false,
        'taking_folic_acid': false,
        'relationship_label': 'self',
        'occupation': 'Software Engineer',
        'exercise_habits': '3x week running and strength training',
        'sleep_pattern': 'Average 7h/night',
        'symptom_triggers': 'Stress and low hydration',
        'functional_limitations': 'None',
      },
      'onboarding': {
        'health_data_consent': true,
        'consented_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 150))
            .toIso8601String(),
        'ai_external_consent': true,
        'ai_external_consented_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 145))
            .toIso8601String(),
        'onboarding_completed_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 145))
            .toIso8601String(),
      },
      'allergies': [
        {
          'id': 'allergy-1',
          'allergen': 'Penicillin',
          'severity': 'high',
          'notes': 'Rash and dyspnea in 2018',
        },
        {
          'id': 'allergy-2',
          'allergen': 'Dust mites',
          'severity': 'moderate',
          'notes': 'Seasonal symptoms',
        },
      ],
      'medical_conditions': [
        {
          'id': 'condition-1',
          'name': 'Mild hypertension',
          'status': 'active',
          'notes': 'Controlled with lifestyle + medication',
          'diagnosis_date': '2023-02-10',
        },
        {
          'id': 'condition-2',
          'name': 'Gastroesophageal reflux',
          'status': 'active',
          'notes': 'Worse with spicy food',
          'diagnosis_date': '2021-11-02',
        },
      ],
      'medications': [
        {
          'id': 'med-1',
          'name': 'Lisinopril',
          'dosage': '10 mg',
          'frequency': 'Daily',
          'route': 'oral',
          'start_date': '2023-03-01',
          'end_date': null,
          'active': true,
          'notes': 'Take in the morning',
          'schedules': [
            {
              'id': 'sched-1',
              'scheduled_time': '08:00',
              'days_of_week': [0, 1, 2, 3, 4, 5, 6],
              'start_date': '2023-03-01',
              'end_date': null,
              'cycle_days_on': null,
              'cycle_days_off': null,
              'paused_until': null,
              'instructions': 'Take with water',
              'active': true,
            },
          ],
        },
        {
          'id': 'med-2',
          'name': 'Pantoprazole',
          'dosage': '20 mg',
          'frequency': 'As needed',
          'route': 'oral',
          'start_date': '2024-01-15',
          'end_date': null,
          'active': true,
          'notes': 'Use before heavy meals if reflux appears',
          'schedules': [
            {
              'id': 'sched-2',
              'scheduled_time': '13:00',
              'days_of_week': [0, 1, 2, 3, 4],
              'start_date': '2024-01-15',
              'end_date': null,
              'cycle_days_on': null,
              'cycle_days_off': null,
              'paused_until': null,
              'instructions': 'Before lunch',
              'active': true,
            },
          ],
        },
      ],
      'family_history': [
        {
          'id': 'fam-1',
          'relation': 'Father',
          'condition_name': 'Type 2 diabetes',
          'notes': 'Diagnosed at 55',
        },
        {
          'id': 'fam-2',
          'relation': 'Mother',
          'condition_name': 'Hypercholesterolemia',
          'notes': null,
        },
      ],
      'managed_profiles': [
        {
          'id': 'profile-2',
          'user_id': demoUserId,
          'is_primary': false,
          'first_name': 'Giulia',
          'last_name': 'Rossi',
          'birth_date': '2015-03-21',
          'biological_sex': 'female',
          'height_cm': 145,
          'weight_kg': 38,
          'smoker': false,
          'former_smoker': false,
          'smoking_pack_years': null,
          'years_since_quitting': null,
          'alcohol_use': null,
          'activity_level': 'high',
          'postmenopausal': false,
          'fragility_fracture_history': false,
          'falls_last_year': 0,
          'feels_unsteady': false,
          'sexually_active': null,
          'new_or_multiple_partners': false,
          'partner_with_sti': false,
          'sex_with_men': false,
          'sti_or_exposure_concerns': false,
          'trying_to_conceive': false,
          'currently_pregnant': false,
          'taking_folic_acid': false,
          'relationship_label': 'daughter',
          'occupation': 'Student',
          'exercise_habits': 'Swimming 2x week',
          'sleep_pattern': null,
          'symptom_triggers': null,
          'functional_limitations': null,
        },
        {
          'id': 'profile-3',
          'user_id': demoUserId,
          'is_primary': false,
          'first_name': 'Luisa',
          'last_name': 'Rossi',
          'birth_date': '1956-09-10',
          'biological_sex': 'female',
          'height_cm': 160,
          'weight_kg': 64,
          'smoker': false,
          'former_smoker': true,
          'smoking_pack_years': 8,
          'years_since_quitting': 20,
          'alcohol_use': 'none',
          'activity_level': 'low',
          'postmenopausal': true,
          'fragility_fracture_history': false,
          'falls_last_year': 1,
          'feels_unsteady': false,
          'sexually_active': false,
          'new_or_multiple_partners': false,
          'partner_with_sti': false,
          'sex_with_men': false,
          'sti_or_exposure_concerns': false,
          'trying_to_conceive': false,
          'currently_pregnant': false,
          'taking_folic_acid': false,
          'relationship_label': 'mother',
          'occupation': 'Retired',
          'exercise_habits': 'Daily walk',
          'sleep_pattern': '6h average',
          'symptom_triggers': 'Cold weather',
          'functional_limitations': 'Mild knee pain on stairs',
        },
      ],
      'vaccinations': [
        {
          'id': 'vac-1',
          'vaccine_name': 'Influenza',
          'administered_on': '2025-10-12',
          'dose_number': 1,
          'next_due_date': '2026-10-01',
          'provider_name': 'Milan Community Clinic',
          'notes': 'Annual vaccination',
        },
        {
          'id': 'vac-2',
          'vaccine_name': 'COVID-19 booster',
          'administered_on': '2025-11-05',
          'dose_number': 1,
          'next_due_date': null,
          'provider_name': 'Milan Community Clinic',
          'notes': null,
        },
      ],
      'clinical_episodes': [
        {
          'id': 'ep-1',
          'title': 'Lumbar pain episode',
          'summary': 'Acute low back pain after lifting heavy box.',
          'status': 'improving',
          'onset_date': '2025-12-04',
          'resolved_date': null,
          'next_review_date': '2026-05-05',
          'notes': 'Responding to physiotherapy exercises.',
        },
      ],
      'prevention_records': _preventionRecordsJson(),
    };
  }

  static List<Map<String, dynamic>> _alertsJson() {
    return [
      {
        'id': 'alert-may-1',
        'severity': 'medium',
        'alert_type': 'screening_due',
        'rule_code': 'bp_followup',
        'title': 'Blood pressure follow-up due',
        'description':
            'Early May home blood pressure readings were sometimes elevated. Keep them ready for discussion.',
        'status': 'open',
        'source_type': 'screening',
        'source_id': 'scr-1',
        'triggered_at': _isoAt(24, 8, 0),
        'resolved_at': null,
        'resolution_notes': null,
      },
      {
        'id': 'alert-may-2',
        'severity': 'low',
        'alert_type': 'medication_missed',
        'rule_code': 'med_adherence',
        'title': 'Medication adherence warning',
        'description':
            'Medication adherence was mostly consistent, with two missed doses and one late entry this month.',
        'status': 'open',
        'source_type': 'medication',
        'source_id': 'med-1',
        'triggered_at': _isoAt(27, 9, 0),
        'resolved_at': null,
        'resolution_notes': null,
      },
      {
        'id': 'alert-may-3',
        'severity': 'low',
        'alert_type': 'document_follow_up',
        'rule_code': 'lab_review',
        'title': 'Review May lab questions',
        'description':
            'Local reports added questions about creatinine, eGFR, LDL, and HbA1c for clinician discussion.',
        'status': 'open',
        'source_type': 'document',
        'source_id': 'doc-previsit-may-2026',
        'triggered_at': _isoAt(29, 20, 20),
        'resolved_at': null,
        'resolution_notes': null,
      },
    ];
  }

  static List<Map<String, dynamic>> _timelineJson() {
    return [
      {
        'id': 'tl-may-01',
        'event_type': 'daily_entry',
        'title': 'Early-month fatigue logged',
        'description':
            'Daily check-in captured poor sleep, fatigue, and mild headache.',
        'event_date': _isoAt(3, 18, 30),
        'severity': null,
      },
      {
        'id': 'tl-may-02',
        'event_type': 'vitals_review',
        'title': 'Higher home BP noted',
        'description':
            'Home blood pressure was slightly above usual values between May 6 and May 10.',
        'event_date': _isoAt(8, 20, 10),
        'severity': null,
      },
      {
        'id': 'tl-may-03',
        'event_type': 'document_uploaded',
        'title': 'Blood pressure diary note added',
        'description': 'Local home-monitoring note saved for later discussion.',
        'event_date': _isoAt(10, 21, 5),
        'severity': null,
      },
      {
        'id': 'tl-may-04',
        'event_type': 'wellbeing',
        'title': 'Walking routine improved',
        'description':
            'More walking and hydration were associated with lower stress and better energy.',
        'event_date': _isoAt(15, 19, 0),
        'severity': null,
      },
      {
        'id': 'tl-may-05',
        'event_type': 'document_uploaded',
        'title': 'Metabolic panel uploaded',
        'description': 'May 2026 metabolic panel added to the local archive.',
        'event_date': _isoAt(16, 12, 5),
        'severity': 'medium',
      },
      {
        'id': 'tl-may-06',
        'event_type': 'document_uploaded',
        'title': 'Lipid and glucose follow-up uploaded',
        'description':
            'Borderline lipid and glucose values were added for review.',
        'event_date': _isoAt(19, 18, 20),
        'severity': 'medium',
      },
      {
        'id': 'tl-may-07',
        'event_type': 'medication',
        'title': 'Medication adherence note',
        'description':
            'A missed dose was logged and reminders were kept active.',
        'event_date': _isoAt(18, 18, 10),
        'severity': 'low',
      },
      {
        'id': 'tl-may-08',
        'event_type': 'document_uploaded',
        'title': 'Allergy and inflammation check added',
        'description':
            'Seasonal symptom context was added to the local archive.',
        'event_date': _isoAt(22, 17, 40),
        'severity': null,
      },
      {
        'id': 'tl-may-09',
        'event_type': 'alert',
        'title': 'Preventive review suggested',
        'description':
            'Prevention center highlighted blood pressure and lab follow-up discussion points.',
        'event_date': _isoAt(24, 8, 15),
        'severity': 'medium',
      },
      {
        'id': 'tl-may-10',
        'event_type': 'document_uploaded',
        'title': 'Pre-visit summary note added',
        'description':
            'Questions for the clinician visit were collected in one local note.',
        'event_date': _isoAt(29, 20, 20),
        'severity': null,
      },
      {
        'id': 'tl-may-11',
        'event_type': 'daily_entry',
        'title': 'Month-end recap prepared',
        'description':
            'Final May check-in captured better sleep, lower stress, and visit preparation.',
        'event_date': _isoAt(31, 20, 10),
        'severity': null,
      },
    ];
  }

  static List<Map<String, dynamic>> _documentFoldersJson() {
    return [
      {
        'id': 'folder-labs',
        'name': 'May Lab Reports',
        'parent_folder_id': null,
        'path_label': 'May Lab Reports',
        'child_folder_count': 0,
        'document_count': 3,
      },
      {
        'id': 'folder-home',
        'name': 'Home Monitoring',
        'parent_folder_id': null,
        'path_label': 'Home Monitoring',
        'child_folder_count': 0,
        'document_count': 1,
      },
      {
        'id': 'folder-visit',
        'name': 'Visit Prep',
        'parent_folder_id': null,
        'path_label': 'Visit Prep',
        'child_folder_count': 0,
        'document_count': 1,
      },
    ];
  }

  static List<Map<String, dynamic>> _documentsJson() {
    return [
      {
        'id': 'doc-metabolic-may-2026',
        'folder_id': 'folder-labs',
        'folder_name': 'May Lab Reports',
        'title': 'May 2026 metabolic panel',
        'document_type': 'lab_report',
        'upload_date': _isoAt(16, 12, 5),
        'exam_date': _isoAt(16, 9, 0),
        'source': 'Milan Community Clinic',
        'original_filename': 'may_2026_metabolic_panel.txt',
        'mime_type': 'text/plain',
        'file_size_bytes': 4820,
        'parsed_status': 'parsed',
        'context_status': 'active',
        'classification_confidence': 0.98,
        'parsing_confidence': 0.95,
        'processing_error': null,
        'pending_sync': false,
        'storage_location': 'local',
        'local_file_path': null,
      },
      {
        'id': 'doc-lipids-glucose-may-2026',
        'folder_id': 'folder-labs',
        'folder_name': 'May Lab Reports',
        'title': 'May 2026 lipid and glucose follow-up',
        'document_type': 'lab_report',
        'upload_date': _isoAt(19, 18, 20),
        'exam_date': _isoAt(19, 8, 45),
        'source': 'Milan Community Clinic',
        'original_filename': 'may_2026_lipid_glucose_followup.txt',
        'mime_type': 'text/plain',
        'file_size_bytes': 4330,
        'parsed_status': 'parsed',
        'context_status': 'active',
        'classification_confidence': 0.98,
        'parsing_confidence': 0.95,
        'processing_error': null,
        'pending_sync': false,
        'storage_location': 'local',
        'local_file_path': null,
      },
      {
        'id': 'doc-bp-note-may-2026',
        'folder_id': 'folder-home',
        'folder_name': 'Home Monitoring',
        'title': 'May 2026 blood pressure diary note',
        'document_type': 'clinical_note',
        'upload_date': _isoAt(10, 21, 5),
        'exam_date': _isoAt(10, 20, 30),
        'source': 'ClinDiary local note',
        'original_filename': 'may_2026_bp_diary_note.txt',
        'mime_type': 'text/plain',
        'file_size_bytes': 3180,
        'parsed_status': 'local_only',
        'context_status': 'active',
        'classification_confidence': 0.96,
        'parsing_confidence': 0.82,
        'processing_error': null,
        'pending_sync': false,
        'storage_location': 'local',
        'local_file_path': null,
      },
      {
        'id': 'doc-allergy-may-2026',
        'folder_id': 'folder-labs',
        'folder_name': 'May Lab Reports',
        'title': 'May 2026 allergy / inflammation check',
        'document_type': 'lab_report',
        'upload_date': _isoAt(22, 17, 40),
        'exam_date': _isoAt(22, 10, 15),
        'source': 'Poliambulatorio San Marco',
        'original_filename': 'may_2026_allergy_inflammation_check.txt',
        'mime_type': 'text/plain',
        'file_size_bytes': 4010,
        'parsed_status': 'parsed',
        'context_status': 'active',
        'classification_confidence': 0.97,
        'parsing_confidence': 0.94,
        'processing_error': null,
        'pending_sync': false,
        'storage_location': 'local',
        'local_file_path': null,
      },
      {
        'id': 'doc-previsit-may-2026',
        'folder_id': 'folder-visit',
        'folder_name': 'Visit Prep',
        'title': 'May 2026 pre-visit summary note',
        'document_type': 'clinical_note',
        'upload_date': _isoAt(29, 20, 20),
        'exam_date': _isoAt(29, 20, 10),
        'source': 'ClinDiary local note',
        'original_filename': 'may_2026_previsit_summary_note.txt',
        'mime_type': 'text/plain',
        'file_size_bytes': 2890,
        'parsed_status': 'local_only',
        'context_status': 'active',
        'classification_confidence': 0.95,
        'parsing_confidence': 0.8,
        'processing_error': null,
        'pending_sync': false,
        'storage_location': 'local',
        'local_file_path': null,
      },
    ];
  }

  static Map<String, dynamic> _documentDetailJson(String documentId) {
    final docs = _documentsJson();
    var selected = docs.first;
    for (final item in docs) {
      if (item['id'].toString() == documentId) {
        selected = item;
        break;
      }
    }

    final detail =
        _documentDetailTemplates()[selected['id'].toString()] ??
        _documentDetailTemplates().values.first;
    return {
      ...selected,
      'file_url': 'https://demo.clindiary.app/files/${selected['id']}.pdf',
      'viewer_url': 'https://demo.clindiary.app/viewer/${selected['id']}',
      'ocr_text': detail['ocr_text'],
      'processed_at': detail['processed_at'],
      'lab_panels': detail['lab_panels'],
      'imaging_reports': detail['imaging_reports'],
    };
  }

  static List<Map<String, dynamic>> _notificationsJson() {
    return [
      {
        'id': 'notif-may-01',
        'patient_id': primaryProfileId,
        'notification_type': 'daily_checkin',
        'title': 'Daily check-in reminder',
        'body': 'Remember to complete your May daily check-in before 21:00.',
        'priority': 'normal',
        'read_status': false,
        'read_at': null,
        'source_type': 'daily_entry',
        'source_id': 'de-may-2026-31',
        'created_at': _isoAt(31, 19, 0),
      },
      {
        'id': 'notif-may-02',
        'patient_id': primaryProfileId,
        'notification_type': 'medication',
        'title': 'Medication timing reminder',
        'body':
            'Medication adherence has been mostly consistent, with one late entry this week.',
        'priority': 'high',
        'read_status': true,
        'read_at': _isoAt(21, 8, 30),
        'source_type': 'medication',
        'source_id': 'med-1',
        'created_at': _isoAt(21, 7, 45),
      },
      {
        'id': 'notif-may-03',
        'patient_id': primaryProfileId,
        'notification_type': 'document',
        'title': 'Metabolic panel added',
        'body': 'New local document ready to review: May 2026 metabolic panel.',
        'priority': 'high',
        'read_status': true,
        'read_at': _isoAt(16, 19, 10),
        'source_type': 'document',
        'source_id': 'doc-metabolic-may-2026',
        'created_at': _isoAt(16, 12, 10),
      },
      {
        'id': 'notif-may-04',
        'patient_id': primaryProfileId,
        'notification_type': 'document',
        'title': 'Lipid and glucose follow-up ready',
        'body':
            'Use Ask about this file for a simple explanation of the values in the new report.',
        'priority': 'high',
        'read_status': false,
        'read_at': null,
        'source_type': 'document',
        'source_id': 'doc-lipids-glucose-may-2026',
        'created_at': _isoAt(19, 18, 25),
      },
      {
        'id': 'notif-may-05',
        'patient_id': primaryProfileId,
        'notification_type': 'screening',
        'title': 'Blood pressure follow-up',
        'body':
            'Home measurements from early May are ready to discuss with a clinician.',
        'priority': 'high',
        'read_status': true,
        'read_at': _isoAt(24, 9, 0),
        'source_type': 'screening',
        'source_id': 'scr-1',
        'created_at': _isoAt(24, 8, 15),
      },
      {
        'id': 'notif-may-06',
        'patient_id': primaryProfileId,
        'notification_type': 'prevention',
        'title': 'Prepare visit questions',
        'body':
            'Your pre-visit summary note is ready. Review questions about LDL, HbA1c, creatinine, and BP trend.',
        'priority': 'normal',
        'read_status': false,
        'read_at': null,
        'source_type': 'document',
        'source_id': 'doc-previsit-may-2026',
        'created_at': _isoAt(29, 20, 30),
      },
    ];
  }

  static Map<String, dynamic> _notificationPreferencesJson() {
    return {
      'in_app_enabled': true,
      'daily_checkin_enabled': true,
      'symptom_follow_up_enabled': true,
      'medication_reminders_enabled': true,
      'screening_reminders_enabled': true,
      'document_follow_up_enabled': true,
      'report_ready_enabled': true,
      'clinical_alerts_enabled': true,
      'prevention_tips_enabled': true,
      'push_enabled': false,
      'email_enabled': true,
      'email_address': 'demo@clindiary.app',
    };
  }

  static List<Map<String, dynamic>> _medicationLogsJson() {
    final logs = <Map<String, dynamic>>[];
    const lateDays = {7};
    const missedDays = {18, 27};
    const pantoprazoleDays = {3, 8, 17};

    for (var day = 1; day <= 31; day++) {
      final status = missedDays.contains(day)
          ? 'missed'
          : lateDays.contains(day)
          ? 'late'
          : 'taken';
      logs.add({
        'id': 'ml-may-$day',
        'medication_id': 'med-1',
        'medication_name': 'Lisinopril',
        'medication_dosage': '10 mg',
        'scheduled_at': _isoAt(day, 8, 0),
        'taken_at': status == 'missed'
            ? null
            : status == 'late'
            ? _isoAt(day, 10, 20)
            : _isoAt(day, 8, 10),
        'status': status,
        'notes': status == 'missed'
            ? 'Missed morning dose.'
            : status == 'late'
            ? 'Taken late after reminder.'
            : 'Taken as scheduled.',
        'pending_sync': false,
      });
      if (pantoprazoleDays.contains(day)) {
        logs.add({
          'id': 'ml-pantoprazole-may-$day',
          'medication_id': 'med-2',
          'medication_name': 'Pantoprazole',
          'medication_dosage': '20 mg',
          'scheduled_at': _isoAt(day, 13, 0),
          'taken_at': _isoAt(day, 12, 50),
          'status': 'taken',
          'notes': 'Used before lunch for reflux prevention.',
          'pending_sync': false,
        });
      }
    }

    return logs.reversed.toList(growable: false);
  }

  static List<Map<String, dynamic>> _wearableSummariesJson() {
    const steps = [
      4100,
      3900,
      3500,
      4300,
      4600,
      4800,
      5000,
      5300,
      5600,
      5900,
      6700,
      7100,
      7600,
      7900,
      8200,
      7800,
      7500,
      7000,
      7200,
      7400,
      8000,
      8300,
      8700,
      9100,
      8800,
      8400,
      8100,
      8600,
      9000,
      9300,
      9500,
    ];
    const sleepMinutes = [
      366,
      354,
      348,
      372,
      384,
      366,
      360,
      378,
      384,
      396,
      408,
      414,
      426,
      420,
      432,
      420,
      414,
      408,
      414,
      420,
      438,
      426,
      444,
      450,
      432,
      426,
      420,
      432,
      444,
      456,
      468,
    ];
    const restingHr = [
      78,
      77,
      76,
      75,
      74,
      74,
      74,
      73,
      72,
      72,
      71,
      70,
      69,
      68,
      67,
      68,
      68,
      69,
      68,
      67,
      66,
      65,
      64,
      63,
      63,
      64,
      64,
      63,
      62,
      61,
      61,
    ];
    const activeMinutes = [
      12,
      10,
      12,
      14,
      16,
      18,
      20,
      25,
      28,
      30,
      34,
      36,
      40,
      42,
      45,
      38,
      35,
      32,
      34,
      36,
      42,
      45,
      48,
      52,
      49,
      46,
      44,
      47,
      50,
      53,
      55,
    ];

    return List.generate(31, (index) {
      final day = index + 1;
      final sleep = sleepMinutes[index];
      final active = activeMinutes[index].toDouble();
      final stepCount = steps[index];
      final rest = restingHr[index].toDouble();
      final avgHr = rest + 7;
      return {
        'id': 'wear-may-2026-${day.toString().padLeft(2, '0')}',
        'summary_date': _isoDay(day),
        'source_platform': 'health_connect',
        'source_name': 'Xiaomi Fitness',
        'source_device_model': 'Xiaomi Smart Band 8',
        'steps_count': stepCount,
        'active_energy_kcal': 180 + (stepCount / 23),
        'exercise_minutes': active,
        'distance_meters': stepCount * 0.73,
        'sleep_minutes': sleep.toDouble(),
        'sleep_deep_minutes': (sleep * 0.22).roundToDouble(),
        'sleep_rem_minutes': (sleep * 0.2).roundToDouble(),
        'heart_rate_avg_bpm': avgHr,
        'heart_rate_min_bpm': rest - 10,
        'heart_rate_max_bpm': avgHr + 55,
        'resting_heart_rate_bpm': rest,
        'blood_oxygen_avg_pct': 97,
        'hrv_sdnn_ms': 28 + (index % 8) * 2,
        'record_count': 118 + (index % 7),
        'synced_at': _isoAt(day, 22, 15),
      };
    }).reversed.toList(growable: false);
  }

  static Map<String, Map<String, dynamic>> _documentDetailTemplates() {
    return {
      'doc-metabolic-may-2026': {
        'processed_at': _isoAt(16, 12, 10),
        'ocr_text':
            'Patient: Marco Rossi\nMay 2026 metabolic panel\nCreatinine: 1.29 mg/dL (reference 0.67-1.17) [ABNORMAL]\neGFR: 71 mL/min/1.73m2 (reference > 90) [ABNORMAL]\nPotassium: 5.1 mmol/L (reference 3.5-5.0) [ABNORMAL]\nSodium: 139 mmol/L (reference 136-145)\nAST: 24 U/L (reference 0-40)\nALT: 27 U/L (reference 0-41)\nComment: Mild kidney marker variation compared with prior local report. Hydration and clinician discussion recommended.',
        'lab_panels': [
          {
            'id': 'panel-metabolic-may-2026',
            'panel_name': 'Metabolic panel',
            'panel_date': _isoAt(16, 9, 0),
            'confidence_score': 0.96,
            'results': [
              {
                'id': 'res-met-1',
                'analyte_name': 'Creatinine',
                'value': '1.29',
                'unit': 'mg/dL',
                'ref_min': 0.67,
                'ref_max': 1.17,
                'abnormal_flag': true,
                'confidence_score': 0.98,
              },
              {
                'id': 'res-met-2',
                'analyte_name': 'eGFR',
                'value': '71',
                'unit': 'mL/min/1.73m2',
                'ref_min': 90,
                'ref_max': 130,
                'abnormal_flag': true,
                'confidence_score': 0.95,
              },
              {
                'id': 'res-met-3',
                'analyte_name': 'Potassium',
                'value': '5.1',
                'unit': 'mmol/L',
                'ref_min': 3.5,
                'ref_max': 5.0,
                'abnormal_flag': true,
                'confidence_score': 0.94,
              },
            ],
          },
        ],
        'imaging_reports': <Map<String, dynamic>>[],
      },
      'doc-lipids-glucose-may-2026': {
        'processed_at': _isoAt(19, 18, 25),
        'ocr_text':
            'Patient: Marco Rossi\nMay 2026 lipid and glucose follow-up\nLDL cholesterol: 142 mg/dL (reference < 115) [ABNORMAL]\nHDL cholesterol: 47 mg/dL (reference > 40)\nTriglycerides: 168 mg/dL (reference < 150) [ABNORMAL]\nHbA1c: 5.8 % (reference 4.0-5.6) [ABNORMAL]\nFasting glucose: 103 mg/dL (reference 70-99) [ABNORMAL]\nComment: Borderline metabolic values. Review lifestyle measures and discuss follow-up timing with clinician.',
        'lab_panels': [
          {
            'id': 'panel-lipid-may-2026',
            'panel_name': 'Lipid and glucose follow-up',
            'panel_date': _isoAt(19, 8, 45),
            'confidence_score': 0.96,
            'results': [
              {
                'id': 'res-lipid-1',
                'analyte_name': 'LDL cholesterol',
                'value': '142',
                'unit': 'mg/dL',
                'ref_min': 0,
                'ref_max': 115,
                'abnormal_flag': true,
                'confidence_score': 0.97,
              },
              {
                'id': 'res-lipid-2',
                'analyte_name': 'Triglycerides',
                'value': '168',
                'unit': 'mg/dL',
                'ref_min': 0,
                'ref_max': 150,
                'abnormal_flag': true,
                'confidence_score': 0.95,
              },
              {
                'id': 'res-lipid-3',
                'analyte_name': 'HbA1c',
                'value': '5.8',
                'unit': '%',
                'ref_min': 4.0,
                'ref_max': 5.6,
                'abnormal_flag': true,
                'confidence_score': 0.95,
              },
              {
                'id': 'res-lipid-4',
                'analyte_name': 'Fasting glucose',
                'value': '103',
                'unit': 'mg/dL',
                'ref_min': 70,
                'ref_max': 99,
                'abnormal_flag': true,
                'confidence_score': 0.93,
              },
            ],
          },
        ],
        'imaging_reports': <Map<String, dynamic>>[],
      },
      'doc-bp-note-may-2026': {
        'processed_at': _isoAt(10, 21, 5),
        'ocr_text':
            'May 2026 blood pressure diary note\nHome readings from May 6 to May 10: 134/86, 136/88, 135/84, 132/83, 131/82.\nContext: early month stress, poor sleep, and irregular hydration.\nPatient note: walked more on May 8 and May 9 and felt calmer afterwards.\nPlan for discussion: ask whether the home pattern is worth repeating or reviewing at the next visit.',
        'lab_panels': <Map<String, dynamic>>[],
        'imaging_reports': <Map<String, dynamic>>[],
      },
      'doc-allergy-may-2026': {
        'processed_at': _isoAt(22, 17, 45),
        'ocr_text':
            'Patient: Marco Rossi\nMay 2026 allergy / inflammation check\nEosinophils: 6.8 % (reference 0.0-6.0) [ABNORMAL]\nhs-CRP: 3.6 mg/L (reference < 3.0) [ABNORMAL]\nHemoglobin: 14.5 g/dL (reference 13.5-17.5)\nComment: Mild seasonal allergy and inflammation signal. Review together with symptoms, not as a diagnosis.',
        'lab_panels': [
          {
            'id': 'panel-allergy-may-2026',
            'panel_name': 'Allergy and inflammation check',
            'panel_date': _isoAt(22, 10, 15),
            'confidence_score': 0.94,
            'results': [
              {
                'id': 'res-allergy-1',
                'analyte_name': 'Eosinophils',
                'value': '6.8',
                'unit': '%',
                'ref_min': 0.0,
                'ref_max': 6.0,
                'abnormal_flag': true,
                'confidence_score': 0.94,
              },
              {
                'id': 'res-allergy-2',
                'analyte_name': 'hs-CRP',
                'value': '3.6',
                'unit': 'mg/L',
                'ref_min': 0,
                'ref_max': 3.0,
                'abnormal_flag': true,
                'confidence_score': 0.93,
              },
            ],
          },
        ],
        'imaging_reports': <Map<String, dynamic>>[],
      },
      'doc-previsit-may-2026': {
        'processed_at': _isoAt(29, 20, 25),
        'ocr_text':
            'May 2026 pre-visit summary note\nTopics to discuss with clinician:\n1. Are creatinine and eGFR changes worth repeating soon?\n2. How should LDL, triglycerides, HbA1c, and fasting glucose be reviewed in context?\n3. Do the higher home blood pressure readings from May 6 to May 10 change the monitoring plan?\n4. Which values should be watched again before the next follow-up?\nPatient goal: leave the visit with a clear monitoring plan, not a diagnosis.',
        'lab_panels': <Map<String, dynamic>>[],
        'imaging_reports': <Map<String, dynamic>>[],
      },
    };
  }

  static Map<String, dynamic> _symptomSeed(
    String code,
    int severity,
    int durationMinutes,
    String bodyLocation,
    Map<String, dynamic> metadata,
  ) {
    return {
      'id': '',
      'symptom_code': code,
      'severity': severity,
      'duration_minutes': durationMinutes,
      'body_location': bodyLocation,
      'metadata_json': metadata,
    };
  }

  static List<Map<String, dynamic>> _screeningCatalogJson() {
    return [
      {
        'id': 'cat-1',
        'code': 'blood_pressure',
        'name': 'Blood pressure check',
        'description':
            'Routine blood pressure monitoring for cardiovascular prevention.',
        'min_age': 18,
        'max_age': null,
        'target_sex': null,
        'interval_months': 12,
        'public_coverage_flag': true,
        'category': 'cardiovascular',
        'care_pathway': 'self_book_or_gp',
        'recommendation_level': 'routine',
        'cadence_label': 'Every 12 months',
        'catalog_only': false,
        'explanation': 'Recommended because of previous elevated values.',
        'active': true,
        'regional_availability': [
          {
            'region_name': 'Lombardia',
            'booking_url': 'https://prenota.lombardia.it',
            'notes': 'Book through regional portal',
            'active': true,
          },
        ],
      },
      {
        'id': 'cat-2',
        'code': 'lipid_panel',
        'name': 'Lipid panel',
        'description': 'Periodic cholesterol and triglycerides panel.',
        'min_age': 30,
        'max_age': null,
        'target_sex': null,
        'interval_months': 24,
        'public_coverage_flag': true,
        'category': 'metabolic',
        'care_pathway': 'gp_referral',
        'recommendation_level': 'routine',
        'cadence_label': 'Every 24 months',
        'catalog_only': false,
        'explanation': null,
        'active': true,
        'regional_availability': [
          {
            'region_name': 'Lombardia',
            'booking_url': 'https://prenota.lombardia.it',
            'notes': null,
            'active': true,
          },
        ],
      },
    ];
  }

  static List<Map<String, dynamic>> _myScreeningsJson() {
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'scr-1',
        'screening_program_id': 'cat-1',
        'screening_code': 'blood_pressure',
        'screening_name': 'Blood pressure check',
        'screening_category': 'cardiovascular',
        'care_pathway': 'self_book_or_gp',
        'recommendation_level': 'routine',
        'cadence_label': 'Every 12 months',
        'public_coverage_flag': true,
        'explanation': 'Annual follow-up based on your profile and trend.',
        'recommendation_reason': 'Previous values near threshold.',
        'last_done_date': now
            .subtract(const Duration(days: 380))
            .toIso8601String(),
        'next_due_date': now.add(const Duration(days: 10)).toIso8601String(),
        'completed_this_year': false,
        'current_year_last_completed_on': null,
        'status': 'recommended',
        'regional_availability': [
          {
            'region_name': 'Lombardia',
            'booking_url': 'https://prenota.lombardia.it',
            'notes': null,
            'active': true,
          },
        ],
      },
      {
        'id': 'scr-2',
        'screening_program_id': 'cat-2',
        'screening_code': 'lipid_panel',
        'screening_name': 'Lipid panel',
        'screening_category': 'metabolic',
        'care_pathway': 'gp_referral',
        'recommendation_level': 'routine',
        'cadence_label': 'Every 24 months',
        'public_coverage_flag': true,
        'explanation': null,
        'recommendation_reason': 'Periodic prevention tracking.',
        'last_done_date': now
            .subtract(const Duration(days: 30))
            .toIso8601String(),
        'next_due_date': now.add(const Duration(days: 700)).toIso8601String(),
        'completed_this_year': true,
        'current_year_last_completed_on': now
            .subtract(const Duration(days: 30))
            .toIso8601String(),
        'status': 'up_to_date',
        'regional_availability': [
          {
            'region_name': 'Lombardia',
            'booking_url': 'https://prenota.lombardia.it',
            'notes': null,
            'active': true,
          },
        ],
      },
    ];
  }

  static Map<String, dynamic> _preventionCenterJson() {
    final now = _demoGeneratedAtUtc();
    return {
      'generated_at': now.toIso8601String(),
      'display_name': 'Marco Rossi',
      'age': 37,
      'biological_sex': 'male',
      'region_name': 'Lombardia',
      'overview': {
        'actionable_screenings': 2,
        'vaccine_reviews': 1,
        'vaccine_registry_items': 1,
        'pregnancy_items': 0,
        'shared_decision_items': 1,
        'seasonal_checks': 1,
        'follow_up_items': 3,
      },
      'annual_visit': {
        'code': 'annual_visit',
        'title': 'Annual GP visit',
        'subtitle': 'Review May blood pressure trend and lab questions',
        'reason': 'May 2026 local follow-up preparation',
        'action_hint': 'Book through your GP office',
        'cadence_label': 'Every 12 months',
        'status': 'recommended',
        'priority': 'high',
        'category': 'visits',
        'kind': 'visit',
        'source_type': 'profile',
        'source_id': primaryProfileId,
      },
      'visits_and_controls': [
        {
          'code': 'bp_control',
          'title': 'Blood pressure control',
          'subtitle': 'Home + clinic check',
          'reason': 'Early May home readings were sometimes elevated',
          'action_hint': 'Bring the May home diary note to the visit',
          'cadence_label': 'Monthly',
          'status': 'recommended',
          'priority': 'high',
          'category': 'cardiovascular',
          'kind': 'screening',
          'source_type': 'screening',
          'source_id': 'scr-1',
        },
        {
          'code': 'metabolic_followup',
          'title': 'Discuss metabolic panel follow-up',
          'subtitle': 'Creatinine, eGFR, LDL, HbA1c',
          'reason': 'Mid-May reports raised questions worth clinician review',
          'action_hint': 'Use the pre-visit note to organize questions',
          'cadence_label': 'At next visit',
          'status': 'recommended',
          'priority': 'normal',
          'category': 'metabolic',
          'kind': 'follow_up',
          'source_type': 'document',
          'source_id': 'doc-metabolic-may-2026',
        },
      ],
      'vaccines': [
        {
          'code': 'influenza_booster',
          'title': 'Seasonal influenza vaccine',
          'subtitle': 'Autumn campaign',
          'reason': 'Annual prevention recommendation',
          'action_hint': 'Book in September',
          'cadence_label': 'Yearly',
          'status': 'review',
          'priority': 'normal',
          'category': 'vaccination',
          'kind': 'vaccine',
          'source_type': 'vaccination',
          'source_id': 'vac-1',
        },
      ],
      'vaccine_registry': [
        {
          'code': 'registry_sync',
          'title': 'Check regional vaccine registry',
          'subtitle': 'Verify completed doses',
          'reason': 'Ensure records are complete',
          'action_hint': 'Open regional health portal',
          'cadence_label': 'Every 6 months',
          'status': 'review',
          'priority': 'low',
          'category': 'registry',
          'kind': 'administrative',
          'source_type': null,
          'source_id': null,
        },
      ],
      'pregnancy_and_preconception': <Map<String, dynamic>>[],
      'shared_decisions': [
        {
          'code': 'lipid_strategy',
          'title': 'Discuss lipid management strategy',
          'subtitle': 'Lifestyle review and follow-up timing',
          'reason': 'LDL, triglycerides, and HbA1c were borderline in May',
          'action_hint': 'Review with GP at next visit',
          'cadence_label': 'At next visit',
          'status': 'review',
          'priority': 'normal',
          'category': 'metabolic',
          'kind': 'shared_decision',
          'source_type': 'document',
          'source_id': 'doc-lipids-glucose-may-2026',
        },
      ],
      'seasonal_checks': [
        {
          'code': 'allergy_season',
          'title': 'Allergy symptom monitoring',
          'subtitle': 'Spring period',
          'reason':
              'Seasonal symptoms and mild inflammation markers were logged',
          'action_hint': 'Track symptoms weekly',
          'cadence_label': 'Seasonal',
          'status': 'recommended',
          'priority': 'low',
          'category': 'allergy',
          'kind': 'monitoring',
          'source_type': 'allergy',
          'source_id': 'allergy-2',
        },
      ],
      'follow_up_reminders': [
        {
          'code': 'med_adherence_followup',
          'title': 'Medication adherence follow-up',
          'subtitle': 'Two missed doses and one late entry this month',
          'reason': 'Keep the monthly BP context interpretable',
          'action_hint': 'Enable stronger reminder notifications',
          'cadence_label': 'Weekly',
          'status': 'recommended',
          'priority': 'normal',
          'category': 'medication',
          'kind': 'follow_up',
          'source_type': 'medication',
          'source_id': 'med-1',
        },
        {
          'code': 'previsit_questions',
          'title': 'Review pre-visit questions',
          'subtitle': 'Use the note created on May 29',
          'reason': 'The month included several local reports worth discussing',
          'action_hint':
              'Open the pre-visit summary note before the appointment',
          'cadence_label': 'Before visit',
          'status': 'recommended',
          'priority': 'normal',
          'category': 'visit_prep',
          'kind': 'follow_up',
          'source_type': 'document',
          'source_id': 'doc-previsit-may-2026',
        },
      ],
    };
  }

  static Map<String, dynamic> _insightJson({
    required String summaryType,
    DateTime? referenceDate,
    String provider = 'local_gemma4',
  }) {
    final now = _demoGeneratedAtUtc();
    final baseDate = referenceDate?.toUtc() ?? now;
    DateTime start;
    DateTime end;
    String content;

    switch (summaryType) {
      case 'weekly':
        end = DateTime.utc(baseDate.year, baseDate.month, baseDate.day);
        start = end.subtract(const Duration(days: 6));
        content =
            'Weekly trend: sleep and stress improved, walking remained regular, and medication adherence was mostly consistent despite a few missed or late entries earlier in the month.';
        break;
      case 'monthly':
        start = DateTime.utc(baseDate.year, baseDate.month, 1);
        final nextMonth = baseDate.month == 12
            ? DateTime.utc(baseDate.year + 1, 1, 1)
            : DateTime.utc(baseDate.year, baseDate.month + 1, 1);
        end = nextMonth.subtract(const Duration(days: 1));
        content =
            'Monthly recap: early May fatigue, poor sleep, and stress gradually improved with more walking and hydration. Home blood pressure was sometimes elevated in the first third of the month, while mid-May reports added questions about kidney markers, LDL, triglycerides, and HbA1c for clinician review.';
        break;
      default:
        start = DateTime.utc(baseDate.year, baseDate.month, baseDate.day);
        end = start;
        content =
            'Daily recap: local diary, medication, wearable, and document context suggest a stable day with no acute alarm signals. Keep the discussion focused on tracking trends and follow-up questions for the clinician.';
    }

    return {
      'id': 'ins-$summaryType-${_date(baseDate)}',
      'summary_type': summaryType,
      'period_start': start.toIso8601String(),
      'period_end': end.toIso8601String(),
      'content': content,
      'provider_name': provider,
      'model_name': provider == 'on_device_litertlm'
          ? 'Gemma 4 E2B LiteRT-LM'
          : 'Gemma 4 Local',
      'generated_at': now.toIso8601String(),
    };
  }

  static Map<String, dynamic> _historyDayJson(
    DateTime targetDate, {
    bool includeRollups = false,
  }) {
    final target = DateTime.utc(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final dayString = _date(target);

    Map<String, dynamic>? dailyEntry;
    for (final entry in _dailyEntriesJson()) {
      if (entry['entry_date'].toString() == dayString) {
        dailyEntry = entry;
        break;
      }
    }

    final wearables = _wearableSummariesJson();
    var wearableSummary = wearables.first;
    for (final item in wearables) {
      if (item['summary_date'].toString() == dayString) {
        wearableSummary = item;
        break;
      }
    }
    final timelineEvents = _timelineJson()
        .where(
          (item) =>
              _date(DateTime.parse(item['event_date'].toString())) == dayString,
        )
        .toList(growable: false);
    final documents = _documentsJson()
        .where((item) {
          final examDate = item['exam_date']?.toString();
          return examDate != null &&
              _date(DateTime.parse(examDate)) == dayString;
        })
        .toList(growable: false);

    return {
      'target_date': dayString,
      'daily_entry': dailyEntry,
      'daily_summary': _insightJson(
        summaryType: 'daily',
        referenceDate: target,
      ),
      'weekly_summary': includeRollups
          ? _insightJson(summaryType: 'weekly', referenceDate: target)
          : null,
      'monthly_summary': includeRollups
          ? _insightJson(summaryType: 'monthly', referenceDate: target)
          : null,
      'wearable_summary': wearableSummary,
      'documents': documents,
      'timeline_events': timelineEvents,
    };
  }

  static Map<String, dynamic> _historyActivityJson(
    DateTime start,
    DateTime end,
  ) {
    final activityDays = <String>[];
    for (final entry in _dailyEntriesJson()) {
      final day = DateTime.parse(entry['entry_date'].toString());
      if (!day.isBefore(start) && !day.isAfter(end)) {
        activityDays.add(entry['entry_date'].toString());
      }
    }
    return {'activity_dates': activityDays};
  }

  static List<Map<String, dynamic>> _dossierShareLinksJson() {
    final now = _demoGeneratedAtUtc();
    return [
      {
        'id': 'share-1',
        'scope': 'full',
        'label': 'May 2026 clinician review package',
        'share_url': 'https://demo.clindiary.app/share/share-1',
        'filename': 'clindiary_may_2026_marco_rossi.pdf',
        'mime_type': 'application/pdf',
        'expires_at': now.add(const Duration(days: 5)).toIso8601String(),
        'revoked_at': null,
        'last_accessed_at': now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];
  }

  static List<Map<String, dynamic>> _dossierShareLinksJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _cloneListOfMaps(_dossierShareLinksJson());
    }
    final links = _cloneListOfMaps(_dossierShareLinksJson());
    for (final link in links) {
      link['id'] = '$profileId-${link['id']}';
      link['filename'] = '${profileId}_${link['filename']}';
      link['label'] = '${_profileContextLabel(profileId)} ${link['label']}';
    }
    return links;
  }

  static List<Map<String, dynamic>> _documentQueryHistoryJsonForProfile(
    String profileId,
  ) {
    final docs = _documentsJsonForProfile(profileId);
    final firstDoc = docs.first;
    final secondDoc = docs.length > 1 ? docs[1] : docs.first;
    return [
      {
        'id': '$profileId-doc-history-1',
        'question': 'Explain this report in simple words.',
        'answer':
            'This report highlights a few values outside the listed reference ranges and suggests discussing them with a clinician rather than drawing conclusions alone.',
        'citations': [
          {
            'document_id': firstDoc['id'],
            'document_title': firstDoc['title'],
            'document_type': firstDoc['document_type'],
            'folder_name': firstDoc['folder_name'],
            'exam_date': firstDoc['exam_date'],
            'chunk_kind': 'lab_panel',
            'chunk_label': firstDoc['title'],
            'excerpt':
                'Creatinine, eGFR, and potassium were outside the listed reference ranges.',
            'score': 4.8,
            'viewer_url': 'https://demo.clindiary.app/viewer/${firstDoc['id']}',
          },
        ],
        'model_name': 'gemma-4-E2B-it.litertlm',
        'provider_name': 'on_device_litertlm',
        'embedding_model_name': 'gecko-110m-en',
        'retrieved_chunks': 1,
        'retrieved_documents': 1,
        'search_scope_label': 'Entire archive',
        'language_code': 'en',
        'created_at': _isoAt(19, 19, 0),
      },
      {
        'id': '$profileId-doc-history-2',
        'question': 'Which values are abnormal?',
        'answer':
            'The stored report marks LDL, triglycerides, HbA1c, and fasting glucose as outside the listed reference ranges.',
        'citations': [
          {
            'document_id': secondDoc['id'],
            'document_title': secondDoc['title'],
            'document_type': secondDoc['document_type'],
            'folder_name': secondDoc['folder_name'],
            'exam_date': secondDoc['exam_date'],
            'chunk_kind': 'lab_panel',
            'chunk_label': secondDoc['title'],
            'excerpt':
                'LDL cholesterol 142 mg/dL, triglycerides 168 mg/dL, HbA1c 5.8 %, fasting glucose 103 mg/dL.',
            'score': 4.6,
            'viewer_url':
                'https://demo.clindiary.app/viewer/${secondDoc['id']}',
          },
        ],
        'model_name': 'gemma-4-E2B-it.litertlm',
        'provider_name': 'on_device_litertlm',
        'embedding_model_name': 'gecko-110m-en',
        'retrieved_chunks': 1,
        'retrieved_documents': 1,
        'search_scope_label': 'Entire archive',
        'language_code': 'en',
        'created_at': _isoAt(20, 9, 15),
      },
    ];
  }

  static Map<String, dynamic> _latestReportJson() {
    final now = _demoGeneratedAtUtc();
    final periodStart = _demoMonthStartUtc();
    return {
      'id': 'report-1',
      'report_type': 'monthly',
      'status': 'generated',
      'title': 'May 2026 Clinical Report',
      'period_start': periodStart.toIso8601String(),
      'period_end': now.toIso8601String(),
      'summary_excerpt':
          'Early fatigue and stress improved, while May reports raised follow-up questions about blood pressure, kidney markers, LDL, and HbA1c.',
      'content_text':
          'May 2026 local report: early month fatigue, poor sleep, and occasional elevated home blood pressure improved with more walking and hydration. Medication adherence was mostly consistent, with two missed doses and one late entry. Local reports added discussion points about creatinine, eGFR, LDL, triglycerides, HbA1c, fasting glucose, and mild inflammation markers.',
      'generated_at': now.toIso8601String(),
    };
  }

  static Map<String, dynamic> _healthDossierJson() {
    final now = _demoGeneratedAtUtc();
    final documents = _documentsJson();
    return {
      'generated_at': now.toIso8601String(),
      'display_name': 'Marco Rossi',
      'age': 37,
      'biological_sex': 'male',
      'profile_facts': [
        {'label': 'Region', 'value': 'Lombardia'},
        {'label': 'Primary profile', 'value': 'Yes'},
      ],
      'provenance_facts': [
        {'label': 'Last sync', 'value': now.toIso8601String()},
      ],
      'emergency_summary': {
        'generated_at': now.toIso8601String(),
        'headline': 'No critical emergency risks detected in local demo data',
        'key_points': [
          'May 2026 diary shows improving sleep and stress after the first week',
          'Mid-May reports added non-urgent discussion points for clinician review',
        ],
        'active_problems': ['Mild hypertension', 'Reflux'],
        'active_medications': ['Lisinopril 10 mg', 'Pantoprazole 20 mg PRN'],
        'allergies': ['Penicillin', 'Dust mites'],
        'conditions': ['Mild hypertension', 'Gastroesophageal reflux'],
        'open_alerts': [
          'Blood pressure follow-up due',
          'Medication adherence follow-up',
        ],
        'latest_wearable_summary':
            'May 31: 9500 steps, 7.8 h sleep, resting HR 61 bpm',
        'latest_report_summary':
            'May report highlights improved routine and pending follow-up questions',
      },
      'allergies': _profileBundleJson()['allergies'],
      'medical_conditions': _profileBundleJson()['medical_conditions'],
      'medications': _profileBundleJson()['medications'],
      'family_history': _profileBundleJson()['family_history'],
      'vaccinations': _profileBundleJson()['vaccinations'],
      'clinical_episodes': _profileBundleJson()['clinical_episodes'],
      'prevention_records': _profileBundleJson()['prevention_records'],
      'recent_daily_entries': _dailyEntriesJson(),
      'recent_documents': documents
          .map(
            (doc) => {
              'id': doc['id'],
              'title': doc['title'],
              'document_type': doc['document_type'],
              'upload_date': doc['upload_date'],
              'exam_date': doc['exam_date'],
              'source': doc['source'],
              'parsed_status': doc['parsed_status'],
              'context_status': doc['context_status'],
            },
          )
          .toList(),
      'recent_lab_panels': [
        {
          'document_id': 'doc-metabolic-may-2026',
          'document_title': 'May 2026 metabolic panel',
          'panel_name': 'Metabolic panel',
          'panel_date': _isoAt(16, 9, 0),
          'abnormal_results_count': 3,
          'key_results': [
            'Creatinine 1.29 mg/dL',
            'eGFR 71 mL/min/1.73m2',
            'Potassium 5.1 mmol/L',
          ],
        },
        {
          'document_id': 'doc-lipids-glucose-may-2026',
          'document_title': 'May 2026 lipid and glucose follow-up',
          'panel_name': 'Lipid and glucose follow-up',
          'panel_date': _isoAt(19, 8, 45),
          'abnormal_results_count': 4,
          'key_results': [
            'LDL 142 mg/dL',
            'Triglycerides 168 mg/dL',
            'HbA1c 5.8 %',
          ],
        },
      ],
      'recent_imaging_reports': const <Map<String, dynamic>>[],
      'device_measurement_summaries': [
        {
          'provider_code': 'health_connect',
          'provider_name': 'Health Connect',
          'metric_type': 'blood_pressure',
          'metric_label': 'Blood pressure',
          'measurement_count': 31,
          'latest_measured_at': _isoAt(31, 8, 15),
          'latest_value': '121/75 mmHg',
          'trend_label': 'improving after early May elevation',
          'concern_level': 'low',
          'concern_note': null,
          'summary':
              'Home BP was higher on May 6-10, then settled later in the month.',
        },
      ],
      'recent_insights': [
        _insightJson(summaryType: 'daily', referenceDate: _demoMonthEndUtc()),
        _insightJson(summaryType: 'weekly', referenceDate: _demoMonthEndUtc()),
        _insightJson(summaryType: 'monthly', referenceDate: _demoMonthEndUtc()),
      ],
      'recent_reports': [_latestReportJson()],
      'alerts': _alertsJson(),
      'wearable_summaries': _wearableSummariesJson(),
    };
  }

  static Map<String, dynamic> _billingStatusJson() {
    return {
      'current_plan': {
        'id': 'plan-pro',
        'code': 'ai_plus_yearly',
        'name': 'AI Plus Annual',
        'description': 'Full cloud + AI feature set for demo',
        'billing_interval': 'yearly',
        'price_cents': 9900,
        'currency': 'EUR',
        'sort_order': 1,
        'highlight_label': 'Recommended',
        'is_active': true,
        'is_public': true,
        'is_recommended': true,
        'feature_codes': [
          'cloud_document_storage',
          'ai_document_query',
          'advanced_reports',
        ],
      },
      'available_plans': [
        {
          'id': 'plan-free',
          'code': 'free',
          'name': 'Free',
          'description': 'Local-only mode',
          'billing_interval': 'monthly',
          'price_cents': 0,
          'currency': 'EUR',
          'sort_order': 0,
          'highlight_label': null,
          'is_active': true,
          'is_public': true,
          'is_recommended': false,
          'feature_codes': [],
        },
        {
          'id': 'plan-pro',
          'code': 'ai_plus_yearly',
          'name': 'AI Plus Annual',
          'description': 'Full cloud + AI feature set for demo',
          'billing_interval': 'yearly',
          'price_cents': 9900,
          'currency': 'EUR',
          'sort_order': 1,
          'highlight_label': 'Recommended',
          'is_active': true,
          'is_public': true,
          'is_recommended': true,
          'feature_codes': [
            'cloud_document_storage',
            'ai_document_query',
            'advanced_reports',
          ],
        },
      ],
      'entitlement_codes': [
        'cloud_document_storage',
        'ai_document_query',
        'advanced_reports',
      ],
      'has_active_paid_subscription': true,
      'checkout_ready': true,
      'hackathon_demo_mode': true,
      'active_subscription': null,
    };
  }

  static Map<String, dynamic> _deviceOverviewJson() {
    final now = DateTime.now().toUtc();
    return {
      'providers': [
        {
          'code': 'health_connect',
          'display_name': 'Health Connect',
          'summary': 'Android health data hub',
          'category': 'wearable',
          'integration_kind': 'native',
          'connection_flow': 'oauth2',
          'docs_url':
              'https://developer.android.com/health-and-fitness/guides/health-connect',
          'capabilities': ['steps', 'heart_rate', 'sleep', 'spo2'],
          'setup_notes': [
            'Open Health Connect permissions and enable ClinDiary access',
          ],
          'is_wave_one': true,
          'requires_vendor_contract': false,
          'provider_configured': true,
          'supports_live_sync': true,
          'supports_manual_ingest': true,
          'priority': 1,
        },
      ],
      'connections': [
        {
          'id': 'conn-1',
          'provider_code': 'health_connect',
          'provider_name': 'Health Connect',
          'integration_kind': 'native',
          'connection_flow': 'oauth2',
          'status': 'connected',
          'account_label': 'Marco Rossi Android',
          'external_user_id': 'hc-demo-001',
          'token_expires_at': null,
          'last_synced_at': now
              .subtract(const Duration(hours: 4))
              .toIso8601String(),
          'last_error': null,
          'measurement_count': 245,
          'latest_measurement': {
            'id': 'm-1',
            'provider_code': 'health_connect',
            'metric_type': 'heart_rate',
            'measured_at': now
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            'connection_id': 'conn-1',
            'source_device_model': 'Xiaomi Smart Band 8',
            'unit': 'bpm',
            'primary_value': 64,
            'secondary_value': null,
            'tertiary_value': null,
            'notes': null,
            'display_title': 'Heart rate',
            'display_value': '64 bpm',
          },
          'supports_live_sync': true,
          'supports_manual_ingest': true,
        },
      ],
      'recent_measurements': [
        {
          'id': 'm-1',
          'provider_code': 'health_connect',
          'metric_type': 'heart_rate',
          'measured_at': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'connection_id': 'conn-1',
          'source_device_model': 'Xiaomi Smart Band 8',
          'unit': 'bpm',
          'primary_value': 64,
          'secondary_value': null,
          'tertiary_value': null,
          'notes': null,
          'display_title': 'Heart rate',
          'display_value': '64 bpm',
        },
      ],
      'recent_jobs': [
        {
          'id': 'job-1',
          'provider_code': 'health_connect',
          'status': 'completed',
          'started_at': now
              .subtract(const Duration(hours: 4))
              .toIso8601String(),
          'connection_id': 'conn-1',
          'completed_at': now
              .subtract(const Duration(hours: 3, minutes: 56))
              .toIso8601String(),
          'item_count': 45,
          'summary': 'Synchronized 45 wearable records',
          'error_message': null,
        },
      ],
    };
  }

  static Map<String, dynamic> _localAiStatusJson() {
    return {
      'enabled': true,
      'provider': 'local_gemma4',
      'active_provider_label': 'Gemma 4 local',
      'runtime_mode': 'local',
      'backend': 'litert',
      'model_name': 'Gemma 4 E2B LiteRT-LM',
      'configured_base_url_present': false,
      'fallback_provider': 'rule_based',
      'is_cloud_bypassed_for_this_request': true,
    };
  }

  static Map<String, dynamic> _onDeviceAiStatusJson() {
    return {
      'isSupported': true,
      'isReady': true,
      'runtime': 'LiteRT-LM Android',
      'provider': 'on_device_litertlm',
      'activeProviderLabel': 'On-device local',
      'backendPreference': 'GPU',
      'backendResolved': 'GPU',
      'modelName': 'gemma-4-E2B-it.litertlm',
      'modelPath':
          '/data/user/0/it.clindiary.clindiary/files/models/gemma-4-E2B-it.litertlm',
      'modelFileSizeBytes': 2580000000,
      'modelLastModifiedAt': DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2))
          .toIso8601String(),
      'defaultModelDirectory':
          '/data/user/0/it.clindiary.clindiary/files/models',
      'lastError': null,
      'isCloudBypassedForThisRequest': true,
    };
  }

  static List<Map<String, dynamic>> _gemmaCenterHistoryJson() {
    return [
      {
        'id': 'gh-may-1',
        'kind': 'daily_recap',
        'title': 'Daily recap',
        'response':
            'By the end of May, sleep and stress looked better than at the start of the month. The app also noted a few local documents worth discussing with a clinician.',
        'created_at': _isoAt(31, 20, 0),
        'prompt': null,
        'reference_date': _isoAt(31, 20, 0),
        'document_id': null,
        'document_title': null,
        'language_code': 'en',
      },
      {
        'id': 'gh-may-2',
        'kind': 'document_summary',
        'title': 'Summary: May 2026 metabolic panel',
        'response':
            'Main points: creatinine, eGFR, and potassium were outside the listed reference ranges. The safe next step is to discuss the pattern with the clinician rather than self-diagnose.',
        'created_at': _isoAt(16, 19, 20),
        'prompt': null,
        'reference_date': _isoAt(16, 19, 20),
        'document_id': 'doc-metabolic-may-2026',
        'document_title': 'May 2026 metabolic panel',
        'language_code': 'en',
      },
      {
        'id': 'gh-may-3',
        'kind': 'question',
        'title': 'What should I ask my doctor about the May reports?',
        'response':
            'You could ask about the early-May blood pressure readings, the meaning of creatinine and eGFR changes, and how LDL, triglycerides, HbA1c, and fasting glucose should be reviewed together.',
        'created_at': _isoAt(29, 20, 35),
        'prompt': 'What should I ask my doctor about the May reports?',
        'reference_date': _isoAt(29, 20, 35),
        'document_id': 'doc-previsit-may-2026',
        'document_title': 'May 2026 pre-visit summary note',
        'language_code': 'en',
      },
    ];
  }

  static Map<String, dynamic> _profileBundleJsonForProfile(String profileId) {
    if (profileId == primaryProfileId) {
      return _profileBundleJson();
    }

    return {
      'profile': _coreProfileJsonForId(profileId),
      'onboarding': _primaryBundleMap('onboarding'),
      'allergies': _allergiesJsonForProfile(profileId),
      'medical_conditions': _medicalConditionsJsonForProfile(profileId),
      'medications': _medicationsJsonForProfile(profileId),
      'family_history': _familyHistoryJsonForProfile(profileId),
      'vaccinations': _vaccinationsJsonForProfile(profileId),
      'clinical_episodes': _clinicalEpisodesJsonForProfile(profileId),
      'prevention_records': _preventionRecordsJsonForProfile(profileId),
      'managed_profiles': _managedProfilesForProfile(profileId),
    };
  }

  static List<Map<String, dynamic>> _preventionRecordsJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _cloneListOfMaps(_preventionRecordsJson());
    }
    if (profileId == childManagedProfileId) {
      return [
        {
          'code': 'pediatric_annual_visit',
          'performed_at': _isoAt(8, 16, 0),
          'result_summary': 'Pediatric preventive review completed locally.',
          'source_id': 'profile-2',
        },
      ];
    }
    return [
      {
        'code': 'chronic_care_review',
        'performed_at': _isoAt(18, 10, 0),
        'result_summary': 'Chronic care follow-up captured for review.',
        'source_id': 'profile-3',
      },
    ];
  }

  static Map<String, dynamic> _primaryBundleMap(String key) {
    final value = _profileBundleJson()[key];
    if (value is Map<String, dynamic>) {
      return _cloneMap(value);
    }
    if (value is Map) {
      return _cloneMap(Map<String, dynamic>.from(value));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _primaryBundleList(String key) {
    final value = _profileBundleJson()[key];
    if (value is List<dynamic>) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  static List<Map<String, dynamic>> _managedProfilesForProfile(
    String profileId,
  ) {
    return _demoProfileIds
        .where((id) => id != profileId)
        .map(_coreProfileJsonForId)
        .toList(growable: false);
  }

  static Map<String, dynamic> _coreProfileJsonForId(String profileId) {
    if (profileId == primaryProfileId) {
      return _primaryBundleMap('profile');
    }
    for (final profile in _primaryBundleList('managed_profiles')) {
      if (profile['id']?.toString() == profileId) {
        return _cloneMap(profile);
      }
    }
    return _primaryBundleMap('profile');
  }

  static List<Map<String, dynamic>> _allergiesJsonForProfile(String profileId) {
    if (profileId == primaryProfileId) {
      return _primaryBundleList('allergies');
    }
    if (profileId == childManagedProfileId) {
      return [
        {
          'id': 'allergy-1',
          'allergen': 'Pollen',
          'severity': 'low',
          'notes': 'Seasonal sneezing and itchy eyes in spring',
        },
      ];
    }
    return [
      {
        'id': 'allergy-1',
        'allergen': 'NSAIDs',
        'severity': 'high',
        'notes': 'Past urticaria reaction',
      },
      {
        'id': 'allergy-2',
        'allergen': 'Latex',
        'severity': 'moderate',
        'notes': 'Skin irritation on prolonged exposure',
      },
    ];
  }

  static List<Map<String, dynamic>> _medicalConditionsJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _primaryBundleList('medical_conditions');
    }
    if (profileId == childManagedProfileId) {
      return [
        {
          'id': 'condition-1',
          'name': 'Allergic rhinitis',
          'status': 'active',
          'notes': 'Pollen season monitoring with pediatrician',
          'diagnosis_date': '2022-04-10',
        },
      ];
    }
    return [
      {
        'id': 'condition-1',
        'name': 'Primary hypertension',
        'status': 'active',
        'notes': 'Home BP monitoring 3x week',
        'diagnosis_date': '2019-06-18',
      },
      {
        'id': 'condition-2',
        'name': 'Knee osteoarthritis',
        'status': 'active',
        'notes': 'Worse after long walks or stairs',
        'diagnosis_date': '2020-10-03',
      },
      {
        'id': 'condition-3',
        'name': 'Hypothyroidism',
        'status': 'active',
        'notes': 'Stable replacement therapy',
        'diagnosis_date': '2016-01-21',
      },
    ];
  }

  static List<Map<String, dynamic>> _medicationsJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _primaryBundleList('medications');
    }
    if (profileId == childManagedProfileId) {
      return [
        {
          'id': 'med-1',
          'name': 'Cetirizine',
          'dosage': '5 mg',
          'frequency': 'As needed',
          'route': 'oral',
          'start_date': '2024-03-20',
          'end_date': null,
          'active': true,
          'notes': 'During allergy flare-ups',
          'schedules': [
            {
              'id': 'sched-1',
              'scheduled_time': '21:00',
              'days_of_week': [0, 1, 2, 3, 4, 5, 6],
              'start_date': '2024-03-20',
              'end_date': null,
              'cycle_days_on': null,
              'cycle_days_off': null,
              'paused_until': null,
              'instructions': 'Only if symptomatic',
              'active': true,
            },
          ],
        },
        {
          'id': 'med-2',
          'name': 'Vitamin D3',
          'dosage': '1000 IU',
          'frequency': 'Daily',
          'route': 'oral',
          'start_date': '2025-01-10',
          'end_date': null,
          'active': true,
          'notes': 'Support per pediatrician advice',
          'schedules': [
            {
              'id': 'sched-2',
              'scheduled_time': '08:00',
              'days_of_week': [0, 1, 2, 3, 4, 5, 6],
              'start_date': '2025-01-10',
              'end_date': null,
              'cycle_days_on': null,
              'cycle_days_off': null,
              'paused_until': null,
              'instructions': 'With breakfast',
              'active': true,
            },
          ],
        },
      ];
    }
    return [
      {
        'id': 'med-1',
        'name': 'Amlodipine',
        'dosage': '5 mg',
        'frequency': 'Daily',
        'route': 'oral',
        'start_date': '2019-06-20',
        'end_date': null,
        'active': true,
        'notes': 'Morning antihypertensive therapy',
        'schedules': [
          {
            'id': 'sched-1',
            'scheduled_time': '08:00',
            'days_of_week': [0, 1, 2, 3, 4, 5, 6],
            'start_date': '2019-06-20',
            'end_date': null,
            'cycle_days_on': null,
            'cycle_days_off': null,
            'paused_until': null,
            'instructions': 'Take after breakfast',
            'active': true,
          },
        ],
      },
      {
        'id': 'med-2',
        'name': 'Levothyroxine',
        'dosage': '50 mcg',
        'frequency': 'Daily',
        'route': 'oral',
        'start_date': '2016-01-22',
        'end_date': null,
        'active': true,
        'notes': 'Take before breakfast',
        'schedules': [
          {
            'id': 'sched-2',
            'scheduled_time': '07:00',
            'days_of_week': [0, 1, 2, 3, 4, 5, 6],
            'start_date': '2016-01-22',
            'end_date': null,
            'cycle_days_on': null,
            'cycle_days_off': null,
            'paused_until': null,
            'instructions': 'Take fasting',
            'active': true,
          },
        ],
      },
    ];
  }

  static List<Map<String, dynamic>> _familyHistoryJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _primaryBundleList('family_history');
    }
    if (profileId == childManagedProfileId) {
      return [
        {
          'id': 'fam-1',
          'relation': 'Father',
          'condition_name': 'Hypertension',
          'notes': 'Monitored in adulthood',
        },
        {
          'id': 'fam-2',
          'relation': 'Grandmother',
          'condition_name': 'Thyroid disease',
          'notes': null,
        },
      ];
    }
    return [
      {
        'id': 'fam-1',
        'relation': 'Father',
        'condition_name': 'Stroke',
        'notes': 'Occurred at age 72',
      },
      {
        'id': 'fam-2',
        'relation': 'Mother',
        'condition_name': 'Osteoporosis',
        'notes': null,
      },
    ];
  }

  static List<Map<String, dynamic>> _vaccinationsJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _primaryBundleList('vaccinations');
    }
    if (profileId == childManagedProfileId) {
      return [
        {
          'id': 'vac-1',
          'vaccine_name': 'MMR booster',
          'administered_on': '2024-09-15',
          'dose_number': 2,
          'next_due_date': null,
          'provider_name': 'Pediatric Vaccination Center',
          'notes': 'Routine pediatric booster',
        },
        {
          'id': 'vac-2',
          'vaccine_name': 'Influenza pediatric',
          'administered_on': '2025-10-01',
          'dose_number': 1,
          'next_due_date': '2026-10-01',
          'provider_name': 'Pediatric Vaccination Center',
          'notes': null,
        },
      ];
    }
    return [
      {
        'id': 'vac-1',
        'vaccine_name': 'Influenza',
        'administered_on': '2025-10-10',
        'dose_number': 1,
        'next_due_date': '2026-10-01',
        'provider_name': 'Milan Community Clinic',
        'notes': 'Annual dose',
      },
      {
        'id': 'vac-2',
        'vaccine_name': 'Pneumococcal',
        'administered_on': '2024-11-18',
        'dose_number': 1,
        'next_due_date': null,
        'provider_name': 'Milan Community Clinic',
        'notes': null,
      },
    ];
  }

  static List<Map<String, dynamic>> _clinicalEpisodesJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _primaryBundleList('clinical_episodes');
    }
    if (profileId == childManagedProfileId) {
      return [
        {
          'id': 'ep-1',
          'title': 'Seasonal allergy flare',
          'summary': 'Nasal congestion and mild wheezing during pollen peak.',
          'status': 'improving',
          'onset_date': '2026-03-29',
          'resolved_date': null,
          'next_review_date': '2026-05-08',
          'notes': 'Responded to antihistamine and environmental control.',
        },
      ];
    }
    return [
      {
        'id': 'ep-1',
        'title': 'Knee pain exacerbation',
        'summary': 'Temporary flare after prolonged standing.',
        'status': 'stable',
        'onset_date': '2026-02-14',
        'resolved_date': null,
        'next_review_date': '2026-05-18',
        'notes': 'Improved with physiotherapy exercises and pacing.',
      },
    ];
  }

  static List<Map<String, dynamic>> _dailyEntriesJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _dailyEntriesJson();
    }

    final entries = _cloneListOfMaps(_dailyEntriesJson());
    final bloodPressureSeries = profileId == childManagedProfileId
        ? ['101/65', '103/66', '99/63', '104/67', '100/64']
        : ['134/82', '131/80', '136/84', '129/78', '133/81'];
    final heartRateSeries = profileId == childManagedProfileId
        ? ['86', '89', '82', '84', '90']
        : ['72', '74', '70', '69', '73'];

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      entry['id'] = '$profileId-de-${index + 1}';
      entry['general_notes'] =
          '${_profileContextLabel(profileId)} ${entry['general_notes']}';

      if (profileId == childManagedProfileId) {
        entry['energy_level'] = 8;
        entry['stress_level'] = 2;
        entry['general_pain'] = 0;
      } else {
        entry['energy_level'] = 6;
        entry['stress_level'] = 4;
        entry['general_pain'] = 3;
      }

      final symptoms = entry['symptoms'];
      if (symptoms is List<dynamic>) {
        for (
          var symptomIndex = 0;
          symptomIndex < symptoms.length;
          symptomIndex++
        ) {
          final symptom = symptoms[symptomIndex];
          if (symptom is Map<String, dynamic>) {
            symptom['id'] = '$profileId-sym-${index + 1}-${symptomIndex + 1}';
          } else if (symptom is Map) {
            final mutable = Map<String, dynamic>.from(symptom);
            mutable['id'] = '$profileId-sym-${index + 1}-${symptomIndex + 1}';
            symptoms[symptomIndex] = mutable;
          }
        }
      }

      final vitals = entry['vitals'];
      if (vitals is List<dynamic>) {
        for (var vitalIndex = 0; vitalIndex < vitals.length; vitalIndex++) {
          final vitalRaw = vitals[vitalIndex];
          final vital = vitalRaw is Map<String, dynamic>
              ? vitalRaw
              : Map<String, dynamic>.from(vitalRaw as Map);
          vital['id'] = '$profileId-vit-${index + 1}-${vitalIndex + 1}';
          final type = vital['type']?.toString();
          if (type == 'blood_pressure') {
            vital['value'] =
                bloodPressureSeries[index % bloodPressureSeries.length];
          }
          if (type == 'heart_rate') {
            vital['value'] = heartRateSeries[index % heartRateSeries.length];
          }
          vitals[vitalIndex] = vital;
        }
      }
    }
    return entries;
  }

  static List<Map<String, dynamic>> _alertsJsonForProfile(String profileId) {
    if (profileId == primaryProfileId) {
      return _alertsJson();
    }

    final alerts = _cloneListOfMaps(_alertsJson());
    for (var index = 0; index < alerts.length; index++) {
      final alert = alerts[index];
      alert['id'] = '$profileId-alert-${index + 1}';
      if (profileId == childManagedProfileId) {
        if (index == 0) {
          alert['title'] = 'Pediatric follow-up due';
          alert['description'] =
              'Pediatric annual check should be scheduled this month.';
          alert['source_id'] = 'scr-child-1';
        } else {
          alert['title'] = 'Allergy prevention reminder';
          alert['description'] =
              'Remember evening antihistamine during pollen peak days.';
          alert['source_id'] = 'med-1';
        }
      } else {
        if (index == 0) {
          alert['title'] = 'Blood pressure re-check due';
          alert['description'] =
              'Weekly blood pressure review is recommended for this profile.';
          alert['source_id'] = 'scr-senior-1';
        } else {
          alert['title'] = 'Medication timing warning';
          alert['description'] =
              'One thyroid medication dose was delayed in the last 7 days.';
          alert['source_id'] = 'med-2';
        }
      }
    }
    return alerts;
  }

  static List<Map<String, dynamic>> _timelineJsonForProfile(String profileId) {
    if (profileId == primaryProfileId) {
      return _timelineJson();
    }
    final timeline = _cloneListOfMaps(_timelineJson());
    for (var index = 0; index < timeline.length; index++) {
      final event = timeline[index];
      event['id'] = '$profileId-tl-${index + 1}';
      event['title'] = '${_profileContextLabel(profileId)} ${event['title']}';
    }
    return timeline;
  }

  static List<Map<String, dynamic>> _documentsJsonForProfile(String profileId) {
    if (profileId == primaryProfileId) {
      return _documentsJson();
    }
    final docs = _cloneListOfMaps(_documentsJson());
    final name = _displayNameForProfile(
      profileId,
    ).toLowerCase().replaceAll(' ', '_');
    for (var index = 0; index < docs.length; index++) {
      final doc = docs[index];
      if (profileId == childManagedProfileId) {
        doc['folder_name'] = index == 0 ? 'Pediatric Visits' : 'Vaccinations';
        doc['title'] = index == 0
            ? 'Pediatric checkup summary 2026'
            : 'Vaccination review 2026';
        doc['source'] = 'Pediatric Care Unit Milano';
      } else {
        doc['folder_name'] = index == 0 ? 'Chronic Care' : 'Cardiology';
        doc['title'] = index == 0
            ? 'Chronic care review 2026'
            : 'Cardiology follow-up 2026';
        doc['source'] = 'Centro Clinico San Carlo';
      }
      doc['original_filename'] = '$name-${doc['id']}.pdf';
    }
    return docs;
  }

  static Map<String, dynamic> _documentDetailJsonForProfile(
    String profileId,
    String documentId,
  ) {
    if (profileId == primaryProfileId) {
      return _documentDetailJson(documentId);
    }
    final details = _cloneMap(_documentDetailJson(documentId));
    final docs = _documentsJsonForProfile(profileId);
    var selected = docs.first;
    for (final item in docs) {
      if (item['id']?.toString() == documentId) {
        selected = item;
        break;
      }
    }
    details.addAll(selected);
    details['file_url'] =
        'https://demo.clindiary.app/files/$profileId/${selected['id']}.pdf';
    details['viewer_url'] =
        'https://demo.clindiary.app/viewer/$profileId/${selected['id']}';
    details['ocr_text'] = profileId == childManagedProfileId
        ? 'Pediatric follow-up: growth, vaccination status, and allergy prevention plan reviewed.'
        : 'Follow-up report: blood pressure trend monitored, chronic therapy adherence acceptable.';
    return details;
  }

  static List<Map<String, dynamic>> _notificationsJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _notificationsJson();
    }
    final notifications = _cloneListOfMaps(_notificationsJson());
    for (var index = 0; index < notifications.length; index++) {
      final item = notifications[index];
      item['id'] = '$profileId-notif-${index + 1}';
      item['patient_id'] = profileId;
      item['title'] = '${_profileContextLabel(profileId)} ${item['title']}';
    }
    return notifications;
  }

  static Map<String, dynamic> _notificationPreferencesJsonForProfile(
    String profileId,
  ) {
    final preferences = _cloneMap(_notificationPreferencesJson());
    if (profileId == primaryProfileId) {
      return preferences;
    }
    preferences['email_address'] = 'demo+$profileId@clindiary.app';
    preferences['push_enabled'] = profileId == childManagedProfileId;
    return preferences;
  }

  static List<Map<String, dynamic>> _medicationLogsJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _medicationLogsJson();
    }
    final logs = _cloneListOfMaps(_medicationLogsJson());
    final meds = _medicationsJsonForProfile(profileId);
    for (var index = 0; index < logs.length; index++) {
      final log = logs[index];
      log['id'] = '$profileId-ml-${index + 1}';
      final med = meds[index % meds.length];
      log['medication_id'] = med['id'];
      log['medication_name'] = med['name'];
      log['medication_dosage'] = med['dosage'];
    }
    return logs;
  }

  static List<Map<String, dynamic>> _wearableSummariesJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _wearableSummariesJson();
    }
    final summaries = _cloneListOfMaps(_wearableSummariesJson());
    for (var index = 0; index < summaries.length; index++) {
      final day = summaries[index];
      day['id'] = '$profileId-wear-${index + 1}';
      if (profileId == childManagedProfileId) {
        day['source_device_model'] = 'Kids Smartwatch K2';
        day['steps_count'] = (day['steps_count'] as int? ?? 6000) + 1800;
        day['heart_rate_avg_bpm'] =
            ((day['heart_rate_avg_bpm'] as num?)?.toDouble() ?? 70) + 9;
      } else {
        day['source_device_model'] = 'Xiaomi Smart Band 8';
        day['steps_count'] = (day['steps_count'] as int? ?? 6000) - 1900;
        day['heart_rate_avg_bpm'] =
            ((day['heart_rate_avg_bpm'] as num?)?.toDouble() ?? 70) + 4;
      }
      summaries[index] = day;
    }
    return summaries;
  }

  static List<Map<String, dynamic>> _screeningCatalogJsonForProfile(
    String profileId,
  ) {
    final catalog = _cloneListOfMaps(_screeningCatalogJson());
    if (profileId == childManagedProfileId) {
      if (catalog.isNotEmpty) {
        catalog[0]['code'] = 'pediatric_vision';
        catalog[0]['name'] = 'Pediatric vision check';
        catalog[0]['category'] = 'pediatric';
      }
    }
    if (profileId == seniorManagedProfileId && catalog.length > 1) {
      catalog[1]['code'] = 'bone_density';
      catalog[1]['name'] = 'Bone density scan';
      catalog[1]['category'] = 'geriatric';
      catalog[1]['interval_months'] = 18;
    }
    return catalog;
  }

  static List<Map<String, dynamic>> _myScreeningsJsonForProfile(
    String profileId,
  ) {
    final screenings = _cloneListOfMaps(_myScreeningsJson());
    if (profileId == primaryProfileId) {
      return screenings;
    }

    for (var index = 0; index < screenings.length; index++) {
      final item = screenings[index];
      item['id'] = '$profileId-scr-${index + 1}';
      if (profileId == childManagedProfileId) {
        if (index == 0) {
          item['screening_code'] = 'pediatric_vision';
          item['screening_name'] = 'Pediatric vision check';
          item['screening_category'] = 'pediatric';
          item['status'] = 'recommended';
        } else {
          item['screening_code'] = 'vaccination_review';
          item['screening_name'] = 'Vaccination review';
          item['screening_category'] = 'pediatric';
          item['status'] = 'up_to_date';
          item['completed_this_year'] = true;
        }
      } else {
        if (index == 0) {
          item['screening_code'] = 'blood_pressure';
          item['screening_name'] = 'Blood pressure check';
          item['screening_category'] = 'cardiovascular';
          item['status'] = 'recommended';
        } else {
          item['screening_code'] = 'bone_density';
          item['screening_name'] = 'Bone density scan';
          item['screening_category'] = 'geriatric';
          item['status'] = 'recommended';
          item['completed_this_year'] = false;
        }
      }
      screenings[index] = item;
    }
    return screenings;
  }

  static Map<String, dynamic> _preventionCenterJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _preventionCenterJson();
    }
    final center = _cloneMap(_preventionCenterJson());
    final profile = _coreProfileJsonForId(profileId);
    center['display_name'] = _displayNameForProfile(profileId);
    center['age'] = _ageForProfile(profileId);
    center['biological_sex'] = profile['biological_sex'];
    center['region_code'] = 'IT';

    final annualVisit = Map<String, dynamic>.from(
      center['annual_visit'] as Map<String, dynamic>,
    );
    annualVisit['source_id'] = profileId;
    if (profileId == childManagedProfileId) {
      annualVisit['title'] = 'Pediatric annual visit';
      annualVisit['subtitle'] = 'Growth and vaccination review';
      annualVisit['reason'] = 'Routine pediatric preventive care';
      annualVisit['priority'] = 'normal';
    } else {
      annualVisit['title'] = 'Chronic care follow-up';
      annualVisit['subtitle'] = 'Blood pressure and thyroid review';
      annualVisit['reason'] = 'Geriatric prevention and chronic monitoring';
      annualVisit['priority'] = 'high';
    }
    center['annual_visit'] = annualVisit;
    return center;
  }

  static Map<String, dynamic> _historyDayJsonForProfile(
    String profileId,
    DateTime targetDate, {
    bool includeRollups = false,
  }) {
    if (profileId == primaryProfileId) {
      return _historyDayJson(targetDate, includeRollups: includeRollups);
    }

    final target = DateTime.utc(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final dayString = _date(target);

    Map<String, dynamic>? dailyEntry;
    for (final entry in _dailyEntriesJsonForProfile(profileId)) {
      if (entry['entry_date'].toString() == dayString) {
        dailyEntry = entry;
        break;
      }
    }

    final wearables = _wearableSummariesJsonForProfile(profileId);
    final timeline = _timelineJsonForProfile(profileId)
        .where(
          (item) =>
              _date(DateTime.parse(item['event_date'].toString())) == dayString,
        )
        .toList(growable: false);
    final documents = _documentsJsonForProfile(profileId)
        .where((item) {
          final examDate = item['exam_date']?.toString();
          return examDate != null &&
              _date(DateTime.parse(examDate)) == dayString;
        })
        .toList(growable: false);

    return {
      'target_date': dayString,
      'daily_entry': dailyEntry,
      'daily_summary': _insightJsonForProfile(
        profileId,
        summaryType: 'daily',
        referenceDate: target,
      ),
      'weekly_summary': includeRollups
          ? _insightJsonForProfile(
              profileId,
              summaryType: 'weekly',
              referenceDate: target,
            )
          : null,
      'monthly_summary': includeRollups
          ? _insightJsonForProfile(
              profileId,
              summaryType: 'monthly',
              referenceDate: target,
            )
          : null,
      'wearable_summary': () {
        var selectedWearable = wearables.first;
        for (final item in wearables) {
          if (item['summary_date'].toString() == dayString) {
            selectedWearable = item;
            break;
          }
        }
        return selectedWearable;
      }(),
      'documents': documents,
      'timeline_events': timeline,
    };
  }

  static Map<String, dynamic> _historyActivityJsonForProfile(
    String profileId,
    DateTime start,
    DateTime end,
  ) {
    if (profileId == primaryProfileId) {
      return _historyActivityJson(start, end);
    }
    final activityDays = <String>[];
    for (final entry in _dailyEntriesJsonForProfile(profileId)) {
      final day = DateTime.parse(entry['entry_date'].toString());
      if (!day.isBefore(start) && !day.isAfter(end)) {
        activityDays.add(entry['entry_date'].toString());
      }
    }
    return {'activity_dates': activityDays};
  }

  static Map<String, dynamic> _latestReportJsonForProfile(String profileId) {
    if (profileId == primaryProfileId) {
      return _latestReportJson();
    }
    final report = _cloneMap(_latestReportJson());
    report['id'] = 'report-$profileId';
    report['title'] =
        'Monthly Clinical Report - ${_displayNameForProfile(profileId)}';
    report['summary_excerpt'] =
        '${_profileContextLabel(profileId)} stable trend with actionable prevention suggestions.';
    return report;
  }

  static Map<String, dynamic> _healthDossierJsonForProfile(String profileId) {
    if (profileId == primaryProfileId) {
      return _healthDossierJson();
    }

    final now = DateTime.now().toUtc();
    final profile = _coreProfileJsonForId(profileId);
    final allergies = _allergiesJsonForProfile(profileId);
    final conditions = _medicalConditionsJsonForProfile(profileId);
    final medications = _medicationsJsonForProfile(profileId);
    final vaccinations = _vaccinationsJsonForProfile(profileId);
    final episodes = _clinicalEpisodesJsonForProfile(profileId);
    final dailyEntries = _dailyEntriesJsonForProfile(profileId);
    final documents = _documentsJsonForProfile(profileId);
    final alerts = _alertsJsonForProfile(profileId);
    final wearables = _wearableSummariesJsonForProfile(profileId);

    final activeProblems = conditions
        .map((item) => item['name']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final activeMeds = medications
        .map((item) => '${item['name']} ${item['dosage']}')
        .toList(growable: false);
    final allergyNames = allergies
        .map((item) => item['allergen']?.toString())
        .whereType<String>()
        .toList(growable: false);

    return {
      'generated_at': now.toIso8601String(),
      'display_name': _displayNameForProfile(profileId),
      'age': _ageForProfile(profileId),
      'biological_sex': profile['biological_sex'],
      'profile_facts': [
        {'label': 'Region', 'value': 'IT'},
        {
          'label': 'Relationship',
          'value': profile['relationship_label']?.toString() ?? 'managed',
        },
      ],
      'provenance_facts': [
        {'label': 'Last sync', 'value': now.toIso8601String()},
      ],
      'emergency_summary': {
        'generated_at': now.toIso8601String(),
        'headline': 'No acute emergency risk detected',
        'key_points': [
          '${_profileContextLabel(profileId)} profile overview up to date',
          if (allergyNames.isNotEmpty)
            'Known allergies: ${allergyNames.join(', ')}',
        ],
        'active_problems': activeProblems,
        'active_medications': activeMeds,
        'allergies': allergyNames,
        'conditions': activeProblems,
        'open_alerts': alerts
            .map((item) => item['title']?.toString())
            .whereType<String>()
            .take(2)
            .toList(growable: false),
        'latest_wearable_summary': wearables.isEmpty
            ? null
            : 'Average HR ${wearables.first['heart_rate_avg_bpm']} bpm, steps ${wearables.first['steps_count']}',
        'latest_report_summary':
            'Latest profile-specific monthly report generated successfully.',
      },
      'allergies': allergies,
      'medical_conditions': conditions,
      'medications': medications,
      'family_history': _familyHistoryJsonForProfile(profileId),
      'vaccinations': vaccinations,
      'clinical_episodes': episodes,
      'recent_daily_entries': dailyEntries,
      'recent_documents': documents
          .map(
            (doc) => {
              'id': doc['id'],
              'title': doc['title'],
              'document_type': doc['document_type'],
              'upload_date': doc['upload_date'],
              'exam_date': doc['exam_date'],
              'source': doc['source'],
              'parsed_status': doc['parsed_status'],
              'context_status': doc['context_status'],
            },
          )
          .toList(growable: false),
      'recent_lab_panels': [
        {
          'document_id': 'doc-1',
          'document_title': documents.first['title'],
          'panel_name': 'Routine panel',
          'panel_date': documents.first['exam_date'],
          'abnormal_results_count': 1,
          'key_results': ['One mildly out-of-range marker for follow-up'],
        },
      ],
      'recent_imaging_reports': [
        {
          'document_id': 'doc-2',
          'document_title': documents.last['title'],
          'exam_date': documents.last['exam_date'],
          'exam_type': 'Follow-up report',
          'body_part': 'General',
          'impression': 'Stable trend compared to previous assessment.',
        },
      ],
      'device_measurement_summaries': [
        {
          'provider_code': 'health_connect',
          'provider_name': 'Health Connect',
          'metric_type': 'heart_rate',
          'metric_label': 'Heart rate',
          'measurement_count': 18,
          'latest_measured_at': now
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'latest_value': '${wearables.first['heart_rate_avg_bpm']} bpm',
          'trend_label': 'stable',
          'concern_level': 'low',
          'concern_note': null,
          'summary': 'Consistent wearable trend in recent days.',
        },
      ],
      'recent_insights': [
        _insightJsonForProfile(profileId, summaryType: 'daily'),
        _insightJsonForProfile(profileId, summaryType: 'weekly'),
      ],
      'recent_reports': [
        {
          'id': 'report-$profileId',
          'report_type': 'monthly',
          'title':
              'Monthly Clinical Report - ${_displayNameForProfile(profileId)}',
          'period_start': now
              .subtract(const Duration(days: 30))
              .toIso8601String(),
          'period_end': now.toIso8601String(),
          'generated_at': now.toIso8601String(),
          'summary_excerpt':
              'Profile-specific trend remains stable with preventive actions tracked.',
        },
      ],
      'alerts': alerts,
      'wearable_summaries': wearables,
    };
  }

  static List<Map<String, dynamic>> _gemmaCenterHistoryJsonForProfile(
    String profileId,
  ) {
    if (profileId == primaryProfileId) {
      return _gemmaCenterHistoryJson();
    }
    final history = _cloneListOfMaps(_gemmaCenterHistoryJson());
    final docs = _documentsJsonForProfile(profileId);
    for (var index = 0; index < history.length; index++) {
      final entry = history[index];
      entry['id'] = '$profileId-gh-${index + 1}';
      entry['title'] = '${_profileContextLabel(profileId)} ${entry['title']}';
      if (entry['response'] is String) {
        entry['response'] =
            '${_displayNameForProfile(profileId)}: ${entry['response']}';
      }
      if (entry['document_id'] != null && docs.isNotEmpty) {
        entry['document_title'] = docs.first['title'];
      }
      history[index] = entry;
    }
    return history;
  }

  static Map<String, dynamic> _insightJsonForProfile(
    String profileId, {
    required String summaryType,
    DateTime? referenceDate,
    String provider = 'local_gemma4',
  }) {
    if (profileId == primaryProfileId) {
      return _insightJson(
        summaryType: summaryType,
        referenceDate: referenceDate,
        provider: provider,
      );
    }
    final summary = _cloneMap(
      _insightJson(
        summaryType: summaryType,
        referenceDate: referenceDate,
        provider: provider,
      ),
    );
    summary['id'] = '$profileId-${summary['id']}';
    summary['content'] =
        '${_profileContextLabel(profileId)} ${summary['content']}';
    return summary;
  }

  static String _displayNameForProfile(String profileId) {
    final profile = _coreProfileJsonForId(profileId);
    final first = profile['first_name']?.toString().trim() ?? '';
    final last = profile['last_name']?.toString().trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isEmpty) {
      return 'Demo Profile';
    }
    return combined;
  }

  static int _ageForProfile(String profileId) {
    final profile = _coreProfileJsonForId(profileId);
    final birthDateRaw = profile['birth_date']?.toString();
    if (birthDateRaw == null || birthDateRaw.isEmpty) {
      return 35;
    }
    final parsed = DateTime.tryParse(birthDateRaw);
    if (parsed == null) {
      return 35;
    }
    final now = DateTime.now().toUtc();
    var years = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      years -= 1;
    }
    return years;
  }

  static String _profileContextLabel(String profileId) {
    if (profileId == childManagedProfileId) {
      return 'Pediatric profile';
    }
    if (profileId == seniorManagedProfileId) {
      return 'Senior profile';
    }
    return 'Primary profile';
  }

  static Map<String, dynamic> _cloneMap(Map<String, dynamic> map) {
    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode(map)) as Map<String, dynamic>,
    );
  }

  static List<Map<String, dynamic>> _cloneListOfMaps(
    List<Map<String, dynamic>> list,
  ) {
    return (jsonDecode(jsonEncode(list)) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }
}
