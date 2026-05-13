import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/timeline/presentation/timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('timeline screen shows available events', (tester) async {
    await initializeDateFormatting('en_US');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timelineEventsProvider.overrideWith(
            (ref) async => [
              TimelineEventItem(
                id: '1',
                eventType: 'daily_entry',
                title: 'Daily check-up completed',
                description: 'Energy 6/10, mood 7/10',
                eventDate: DateTime.utc(2026, 3, 20, 8),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily check-up completed'), findsOneWidget);
    expect(find.text('Energy 6/10, mood 7/10'), findsOneWidget);
  });
}
