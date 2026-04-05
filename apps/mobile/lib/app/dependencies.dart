import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/auth/data/auth_repository.dart';
import 'package:clindiary/features/billing/data/billing_repository.dart';
import 'package:clindiary/features/alerts/data/alerts_repository.dart';
import 'package:clindiary/features/daily_journal/data/daily_journal_repository.dart';
import 'package:clindiary/features/devices/data/devices_repository.dart';
import 'package:clindiary/features/dossier/data/dossier_repository.dart';
import 'package:clindiary/features/documents/data/document_picker_service.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/history/data/history_repository.dart';
import 'package:clindiary/features/insights/data/insights_repository.dart';
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
import 'package:http/http.dart' as http;

final appConfigProvider = Provider<AppConfig>((ref) => defaultAppConfig);

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final secureTokenStorageProvider = Provider<SecureTokenStorage>(
  (ref) => SecureTokenStorage(ref.watch(flutterSecureStorageProvider)),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    client: ref.watch(httpClientProvider),
    config: ref.watch(appConfigProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
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
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
    localDatabase: ref.watch(localDatabaseProvider),
    appConfig: ref.watch(appConfigProvider),
    localDocumentVaultService: ref.watch(localDocumentVaultServiceProvider),
    localMedicationReminderService: ref.watch(
      localMedicationReminderServiceProvider,
    ),
  ),
);

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(apiClient: ref.watch(apiClientProvider)),
);

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(apiClient: ref.watch(apiClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final dailyJournalRepositoryProvider = Provider<DailyJournalRepository>(
  (ref) => DailyJournalRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
    onDeviceAiService: ref.watch(onDeviceAiServiceProvider),
    onDevicePromptBuilder: ref.watch(onDevicePromptBuilderProvider),
  ),
);

final onDeviceAiServiceProvider = Provider<OnDeviceAiService>(
  (ref) => OnDeviceAiService(),
);

final onDevicePromptBuilderProvider = Provider<OnDevicePromptBuilder>(
  (ref) => OnDevicePromptBuilder(
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => AlertsRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final timelineRepositoryProvider = Provider<TimelineRepository>(
  (ref) => TimelineRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final documentsRepositoryProvider = Provider<DocumentsRepository>(
  (ref) => DocumentsRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
    billingRepository: ref.watch(billingRepositoryProvider),
    localVaultService: ref.watch(localDocumentVaultServiceProvider),
  ),
);

final screeningsRepositoryProvider = Provider<ScreeningsRepository>(
  (ref) => ScreeningsRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final medicationsRepositoryProvider = Provider<MedicationsRepository>(
  (ref) => MedicationsRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final wearablesRepositoryProvider = Provider<WearablesRepository>(
  (ref) => WearablesRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final documentPickerServiceProvider = Provider<DocumentPickerService>(
  (ref) => DocumentPickerService(),
);

final localDocumentVaultServiceProvider = Provider<LocalDocumentVaultService>(
  (ref) => LocalDocumentVaultService(
    secureStorage: ref.watch(flutterSecureStorageProvider),
  ),
);

final preventionCenterRepositoryProvider = Provider<PreventionCenterRepository>(
  (ref) => PreventionCenterRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);

final dossierRepositoryProvider = Provider<DossierRepository>(
  (ref) => DossierRepository(
    apiClient: ref.watch(apiClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  ),
);
