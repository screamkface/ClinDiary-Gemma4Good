import 'active_profile_store.dart';
import 'local_database.dart';

Future<String?> activeProfileCacheScope(LocalDatabase database) async {
  final activeProfileId = await database.readCache(activeProfileIdCacheKey);
  final normalized = activeProfileId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String scopedCacheKey(String baseKey, String? profileScope) {
  if (profileScope == null || profileScope.isEmpty) {
    return baseKey;
  }
  return '$baseKey::$profileScope';
}

Future<String> profileScopedCacheKey(
  LocalDatabase database,
  String baseKey,
) async {
  return scopedCacheKey(baseKey, await activeProfileCacheScope(database));
}

Future<String?> readProfileScopedCache(
  LocalDatabase database,
  String baseKey,
) async {
  final scope = await activeProfileCacheScope(database);
  if (scope == null) {
    return database.readCache(baseKey);
  }
  return database.readCache(scopedCacheKey(baseKey, scope));
}
