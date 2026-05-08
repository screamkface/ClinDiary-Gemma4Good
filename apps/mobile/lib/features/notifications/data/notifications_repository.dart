import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  static const _notificationsCacheKey = 'family_notifications_list';
  static const _preferencesCacheKey = 'notifications_preferences';

  final LocalDatabase _localDatabase;

  Future<List<AppNotificationItem>> fetchNotifications() async {
    final cached = await _readCachedNotifications();
    return cached ?? const <AppNotificationItem>[];
  }

  Future<AppNotificationItem> markRead(String notificationId) async {
    final cached = await _readCachedNotifications() ?? <AppNotificationItem>[];
    final now = DateTime.now().toUtc();
    final updated = cached
        .map(
          (item) => item.id == notificationId
              ? item.copyWith(readStatus: true, readAt: now)
              : item,
        )
        .toList();
    await _cacheNotifications(updated);
    return updated.firstWhere(
      (item) => item.id == notificationId,
      orElse: () => AppNotificationItem(
        id: notificationId,
        notificationType: 'local',
        title: 'Notification updated',
        body: 'Marked as read offline.',
        priority: 'normal',
        readStatus: true,
        readAt: now,
        createdAt: now,
      ),
    );
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final cached = await _readCachedPreferences();
    return cached ??
        const NotificationPreferences(
          inAppEnabled: true,
          dailyCheckinEnabled: true,
          symptomFollowUpEnabled: true,
          medicationRemindersEnabled: true,
          screeningRemindersEnabled: true,
          documentFollowUpEnabled: true,
          reportReadyEnabled: true,
          clinicalAlertsEnabled: true,
          preventionTipsEnabled: true,
          pushEnabled: false,
          emailEnabled: false,
        );
  }

  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> body,
  ) async {
    final current = await fetchPreferences();
    final updated = current.copyWith(
      inAppEnabled: body['in_app_enabled'] as bool?,
      dailyCheckinEnabled: body['daily_checkin_enabled'] as bool?,
      symptomFollowUpEnabled: body['symptom_follow_up_enabled'] as bool?,
      medicationRemindersEnabled: body['medication_reminders_enabled'] as bool?,
      screeningRemindersEnabled: body['screening_reminders_enabled'] as bool?,
      documentFollowUpEnabled: body['document_follow_up_enabled'] as bool?,
      reportReadyEnabled: body['report_ready_enabled'] as bool?,
      clinicalAlertsEnabled: body['clinical_alerts_enabled'] as bool?,
      preventionTipsEnabled: body['prevention_tips_enabled'] as bool?,
      pushEnabled: body['push_enabled'] as bool?,
      emailEnabled: body['email_enabled'] as bool?,
      emailAddress: body.containsKey('email_address')
          ? body['email_address'] as String?
          : null,
    );
    await _cachePreferences(updated);
    return updated;
  }

  Future<NotificationDeliveryReport> sendTestDelivery({
    Map<String, dynamic> body = const {},
  }) async {
    return NotificationDeliveryReport(
      attempted: true,
      delivered: true,
      hasErrors: false,
    );
  }

  Future<void> _cacheNotifications(List<AppNotificationItem> items) async {
    await _localDatabase.putCache(
      key: _notificationsCacheKey,
      payload: jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<AppNotificationItem>?> _readCachedNotifications() async {
    final cached = await _localDatabase.readCache(_notificationsCacheKey);
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map(
          (item) => AppNotificationItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _cachePreferences(NotificationPreferences preferences) async {
    await _localDatabase.putCache(
      key: await _preferencesScopedCacheKey(),
      payload: jsonEncode(preferences.toJson()),
    );
  }

  Future<NotificationPreferences?> _readCachedPreferences() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      _preferencesCacheKey,
    );
    if (cached == null) {
      return null;
    }
    return NotificationPreferences.fromJson(
      jsonDecode(cached) as Map<String, dynamic>,
    );
  }

  Future<String> _preferencesScopedCacheKey() {
    return profileScopedCacheKey(_localDatabase, _preferencesCacheKey);
  }
}
