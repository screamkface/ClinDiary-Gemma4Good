import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const gemmaDownloadRoute = '/app/ai';
const _gemmaDownloadNotificationChannelId = 'clindiary_gemma_downloads';
const _gemmaDownloadNotificationChannelName = 'Gemma model download';
const _gemmaDownloadNotificationChannelDescription =
    'Progress notification for Gemma model downloads.';
const _gemmaDownloadNotificationId = 42042;

final ValueNotifier<String?> gemmaDownloadRouteNotifier =
    ValueNotifier<String?>(null);

class GemmaDownloadNotificationService {
  GemmaDownloadNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _gemmaDownloadNotificationChannelId,
        _gemmaDownloadNotificationChannelName,
        description: _gemmaDownloadNotificationChannelDescription,
        importance: Importance.low,
      ),
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true) {
      gemmaDownloadRouteNotifier.value = _normalizeRoute(payload);
    }

    _initialized = true;
  }

  Future<void> showProgress({
    required int downloadedBytes,
    int? totalBytes,
    String? body,
  }) async {
    await initialize();
    final percent = _progressPercent(downloadedBytes, totalBytes);
    await _plugin.show(
      id: _gemmaDownloadNotificationId,
      title: 'Gemma 4 download in progress',
      body: body ?? _buildBody(downloadedBytes, totalBytes),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _gemmaDownloadNotificationChannelId,
          _gemmaDownloadNotificationChannelName,
          channelDescription: _gemmaDownloadNotificationChannelDescription,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showProgress: totalBytes != null,
          maxProgress: 100,
          progress: percent ?? 0,
          indeterminate: totalBytes == null,
          playSound: false,
          enableVibration: false,
        ),
      ),
      payload: gemmaDownloadRoute,
    );
  }

  Future<void> complete() async {
    await initialize();
    await _plugin.cancel(id: _gemmaDownloadNotificationId);
  }

  Future<void> fail(String message) async {
    await initialize();
    await _plugin.show(
      id: _gemmaDownloadNotificationId,
      title: 'Gemma 4 download failed',
      body: message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _gemmaDownloadNotificationChannelId,
          _gemmaDownloadNotificationChannelName,
          channelDescription: _gemmaDownloadNotificationChannelDescription,
          importance: Importance.low,
          priority: Priority.low,
          autoCancel: true,
          playSound: false,
          enableVibration: false,
        ),
      ),
      payload: gemmaDownloadRoute,
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    gemmaDownloadRouteNotifier.value = _normalizeRoute(response.payload);
  }

  String _buildBody(int downloadedBytes, int? totalBytes) {
    final downloaded = _formatBytes(downloadedBytes);
    if (totalBytes == null) {
      return 'Downloaded $downloaded';
    }
    return 'Downloaded $downloaded of ${_formatBytes(totalBytes)}';
  }

  int? _progressPercent(int downloadedBytes, int? totalBytes) {
    if (totalBytes == null || totalBytes <= 0) {
      return null;
    }
    final percent = (downloadedBytes / totalBytes * 100).round();
    return percent.clamp(0, 100);
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final digits = value >= 10 || value % 1 == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }

  String _normalizeRoute(String? payload) {
    final route = payload?.trim();
    if (route == null || route.isEmpty) {
      return gemmaDownloadRoute;
    }
    return route;
  }
}
