import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:clindiary/app/core/notifications/symptom_follow_up_response_store.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _medicationReminderChannelId = 'clindiary_medication_reminders';
const _medicationReminderChannelName = 'Medication reminders';
const _medicationReminderChannelDescription =
    'Local reminders generated on the device for medication therapy.';
const _dailyCheckInReminderChannelId = 'clindiary_daily_checkin_reminders';
const _dailyCheckInReminderChannelName = 'Check-in reminders';
const _dailyCheckInReminderChannelDescription =
    'Local reminders generated on the device for the daily check-up.';
const _symptomFollowUpReminderChannelId = 'clindiary_symptom_follow_up';
const _symptomFollowUpReminderChannelName = 'Symptom follow-up';
const _symptomFollowUpReminderChannelDescription =
    'Local reminders generated on the device to confirm recent symptoms.';
const _dailyCheckInReminderSlots = <({int hour, int minute})>[
  (hour: 9, minute: 0),
  (hour: 13, minute: 0),
  (hour: 17, minute: 0),
  (hour: 20, minute: 30),
];

final ValueNotifier<String?> symptomFollowUpRouteNotifier =
    ValueNotifier<String?>(null);

@pragma('vm:entry-point')
Future<void> handleSymptomFollowUpBackgroundResponse(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final actionId = response.actionId?.trim();
  if (actionId != 'still_present' && actionId != 'resolved') {
    return;
  }

  final payload = _decodeSymptomFollowUpPayload(response.payload);
  if (payload == null) {
    return;
  }

  await SymptomFollowUpResponseStore().enqueue(
    PendingSymptomFollowUpResponse(
      sourceEntryId: payload['source_entry_id'].toString(),
      sourceSymptomId: payload['source_symptom_id'].toString(),
      response: actionId!,
      recordedAt: DateTime.now().toUtc(),
    ),
  );
}

