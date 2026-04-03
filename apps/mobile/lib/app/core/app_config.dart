import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.googleAuthClientId = '',
  });

  final String apiBaseUrl;
  final String googleAuthClientId;
}

const defaultAppConfig = AppConfig(
  apiBaseUrl: String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  ),
  googleAuthClientId: String.fromEnvironment(
    'GOOGLE_AUTH_CLIENT_ID',
    defaultValue: '',
  ),
);
