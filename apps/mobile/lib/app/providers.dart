import 'package:clindiary/app/dependencies.dart';
import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/billing/domain/billing_status.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/auth/presentation/auth_controller.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/devices/domain/device_hub.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
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
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:clindiary/app/dependencies.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final profileBundleProvider = FutureProvider<ProfileBundle?>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return null;
  }
  return ref.watch(profileRepositoryProvider).fetchProfile();
});

final billingStatusProvider = FutureProvider<BillingStatus?>((ref) async {
  final session = ref.watch(authControllerProvider).asData?.value;
  if (session == null) {
    return null;
  }
  return ref.watch(billingRepositoryProvider).fetchStatus();
});

final activeProfileIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(profileRepositoryProvider).getActiveProfileId();
});

final profileRegionCodeProvider = FutureProvider<String>((ref) async {
  final bundle = await ref.watch(profileBundleProvider.future);
  return bundle?.profile.regionCode?.trim().toUpperCase() ?? 'IT';
});

final dailyEntriesProvider = FutureProvider<List<DailyEntry>>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(dailyJournalRepositoryProvider).fetchEntries();
});

final insightSummaryProvider =
    FutureProvider.family<InsightSummary, InsightSummaryQuery>((
      ref,
      query,
    ) async {
      final session = await ref.watch(authControllerProvider.future);
      if (session == null) {
        throw Exception('Sessione non disponibile');
      }
      return ref.watch(insightsRepositoryProvider).fetchSummary(query);
    });

final localAiStatusProvider = FutureProvider<LocalAiStatus>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return ref.watch(insightsRepositoryProvider).fetchLocalStatus();
});

final onDeviceAiStatusProvider = FutureProvider<OnDeviceAiStatus>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return ref.watch(insightsRepositoryProvider).fetchOnDeviceStatus();
});

final historyDayProvider = FutureProvider.family<HistoryDay, DateTime>((
  ref,
  targetDate,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return ref
      .watch(historyRepositoryProvider)
      .fetchDay(targetDate: targetDate, includeRollups: false);
});

final historyActivityDatesProvider =
    FutureProvider.family<List<DateTime>, DateTime>((ref, monthAnchor) async {
      final session = await ref.watch(authControllerProvider.future);
      if (session == null) {
        return const [];
      }
      final monthStart = DateTime(monthAnchor.year, monthAnchor.month, 1);
      final nextMonth = monthAnchor.month == 12
          ? DateTime(monthAnchor.year + 1, 1, 1)
          : DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
      final monthEnd = nextMonth.subtract(const Duration(days: 1));
      return ref
          .watch(historyRepositoryProvider)
          .fetchActivityDates(startDate: monthStart, endDate: monthEnd);
    });

final deviceOverviewProvider = FutureProvider<DeviceOverview>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return ref.watch(devicesRepositoryProvider).fetchOverview();
});

final alertsProvider = FutureProvider<List<ClinicalAlert>>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(alertsRepositoryProvider).fetchAlerts();
});

final screeningCatalogProvider = FutureProvider<List<ScreeningCatalogItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  final regionCode = await ref.watch(profileRegionCodeProvider.future);
  return ref
      .watch(screeningsRepositoryProvider)
      .fetchCatalog(regionCode: regionCode);
});

final myScreeningsProvider = FutureProvider<List<PatientScreeningStatusItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  final regionCode = await ref.watch(profileRegionCodeProvider.future);
  return ref
      .watch(screeningsRepositoryProvider)
      .fetchMyScreenings(regionCode: regionCode);
});

final preventionCenterProvider = FutureProvider<PreventionCenterData>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  final regionCode = await ref.watch(profileRegionCodeProvider.future);
  return ref
      .watch(preventionCenterRepositoryProvider)
      .fetchCenter(regionCode: regionCode);
});

final healthDossierProvider = FutureProvider<HealthDossier>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return ref.watch(dossierRepositoryProvider).fetchDossier();
});

final dossierShareLinksProvider = FutureProvider<List<DossierShareLinkItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(dossierRepositoryProvider).fetchShareLinks();
});

final medicationLogsProvider = FutureProvider<List<MedicationLogItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(medicationsRepositoryProvider).fetchLogs();
});

final notificationsProvider = FutureProvider<List<AppNotificationItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(notificationsRepositoryProvider).fetchNotifications();
});

final unreadNotificationsProvider = FutureProvider<bool>((ref) async {
  final notifications = await ref.watch(notificationsProvider.future);
  return notifications.any((item) => item.isUnread);
});

