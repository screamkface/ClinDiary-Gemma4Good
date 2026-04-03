import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/timeline/presentation/timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('timeline screen mostra gli eventi disponibili', (tester) async {
    await initializeDateFormatting('it_IT');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timelineEventsProvider.overrideWith(
            (ref) async => [
              TimelineEventItem(
                id: '1',
                eventType: 'daily_entry',
                title: 'Check-up giornaliero completato',
                description: 'Energia 6/10, umore 7/10',
                eventDate: DateTime.utc(2026, 3, 20, 8),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Check-up giornaliero completato'), findsOneWidget);
    expect(find.text('Energia 6/10, umore 7/10'), findsOneWidget);
  });
}
