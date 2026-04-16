import 'dart:convert';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  static const _notificationsCacheKey = 'family_notifications_list';
  static const _preferencesCacheKey = 'notifications_preferences';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;

  Future<List<AppNotificationItem>> fetchNotifications() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJsonList('/api/v1/notifications');
      final items = response
          .map(
            (item) =>
                AppNotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      await _cacheNotifications(items);
      return items;
    } on ApiException {
      final cached = await _readCachedNotifications();
      if (cached == null) rethrow;
      return cached;
    } catch (_) {
      final cached = await _readCachedNotifications();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<AppNotificationItem> markRead(String notificationId) async {
    try {
      final response = await _apiClient.postJson(
        '/api/v1/notifications/$notificationId/read',
        body: const {},
      );
      final item = AppNotificationItem.fromJson(response);
      final cached = await _readCachedNotifications();
      if (cached != null) {
        await _cacheNotifications(
          cached
              .map((existing) => existing.id == item.id ? item : existing)
              .toList(),
        );
      }
      return item;
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queueMarkRead(notificationId, error.message);
    } catch (error) {
      return _queueMarkRead(notificationId, error.toString());
    }
  }

  Future<NotificationPreferences> fetchPreferences() async {
    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson(
        '/api/v1/notifications/preferences',
      );
      final preferences = NotificationPreferences.fromJson(response);
      await _cachePreferences(preferences);
      return preferences;
    } on ApiException {
      final cached = await _readCachedPreferences();
      if (cached == null) rethrow;
      return cached;
    } catch (_) {
      final cached = await _readCachedPreferences();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _apiClient.putJson(
        '/api/v1/notifications/preferences',
        body: body,
      );
      final preferences = NotificationPreferences.fromJson(response);
      await _cachePreferences(preferences);
      return preferences;
    } on ApiException catch (error) {
      if (!_shouldQueue(error.statusCode)) {
        rethrow;
      }
      return _queuePreferencesUpdate(body, error.message);
    } catch (error) {
      return _queuePreferencesUpdate(body, error.toString());
    }
  }

  Future<NotificationDeliveryReport> sendTestDelivery({
    Map<String, dynamic> body = const {},
  }) async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.postJson(
      '/api/v1/notifications/test-delivery',
      body: body,
    );
    return NotificationDeliveryReport.fromJson(response);
  }

  Future<AppNotificationItem> _queueMarkRead(
    String notificationId,
    String lastError,
  ) async {
    await _apiClient.enqueueJsonOperation(
      method: 'POST',
      path: '/api/v1/notifications/$notificationId/read',
      body: const {},
      lastError: lastError,
      replaceExisting: true,
    );
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
        notificationType: 'queued',
        title: 'Notification updated',
        body: 'Marked as read offline.',
        priority: 'normal',
        readStatus: true,
        readAt: now,
        createdAt: now,
      ),
    );
  }

  Future<NotificationPreferences> _queuePreferencesUpdate(
    Map<String, dynamic> body,
    String lastError,
  ) async {
    await _apiClient.enqueueJsonOperation(
      method: 'PUT',
      path: '/api/v1/notifications/preferences',
      body: body,
      lastError: lastError,
      replaceExisting: true,
    );
    final current =
        await _readCachedPreferences() ??
        const NotificationPreferences(
          inAppEnabled: true,
          dailyCheckinEnabled: true,
          medicationRemindersEnabled: true,
          screeningRemindersEnabled: true,
          documentFollowUpEnabled: true,
          reportReadyEnabled: true,
          clinicalAlertsEnabled: true,
          preventionTipsEnabled: true,
          pushEnabled: false,
          emailEnabled: false,
        );
    final updated = current.copyWith(
      inAppEnabled: body['in_app_enabled'] as bool?,
      dailyCheckinEnabled: body['daily_checkin_enabled'] as bool?,
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

  bool _shouldQueue(int? statusCode) => statusCode == null || statusCode >= 500;

  Future<String> _preferencesScopedCacheKey() {
    return profileScopedCacheKey(_localDatabase, _preferencesCacheKey);
  }
}
