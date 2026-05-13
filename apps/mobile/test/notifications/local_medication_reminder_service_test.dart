import 'package:clindiary/app/core/notifications/local_medication_reminder_service.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalMedicationReminderService.buildSchedulePlan', () {
    test('generates future daily reminders', () {
      final service = LocalMedicationReminderService();

      final plan = service.buildSchedulePlan(
        medications: [
          MedicationItem(
            id: 'med-1',
            name: 'Atorvastatina',
            dosage: '20 mg',
            active: true,
            schedules: [
              MedicationScheduleItem(
                id: 'sched-1',
                scheduledTime: '21:00:00',
                daysOfWeek: [],
                active: true,
              ),
            ],
          ),
        ],
        from: DateTime(2026, 3, 21, 20, 0),
        horizonDays: 3,
      );

      expect(plan, hasLength(3));
      expect(plan.first.scheduledAt, DateTime(2026, 3, 21, 21, 0));
      expect(plan[1].scheduledAt, DateTime(2026, 3, 22, 21, 0));
    });

    test('respects selected days, pauses, and cycles', () {
      final service = LocalMedicationReminderService();

      final plan = service.buildSchedulePlan(
        medications: [
          MedicationItem(
            id: 'med-2',
            name: 'Vitamina D',
            active: true,
            schedules: [
              MedicationScheduleItem(
                id: 'sched-2',
                scheduledTime: '08:00:00',
                daysOfWeek: [0, 2, 4],
                startDate: DateTime(2026, 3, 23),
                cycleDaysOn: 2,
                cycleDaysOff: 1,
                active: true,
              ),
            ],
          ),
        ],
        from: DateTime(2026, 3, 22, 9, 0),
        horizonDays: 8,
      );

      final scheduledDates = plan
          .map(
            (item) =>
                '${item.scheduledAt.year}-${item.scheduledAt.month.toString().padLeft(2, '0')}-${item.scheduledAt.day.toString().padLeft(2, '0')}',
          )
          .toList();

      expect(scheduledDates, ['2026-03-23', '2026-03-27']);
    });

    test('does not regenerate reminders for a dose already logged today', () {
      final service = LocalMedicationReminderService();

      final plan = service.buildSchedulePlan(
        medications: [
          MedicationItem(
            id: 'med-3',
            name: 'Metformina',
            active: true,
            schedules: [
              MedicationScheduleItem(
                id: 'sched-3',
                scheduledTime: '21:00:00',
                daysOfWeek: [],
                active: true,
              ),
            ],
          ),
        ],
        logs: [
          MedicationLogItem(
            id: 'log-1',
            medicationId: 'med-3',
            medicationName: 'Metformina',
            scheduledAt: DateTime(2026, 3, 21, 21, 0),
            takenAt: DateTime(2026, 3, 21, 21, 5),
            status: 'taken',
          ),
        ],
        from: DateTime(2026, 3, 21, 12, 0),
        horizonDays: 2,
      );

      expect(plan, hasLength(1));
      expect(plan.single.scheduledAt, DateTime(2026, 3, 22, 21, 0));
    });
  });
}
