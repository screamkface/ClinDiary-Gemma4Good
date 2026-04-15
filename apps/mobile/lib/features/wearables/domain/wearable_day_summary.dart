class WearableDaySummary {
  const WearableDaySummary({
    this.id,
    required this.summaryDate,
    required this.sourcePlatform,
    this.sourceName,
    this.sourceDeviceModel,
    this.stepsCount,
    this.activeEnergyKcal,
    this.exerciseMinutes,
    this.distanceMeters,
    this.sleepMinutes,
    this.sleepDeepMinutes,
    this.sleepRemMinutes,
    this.heartRateAvgBpm,
    this.heartRateMinBpm,
    this.heartRateMaxBpm,
    this.restingHeartRateBpm,
    this.bloodOxygenAvgPct,
    this.hrvSdnnMs,
    this.recordCount = 0,
    this.syncedAt,
  });

  final String? id;
  final DateTime summaryDate;
  final String sourcePlatform;
  final String? sourceName;
  final String? sourceDeviceModel;
  final int? stepsCount;
  final double? activeEnergyKcal;
  final double? exerciseMinutes;
  final double? distanceMeters;
  final double? sleepMinutes;
  final double? sleepDeepMinutes;
  final double? sleepRemMinutes;
  final double? heartRateAvgBpm;
  final double? heartRateMinBpm;
  final double? heartRateMaxBpm;
  final double? restingHeartRateBpm;
  final double? bloodOxygenAvgPct;
  final double? hrvSdnnMs;
  final int recordCount;
  final DateTime? syncedAt;

  bool get hasAnyMetric =>
      stepsCount != null ||
      activeEnergyKcal != null ||
      exerciseMinutes != null ||
      distanceMeters != null ||
      sleepMinutes != null ||
      sleepDeepMinutes != null ||
      sleepRemMinutes != null ||
      heartRateAvgBpm != null ||
      heartRateMinBpm != null ||
      heartRateMaxBpm != null ||
      restingHeartRateBpm != null ||
      bloodOxygenAvgPct != null ||
      hrvSdnnMs != null;

  factory WearableDaySummary.fromJson(Map<String, dynamic> json) =>
      WearableDaySummary(
        id: json['id']?.toString(),
        summaryDate: DateTime.parse(json['summary_date'].toString()),
        sourcePlatform: json['source_platform'].toString(),
        sourceName: json['source_name'] as String?,
        sourceDeviceModel: json['source_device_model'] as String?,
        stepsCount: json['steps_count'] as int?,
        activeEnergyKcal: (json['active_energy_kcal'] as num?)?.toDouble(),
        exerciseMinutes: (json['exercise_minutes'] as num?)?.toDouble(),
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
        sleepMinutes: (json['sleep_minutes'] as num?)?.toDouble(),
        sleepDeepMinutes: (json['sleep_deep_minutes'] as num?)?.toDouble(),
        sleepRemMinutes: (json['sleep_rem_minutes'] as num?)?.toDouble(),
        heartRateAvgBpm: (json['heart_rate_avg_bpm'] as num?)?.toDouble(),
        heartRateMinBpm: (json['heart_rate_min_bpm'] as num?)?.toDouble(),
        heartRateMaxBpm: (json['heart_rate_max_bpm'] as num?)?.toDouble(),
        restingHeartRateBpm: (json['resting_heart_rate_bpm'] as num?)
            ?.toDouble(),
        bloodOxygenAvgPct: (json['blood_oxygen_avg_pct'] as num?)?.toDouble(),
        hrvSdnnMs: (json['hrv_sdnn_ms'] as num?)?.toDouble(),
        recordCount: json['record_count'] as int? ?? 0,
        syncedAt: json['synced_at'] == null
            ? null
            : DateTime.parse(json['synced_at'].toString()),
      );

  Map<String, dynamic> toSyncJson() => {
    'summary_date': summaryDate.toIso8601String().split('T').first,
    'source_platform': sourcePlatform,
    'source_name': sourceName,
    'source_device_model': sourceDeviceModel,
    'steps_count': stepsCount,
    'active_energy_kcal': activeEnergyKcal,
    'exercise_minutes': exerciseMinutes,
    'distance_meters': distanceMeters,
    'sleep_minutes': sleepMinutes,
    'sleep_deep_minutes': sleepDeepMinutes,
    'sleep_rem_minutes': sleepRemMinutes,
    'heart_rate_avg_bpm': heartRateAvgBpm,
    'heart_rate_min_bpm': heartRateMinBpm,
    'heart_rate_max_bpm': heartRateMaxBpm,
    'resting_heart_rate_bpm': restingHeartRateBpm,
    'blood_oxygen_avg_pct': bloodOxygenAvgPct,
    'hrv_sdnn_ms': hrvSdnnMs,
    'record_count': recordCount,
  };

  String toDiagnosticText() {
    final metrics = <String>[];
    if (stepsCount != null) {
      metrics.add('${stepsCount!} steps');
    }
    if (sleepMinutes != null) {
      metrics.add('sleep ${(sleepMinutes! / 60).toStringAsFixed(1)}h');
    }
    if (heartRateAvgBpm != null) {
      metrics.add('avg HR ${heartRateAvgBpm!.toStringAsFixed(0)} bpm');
    }
    if (restingHeartRateBpm != null) {
      metrics.add('resting HR ${restingHeartRateBpm!.toStringAsFixed(0)} bpm');
    }
    if (bloodOxygenAvgPct != null) {
      metrics.add('SpO2 ${bloodOxygenAvgPct!.toStringAsFixed(0)}%');
    }
    if (distanceMeters != null) {
      metrics.add('distance ${(distanceMeters! / 1000).toStringAsFixed(1)} km');
    }
    if (exerciseMinutes != null) {
      metrics.add('activity ${exerciseMinutes!.toStringAsFixed(0)} min');
    }
    if (activeEnergyKcal != null) {
      metrics.add('energy ${activeEnergyKcal!.toStringAsFixed(0)} kcal');
    }
    if (recordCount > 0) {
      metrics.add('records $recordCount');
    }

    final dateLabel = summaryDate.toIso8601String().split('T').first;
    final sourceParts = <String>[];
    final cleanedSourceName = sourceName?.trim();
    if (cleanedSourceName != null && cleanedSourceName.isNotEmpty) {
      sourceParts.add(cleanedSourceName);
    }
    final cleanedDeviceModel = sourceDeviceModel?.trim();
    if (cleanedDeviceModel != null && cleanedDeviceModel.isNotEmpty) {
      sourceParts.add(cleanedDeviceModel);
    }
    final sourceLabel = sourceParts.isEmpty
        ? ''
        : ' (${sourceParts.join(' - ')})';
    final metricsLabel = metrics.isEmpty
        ? 'no metrics available'
        : metrics.join(', ');
    return '$dateLabel$sourceLabel: $metricsLabel';
  }
}
