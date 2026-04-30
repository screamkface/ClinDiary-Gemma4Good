import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MedicationReminderBootstrap extends ConsumerStatefulWidget {
  const MedicationReminderBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MedicationReminderBootstrap> createState() =>
      _MedicationReminderBootstrapState();
}

class _MedicationReminderBootstrapState
    extends ConsumerState<MedicationReminderBootstrap> {
  String? _lastFingerprint;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeService());
  }

  Future<void> _initializeService() async {
    if (_initializing) {
      return;
    }
    _initializing = true;
    await ref.read(localMedicationReminderServiceProvider).initialize();
    ref.invalidate(localMedicationReminderStatusProvider);
    _initializing = false;
  }

  Future<void> _syncIfNeeded({
    required ProfileBundle bundle,
    required NotificationPreferences preferences,
    required List<MedicationLogItem> logs,
    required List<DailyEntry> dailyEntries,
  }) async {
    final fingerprint = _buildFingerprint(
      bundle,
      preferences,
      logs,
      dailyEntries,
    );
    if (fingerprint == _lastFingerprint) {
      return;
    }
    _lastFingerprint = fingerprint;
    final today = DateTime.now();
    final todayCompleted = dailyEntries.any(
      (entry) => DateUtils.isSameDay(entry.entryDate, today),
    );
    await ref
        .read(localMedicationReminderServiceProvider)
        .syncMedicationReminders(
          medications: bundle.medications,
          preferences: preferences,
          logs: logs,
        );
    await ref
        .read(localMedicationReminderServiceProvider)
        .syncDailyCheckInReminders(
          enabled: preferences.dailyCheckinEnabled,
          completedToday: todayCompleted,
        );
    ref.invalidate(localMedicationReminderStatusProvider);
  }

  String _buildFingerprint(
    ProfileBundle bundle,
    NotificationPreferences preferences,
    List<MedicationLogItem> logs,
    List<DailyEntry> dailyEntries,
  ) {
    final today = DateTime.now();
    final todayCompleted = dailyEntries.any(
      (entry) => DateUtils.isSameDay(entry.entryDate, today),
    );
    final parts = <String>[
      preferences.medicationRemindersEnabled.toString(),
      preferences.dailyCheckinEnabled.toString(),
      todayCompleted.toString(),
      for (final medication in bundle.medications)
        [
          medication.id,
          medication.active.toString(),
          for (final schedule in medication.schedules)
            [
              schedule.id,
              schedule.active.toString(),
              schedule.scheduledTime,
              schedule.daysOfWeek.join(','),
              schedule.startDate?.toIso8601String() ?? '',
              schedule.endDate?.toIso8601String() ?? '',
              schedule.cycleDaysOn?.toString() ?? '',
              schedule.cycleDaysOff?.toString() ?? '',
              schedule.pausedUntil?.toIso8601String() ?? '',
            ].join('|'),
        ].join('::'),
      for (final log in logs.take(20))
        [
          log.medicationId,
          log.status,
          log.scheduledAt.toIso8601String(),
        ].join('|'),
    ];
    return parts.join('##');
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authControllerProvider);
    final session = authAsync.asData?.value;

    if (session == null) {
      if (_lastFingerprint != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _lastFingerprint = null;
          await ref
              .read(localMedicationReminderServiceProvider)
              .cancelAllMedicationReminders();
          ref.invalidate(localMedicationReminderStatusProvider);
        });
      }
      return widget.child;
    }

    final profileAsync = ref.watch(profileBundleProvider);
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final logsAsync = ref.watch(medicationLogsProvider);
    final dailyEntriesAsync = ref.watch(dailyEntriesProvider);
    final bundle = profileAsync.asData?.value;
    final preferences = preferencesAsync.asData?.value;
    final logs = logsAsync.asData?.value ?? const <MedicationLogItem>[];
    final dailyEntries =
        dailyEntriesAsync.asData?.value ?? const <DailyEntry>[];

    if (bundle != null && preferences != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncIfNeeded(
          bundle: bundle,
          preferences: preferences,
          logs: logs,
          dailyEntries: dailyEntries,
        );
      });

      final today = DateTime.now();
      final todayCheckUpCompleted = dailyEntries.any(
        (entry) => DateUtils.isSameDay(entry.entryDate, today),
      );
      if (todayCheckUpCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await ref
              .read(localMedicationReminderServiceProvider)
              .cancelDailyCheckInRemindersForDate(targetDate: today);
        });
      }
    }

    return widget.child;
  }
}