final notificationPreferencesProvider = FutureProvider<NotificationPreferences>(
  (ref) async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw Exception('Sessione non disponibile');
    }
    return ref.watch(notificationsRepositoryProvider).fetchPreferences();
  },
);

final localMedicationReminderStatusProvider =
    FutureProvider<LocalMedicationReminderStatus>((ref) async {
      final session = await ref.watch(authControllerProvider.future);
      if (session == null) {
        return const LocalMedicationReminderStatus(
          isSupported: true,
          permissionGranted: false,
          scheduledCount: 0,
          lastSyncedAt: null,
        );
      }
      return ref.watch(localMedicationReminderServiceProvider).getStatus();
    });

final pendingMedicationDosesProvider = FutureProvider<bool>((ref) async {
  final bundle = await ref.watch(profileBundleProvider.future);
  if (bundle == null) {
    return false;
  }

  final logs = await ref.watch(medicationLogsProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final plan = ref
      .watch(localMedicationReminderServiceProvider)
      .buildSchedulePlan(
        medications: bundle.medications,
        logs: logs,
        from: today,
        horizonDays: 1,
      );

  return plan.any(
    (item) =>
        DateUtils.isSameDay(item.scheduledAt, now) &&
        !item.scheduledAt.isAfter(now),
  );
});

final wearableSyncStatusProvider = FutureProvider<WearableSyncStatus>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const WearableSyncStatus.unsupported(
      message: 'Sessione non disponibile.',
    );
  }
  return ref.watch(wearableHealthServiceProvider).getStatus();
});

final wearableDailySummariesProvider = FutureProvider<List<WearableDaySummary>>(
  (ref) async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      return const [];
    }
    return ref.watch(wearablesRepositoryProvider).fetchDailySummaries();
  },
);

final pendingOperationsProvider = FutureProvider<List<PendingOperation>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(localDatabaseProvider).listPendingOperations(limit: 50);
});

final requestTracesProvider = FutureProvider<List<RequestTrace>>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(localDatabaseProvider).readRecentTraces(limit: 50);
});

final timelineEventsProvider = FutureProvider<List<TimelineEventItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(timelineRepositoryProvider).fetchEvents();
});

final documentsProvider = FutureProvider<List<ClinicalDocumentSummary>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(documentsRepositoryProvider).fetchDocuments();
});

final documentArchiveProvider =
    FutureProvider.family<DocumentArchiveView, DocumentArchiveQuery>((
      ref,
      query,
    ) async {
      final session = await ref.watch(authControllerProvider.future);
      if (session == null) {
        return const DocumentArchiveView(
          breadcrumbs: [],
          folders: [],
          documents: [],
          isSearch: false,
        );
      }
      return ref.watch(documentsRepositoryProvider).fetchArchive(
        folderId: query.folderId,
        query: query.searchQuery,
      );
    });

final documentFoldersProvider = FutureProvider<List<DocumentFolderItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return ref.watch(documentsRepositoryProvider).fetchFolders();
});

final documentDetailProvider =
    FutureProvider.family<ClinicalDocumentDetail, String>((
      ref,
      documentId,
    ) async {
      final session = await ref.watch(authControllerProvider.future);
      if (session == null) {
        throw Exception('Sessione non disponibile');
      }
      return ref
          .watch(documentsRepositoryProvider)
          .fetchDocumentDetail(documentId);
    });

void invalidatePatientScopedProviders(WidgetRef ref) {
  ref.invalidate(activeProfileIdProvider);
  ref.invalidate(profileBundleProvider);
  ref.invalidate(profileRegionCodeProvider);
  ref.invalidate(dailyEntriesProvider);
  ref.invalidate(insightSummaryProvider);
  ref.invalidate(historyDayProvider);
  ref.invalidate(historyActivityDatesProvider);
  ref.invalidate(alertsProvider);
  ref.invalidate(screeningCatalogProvider);
  ref.invalidate(myScreeningsProvider);
  ref.invalidate(preventionCenterProvider);
  ref.invalidate(healthDossierProvider);
  ref.invalidate(dossierShareLinksProvider);
  ref.invalidate(medicationLogsProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadNotificationsProvider);
  ref.invalidate(notificationPreferencesProvider);
  ref.invalidate(localMedicationReminderStatusProvider);
  ref.invalidate(pendingMedicationDosesProvider);
  ref.invalidate(wearableSyncStatusProvider);
  ref.invalidate(wearableDailySummariesProvider);
  ref.invalidate(timelineEventsProvider);
  ref.invalidate(deviceOverviewProvider);
  ref.invalidate(documentsProvider);
  ref.invalidate(documentArchiveProvider);
  ref.invalidate(documentFoldersProvider);
  ref.invalidate(documentDetailProvider);
}
