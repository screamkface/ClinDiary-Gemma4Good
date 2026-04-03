import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';

abstract class WearableHealthService {
  Future<WearableSyncStatus> getStatus();

  Future<WearableSyncStatus> requestAccess();

  Future<void> installProvider();

  Future<bool> openProviderSettings();

  Future<List<WearableDaySummary>> collectDailySummaries({int days = 30});
}
