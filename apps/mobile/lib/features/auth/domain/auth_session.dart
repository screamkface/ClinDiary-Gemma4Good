class UserSummary {
  const UserSummary({
    required this.id,
    required this.email,
    required this.role,
    required this.onboardingCompleted,
    required this.healthDataConsent,
    this.aiExternalConsent = false,
    this.aiExternalConsentedAt,
    this.authProvider = 'password',
  });

  final String id;
  final String email;
  final String role;
  final bool onboardingCompleted;
  final bool healthDataConsent;
  final bool aiExternalConsent;
  final DateTime? aiExternalConsentedAt;
  final String authProvider;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'].toString(),
      email: json['email'].toString(),
      role: json['role'].toString(),
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      healthDataConsent: json['health_data_consent'] as bool? ?? false,
      aiExternalConsent: json['ai_external_consent'] as bool? ?? false,
      aiExternalConsentedAt: json['ai_external_consented_at'] == null
          ? null
          : DateTime.parse(json['ai_external_consented_at'].toString()),
      authProvider: json['auth_provider']?.toString() ?? 'password',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    'onboarding_completed': onboardingCompleted,
    'health_data_consent': healthDataConsent,
    'ai_external_consent': aiExternalConsent,
    'ai_external_consented_at': aiExternalConsentedAt?.toIso8601String(),
    'auth_provider': authProvider,
  };

  UserSummary copyWith({
    bool? onboardingCompleted,
    bool? healthDataConsent,
    bool? aiExternalConsent,
    DateTime? aiExternalConsentedAt,
    String? authProvider,
  }) {
    return UserSummary(
      id: id,
      email: email,
      role: role,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      healthDataConsent: healthDataConsent ?? this.healthDataConsent,
      aiExternalConsent: aiExternalConsent ?? this.aiExternalConsent,
      aiExternalConsentedAt:
          aiExternalConsentedAt ?? this.aiExternalConsentedAt,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final UserSummary user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'].toString(),
      refreshToken: json['refresh_token'].toString(),
      accessTokenExpiresAt: DateTime.parse(
        json['access_token_expires_at'].toString(),
      ).toUtc(),
      refreshTokenExpiresAt: DateTime.parse(
        json['refresh_token_expires_at'].toString(),
      ).toUtc(),
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_token_expires_at': accessTokenExpiresAt.toIso8601String(),
    'refresh_token_expires_at': refreshTokenExpiresAt.toIso8601String(),
    'user': user.toJson(),
  };

  AuthSession copyWith({UserSummary? user}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
      user: user ?? this.user,
    );
  }
}
