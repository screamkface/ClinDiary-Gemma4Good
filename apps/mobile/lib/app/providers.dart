import 'package:clindiary/app/dependencies.dart';
import 'package:clindiary/app/core/demo_seed_data.dart';
import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/auth/presentation/auth_controller.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/devices/domain/device_hub.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/history/domain/history_day.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';
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

bool _isHackathonDemoMode(Ref ref) {
  final config = ref.read(appConfigProvider);
  return config.hackathonDemoMode || config.localOnlyMode;
}

Future<T> _withDemoFallback<T>(
  Ref ref, {
  required Future<T> Function() run,
  required T Function() demoValue,
}) async {
  try {
    return await run();
  } catch (_) {
    if (_isHackathonDemoMode(ref)) {
      return demoValue();
    }
    rethrow;
  }
}

final profileBundleProvider = FutureProvider<ProfileBundle?>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  final isDemoMode = _isHackathonDemoMode(ref);

  if (session == null && !isDemoMode) {
    return null;
  }

  return _withDemoFallback(
    ref,
    run: () => ref.watch(profileRepositoryProvider).fetchProfile(),
    demoValue: DemoSeedData.demoProfileBundle,
  );
});

final activeProfileIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(profileRepositoryProvider).getActiveProfileId();
});

final gemmaCenterHistoryProvider =
    FutureProvider<List<GemmaCenterHistoryEntry>>((ref) async {
      final activeProfileId = await ref.watch(activeProfileIdProvider.future);
      if (activeProfileId == null || activeProfileId.trim().isEmpty) {
        return const [];
      }
      return ref
          .watch(gemmaCenterHistoryStoreProvider)
          .readEntries(profileScope: activeProfileId.trim());
    });

final profileRegionCodeProvider = FutureProvider<String>((ref) async {
  final bundle = await ref.watch(profileBundleProvider.future);
  return bundle?.profile.regionCode?.trim().toUpperCase() ?? 'IT';
});

final dailyEntriesProvider = FutureProvider<List<DailyEntry>>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  final isDemoMode = _isHackathonDemoMode(ref);

  if (session == null && !isDemoMode) {
    return const [];
  }

  return _withDemoFallback(
    ref,
    run: () => ref.watch(dailyJournalRepositoryProvider).fetchEntries(),
    demoValue: DemoSeedData.demoDailyEntries,
  );
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
      return _withDemoFallback(
        ref,
        run: () => ref.watch(insightsRepositoryProvider).fetchSummary(query),
        demoValue: () => DemoSeedData.demoInsightSummary(query),
      );
    });

final localAiStatusProvider = FutureProvider<LocalAiStatus>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(insightsRepositoryProvider).fetchLocalStatus(),
    demoValue: DemoSeedData.demoLocalAiStatus,
  );
});

final onDeviceAiStatusProvider = FutureProvider<OnDeviceAiStatus>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(insightsRepositoryProvider).fetchOnDeviceStatus(),
    demoValue: DemoSeedData.demoOnDeviceAiStatus,
  );
});

final historyDayProvider = FutureProvider.family<HistoryDay, DateTime>((
  ref,
  targetDate,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return _withDemoFallback(
    ref,
    run: () => ref
        .watch(historyRepositoryProvider)
        .fetchDay(targetDate: targetDate, includeRollups: false),
    demoValue: () => DemoSeedData.demoHistoryDay(targetDate),
  );
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
      return _withDemoFallback(
        ref,
        run: () => ref
            .watch(historyRepositoryProvider)
            .fetchActivityDates(startDate: monthStart, endDate: monthEnd),
        demoValue: () => DemoSeedData.demoHistoryActivityDates(monthAnchor),
      );
    });

final deviceOverviewProvider = FutureProvider<DeviceOverview>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(devicesRepositoryProvider).fetchOverview(),
    demoValue: DemoSeedData.demoDeviceOverview,
  );
});

final alertsProvider = FutureProvider<List<ClinicalAlert>>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(alertsRepositoryProvider).fetchAlerts(),
    demoValue: DemoSeedData.demoAlerts,
  );
});

