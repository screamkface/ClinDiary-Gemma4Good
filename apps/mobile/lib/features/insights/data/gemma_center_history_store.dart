import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';

class GemmaCenterHistoryStore {
  GemmaCenterHistoryStore({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  static const _cacheKey = 'gemma_center_history';
  static const _maxEntries = 12;

  final LocalDatabase _localDatabase;

  Future<List<GemmaCenterHistoryEntry>> readEntries({
    String? profileScope,
  }) async {
    final scope = profileScope ?? await activeProfileCacheScope(_localDatabase);
    if (scope == null) {
      return const [];
    }

    final cached = await _localDatabase.readCache(
      scopedCacheKey(_cacheKey, scope),
    );
    if (cached == null || cached.trim().isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(cached);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => GemmaCenterHistoryEntry.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> appendEntry(
    GemmaCenterHistoryEntry entry, {
    String? profileScope,
  }) async {
    final scope = profileScope ?? await activeProfileCacheScope(_localDatabase);
    if (scope == null) {
      return;
    }

    final existing = await readEntries(profileScope: scope);
    final updated = [entry, ...existing].take(_maxEntries).toList();
    await _localDatabase.putCache(
      key: scopedCacheKey(_cacheKey, scope),
      payload: jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearEntries({String? profileScope}) async {
    final scope = profileScope ?? await activeProfileCacheScope(_localDatabase);
    if (scope == null) {
      return;
    }
    await _localDatabase.removeCache(scopedCacheKey(_cacheKey, scope));
  }
}