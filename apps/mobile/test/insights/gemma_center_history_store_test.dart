import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/insights/data/gemma_center_history_store.dart';
import 'package:clindiary/features/insights/domain/gemma_center_history_entry.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gemma Center history is isolated by active profile', () async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final store = GemmaCenterHistoryStore(localDatabase: database);

    await database.putCache(key: activeProfileIdCacheKey, payload: 'profile-a');
    await store.appendEntry(
      GemmaCenterHistoryEntry.question(
        question: 'How is my condition doing?',
        response: 'Answer A',
        referenceDate: DateTime.utc(2026, 4, 8),
      ),
    );

    final profileAEntries = await store.readEntries();
    expect(profileAEntries, hasLength(1));
    expect(profileAEntries.single.title, 'How is my condition doing?');
    expect(profileAEntries.single.response, 'Answer A');

    await database.putCache(key: activeProfileIdCacheKey, payload: 'profile-b');
    final profileBEntriesBeforeWrite = await store.readEntries();
    expect(profileBEntriesBeforeWrite, isEmpty);

    await store.appendEntry(
      GemmaCenterHistoryEntry.preVisit(
        response: 'Answer B',
        referenceDate: DateTime.utc(2026, 4, 8),
      ),
    );

    final profileBEntries = await store.readEntries();
    expect(profileBEntries, hasLength(1));
    expect(profileBEntries.single.title, 'Pre-visit brief');
    expect(profileBEntries.single.response, 'Answer B');

    await database.putCache(key: activeProfileIdCacheKey, payload: 'profile-a');
    final profileAEntriesAgain = await store.readEntries();
    expect(profileAEntriesAgain, hasLength(1));
    expect(profileAEntriesAgain.single.title, 'How is my condition doing?');
    expect(profileAEntriesAgain.single.response, 'Answer A');
  });

  test(
    'Gemma Center history normalizes legacy metadata to canonical values',
    () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.putCache(
        key: activeProfileIdCacheKey,
        payload: 'profile-a',
      );
      await database.putCache(
        key: scopedCacheKey('gemma_center_history', 'profile-a'),
        payload: '''
[
  {
    "id": "legacy-1",
    "kind": "trend_explanation",
    "title": "",
    "response": "Answer from legacy data",
    "created_at": "2026-04-08T10:00:00Z",
    "prompt": "Legacy prompt",
    "reference_date": "2026-04-08T00:00:00Z"
  }
]
''',
      );

      final store = GemmaCenterHistoryStore(localDatabase: database);
      final entries = await store.readEntries();

      expect(entries, hasLength(1));
      expect(entries.single.title, 'Trend analysis');
      expect(entries.single.kind, 'trend');

      final migratedCache = await database.readCache(
        scopedCacheKey('gemma_center_history', 'profile-a'),
      );
      expect(migratedCache, contains('Trend analysis'));
      expect(migratedCache, isNot(contains('trend_explanation')));
    },
  );
}