Map<String, dynamic>? _decodeSymptomFollowUpPayload(String? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

@immutable
class LocalMedicationReminderStatus {
  const LocalMedicationReminderStatus({
    required this.isSupported,
    required this.permissionGranted,
    required this.scheduledCount,
    required this.lastSyncedAt,
    this.message,
  });

  final bool isSupported;
  final bool permissionGranted;
  final int scheduledCount;
  final DateTime? lastSyncedAt;
  final String? message;

  bool get isActive => isSupported && permissionGranted && scheduledCount > 0;
}

@immutable
class ScheduledMedicationReminder {
  const ScheduledMedicationReminder({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.scheduleId,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String medicationId;
  final String medicationName;
  final String scheduleId;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
}

class LocalMedicationReminderService {
  LocalMedicationReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  DateTime? _lastSyncedAt;

  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> initialize() async {
    if (_initialized || !isSupportedPlatform) {
      return;
    }

    tz_data.initializeTimeZones();
    await _configureTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          handleSymptomFollowUpBackgroundResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _medicationReminderChannelId,
        _medicationReminderChannelName,
        description: _medicationReminderChannelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _dailyCheckInReminderChannelId,
        _dailyCheckInReminderChannelName,
        description: _dailyCheckInReminderChannelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _symptomFollowUpReminderChannelId,
        _symptomFollowUpReminderChannelName,
        description: _symptomFollowUpReminderChannelDescription,
        importance: Importance.high,
      ),
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      final route = _routeFromNotificationResponse(launchResponse);
      if (route != null) {
        symptomFollowUpRouteNotifier.value = route;
      }
    }

    _initialized = true;
  }

  Future<LocalMedicationReminderStatus> getStatus() async {
    if (!isSupportedPlatform) {
      return const LocalMedicationReminderStatus(
        isSupported: false,
        permissionGranted: false,
        scheduledCount: 0,
        lastSyncedAt: null,
        message: 'Local reminders are available on Android and iOS.',
      );
    }

    await initialize();
    final permissionGranted = await _isPermissionGranted();
    final scheduledCount =
        (await _listMedicationPendingRequests()).length +
        (await _listDailyCheckInPendingRequests()).length +
        (await _listSymptomFollowUpPendingRequests()).length;

    return LocalMedicationReminderStatus(
      isSupported: true,
      permissionGranted: permissionGranted,
      scheduledCount: scheduledCount,
      lastSyncedAt: _lastSyncedAt,
      message: permissionGranted
          ? null
          : 'Permesso notifiche non ancora concesso sul dispositivo.',
    );
  }

  Future<LocalMedicationReminderStatus> requestPermission() async {
    if (!isSupportedPlatform) {
      return getStatus();
    }

    await initialize();
    var granted = true;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      granted = await androidPlugin.requestNotificationsPermission() ?? false;
    } else {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final macPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        granted =
            await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      } else if (macPlugin != null) {
        granted =
            await macPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    }

    final status = await getStatus();
    return LocalMedicationReminderStatus(
      isSupported: status.isSupported,
      permissionGranted: granted && status.permissionGranted,
      scheduledCount: status.scheduledCount,
      lastSyncedAt: status.lastSyncedAt,
      message: granted
          ? status.message
          : 'Permesso notifiche negato dal dispositivo.',
    );
  }

  Future<LocalMedicationReminderStatus> syncMedicationReminders({
    required List<MedicationItem> medications,
    required NotificationPreferences preferences,
    List<MedicationLogItem> logs = const [],
    bool requestPermissionIfNeeded = false,
    int horizonDays = 30,
  }) async {
    if (!isSupportedPlatform) {
      return getStatus();
    }

    await initialize();
    await _cancelMedicationPendingRequests();

    if (!preferences.medicationRemindersEnabled) {
      _lastSyncedAt = DateTime.now().toUtc();
      return LocalMedicationReminderStatus(
        isSupported: true,
        permissionGranted: await _isPermissionGranted(),
        scheduledCount: 0,
        lastSyncedAt: _lastSyncedAt,
        message: 'Medication reminders are disabled in preferences.',
      );
    }

    final statusBeforeSync = await getStatus();
    if (!statusBeforeSync.permissionGranted) {
      if (!requestPermissionIfNeeded) {
        return LocalMedicationReminderStatus(
          isSupported: true,
          permissionGranted: false,
          scheduledCount: 0,
          lastSyncedAt: _lastSyncedAt,
          message: 'Enable device notifications first to generate reminders.',
        );
      }
      final permissionStatus = await requestPermission();
      if (!permissionStatus.permissionGranted) {
        return permissionStatus;
      }
    }

    final plan = buildSchedulePlan(
      medications: medications,
      logs: logs,
      from: DateTime.now(),
      horizonDays: horizonDays,
    );

    for (final item in plan) {
      await _scheduleReminder(
        id: item.id,
        scheduledDate: tz.TZDateTime.from(item.scheduledAt, tz.local),
        notificationDetails: _notificationDetails(),
        title: item.title,
        body: item.body,
        payload: item.payload,
      );
    }

    _lastSyncedAt = DateTime.now().toUtc();
    return LocalMedicationReminderStatus(
      isSupported: true,
      permissionGranted: true,
      scheduledCount: plan.length,
      lastSyncedAt: _lastSyncedAt,
      message: plan.isEmpty
          ? 'No reminders can be scheduled with the current data.'
          : 'Local reminders synchronized on the device.',
    );
  }

  Future<void> cancelAllMedicationReminders() async {
    if (!isSupportedPlatform) {
      return;
    }

    await initialize();
    await _cancelMedicationPendingRequests();
    _lastSyncedAt = DateTime.now().toUtc();
  }

  Future<void> cancelMedicationRemindersForDate({
    required String medicationId,
    required DateTime targetDate,
  }) async {
    if (!isSupportedPlatform) {
      return;
    }

    await initialize();
    final targetKey = _dateKey(targetDate);
    for (final request in await _listMedicationPendingRequests()) {
      final payload = _decodePayload(request.payload);
      if (payload == null) {
        continue;
      }
      if (payload['medication_id'] == medicationId &&
          payload['occurrence_date'] == targetKey) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  Future<LocalMedicationReminderStatus> syncDailyCheckInReminders({
    required bool enabled,
    required bool completedToday,
    int horizonDays = 30,
  }) async {
    if (!isSupportedPlatform) {
      return getStatus();
    }

    await initialize();
    await _cancelDailyCheckInPendingRequests();

    if (!enabled) {
      _lastSyncedAt = DateTime.now().toUtc();
      return LocalMedicationReminderStatus(
        isSupported: true,
        permissionGranted: await _isPermissionGranted(),
        scheduledCount: 0,
        lastSyncedAt: _lastSyncedAt,
        message: 'Daily check-in reminders are disabled in preferences.',
      );
    }

    if (!await _isPermissionGranted()) {
      return LocalMedicationReminderStatus(
        isSupported: true,
        permissionGranted: false,
        scheduledCount: 0,
        lastSyncedAt: _lastSyncedAt,
        message: 'Enable device notifications first to generate reminders.',
      );
    }

    final plan = _buildDailyCheckInPlan(
      from: DateTime.now(),
      horizonDays: horizonDays,
      completedToday: completedToday,
    );

    for (final item in plan) {
      await _scheduleReminder(
        id: item.id,
        scheduledDate: tz.TZDateTime.from(item.scheduledAt, tz.local),
        notificationDetails: _dailyCheckInNotificationDetails(),
        title: item.title,
        body: item.body,
        payload: item.payload,
      );
    }

    _lastSyncedAt = DateTime.now().toUtc();
    return LocalMedicationReminderStatus(
      isSupported: true,
      permissionGranted: true,
      scheduledCount: plan.length,
      lastSyncedAt: _lastSyncedAt,
      message: plan.isEmpty
          ? 'No daily check-in reminders can be scheduled right now.'
          : 'Daily check-in reminders synchronized on the device.',
    );
  }

  Future<void> cancelDailyCheckInReminders() async {
    if (!isSupportedPlatform) {
      return;
    }

    await initialize();
    await _cancelDailyCheckInPendingRequests();
    _lastSyncedAt = DateTime.now().toUtc();
  }

  Future<void> cancelDailyCheckInRemindersForDate({
    required DateTime targetDate,
  }) async {
    if (!isSupportedPlatform) {
      return;
    }

    await initialize();
    final targetKey = _dateKey(targetDate);
    for (final request in await _listDailyCheckInPendingRequests()) {
      final payload = _decodePayload(request.payload);
      if (payload == null) {
        continue;
      }
      if (payload['occurrence_date'] == targetKey) {
        await _plugin.cancel(id: request.id);
      }
    }
    _lastSyncedAt = DateTime.now().toUtc();
  }

  Future<LocalMedicationReminderStatus> syncSymptomFollowUpReminders({
    required List<DailyEntry> entries,
    required bool enabled,
  }) async {
    if (!isSupportedPlatform) {
      return getStatus();
    }

    await initialize();
    await _cancelSymptomFollowUpPendingRequests();

    if (!enabled) {
      _lastSyncedAt = DateTime.now().toUtc();
      return LocalMedicationReminderStatus(
        isSupported: true,
        permissionGranted: await _isPermissionGranted(),
        scheduledCount: 0,
        lastSyncedAt: _lastSyncedAt,
        message: 'Symptom follow-up reminders are disabled in preferences.',
      );
    }

    if (!await _isPermissionGranted()) {
      return LocalMedicationReminderStatus(
        isSupported: true,
        permissionGranted: false,
        scheduledCount: 0,
        lastSyncedAt: _lastSyncedAt,
        message: 'Enable device notifications first to generate reminders.',
      );
    }

    final plan = _buildSymptomFollowUpPlan(
      entries: entries,
      from: DateTime.now(),
    );
    for (final item in plan) {
      await _scheduleReminder(
        id: item.id,
        scheduledDate: tz.TZDateTime.from(item.scheduledAt, tz.local),
        notificationDetails: _symptomFollowUpNotificationDetails(),
        title: item.title,
        body: item.body,
        payload: item.payload,
      );
    }

    _lastSyncedAt = DateTime.now().toUtc();
    return LocalMedicationReminderStatus(
      isSupported: true,
      permissionGranted: true,
      scheduledCount: plan.length,
      lastSyncedAt: _lastSyncedAt,
      message: plan.isEmpty
          ? 'No symptom follow-up reminders can be scheduled right now.'
          : 'Symptom follow-up reminders synchronized on the device.',
    );
  }

  List<ScheduledMedicationReminder> buildSchedulePlan({
    required List<MedicationItem> medications,
    List<MedicationLogItem> logs = const [],
    required DateTime from,
    int horizonDays = 30,
  }) {
    final plan = <ScheduledMedicationReminder>[];
    final anchor = DateTime(from.year, from.month, from.day);
    final minimumAllowed = from.add(const Duration(minutes: 1));
    final completedOccurrences = _completedOccurrenceKeys(logs);

    for (final medication in medications.where((item) => item.active)) {
      for (final schedule in medication.schedules.where(
        (item) => item.active,
      )) {
        final parsedTime = _parseTime(schedule.scheduledTime);
        for (var offset = 0; offset < horizonDays; offset++) {
          final day = anchor.add(Duration(days: offset));
          if (!_scheduleOccursOnDate(schedule, day)) {
            continue;
          }

          final scheduledAt = DateTime(
            day.year,
            day.month,
            day.day,
            parsedTime.hour,
            parsedTime.minute,
          );
          if (!scheduledAt.isAfter(minimumAllowed)) {
            continue;
          }
          if (completedOccurrences.contains(
            _occurrenceKey(medicationId: medication.id, occurrenceDate: day),
          )) {
            continue;
          }

          final payload = jsonEncode({
            'type': 'medication_reminder',
            'medication_id': medication.id,
            'medication_name': medication.name,
            'schedule_id': schedule.id,
            'occurrence_date': _dateKey(day),
            'scheduled_time': schedule.scheduledTime,
          });

          plan.add(
            ScheduledMedicationReminder(
              id: _notificationId(
                medicationId: medication.id,
                scheduleId: schedule.id,
                occurrence: scheduledAt,
              ),
              medicationId: medication.id,
              medicationName: medication.name,
              scheduleId: schedule.id,
              scheduledAt: scheduledAt,
              title: medication.dosage == null || medication.dosage!.isEmpty
                  ? medication.name
                  : '${medication.name} • ${medication.dosage}',
              body: _buildBody(medication, schedule, scheduledAt),
              payload: payload,
            ),
          );
        }
      }
    }

    plan.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return plan;
  }

  Future<void> _scheduleReminder({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _medicationReminderChannelId,
        _medicationReminderChannelName,
        channelDescription: _medicationReminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  NotificationDetails _dailyCheckInNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _dailyCheckInReminderChannelId,
        _dailyCheckInReminderChannelName,
        channelDescription: _dailyCheckInReminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  NotificationDetails _symptomFollowUpNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _symptomFollowUpReminderChannelId,
        _symptomFollowUpReminderChannelName,
        channelDescription: _symptomFollowUpReminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'still_present',
            'Still present',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'resolved',
            'Resolved',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _configureTimezone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<bool> _isPermissionGranted() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<void> _cancelMedicationPendingRequests() async {
    for (final request in await _listMedicationPendingRequests()) {
      await _plugin.cancel(id: request.id);
    }
  }

  Future<void> _cancelDailyCheckInPendingRequests() async {
    for (final request in await _listDailyCheckInPendingRequests()) {
      await _plugin.cancel(id: request.id);
    }
  }

  Future<void> _cancelSymptomFollowUpPendingRequests() async {
    for (final request in await _listSymptomFollowUpPendingRequests()) {
      await _plugin.cancel(id: request.id);
    }
  }

  Future<List<PendingNotificationRequest>>
  _listMedicationPendingRequests() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests.where((item) {
      final payload = _decodePayload(item.payload);
      return payload != null && payload['type'] == 'medication_reminder';
    }).toList();
  }

  Future<List<PendingNotificationRequest>>
  _listDailyCheckInPendingRequests() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests.where((item) {
      final payload = _decodePayload(item.payload);
      return payload != null && payload['type'] == 'daily_checkin_reminder';
    }).toList();
  }

  Future<List<PendingNotificationRequest>>
  _listSymptomFollowUpPendingRequests() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests.where((item) {
      final payload = _decodePayload(item.payload);
      return payload != null && payload['type'] == 'symptom_follow_up_reminder';
    }).toList();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId?.trim();
    if (actionId == 'still_present' || actionId == 'resolved') {
      final payload = _decodePayload(response.payload);
      if (payload != null) {
        unawaited(
          SymptomFollowUpResponseStore().enqueue(
            PendingSymptomFollowUpResponse(
              sourceEntryId: payload['source_entry_id'].toString(),
              sourceSymptomId: payload['source_symptom_id'].toString(),
              response: actionId!,
              recordedAt: DateTime.now().toUtc(),
            ),
          ),
        );
      }
      return;
    }
    final route = _routeFromNotificationResponse(response);
    if (route != null) {
      symptomFollowUpRouteNotifier.value = route;
    }
  }

  String? _routeFromNotificationResponse(NotificationResponse response) {
    final payload = _decodePayload(response.payload);
    if (payload == null || payload['type'] != 'symptom_follow_up_reminder') {
      return null;
    }
    final actionId = response.actionId?.trim();
    return Uri(
      path: '/app/diary/symptom-follow-up',
      queryParameters: <String, String>{
        'sourceEntryId': payload['source_entry_id'].toString(),
        'sourceSymptomId': payload['source_symptom_id'].toString(),
        if (actionId != null && actionId.isNotEmpty) 'response': actionId,
      },
    ).toString();
  }

  Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  bool _scheduleOccursOnDate(MedicationScheduleItem schedule, DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final startDate = schedule.startDate == null
        ? null
        : DateTime(
            schedule.startDate!.year,
            schedule.startDate!.month,
            schedule.startDate!.day,
          );
    final endDate = schedule.endDate == null
        ? null
        : DateTime(
            schedule.endDate!.year,
            schedule.endDate!.month,
            schedule.endDate!.day,
          );
    final pausedUntil = schedule.pausedUntil == null
        ? null
        : DateTime(
            schedule.pausedUntil!.year,
            schedule.pausedUntil!.month,
            schedule.pausedUntil!.day,
          );

    if (startDate != null && targetDate.isBefore(startDate)) {
      return false;
    }
    if (endDate != null && targetDate.isAfter(endDate)) {
      return false;
    }
    if (pausedUntil != null &&
        (targetDate.isBefore(pausedUntil) || targetDate == pausedUntil)) {
      return false;
    }

    final weekday = targetDate.weekday - 1;
    if (schedule.daysOfWeek.isNotEmpty &&
        !schedule.daysOfWeek.contains(weekday)) {
      return false;
    }

    if (schedule.cycleDaysOn != null && schedule.cycleDaysOff != null) {
      final anchor = startDate ?? targetDate;
      final elapsedDays = targetDate.difference(anchor).inDays;
      if (elapsedDays < 0) {
        return false;
      }
      final cycleLength = schedule.cycleDaysOn! + schedule.cycleDaysOff!;
      if (cycleLength > 0 &&
          elapsedDays % cycleLength >= schedule.cycleDaysOn!) {
        return false;
      }
    }

    return true;
  }

  ({int hour, int minute}) _parseTime(String rawValue) {
    final parts = rawValue.split(':');
    return (
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String _buildBody(
    MedicationItem medication,
    MedicationScheduleItem schedule,
    DateTime scheduledAt,
  ) {
    final parts = <String>[
      'Previsto alle ${_twoDigits(scheduledAt.hour)}:${_twoDigits(scheduledAt.minute)}',
    ];
    if (medication.frequency != null && medication.frequency!.isNotEmpty) {
      parts.add(medication.frequency!);
    }
    if (schedule.instructions != null && schedule.instructions!.isNotEmpty) {
      parts.add(schedule.instructions!);
    }
    return parts.join(' • ');
  }

  int _notificationId({
    required String medicationId,
    required String scheduleId,
    required DateTime occurrence,
  }) {
    final value = Object.hash(
      medicationId,
      scheduleId,
      occurrence.year,
      occurrence.month,
      occurrence.day,
      occurrence.hour,
      occurrence.minute,
    );
    return value & 0x7fffffff;
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  List<_DailyCheckInReminderPlanItem> _buildDailyCheckInPlan({
    required DateTime from,
    int horizonDays = 30,
    required bool completedToday,
  }) {
    final plan = <_DailyCheckInReminderPlanItem>[];
    final anchor = DateTime(from.year, from.month, from.day);
    final minimumAllowed = from.add(const Duration(minutes: 1));

    for (var offset = 0; offset < horizonDays; offset++) {
      final day = anchor.add(Duration(days: offset));
      if (offset == 0 && completedToday) {
        continue;
      }

      for (final slot in _dailyCheckInReminderSlots) {
        final scheduledAt = DateTime(
          day.year,
          day.month,
          day.day,
          slot.hour,
          slot.minute,
        );
        if (offset == 0 && !scheduledAt.isAfter(minimumAllowed)) {
          continue;
        }

        plan.add(
          _DailyCheckInReminderPlanItem(
            id: _notificationId(
              medicationId: 'daily-checkin',
              scheduleId: 'daily-checkin-${slot.hour}-${slot.minute}',
              occurrence: scheduledAt,
            ),
            scheduledAt: scheduledAt,
            title: 'Daily check-up',
            body: 'You still have not completed today\'s check-up.',
            payload: jsonEncode({
              'type': 'daily_checkin_reminder',
              'occurrence_date': _dateKey(day),
              'scheduled_time':
                  '${_twoDigits(slot.hour)}:${_twoDigits(slot.minute)}',
            }),
          ),
        );
      }
    }

    return plan;
  }

  List<_SymptomFollowUpReminderPlanItem> _buildSymptomFollowUpPlan({
    required List<DailyEntry> entries,
    required DateTime from,
  }) {
    final today = DateTime(from.year, from.month, from.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final scheduledAt = _nextSymptomFollowUpSlot(from);
    final plan = <_SymptomFollowUpReminderPlanItem>[];

    for (final entry in entries.where(
      (item) => _isSameDate(item.entryDate, yesterday),
    )) {
      for (final symptom in entry.symptoms) {
        if (_hasRecordedFollowUp(
          entries,
          today: today,
          sourceSymptomId: symptom.id,
        )) {
          continue;
        }
        final symptomLabel = _symptomLabel(symptom);
        plan.add(
          _SymptomFollowUpReminderPlanItem(
            id: _symptomFollowUpNotificationId(
              sourceEntryId: entry.id,
              sourceSymptomId: symptom.id,
              occurrence: scheduledAt,
            ),
            scheduledAt: scheduledAt,
            title: 'Symptom follow-up',
            body: 'Do you still have $symptomLabel today?',
            payload: jsonEncode({
              'type': 'symptom_follow_up_reminder',
              'source_entry_id': entry.id,
              'source_symptom_id': symptom.id,
              'source_entry_date': _dateKey(entry.entryDate),
            }),
          ),
        );
      }
    }

    return plan;
  }

  DateTime _nextSymptomFollowUpSlot(DateTime from) {
    final scheduled = DateTime(from.year, from.month, from.day, 10);
    if (scheduled.isAfter(from.add(const Duration(minutes: 1)))) {
      return scheduled;
    }
    return from.add(const Duration(minutes: 1));
  }

  bool _hasRecordedFollowUp(
    List<DailyEntry> entries, {
    required DateTime today,
    required String sourceSymptomId,
  }) {
    for (final entry in entries.where(
      (item) => _isSameDate(item.entryDate, today),
    )) {
      for (final symptom in entry.symptoms) {
        if (symptom.metadataJson['follow_up_source_symptom_id']?.toString() ==
            sourceSymptomId) {
          return true;
        }
      }
    }
    return false;
  }

  int _symptomFollowUpNotificationId({
    required String sourceEntryId,
    required String sourceSymptomId,
    required DateTime occurrence,
  }) {
    final value = Object.hash(
      sourceEntryId,
      sourceSymptomId,
      occurrence.year,
      occurrence.month,
      occurrence.day,
    );
    return value & 0x7fffffff;
  }

  String _symptomLabel(SymptomEntry symptom) {
    const labels = <String, String>{
      'headache': 'headache',
      'fever': 'fever',
      'nausea': 'nausea',
      'cough': 'cough',
      'fatigue': 'fatigue',
    };
    final base =
        labels[symptom.symptomCode] ?? symptom.symptomCode.replaceAll('_', ' ');
    final location = symptom.bodyLocation?.trim();
    if (location == null || location.isEmpty) {
      return base;
    }
    return '$base in $location';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Set<String> _completedOccurrenceKeys(List<MedicationLogItem> logs) {
    return logs
        .where(
          (item) =>
              item.status == 'taken' ||
              item.status == 'skipped' ||
              item.status == 'missed',
        )
        .map(
          (item) => _occurrenceKey(
            medicationId: item.medicationId,
            occurrenceDate: item.scheduledAt.toLocal(),
          ),
        )
        .toSet();
  }

  String _occurrenceKey({
    required String medicationId,
    required DateTime occurrenceDate,
  }) {
    return '$medicationId|${_dateKey(occurrenceDate)}';
  }
}

class _DailyCheckInReminderPlanItem {
  const _DailyCheckInReminderPlanItem({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
}

class _SymptomFollowUpReminderPlanItem {
  const _SymptomFollowUpReminderPlanItem({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
}
