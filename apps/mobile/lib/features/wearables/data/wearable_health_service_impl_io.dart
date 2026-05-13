import 'dart:io' show Platform;

import 'package:clindiary/features/wearables/data/wearable_health_service_base.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';
import 'package:clindiary/features/wearables/domain/wearable_sync.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

WearableHealthService createWearableHealthServiceImpl() =>
    IoWearableHealthService();

class IoWearableHealthService extends WearableHealthService {
  IoWearableHealthService({Health? health}) : _health = health ?? Health();

  static const MethodChannel _platformChannel = MethodChannel(
    'clindiary/wearables',
  );

  static const List<HealthDataType> _iosReadTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  ];

  static const List<HealthDataType> _androidReadTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataType> _iosQueryTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  ];

  static const List<HealthDataType> _androidQueryTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.WORKOUT,
  ];

  final Health _health;
  bool _configured = false;

  List<HealthDataType> get _readTypes =>
      Platform.isAndroid ? _androidReadTypes : _iosReadTypes;

  List<HealthDataType> get _queryTypes =>
      Platform.isAndroid ? _androidQueryTypes : _iosQueryTypes;

  @override
  Future<WearableSyncStatus> getStatus() async {
    if (!_isSupportedPlatform) {
      return const WearableSyncStatus.unsupported(
        message: 'Wearable sync disponibile solo su Android e iPhone.',
      );
    }

    await _ensureConfigured();
    final providerName = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    var isAvailable = true;
    var canInstallProvider = false;
    var historyAccessGranted = true;
    String? message;

    if (Platform.isAndroid) {
      final sdkStatus = await _health.getHealthConnectSdkStatus();
      isAvailable = await _health.isHealthConnectAvailable();
      canInstallProvider = !isAvailable;
      if (!isAvailable) {
        message =
            sdkStatus ==
                HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired
            ? 'Health Connect must be installed or updated before syncing.'
            : 'Install Health Connect to import smartwatch data.';
      }
    }

    var permissionGranted = false;
    var healthGranted = false;
    var activityGranted = !Platform.isAndroid;
    if (isAvailable) {
      healthGranted = await _health.hasPermissions(_readTypes) ?? false;
      activityGranted =
          !Platform.isAndroid || await Permission.activityRecognition.isGranted;
      permissionGranted = healthGranted && activityGranted;

      if (Platform.isAndroid && await _health.isHealthDataHistoryAvailable()) {
        historyAccessGranted = await _health.isHealthDataHistoryAuthorized();
      }

      if (!permissionGranted && message == null) {
        if (!healthGranted && !activityGranted) {
          message =
              'Both Health Connect permissions and activity recognition permission are missing.';
        } else if (!healthGranted) {
          message =
              'Authorize ClinDiary in Health Connect to read health data.';
        } else if (!activityGranted) {
          message =
              'Activity recognition permission is also required to read steps and movement.';
        } else {
          message = 'Authorize ClinDiary to read health data from the device.';
        }
      }
    }

    return WearableSyncStatus(
      isSupported: true,
      platformLabel: Platform.isIOS ? 'ios' : 'android',
      providerName: providerName,
      isAvailable: isAvailable,
      permissionGranted: permissionGranted,
      canInstallProvider: canInstallProvider,
      historyAccessGranted: historyAccessGranted,
      healthPermissionsGranted: healthGranted,
      activityRecognitionGranted: activityGranted,
      message: message,
    );
  }

  @override
  Future<void> installProvider() async {
    if (!_isSupportedPlatform || !Platform.isAndroid) {
      return;
    }
    await _ensureConfigured();
    await _health.installHealthConnect();
  }

  @override
  Future<bool> openProviderSettings() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    if (Platform.isAndroid) {
      try {
        final opened = await _platformChannel.invokeMethod<bool>(
          'openHealthConnectSettings',
        );
        if (opened ?? false) {
          return true;
        }
      } on PlatformException {
        // Fall through to generic app settings.
      }
    }

    return openAppSettings();
  }

  @override
  Future<WearableSyncStatus> requestAccess() async {
    final status = await getStatus();
    if (!status.isSupported) {
      return status;
    }
    if (!status.isAvailable) {
      return status;
    }

    await _ensureConfigured();
    if (Platform.isAndroid) {
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) {
        return status.copyWith(
          permissionGranted: false,
          message:
              'Activity recognition permission is required to read steps and movement.',
        );
      }
    }

    final granted = await _health.requestAuthorization(_readTypes);
    var historyAccessGranted = status.historyAccessGranted;
    if (Platform.isAndroid && await _health.isHealthDataHistoryAvailable()) {
      historyAccessGranted =
          await _health.isHealthDataHistoryAuthorized() ||
          await _health.requestHealthDataHistoryAuthorization();
    }

    final refreshed = await getStatus();
    if (!granted || !refreshed.permissionGranted) {
      return refreshed.copyWith(
        historyAccessGranted: historyAccessGranted,
        message:
            refreshed.message ??
            (Platform.isAndroid
                ? 'Wearable permissions were not granted. If the prompt does not appear, open the health settings directly.'
                : 'Wearable permissions were not granted.'),
      );
    }

    if (!historyAccessGranted) {
      return refreshed.copyWith(
        historyAccessGranted: false,
        message:
            'Sync is active, but historical access may remain limited to the last 30 authorized days.',
      );
    }
    return refreshed;
  }

  @override
  Future<List<WearableDaySummary>> collectDailySummaries({
    int days = 30,
  }) async {
    final safeDays = days.clamp(1, 30);
    final status = await requestAccess();
    if (!status.isSupported) {
      throw WearableSyncException(
        status.message ?? 'Wearable sync is not supported.',
      );
    }
    if (!status.isAvailable) {
      throw WearableSyncException(
        status.message ?? 'Health provider is not available.',
      );
    }
    if (!status.permissionGranted) {
      throw WearableSyncException(
        status.message ?? 'Wearable permissions were not granted.',
      );
    }

    await _ensureConfigured();
    final now = DateTime.now();
    final startDay = _dateOnly(now.subtract(Duration(days: safeDays - 1)));
    final endTime = now;
    final points = await _health.getHealthDataFromTypes(
      types: _queryTypes,
      startTime: startDay,
      endTime: endTime,
      recordingMethodsToFilter: const [RecordingMethod.manual],
    );

    final summaries = <DateTime, _WearableAccumulator>{};

    for (final point in points) {
      if (point.recordingMethod == RecordingMethod.manual) {
        continue;
      }
      final summaryDate = _summaryDateFor(point);
      if (summaryDate.isBefore(startDay) ||
          summaryDate.isAfter(_dateOnly(now))) {
        continue;
      }
      final accumulator = summaries.putIfAbsent(
        summaryDate,
        () => _WearableAccumulator(
          summaryDate: summaryDate,
          sourcePlatform: Platform.isIOS ? 'ios' : 'android',
          sourceName: status.providerName,
        ),
      );
      if (point.type == HealthDataType.WORKOUT) {
        accumulator.absorbWorkout(point);
        continue;
      }
      final numericValue = _numericValue(point);
      if (numericValue == null) {
        continue;
      }
      accumulator.absorbPoint(point, numericValue);
    }

    for (var offset = 0; offset < safeDays; offset++) {
      final dayStart = startDay.add(Duration(days: offset));
      final dayEnd = dayStart.add(const Duration(days: 1));
      final steps = await _health.getTotalStepsInInterval(
        dayStart,
        dayEnd,
        includeManualEntry: false,
      );
      if (steps == null || steps <= 0) {
        continue;
      }
      final accumulator = summaries.putIfAbsent(
        dayStart,
        () => _WearableAccumulator(
          summaryDate: dayStart,
          sourcePlatform: Platform.isIOS ? 'ios' : 'android',
          sourceName: status.providerName,
        ),
      );
      accumulator.stepsCount = steps;
      accumulator.recordCount += 1;
    }

    final result =
        summaries.values
            .map((item) => item.build())
            .whereType<WearableDaySummary>()
            .toList()
          ..sort((a, b) => b.summaryDate.compareTo(a.summaryDate));
    return result;
  }

  bool get _isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }
    await _health.configure();
    _configured = true;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static double? _numericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is! NumericHealthValue) {
      return null;
    }
    final numeric = value.numericValue.toDouble();
    if (point.type == HealthDataType.BLOOD_OXYGEN && numeric <= 1) {
      return numeric * 100;
    }
    return numeric;
  }

  static DateTime _summaryDateFor(HealthDataPoint point) {
    switch (point.type) {
      case HealthDataType.SLEEP_ASLEEP:
      case HealthDataType.SLEEP_SESSION:
      case HealthDataType.SLEEP_DEEP:
      case HealthDataType.SLEEP_REM:
        return _dateOnly(point.dateTo.toLocal());
      default:
        return _dateOnly(point.dateFrom.toLocal());
    }
  }
}

