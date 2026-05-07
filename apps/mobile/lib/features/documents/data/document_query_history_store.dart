import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/documents/domain/document_query_history_entry.dart';

class DocumentQueryHistoryStore {
  DocumentQueryHistoryStore({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  static const _cacheKey = 'document_query_history';
  static const _maxEntries = 50;

  final LocalDatabase _localDatabase;

  Future<List<DocumentQueryHistoryEntry>> readEntries({
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

    try {
      final decoded = jsonDecode(cached);
      if (decoded is! List) {
        return const [];
      }

      final rawItems = decoded
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);

      final entries = rawItems
          .map((item) => DocumentQueryHistoryEntry.fromJson(item))
          .toList(growable: false);

      return entries;
    } catch (error) {
      // Malformed cache, return empty list
      return const [];
    }
  }

  Future<void> appendEntry(
    DocumentQueryHistoryEntry entry, {
    String? profileScope,
  }) async {
    final scope = profileScope ?? await activeProfileCacheScope(_localDatabase);
    if (scope == null) {
      return;
    }

    final existing = await readEntries(profileScope: scope);
    // Prepend new entry and keep only the most recent entries
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

  Future<void> deleteEntry(String entryId, {String? profileScope}) async {
    final scope = profileScope ?? await activeProfileCacheScope(_localDatabase);
    if (scope == null) {
      return;
    }

    final existing = await readEntries(profileScope: scope);
    final updated = existing.where((entry) => entry.id != entryId).toList();

    await _localDatabase.putCache(
      key: scopedCacheKey(_cacheKey, scope),
      payload: jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }
}
