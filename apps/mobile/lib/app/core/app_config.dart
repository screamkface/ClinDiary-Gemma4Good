import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.hackathonDemoMode = false,
    this.localOnlyMode = false,
    this.googleAuthClientId = '',
  });

  final String apiBaseUrl;
  final bool hackathonDemoMode;
  final bool localOnlyMode;
  final String googleAuthClientId;
}

const defaultAppConfig = AppConfig(
  apiBaseUrl: String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  ),
  hackathonDemoMode: bool.fromEnvironment(
    'HACKATHON_DEMO_MODE',
    defaultValue: false,
  ),
  localOnlyMode: true,
  googleAuthClientId: String.fromEnvironment(
    'GOOGLE_AUTH_CLIENT_ID',
    defaultValue: '',
  ),
);
