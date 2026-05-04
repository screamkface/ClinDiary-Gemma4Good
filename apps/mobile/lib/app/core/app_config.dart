import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    this.hackathonDemoMode = false,
    this.localOnlyMode = true,
  });

  final bool hackathonDemoMode;
  final bool localOnlyMode;
}

const defaultAppConfig = AppConfig(
  hackathonDemoMode: bool.fromEnvironment(
    'HACKATHON_DEMO_MODE',
    defaultValue: false,
  ),
  localOnlyMode: true,
);
