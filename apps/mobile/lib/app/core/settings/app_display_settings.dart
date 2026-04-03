import 'dart:convert';

import 'package:clindiary/app/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemePreference { system, light, dark }

class AppDisplaySettings {
  const AppDisplaySettings({
    this.themePreference = AppThemePreference.system,
    this.textScale = 1.0,
  });

  factory AppDisplaySettings.fromJson(Map<String, dynamic> json) {
    return AppDisplaySettings(
      themePreference: AppThemePreference.values.firstWhere(
        (value) => value.name == json['theme_preference'],
        orElse: () => AppThemePreference.system,
      ),
      textScale: (json['text_scale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  final AppThemePreference themePreference;
  final double textScale;

  ThemeMode get themeMode {
    switch (themePreference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  AppDisplaySettings copyWith({
    AppThemePreference? themePreference,
    double? textScale,
  }) {
    return AppDisplaySettings(
      themePreference: themePreference ?? this.themePreference,
      textScale: textScale ?? this.textScale,
    );
  }

  Map<String, dynamic> toJson() {
    return {'theme_preference': themePreference.name, 'text_scale': textScale};
  }
}

class AppDisplaySettingsController extends AsyncNotifier<AppDisplaySettings> {
  static const _cacheKey = 'app_display_settings';

  @override
  Future<AppDisplaySettings> build() async {
    final payload = await ref.watch(localDatabaseProvider).readCache(_cacheKey);
    if (payload == null || payload.isEmpty) {
      return const AppDisplaySettings();
    }

    try {
      return AppDisplaySettings.fromJson(
        jsonDecode(payload) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppDisplaySettings();
    }
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    final current = state.valueOrNull ?? const AppDisplaySettings();
    await _persist(current.copyWith(themePreference: value));
  }

  Future<void> setTextScale(double value) async {
    final current = state.valueOrNull ?? const AppDisplaySettings();
    final normalized = value.clamp(0.85, 1.4).toDouble();
    await _persist(current.copyWith(textScale: normalized));
  }

  Future<void> reset() async {
    await _persist(const AppDisplaySettings());
  }

  Future<void> _persist(AppDisplaySettings next) async {
    state = AsyncData(next);
    await ref
        .read(localDatabaseProvider)
        .putCache(key: _cacheKey, payload: jsonEncode(next.toJson()));
  }
}

final appDisplaySettingsControllerProvider =
    AsyncNotifierProvider<AppDisplaySettingsController, AppDisplaySettings>(
      AppDisplaySettingsController.new,
    );
