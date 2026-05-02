import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get givenName => text().nullable()();
  TextColumn get familyName => text().nullable()();
  TextColumn get dateOfBirth => text().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get bloodType => text().nullable()();
  TextColumn get avatarPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DailyEntries extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get entryDate => text()();
  RealColumn get sleepHours => real().nullable()();
  IntColumn get sleepQuality => integer().nullable()();
  IntColumn get energyLevel => integer().nullable()();
  IntColumn get moodLevel => integer().nullable()();
  IntColumn get stressLevel => integer().nullable()();
  IntColumn get appetiteLevel => integer().nullable()();
  IntColumn get hydrationLevel => integer().nullable()();
  IntColumn get generalPain => integer().nullable()();
  TextColumn get generalNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Symptoms extends Table {
  TextColumn get id => text()();
  TextColumn get dailyEntryId => text().references(DailyEntries, #id)();
  TextColumn get symptomCode => text()();
  IntColumn get severity => integer().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get bodyLocation => text().nullable()();
  TextColumn get metadataJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Vitals extends Table {
  TextColumn get id => text()();
  TextColumn get dailyEntryId => text().references(DailyEntries, #id)();
  TextColumn get type => text()();
  TextColumn get value => text()();
  TextColumn get unit => text().nullable()();
  DateTimeColumn get measuredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Medications extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get name => text()();
  TextColumn get activeIngredient => text().nullable()();
  TextColumn get form => text().nullable()();
  TextColumn get strength => text().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MedicationSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get medicationId => text().references(Medications, #id)();
  TextColumn get scheduleType => text()(); 
  TextColumn get timeOfDay => text()(); 
  RealColumn get dose => real()();
  TextColumn get specificDaysJson => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get documentType => text()();
  TextColumn get title => text()();
  TextColumn get fileCategory => text().nullable()();
  DateTimeColumn get documentDate => dateTime()();
  TextColumn get localFilePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  BoolColumn get isProcessed => boolean().withDefault(const Constant(false))();
  TextColumn get extractedText => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DocumentChunks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get documentId => text().references(Documents, #id)();
  IntColumn get chunkIndex => integer()();
  TextColumn get content => text()();
  TextColumn get embeddingJson => text().nullable()(); 
}

class TimelineEvents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get eventType => text()();
  DateTimeColumn get eventDate => dateTime()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get metadataJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Alerts extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get alertType => text()();
  TextColumn get severity => text()();
  TextColumn get title => text()();
  TextColumn get message => text()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get referenceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

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

@DriftDatabase(tables: [
  Profiles,
  DailyEntries,
  Symptoms,
  Vitals,
  Medications,
  MedicationSchedules,
  Documents,
  DocumentChunks,
  TimelineEvents,
  Alerts,
  CacheEntries,
  PendingOperations,
  RequestTraces,
])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  LocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      await customStatement('DROP TABLE IF EXISTS alerts');
      await customStatement('DROP TABLE IF EXISTS timeline_events');
      await customStatement('DROP TABLE IF EXISTS document_chunks');
      await customStatement('DROP TABLE IF EXISTS documents');
      await customStatement('DROP TABLE IF EXISTS medication_schedules');
      await customStatement('DROP TABLE IF EXISTS medications');
      await customStatement('DROP TABLE IF EXISTS vitals');
      await customStatement('DROP TABLE IF EXISTS symptoms');
      await customStatement('DROP TABLE IF EXISTS daily_entries');
      await customStatement('DROP TABLE IF EXISTS profiles');
      
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
