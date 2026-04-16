import 'package:clindiary/features/history/presentation/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TableCalendar isolated test', (tester) async {
    FlutterError.onError = (details) {
      print('FLUTTER_ERROR_MSG: ' + details.exception.toString());
      print(details.stack);
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TableCalendar<String>(
                    locale: 'en_US',
                    firstDay: DateTime(2020),
                    lastDay: DateTime.now().add(const Duration(days: 1)),
                    focusedDay: DateTime.now(),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
