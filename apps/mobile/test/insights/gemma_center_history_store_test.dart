import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
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
        question: 'Come va il mio quadro?',
        response: 'Risposta A',
        referenceDate: DateTime.utc(2026, 4, 8),
      ),
    );

    final profileAEntries = await store.readEntries();
    expect(profileAEntries, hasLength(1));
    expect(profileAEntries.single.response, 'Risposta A');

    await database.putCache(key: activeProfileIdCacheKey, payload: 'profile-b');
    final profileBEntriesBeforeWrite = await store.readEntries();
    expect(profileBEntriesBeforeWrite, isEmpty);

    await store.appendEntry(
      GemmaCenterHistoryEntry.preVisit(
        response: 'Risposta B',
        referenceDate: DateTime.utc(2026, 4, 8),
      ),
    );

    final profileBEntries = await store.readEntries();
    expect(profileBEntries, hasLength(1));
    expect(profileBEntries.single.response, 'Risposta B');

    await database.putCache(key: activeProfileIdCacheKey, payload: 'profile-a');
    final profileAEntriesAgain = await store.readEntries();
    expect(profileAEntriesAgain, hasLength(1));
    expect(profileAEntriesAgain.single.response, 'Risposta A');
  });
}