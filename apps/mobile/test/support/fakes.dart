import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/auth/presentation/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fakeSession = AuthSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  accessTokenExpiresAt: DateTime.utc(2099, 1, 1),
  refreshTokenExpiresAt: DateTime.utc(2099, 1, 2),
  user: const UserSummary(
    id: 'user-1',
    email: 'patient@example.com',
    role: 'patient',
    onboardingCompleted: true,
    healthDataConsent: true,
    authProvider: 'password',
  ),
);

class FakeAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => fakeSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    state = AsyncData(fakeSession);
    return fakeSession;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    state = AsyncData(fakeSession);
    return fakeSession;
  }

  @override
  Future<AuthSession> loginWithGoogle({
    required String idToken,
  }) async {
    state = AsyncData(fakeSession);
    return fakeSession;
  }
}
