import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/session_expiry_notifier.dart';
import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/auth/data/auth_repository.dart';
import 'package:clindiary/features/alerts/data/alerts_repository.dart';
import 'package:clindiary/features/daily_journal/data/daily_journal_repository.dart';
import 'package:clindiary/features/daily_journal/data/voice_check_in_assistant.dart';
import 'package:clindiary/features/devices/data/devices_repository.dart';
import 'package:clindiary/features/dossier/data/dossier_repository.dart';
import 'package:clindiary/features/documents/data/document_picker_service.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/documents/data/document_query_history_store.dart';
import 'package:clindiary/features/history/data/history_repository.dart';
import 'package:clindiary/features/insights/data/insights_repository.dart';
import 'package:clindiary/features/insights/data/gemma_center_history_store.dart';
import 'package:clindiary/features/insights/data/gemma_coach_service.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:clindiary/features/medications/data/medications_repository.dart';
import 'package:clindiary/features/notifications/data/notifications_repository.dart';
import 'package:clindiary/features/prevention_center/data/prevention_center_repository.dart';
import 'package:clindiary/features/profile/data/profile_repository.dart';
import 'package:clindiary/features/reports/data/reports_repository.dart';
import 'package:clindiary/features/screenings/data/screenings_repository.dart';
import 'package:clindiary/features/timeline/data/timeline_repository.dart';
import 'package:clindiary/features/wearables/data/wearable_health_service.dart';
import 'package:clindiary/features/wearables/data/wearables_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) => defaultAppConfig);

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final secureTokenStorageProvider = Provider<SecureTokenStorage>(
  (ref) => SecureTokenStorage(ref.watch(flutterSecureStorageProvider)),
);

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final sessionExpiryNotifierProvider =
    ChangeNotifierProvider<SessionExpiryNotifier>(
      (ref) => SessionExpiryNotifier(),
    );

final localMedicationReminderServiceProvider =
    Provider<LocalMedicationReminderService>(
      (ref) => LocalMedicationReminderService(),
    );

final wearableHealthServiceProvider = Provider<WearableHealthService>(
  (ref) => createWearableHealthService(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    tokenStorage: ref.watch(secureTokenStorageProvider),
    localDatabase: ref.watch(localDatabaseProvider),
    localDocumentVaultService: ref.watch(localDocumentVaultServiceProvider),
    localMedicationReminderService: ref.watch(
      localMedicationReminderServiceProvider,
    ),
    appConfig: ref.watch(appConfigProvider),
  ),
);

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final dailyJournalRepositoryProvider = Provider<DailyJournalRepository>(
  (ref) =>
      DailyJournalRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(
    localDatabase: ref.watch(localDatabaseProvider),
    onDeviceAiService: ref.watch(onDeviceAiServiceProvider),
    onDevicePromptBuilder: ref.watch(onDevicePromptBuilderProvider),
  ),
);

final onDeviceAiServiceProvider = Provider<OnDeviceAiService>(
  (ref) => OnDeviceAiService(),
);

final voiceCheckInAssistantProvider = Provider<VoiceCheckInAssistant>(
  (ref) => VoiceCheckInAssistant(
    onDeviceAiService: ref.watch(onDeviceAiServiceProvider),
  ),
);

final gemmaCoachServiceProvider = Provider<GemmaCoachService>(
  (ref) => GemmaCoachService(
    onDeviceAiService: ref.watch(onDeviceAiServiceProvider),
    onDevicePromptBuilder: ref.watch(onDevicePromptBuilderProvider),
    documentsRepository: ref.watch(documentsRepositoryProvider),
    profileRepository: ref.watch(profileRepositoryProvider),
    dailyJournalRepository: ref.watch(dailyJournalRepositoryProvider),
    alertsRepository: ref.watch(alertsRepositoryProvider),
    medicationsRepository: ref.watch(medicationsRepositoryProvider),
    timelineRepository: ref.watch(timelineRepositoryProvider),
    wearablesRepository: ref.watch(wearablesRepositoryProvider),
    dossierRepository: ref.watch(dossierRepositoryProvider),
  ),
);

final gemmaCenterHistoryStoreProvider = Provider<GemmaCenterHistoryStore>(
  (ref) =>
      GemmaCenterHistoryStore(localDatabase: ref.watch(localDatabaseProvider)),
);

final documentQueryHistoryStoreProvider = Provider<DocumentQueryHistoryStore>(
  (ref) => DocumentQueryHistoryStore(
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final onDevicePromptBuilderProvider = Provider<OnDevicePromptBuilder>(
  (ref) =>
      OnDevicePromptBuilder(localDatabase: ref.watch(localDatabaseProvider)),
);

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => AlertsRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final timelineRepositoryProvider = Provider<TimelineRepository>(
  (ref) => TimelineRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final documentsRepositoryProvider = Provider<DocumentsRepository>(
  (ref) => DocumentsRepository(
    localDatabase: ref.watch(localDatabaseProvider),
    onDeviceAiService: ref.watch(onDeviceAiServiceProvider),
    localVaultService: ref.watch(localDocumentVaultServiceProvider),
  ),
);

final screeningsRepositoryProvider = Provider<ScreeningsRepository>(
  (ref) =>
      ScreeningsRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final medicationsRepositoryProvider = Provider<MedicationsRepository>(
  (ref) =>
      MedicationsRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) =>
      NotificationsRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(
    localDatabase: ref.watch(localDatabaseProvider),
    onDeviceAiService: ref.watch(onDeviceAiServiceProvider),
    onDevicePromptBuilder: ref.watch(onDevicePromptBuilderProvider),
  ),
);

final wearablesRepositoryProvider = Provider<WearablesRepository>(
  (ref) => WearablesRepository(localDatabase: ref.watch(localDatabaseProvider)),
);

final documentPickerServiceProvider = Provider<DocumentPickerService>(
  (ref) => DocumentPickerService(),
);

final localDocumentVaultServiceProvider = Provider<LocalDocumentVaultService>((
  ref,
) {
  final service = LocalDocumentVaultService(
    secureStorage: ref.watch(flutterSecureStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final preventionCenterRepositoryProvider = Provider<PreventionCenterRepository>(
  (ref) => const PreventionCenterRepository(),
);

final dossierRepositoryProvider = Provider<DossierRepository>(
  (ref) => DossierRepository(localDatabase: ref.watch(localDatabaseProvider)),
);
