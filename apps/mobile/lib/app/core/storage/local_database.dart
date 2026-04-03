import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';

class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class PendingOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  TextColumn get profileId => text().nullable()();
  TextColumn get payload => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class RequestTraces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  IntColumn get statusCode => integer()();
  TextColumn get requestId => text().nullable()();
  RealColumn get responseTimeMs => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [CacheEntries, PendingOperations, RequestTraces])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  LocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      // Local storage contains cache, pending sync operations and request traces.
      // On schema changes we prefer a safe reset over brittle in-place migrations.
      await customStatement('DROP TABLE IF EXISTS request_traces');
      await customStatement('DROP TABLE IF EXISTS pending_operations');
      await customStatement('DROP TABLE IF EXISTS cache_entries');
      await migrator.createAll();
    },
  );

  Future<void> putCache({required String key, required String payload}) {
    return into(cacheEntries).insertOnConflictUpdate(
      CacheEntriesCompanion.insert(
        key: key,
        payload: payload,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<String?> readCache(String key) async {
    final entry = await (select(
      cacheEntries,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return entry?.payload;
  }

  Future<void> removeCache(String key) {
    return (delete(cacheEntries)..where((tbl) => tbl.key.equals(key))).go();
  }

  Future<void> enqueuePendingOperation({
    required String method,
    required String path,
    String? profileId,
    String? payload,
    String? lastError,
    bool replaceExisting = false,
  }) {
    if (replaceExisting) {
      return transaction(() async {
        final query = delete(pendingOperations)
          ..where((tbl) => tbl.method.equals(method))
          ..where((tbl) => tbl.path.equals(path));
        if (profileId == null) {
          query.where((tbl) => tbl.profileId.isNull());
        } else {
          query.where((tbl) => tbl.profileId.equals(profileId));
        }
        await query.go();
        await into(pendingOperations).insert(
          PendingOperationsCompanion.insert(
            method: method,
            path: path,
            profileId: Value(profileId),
            payload: Value(payload),
            lastError: Value(lastError),
            createdAt: DateTime.now().toUtc(),
          ),
        );
      });
    }
    return into(pendingOperations).insert(
      PendingOperationsCompanion.insert(
        method: method,
        path: path,
        profileId: Value(profileId),
        payload: Value(payload),
        lastError: Value(lastError),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<PendingOperation>> listPendingOperations({int limit = 20}) {
    return (select(pendingOperations)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markPendingOperationSynced(int id) {
    return (delete(pendingOperations)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> markPendingOperationFailed(int id, String error) {
    return (update(pendingOperations)..where((tbl) => tbl.id.equals(id))).write(
      PendingOperationsCompanion(
        attempts: const Value.absent(),
        lastError: Value(error),
      ),
    );
  }

  Future<void> incrementPendingOperationAttempts(int id, String? error) {
    return customUpdate(
      'UPDATE pending_operations SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      variables: [Variable.withString(error ?? ''), Variable.withInt(id)],
      updates: {pendingOperations},
    );
  }

  Future<void> recordTrace({
    required String method,
    required String path,
    required int statusCode,
    String? requestId,
    double? responseTimeMs,
  }) {
    return into(requestTraces).insert(
      RequestTracesCompanion.insert(
        method: method,
        path: path,
        statusCode: statusCode,
        requestId: Value(requestId),
        responseTimeMs: Value(responseTimeMs),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<RequestTrace>> readRecentTraces({int limit = 30}) {
    return (select(requestTraces)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> clearPendingOperations() => delete(pendingOperations).go();

  Future<void> clearRequestTraces() => delete(requestTraces).go();

  Future<void> clearCache() => delete(cacheEntries).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, 'clindiary.sqlite'));
    return NativeDatabase(file);
  });
}