final screeningCatalogProvider = FutureProvider<List<ScreeningCatalogItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  final regionCode = await ref.watch(profileRegionCodeProvider.future);
  return _withDemoFallback(
    ref,
    run: () => ref
        .watch(screeningsRepositoryProvider)
        .fetchCatalog(regionCode: regionCode),
    demoValue: DemoSeedData.demoScreeningCatalog,
  );
});

final myScreeningsProvider = FutureProvider<List<PatientScreeningStatusItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  final regionCode = await ref.watch(profileRegionCodeProvider.future);
  return _withDemoFallback(
    ref,
    run: () => ref
        .watch(screeningsRepositoryProvider)
        .fetchMyScreenings(regionCode: regionCode),
    demoValue: DemoSeedData.demoMyScreenings,
  );
});

final preventionCenterProvider = FutureProvider<PreventionCenterData>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  final regionCode = await ref.watch(profileRegionCodeProvider.future);
  return _withDemoFallback(
    ref,
    run: () => ref
        .watch(preventionCenterRepositoryProvider)
        .fetchCenter(regionCode: regionCode),
    demoValue: DemoSeedData.demoPreventionCenter,
  );
});

final healthDossierProvider = FutureProvider<HealthDossier>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw Exception('Sessione non disponibile');
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(dossierRepositoryProvider).fetchDossier(),
    demoValue: DemoSeedData.demoHealthDossier,
  );
});

final dossierShareLinksProvider = FutureProvider<List<DossierShareLinkItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(dossierRepositoryProvider).fetchShareLinks(),
    demoValue: DemoSeedData.demoDossierShareLinks,
  );
});

final medicationLogsProvider = FutureProvider<List<MedicationLogItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(medicationsRepositoryProvider).fetchLogs(),
    demoValue: DemoSeedData.demoMedicationLogs,
  );
});

final notificationsProvider = FutureProvider<List<AppNotificationItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(notificationsRepositoryProvider).fetchNotifications(),
    demoValue: DemoSeedData.demoNotifications,
  );
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
    return _withDemoFallback(
      ref,
      run: () => ref.watch(notificationsRepositoryProvider).fetchPreferences(),
      demoValue: DemoSeedData.demoNotificationPreferences,
    );
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
  return _withDemoFallback(
    ref,
    run: () => ref.watch(wearableHealthServiceProvider).getStatus(),
    demoValue: DemoSeedData.demoWearableSyncStatus,
  );
});

final wearableDailySummariesProvider = FutureProvider<List<WearableDaySummary>>(
  (ref) async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      return const [];
    }
    return _withDemoFallback(
      ref,
      run: () => ref.watch(wearablesRepositoryProvider).fetchDailySummaries(),
      demoValue: DemoSeedData.demoWearableSummaries,
    );
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
  return _withDemoFallback(
    ref,
    run: () => ref.watch(timelineRepositoryProvider).fetchEvents(),
    demoValue: DemoSeedData.demoTimelineEvents,
  );
});

final documentsProvider = FutureProvider<List<ClinicalDocumentSummary>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(documentsRepositoryProvider).fetchDocuments(),
    demoValue: DemoSeedData.demoDocuments,
  );
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
      return _withDemoFallback(
        ref,
        run: () => ref
            .watch(documentsRepositoryProvider)
            .fetchArchive(folderId: query.folderId, query: query.searchQuery),
        demoValue: () => DemoSeedData.demoDocumentArchive(
          folderId: query.folderId,
          query: query.searchQuery,
        ),
      );
    });

final documentFoldersProvider = FutureProvider<List<DocumentFolderItem>>((
  ref,
) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    return const [];
  }
  return _withDemoFallback(
    ref,
    run: () => ref.watch(documentsRepositoryProvider).fetchFolders(),
    demoValue: DemoSeedData.demoDocumentFolders,
  );
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
      return _withDemoFallback(
        ref,
        run: () => ref
            .watch(documentsRepositoryProvider)
            .fetchDocumentDetail(documentId),
        demoValue: () => DemoSeedData.demoDocumentDetail(documentId),
      );
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