class _WearableAccumulator {
  _WearableAccumulator({
    required this.summaryDate,
    required this.sourcePlatform,
    required this.sourceName,
  });

  final DateTime summaryDate;
  final String sourcePlatform;
  String? sourceName;
  String? sourceDeviceModel;

  int? stepsCount;
  double? activeEnergyKcal;
  double? exerciseMinutes;
  double? distanceMeters;
  double? sleepMinutes;
  double? sleepDeepMinutes;
  double? sleepRemMinutes;

  double _heartRateSum = 0;
  int _heartRateCount = 0;
  double? _heartRateMin;
  double? _heartRateMax;

  double _restingHeartRateSum = 0;
  int _restingHeartRateCount = 0;

  double _bloodOxygenSum = 0;
  int _bloodOxygenCount = 0;

  double _hrvSum = 0;
  int _hrvCount = 0;

  int recordCount = 0;

  void absorbPoint(HealthDataPoint point, double value) {
    final nextSourceName = point.sourceName.trim();
    if (nextSourceName.isNotEmpty) {
      sourceName = nextSourceName;
    }
    final nextDeviceModel = point.deviceModel?.trim();
    if (nextDeviceModel != null && nextDeviceModel.isNotEmpty) {
      sourceDeviceModel = nextDeviceModel;
    }

    switch (point.type) {
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        activeEnergyKcal = (activeEnergyKcal ?? 0) + value;
        break;
      case HealthDataType.EXERCISE_TIME:
        exerciseMinutes = (exerciseMinutes ?? 0) + value;
        break;
      case HealthDataType.DISTANCE_WALKING_RUNNING:
      case HealthDataType.DISTANCE_DELTA:
        distanceMeters = (distanceMeters ?? 0) + value;
        break;
      case HealthDataType.SLEEP_ASLEEP:
        sleepMinutes = (sleepMinutes ?? 0) + value;
        break;
      case HealthDataType.SLEEP_SESSION:
        sleepMinutes = sleepMinutes == null
            ? value
            : (sleepMinutes! < value ? value : sleepMinutes);
        break;
      case HealthDataType.SLEEP_DEEP:
        sleepDeepMinutes = (sleepDeepMinutes ?? 0) + value;
        break;
      case HealthDataType.SLEEP_REM:
        sleepRemMinutes = (sleepRemMinutes ?? 0) + value;
        break;
      case HealthDataType.HEART_RATE:
        _heartRateSum += value;
        _heartRateCount += 1;
        _heartRateMin = _heartRateMin == null
            ? value
            : (_heartRateMin! < value ? _heartRateMin : value);
        _heartRateMax = _heartRateMax == null
            ? value
            : (_heartRateMax! > value ? _heartRateMax : value);
        break;
      case HealthDataType.RESTING_HEART_RATE:
        _restingHeartRateSum += value;
        _restingHeartRateCount += 1;
        break;
      case HealthDataType.BLOOD_OXYGEN:
        _bloodOxygenSum += value;
        _bloodOxygenCount += 1;
        break;
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
      case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
        _hrvSum += value;
        _hrvCount += 1;
        break;
      default:
        return;
    }
    recordCount += 1;
  }

