import 'package:clindiary/features/wearables/data/wearable_health_service_base.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';

WearableHealthService createWearableHealthServiceImpl() =>
    _StubWearableHealthService();

class _StubWearableHealthService extends WearableHealthService {
  @override
  Future<List<WearableDaySummary>> collectDailySummaries({
    int days = 30,
  }) async {
    return const [];
  }

  @override
  Future<WearableSyncStatus> getStatus() async {
    return const WearableSyncStatus.unsupported(
      message: 'Wearable sync non disponibile su questa piattaforma.',
    );
  }

  @override
  Future<void> installProvider() async {}

  @override
  Future<bool> openProviderSettings() async {
    return false;
  }

  @override
  Future<WearableSyncStatus> requestAccess() async {
    return getStatus();
  }
}
