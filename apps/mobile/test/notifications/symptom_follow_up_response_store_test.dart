import 'package:clindiary/app/core/notifications/symptom_follow_up_response_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SymptomFollowUpResponseStore', () {
    test('consumeAll is safe when there are no pending responses', () async {
      final store = SymptomFollowUpResponseStore();

      await store.consumeAll();

      expect(await store.consumeAll(), isEmpty);
    });

    test(
      'consumeAll returns pending responses sorted by recorded time',
      () async {
        final store = SymptomFollowUpResponseStore();
        await store.consumeAll();

        await store.enqueue(
          PendingSymptomFollowUpResponse(
            sourceEntryId: 'entry-2',
            sourceSymptomId: 'symptom-2',
            response: 'resolved',
            recordedAt: DateTime.utc(2026, 5, 10, 12),
          ),
        );
        await store.enqueue(
          PendingSymptomFollowUpResponse(
            sourceEntryId: 'entry-1',
            sourceSymptomId: 'symptom-1',
            response: 'still_present',
            recordedAt: DateTime.utc(2026, 5, 10, 9),
          ),
        );

        final pending = await store.consumeAll();

        expect(pending.map((item) => item.sourceEntryId), [
          'entry-1',
          'entry-2',
        ]);
        expect(await store.consumeAll(), isEmpty);
      },
    );
  });
}
