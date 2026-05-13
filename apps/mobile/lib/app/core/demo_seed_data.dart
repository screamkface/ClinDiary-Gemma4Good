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
  static const String _seedVersion = '2026-04-18-v4';

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
            'title': 'Comprehensive metabolic panel - Apr 2026',
            'document_type': 'lab_report',
            'source': 'Milan Community Clinic',
            'exam_date': '2026-04-10',
            'content':
                'Patient: Marco Rossi\nCreatinine: 1.31 mg/dL (reference 0.67-1.17) [OUT OF RANGE - high]\neGFR: 68 mL/min/1.73m2 (reference > 90) [OUT OF RANGE - low]\nPotassium: 5.2 mmol/L (reference 3.5-5.1) [OUT OF RANGE - high]\nComment: Renal trend slightly worse than Jan 2026 (creatinine 1.22). Reinforce hydration and repeat in 6-8 weeks.',
          },
          {
            'title': 'Lipid and glucose follow-up - Mar 2026',
            'document_type': 'lab_report',
            'source': 'Milan Community Clinic',
            'exam_date': '2026-03-22',
            'content':
                'Patient: Marco Rossi\nLDL cholesterol: 138 mg/dL (target < 115) [OUT OF RANGE - high]\nTriglycerides: 176 mg/dL (reference < 150) [OUT OF RANGE - high]\nHbA1c: 5.8% (reference 4.0-5.6) [OUT OF RANGE - high]\nComment: Family history of diabetes and hypercholesterolemia noted. Continue Mediterranean diet and increase aerobic exercise frequency.',
          },
          {
            'title': 'CBC and inflammation panel - Jan 2026',
            'document_type': 'lab_report',
            'source': 'Poliambulatorio San Marco',
            'exam_date': '2026-01-14',
            'content':
                'Patient: Marco Rossi\nhs-CRP: 4.2 mg/L (reference < 3.0) [OUT OF RANGE - high]\nCreatinine: 1.22 mg/dL (reference 0.67-1.17) [OUT OF RANGE - high]\nHemoglobin: 14.6 g/dL (reference 13.5-17.5)\nComment: Low-grade inflammatory signal with persistent mild renal marker elevation; monitor trend quarterly.',
          },
          {
            'title': 'Renal baseline comparison - Nov 2025',
            'document_type': 'lab_report',
            'source': 'Poliambulatorio San Marco',
            'exam_date': '2025-11-07',
            'content':
                'Patient: Marco Rossi\nCreatinine: 1.18 mg/dL (reference 0.67-1.17) [OUT OF RANGE - high]\neGFR: 75 mL/min/1.73m2 (reference > 90) [OUT OF RANGE - low]\nUrea: 43 mg/dL (reference 17-43)\nComment: Earliest available value in this local history. Useful baseline for renal trend questions.',
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

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final monthEnd = nextMonth.subtract(const Duration(days: 1));

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
      key: _scopedFor('gemma_center_history', profileId),
      payload: jsonEncode(_gemmaCenterHistoryJsonForProfile(profileId)),
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

  static List<AppNotificationItem> demoNotifications() {
    return _notificationsJson()
        .map((item) => AppNotificationItem.fromJson(item))
        .toList(growable: false);
  }

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

  static List<TimelineEventItem> demoTimelineEvents() {
    return _timelineJson()
        .map((item) => TimelineEventItem.fromJson(item))
        .toList(growable: false);
  }

  static List<ClinicalDocumentSummary> demoDocuments() {
    return _documentsJson()
        .map((item) => ClinicalDocumentSummary.fromJson(item))
        .toList(growable: false);
  }

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
      'storage_location': 'cloud',
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

  static String _scopedFor(String baseKey, String profileId) {
    return scopedCacheKey(baseKey, profileId);
  }

  static String _date(DateTime date) => date.toIso8601String().split('T').first;

  static DateTime _todayUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  static List<Map<String, dynamic>> _dailyEntriesJson() {
    final today = _todayUtc();
    return [
      {
        'id': 'de-001',
        'entry_date': _date(today),
        'sleep_hours': 7.4,
        'sleep_quality': 8,
        'energy_level': 7,
        'mood_level': 8,
        'stress_level': 3,
        'appetite_level': 7,
        'hydration_level': 8,
        'general_pain': 1,
        'general_notes':
            'Good day overall. Light neck stiffness after long desk work.',
        'symptoms': [
          {
            'id': 'sym-001',
            'symptom_code': 'neck_stiffness',
            'severity': 2,
            'duration_minutes': 90,
            'body_location': 'neck',
            'metadata_json': {'trigger': 'desk work'},
          },
        ],
        'vitals': [
          {
            'id': 'vit-001',
            'type': 'blood_pressure',
            'value': '118/76',
            'unit': 'mmHg',
            'measured_at': today
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
          {
            'id': 'vit-002',
            'type': 'heart_rate',
            'value': '63',
            'unit': 'bpm',
            'measured_at': today
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
        ],
      },
      {
        'id': 'de-002',
        'entry_date': _date(today.subtract(const Duration(days: 1))),
        'sleep_hours': 6.8,
        'sleep_quality': 6,
        'energy_level': 6,
        'mood_level': 7,
        'stress_level': 5,
        'appetite_level': 6,
        'hydration_level': 7,
        'general_pain': 2,
        'general_notes': 'Busy workday, mild reflux after dinner.',
        'symptoms': [
          {
            'id': 'sym-002',
            'symptom_code': 'acid_reflux',
            'severity': 3,
            'duration_minutes': 40,
            'body_location': 'abdomen',
            'metadata_json': {'after_meal': true},
          },
        ],
        'vitals': [
          {
            'id': 'vit-003',
            'type': 'blood_pressure',
            'value': '124/79',
            'unit': 'mmHg',
            'measured_at': today
                .subtract(const Duration(days: 1))
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
          {
            'id': 'vit-004',
            'type': 'heart_rate',
            'value': '69',
            'unit': 'bpm',
            'measured_at': today
                .subtract(const Duration(days: 1))
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
        ],
      },
      {
        'id': 'de-003',
        'entry_date': _date(today.subtract(const Duration(days: 2))),
        'sleep_hours': 8.1,
        'sleep_quality': 9,
        'energy_level': 8,
        'mood_level': 8,
        'stress_level': 2,
        'appetite_level': 8,
        'hydration_level': 8,
        'general_pain': 0,
        'general_notes':
            'Preventive checkup done. Doctor confirmed stable clinical trend.',
        'symptoms': [],
        'vitals': [
          {
            'id': 'vit-005',
            'type': 'blood_pressure',
            'value': '116/74',
            'unit': 'mmHg',
            'measured_at': today
                .subtract(const Duration(days: 2))
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
          {
            'id': 'vit-006',
            'type': 'heart_rate',
            'value': '61',
            'unit': 'bpm',
            'measured_at': today
                .subtract(const Duration(days: 2))
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
        ],
      },
      {
        'id': 'de-004',
        'entry_date': _date(today.subtract(const Duration(days: 3))),
        'sleep_hours': 7.0,
        'sleep_quality': 7,
        'energy_level': 7,
        'mood_level': 7,
        'stress_level': 4,
        'appetite_level': 7,
        'hydration_level': 7,
        'general_pain': 1,
        'general_notes': 'Moderate activity, no relevant symptoms.',
        'symptoms': [],
        'vitals': [
          {
            'id': 'vit-007',
            'type': 'blood_pressure',
            'value': '120/77',
            'unit': 'mmHg',
            'measured_at': today
                .subtract(const Duration(days: 3))
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
        ],
      },
      {
        'id': 'de-005',
        'entry_date': _date(today.subtract(const Duration(days: 5))),
        'sleep_hours': 6.9,
        'sleep_quality': 6,
        'energy_level': 6,
        'mood_level': 6,
        'stress_level': 5,
        'appetite_level': 6,
        'hydration_level': 6,
        'general_pain': 2,
        'general_notes': 'Late shift. Slight headache at evening.',
        'symptoms': [
          {
            'id': 'sym-003',
            'symptom_code': 'headache',
            'severity': 3,
            'duration_minutes': 60,
            'body_location': 'head',
            'metadata_json': {'possible_trigger': 'sleep_deprivation'},
          },
        ],
        'vitals': [
          {
            'id': 'vit-008',
            'type': 'heart_rate',
            'value': '71',
            'unit': 'bpm',
            'measured_at': today
                .subtract(const Duration(days: 5))
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
        ],
      },
    ];
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
    };
  }

  static List<Map<String, dynamic>> _alertsJson() {
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'alert-1',
        'severity': 'medium',
        'alert_type': 'screening_due',
        'rule_code': 'bp_followup',
        'title': 'Blood pressure follow-up due',
        'description':
            'Your preventive blood pressure check should be repeated this month.',
        'status': 'open',
        'source_type': 'screening',
        'source_id': 'scr-1',
        'triggered_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'resolved_at': null,
        'resolution_notes': null,
      },
      {
        'id': 'alert-2',
        'severity': 'low',
        'alert_type': 'medication_missed',
        'rule_code': 'med_adherence',
        'title': 'Medication adherence warning',
        'description': 'One evening dose was skipped in the last 7 days.',
        'status': 'open',
        'source_type': 'medication',
        'source_id': 'med-1',
        'triggered_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'resolved_at': null,
        'resolution_notes': null,
      },
    ];
  }

  static List<Map<String, dynamic>> _timelineJson() {
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'tl-1',
        'event_type': 'daily_entry',
        'title': 'Daily check-in completed',
        'description': 'Today check-in logged with vitals and symptoms.',
        'event_date': now.subtract(const Duration(hours: 6)).toIso8601String(),
        'severity': null,
      },
      {
        'id': 'tl-2',
        'event_type': 'document_uploaded',
        'title': 'Lab report uploaded',
        'description': 'Blood panel document added to clinical archive.',
        'event_date': now.subtract(const Duration(days: 3)).toIso8601String(),
        'severity': null,
      },
      {
        'id': 'tl-3',
        'event_type': 'alert',
        'title': 'Preventive check suggested',
        'description':
            'Blood pressure annual control suggested by prevention rules.',
        'event_date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'severity': 'medium',
      },
    ];
  }

  static List<Map<String, dynamic>> _documentFoldersJson() {
    return [
      {
        'id': 'folder-1',
        'name': 'Lab Results',
        'parent_folder_id': null,
        'path_label': 'Lab Results',
        'child_folder_count': 0,
        'document_count': 1,
      },
      {
        'id': 'folder-2',
        'name': 'Cardiology',
        'parent_folder_id': null,
        'path_label': 'Cardiology',
        'child_folder_count': 0,
        'document_count': 1,
      },
    ];
  }

  static List<Map<String, dynamic>> _documentsJson() {
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'doc-1',
        'folder_id': 'folder-1',
        'folder_name': 'Lab Results',
        'title': 'Blood panel March 2026',
        'document_type': 'laboratory_report',
        'upload_date': now.subtract(const Duration(days: 20)).toIso8601String(),
        'exam_date': now.subtract(const Duration(days: 22)).toIso8601String(),
        'source': 'Milan Community Clinic',
        'original_filename': 'blood_panel_2026_03.pdf',
        'mime_type': 'application/pdf',
        'file_size_bytes': 245000,
        'parsed_status': 'completed',
        'context_status': 'active',
        'classification_confidence': 0.96,
        'parsing_confidence': 0.93,
        'processing_error': null,
        'pending_sync': false,
        'storage_location': 'cloud',
        'local_file_path': null,
      },
      {
        'id': 'doc-2',
        'folder_id': 'folder-2',
        'folder_name': 'Cardiology',
        'title': 'ECG follow-up February 2026',
        'document_type': 'cardiology_report',
        'upload_date': now.subtract(const Duration(days: 48)).toIso8601String(),
        'exam_date': now.subtract(const Duration(days: 50)).toIso8601String(),
        'source': 'Poliambulatorio San Marco',
        'original_filename': 'ecg_followup_2026_02.pdf',
        'mime_type': 'application/pdf',
        'file_size_bytes': 168000,
        'parsed_status': 'completed',
        'context_status': 'active',
        'classification_confidence': 0.94,
        'parsing_confidence': 0.91,
        'processing_error': null,
        'pending_sync': false,
        'storage_location': 'cloud',
        'local_file_path': null,
      },
    ];
  }

  static Map<String, dynamic> _documentDetailJson(String documentId) {
    final docs = _documentsJson();
    final selected = docs.firstWhere(
      (item) => item['id'].toString() == documentId,
      orElse: () => docs.first,
    );

    final isLab = selected['document_type'] == 'laboratory_report';
    return {
      ...selected,
      'file_url': 'https://demo.clindiary.app/files/${selected['id']}.pdf',
      'ocr_text': isLab
          ? 'CBC and lipid panel: values mostly within normal range. LDL slightly elevated.'
          : 'ECG report: sinus rhythm, no acute ischemic changes.',
      'viewer_url': 'https://demo.clindiary.app/viewer/${selected['id']}',
      'processed_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 10))
          .toIso8601String(),
      'lab_panels': isLab
          ? [
              {
                'id': 'panel-1',
                'panel_name': 'Complete Blood Count',
                'panel_date': selected['exam_date'],
                'confidence_score': 0.95,
                'results': [
                  {
                    'id': 'res-1',
                    'analyte_name': 'Hemoglobin',
                    'value': '14.2',
                    'unit': 'g/dL',
                    'ref_min': 13.5,
                    'ref_max': 17.5,
                    'abnormal_flag': false,
                    'confidence_score': 0.97,
                  },
                  {
                    'id': 'res-2',
                    'analyte_name': 'LDL Cholesterol',
                    'value': '132',
                    'unit': 'mg/dL',
                    'ref_min': 0,
                    'ref_max': 129,
                    'abnormal_flag': true,
                    'confidence_score': 0.92,
                  },
                ],
              },
            ]
          : <Map<String, dynamic>>[],
      'imaging_reports': isLab
          ? <Map<String, dynamic>>[]
          : [
              {
                'id': 'img-1',
                'exam_type': 'ECG',
                'body_part': 'Heart',
                'report_text': 'Regular sinus rhythm. No acute abnormalities.',
                'impression': 'Stable compared with previous tracing.',
                'confidence_score': 0.94,
              },
            ],
    };
  }

  static List<Map<String, dynamic>> _notificationsJson() {
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'notif-1',
        'patient_id': primaryProfileId,
        'notification_type': 'daily_checkin',
        'title': 'Daily check-in reminder',
        'body': 'Remember to complete your daily check-in before 21:00.',
        'priority': 'normal',
        'read_status': false,
        'read_at': null,
        'source_type': 'daily_entry',
        'source_id': 'de-001',
        'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'id': 'notif-2',
        'patient_id': primaryProfileId,
        'notification_type': 'screening',
        'title': 'Blood pressure follow-up',
        'body': 'Your annual blood pressure follow-up is due this month.',
        'priority': 'high',
        'read_status': true,
        'read_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'source_type': 'screening',
        'source_id': 'scr-1',
        'created_at': now
            .subtract(const Duration(days: 1, hours: 4))
            .toIso8601String(),
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
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'ml-1',
        'medication_id': 'med-1',
        'medication_name': 'Lisinopril',
        'medication_dosage': '10 mg',
        'scheduled_at': now
            .subtract(const Duration(hours: 10))
            .toIso8601String(),
        'taken_at': now
            .subtract(const Duration(hours: 9, minutes: 45))
            .toIso8601String(),
        'status': 'taken',
        'notes': 'On time',
        'pending_sync': false,
      },
      {
        'id': 'ml-2',
        'medication_id': 'med-2',
        'medication_name': 'Pantoprazole',
        'medication_dosage': '20 mg',
        'scheduled_at': now
            .subtract(const Duration(days: 2, hours: 6))
            .toIso8601String(),
        'taken_at': null,
        'status': 'missed',
        'notes': 'Forgot at work',
        'pending_sync': false,
      },
    ];
  }

  static List<Map<String, dynamic>> _wearableSummariesJson() {
    final today = _todayUtc();
    return [
      {
        'id': 'wear-1',
        'summary_date': _date(today),
        'source_platform': 'health_connect',
        'source_name': 'Xiaomi Fitness',
        'source_device_model': 'Xiaomi Smart Band 8',
        'steps_count': 8560,
        'active_energy_kcal': 472.5,
        'exercise_minutes': 54,
        'distance_meters': 6120,
        'sleep_minutes': 430,
        'sleep_deep_minutes': 95,
        'sleep_rem_minutes': 88,
        'heart_rate_avg_bpm': 66,
        'heart_rate_min_bpm': 51,
        'heart_rate_max_bpm': 132,
        'resting_heart_rate_bpm': 58,
        'blood_oxygen_avg_pct': 97,
        'hrv_sdnn_ms': 39,
        'record_count': 124,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      },
      {
        'id': 'wear-2',
        'summary_date': _date(today.subtract(const Duration(days: 1))),
        'source_platform': 'health_connect',
        'source_name': 'Xiaomi Fitness',
        'source_device_model': 'Xiaomi Smart Band 8',
        'steps_count': 7210,
        'active_energy_kcal': 390.2,
        'exercise_minutes': 41,
        'distance_meters': 5050,
        'sleep_minutes': 402,
        'sleep_deep_minutes': 80,
        'sleep_rem_minutes': 74,
        'heart_rate_avg_bpm': 68,
        'heart_rate_min_bpm': 53,
        'heart_rate_max_bpm': 128,
        'resting_heart_rate_bpm': 59,
        'blood_oxygen_avg_pct': 97,
        'hrv_sdnn_ms': 35,
        'record_count': 117,
        'synced_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      },
    ];
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
    final now = DateTime.now().toUtc();
    return {
      'generated_at': now.toIso8601String(),
      'display_name': 'Marco Rossi',
      'age': 37,
      'biological_sex': 'male',
      'region_name': 'Lombardia',
      'overview': {
        'actionable_screenings': 1,
        'vaccine_reviews': 1,
        'vaccine_registry_items': 1,
        'pregnancy_items': 0,
        'shared_decision_items': 1,
        'seasonal_checks': 1,
        'follow_up_items': 2,
      },
      'annual_visit': {
        'code': 'annual_visit',
        'title': 'Annual GP visit',
        'subtitle': 'Review blood pressure and medications',
        'reason': 'Mild hypertension follow-up',
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
          'reason': 'Trend near threshold',
          'action_hint': 'Measure at least 3 times/week',
          'cadence_label': 'Monthly',
          'status': 'recommended',
          'priority': 'high',
          'category': 'cardiovascular',
          'kind': 'screening',
          'source_type': 'screening',
          'source_id': 'scr-1',
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
          'subtitle': 'Lifestyle vs pharmacological step-up',
          'reason': 'LDL slightly above reference',
          'action_hint': 'Review with GP at next visit',
          'cadence_label': 'At next visit',
          'status': 'review',
          'priority': 'normal',
          'category': 'metabolic',
          'kind': 'shared_decision',
          'source_type': 'document',
          'source_id': 'doc-1',
        },
      ],
      'seasonal_checks': [
        {
          'code': 'allergy_season',
          'title': 'Allergy symptom monitoring',
          'subtitle': 'Spring period',
          'reason': 'History of dust-related rhinitis',
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
          'subtitle': 'One missed dose last week',
          'reason': 'Improve consistency for BP control',
          'action_hint': 'Enable stronger reminder notifications',
          'cadence_label': 'Weekly',
          'status': 'recommended',
          'priority': 'normal',
          'category': 'medication',
          'kind': 'follow_up',
          'source_type': 'medication',
          'source_id': 'med-1',
        },
      ],
    };
  }

  static Map<String, dynamic> _insightJson({
    required String summaryType,
    DateTime? referenceDate,
    String provider = 'local_gemma4',
  }) {
    final now = DateTime.now().toUtc();
    final baseDate = referenceDate?.toUtc() ?? now;
    DateTime start;
    DateTime end;
    String content;

    switch (summaryType) {
      case 'weekly':
        end = DateTime.utc(baseDate.year, baseDate.month, baseDate.day);
        start = end.subtract(const Duration(days: 6));
        content =
            'Weekly trend: blood pressure stable, adherence good, one missed medication event. Continue hydration and regular exercise.';
        break;
      case 'monthly':
        start = DateTime.utc(baseDate.year, baseDate.month, 1);
        final nextMonth = baseDate.month == 12
            ? DateTime.utc(baseDate.year + 1, 1, 1)
            : DateTime.utc(baseDate.year, baseDate.month + 1, 1);
        end = nextMonth.subtract(const Duration(days: 1));
        content =
            'Monthly recap: overall positive trend. Cardiovascular indicators remain acceptable. Recommended next step: repeat blood pressure screening.';
        break;
      default:
        start = DateTime.utc(baseDate.year, baseDate.month, baseDate.day);
        end = start;
        content =
            'Daily recap: stable vitals, mild stress-related symptoms, no acute concerns. Suggested action: short evening walk and hydration.';
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
      'wearable_summary': _wearableSummariesJson().first,
      'documents': _documentsJson(),
      'timeline_events': _timelineJson(),
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
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'share-1',
        'scope': 'full',
        'label': 'GP consultation package',
        'share_url': 'https://demo.clindiary.app/share/share-1',
        'filename': 'clindiary_dossier_marco_rossi.pdf',
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

  static Map<String, dynamic> _latestReportJson() {
    final now = DateTime.now().toUtc();
    final periodStart = now.subtract(const Duration(days: 30));
    return {
      'id': 'report-1',
      'report_type': 'monthly',
      'status': 'generated',
      'title': 'Monthly Clinical Report',
      'period_start': periodStart.toIso8601String(),
      'period_end': now.toIso8601String(),
      'summary_excerpt':
          'Stable blood pressure trend with improved medication adherence.',
      'content_text': 'Comprehensive monthly report content for demo.',
      'generated_at': now.toIso8601String(),
    };
  }

  static Map<String, dynamic> _healthDossierJson() {
    final now = DateTime.now().toUtc();
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
        'headline': 'No critical emergency risks detected',
        'key_points': [
          'Mild hypertension under monitoring',
          'Penicillin allergy',
        ],
        'active_problems': ['Mild hypertension', 'Reflux'],
        'active_medications': ['Lisinopril 10 mg', 'Pantoprazole 20 mg PRN'],
        'allergies': ['Penicillin', 'Dust mites'],
        'conditions': ['Mild hypertension', 'Gastroesophageal reflux'],
        'open_alerts': ['Blood pressure follow-up due'],
        'latest_wearable_summary': 'Average HR 66 bpm, steps 8.5k',
        'latest_report_summary': 'Monthly trend stable',
      },
      'allergies': _profileBundleJson()['allergies'],
      'medical_conditions': _profileBundleJson()['medical_conditions'],
      'medications': _profileBundleJson()['medications'],
      'family_history': _profileBundleJson()['family_history'],
      'vaccinations': _profileBundleJson()['vaccinations'],
      'clinical_episodes': _profileBundleJson()['clinical_episodes'],
      'recent_daily_entries': _dailyEntriesJson(),
      'recent_documents': _documentsJson()
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
          'document_id': 'doc-1',
          'document_title': 'Blood panel March 2026',
          'panel_name': 'Complete Blood Count',
          'panel_date': DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 22))
              .toIso8601String(),
          'abnormal_results_count': 1,
          'key_results': ['LDL 132 mg/dL (slightly elevated)'],
        },
      ],
      'recent_imaging_reports': [
        {
          'document_id': 'doc-2',
          'document_title': 'ECG follow-up February 2026',
          'exam_date': DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 50))
              .toIso8601String(),
          'exam_type': 'ECG',
          'body_part': 'Heart',
          'impression': 'Stable sinus rhythm',
        },
      ],
      'device_measurement_summaries': [
        {
          'provider_code': 'health_connect',
          'provider_name': 'Health Connect',
          'metric_type': 'blood_pressure',
          'metric_label': 'Blood pressure',
          'measurement_count': 18,
          'latest_measured_at': now
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'latest_value': '118/76 mmHg',
          'trend_label': 'stable',
          'concern_level': 'low',
          'concern_note': null,
          'summary': 'Values stable in recommended range.',
        },
      ],
      'recent_insights': [
        _insightJson(summaryType: 'daily'),
        _insightJson(summaryType: 'weekly'),
      ],
      'recent_reports': [
        {
          'id': 'report-1',
          'report_type': 'monthly',
          'title': 'Monthly Clinical Report',
          'period_start': now
              .subtract(const Duration(days: 30))
              .toIso8601String(),
          'period_end': now.toIso8601String(),
          'generated_at': now.toIso8601String(),
          'summary_excerpt':
              'Stable blood pressure and adherence improvements.',
        },
      ],
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
    final now = DateTime.now().toUtc();
    return [
      {
        'id': 'gh-1',
        'kind': 'question',
        'title': 'Can I keep running with my current blood pressure trend?',
        'response':
            'Your current trend is stable. Keep moderate running 3 times/week and monitor hydration and recovery.',
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'prompt': 'Can I keep running with my current blood pressure trend?',
        'reference_date': now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'document_id': null,
        'document_title': null,
      },
      {
        'id': 'gh-2',
        'kind': 'document_summary',
        'title': 'Summary: Blood panel March 2026',
        'response':
            'Main findings: LDL slightly elevated, all other CBC markers within reference ranges.',
        'created_at': now.subtract(const Duration(days: 3)).toIso8601String(),
        'prompt': null,
        'reference_date': now
            .subtract(const Duration(days: 3))
            .toIso8601String(),
        'document_id': 'doc-1',
        'document_title': 'Blood panel March 2026',
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
      'managed_profiles': _managedProfilesForProfile(profileId),
    };
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
    final selected = docs.firstWhere(
      (item) => item['id']?.toString() == documentId,
      orElse: () => docs.first,
    );
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
            (day['heart_rate_avg_bpm'] as int? ?? 70) + 9;
      } else {
        day['source_device_model'] = 'Xiaomi Smart Band 8';
        day['steps_count'] = (day['steps_count'] as int? ?? 6000) - 1900;
        day['heart_rate_avg_bpm'] =
            (day['heart_rate_avg_bpm'] as int? ?? 70) + 4;
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
      'wearable_summary': _wearableSummariesJsonForProfile(profileId).first,
      'documents': _documentsJsonForProfile(profileId),
      'timeline_events': _timelineJsonForProfile(profileId),
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