  void absorbWorkout(HealthDataPoint point) {
    final nextSourceName = point.sourceName.trim();
    if (nextSourceName.isNotEmpty) {
      sourceName = nextSourceName;
    }
    final nextDeviceModel = point.deviceModel?.trim();
    if (nextDeviceModel != null && nextDeviceModel.isNotEmpty) {
      sourceDeviceModel = nextDeviceModel;
    }

    final durationMinutes = point.dateTo
        .difference(point.dateFrom)
        .inMinutes
        .toDouble();
    exerciseMinutes = (exerciseMinutes ?? 0) + durationMinutes;

    final workoutSummary = point.workoutSummary;
    if (workoutSummary != null) {
      if (distanceMeters == null && workoutSummary.totalDistance > 0) {
        distanceMeters = workoutSummary.totalDistance.toDouble();
      }
      if (activeEnergyKcal == null && workoutSummary.totalEnergyBurned > 0) {
        activeEnergyKcal = workoutSummary.totalEnergyBurned.toDouble();
      }
      if (stepsCount == null && workoutSummary.totalSteps > 0) {
        stepsCount = workoutSummary.totalSteps.toInt();
      }
    }

    recordCount += 1;
  }

  WearableDaySummary? build() {
    final heartRateAvgBpm = _heartRateCount == 0
        ? null
        : _heartRateSum / _heartRateCount;
    final restingHeartRateBpm = _restingHeartRateCount == 0
        ? null
        : _restingHeartRateSum / _restingHeartRateCount;
    final bloodOxygenAvgPct = _bloodOxygenCount == 0
        ? null
        : _bloodOxygenSum / _bloodOxygenCount;
    final hrvSdnnMs = _hrvCount == 0 ? null : _hrvSum / _hrvCount;

    final summary = WearableDaySummary(
      summaryDate: summaryDate,
      sourcePlatform: sourcePlatform,
      sourceName: sourceName,
      sourceDeviceModel: sourceDeviceModel,
      stepsCount: stepsCount,
      activeEnergyKcal: activeEnergyKcal,
      exerciseMinutes: exerciseMinutes,
      distanceMeters: distanceMeters,
      sleepMinutes: sleepMinutes,
      sleepDeepMinutes: sleepDeepMinutes,
      sleepRemMinutes: sleepRemMinutes,
      heartRateAvgBpm: heartRateAvgBpm,
      heartRateMinBpm: _heartRateMin,
      heartRateMaxBpm: _heartRateMax,
      restingHeartRateBpm: restingHeartRateBpm,
      bloodOxygenAvgPct: bloodOxygenAvgPct,
      hrvSdnnMs: hrvSdnnMs,
      recordCount: recordCount,
    );
    return summary.hasAnyMetric ? summary : null;
  }
}
