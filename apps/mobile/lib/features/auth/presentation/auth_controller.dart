import 'package:clindiary/app/dependencies.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() {
    return ref.watch(authRepositoryProvider).restoreSession();
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final session = await AsyncValue.guard<AuthSession>(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
    state = session;
    return session.requireValue;
  }

  Future<AuthSession> loginWithGoogle({
    required String idToken,
  }) async {
    state = const AsyncLoading();
    final session = await AsyncValue.guard<AuthSession>(
      () => ref.read(authRepositoryProvider).loginWithGoogle(idToken: idToken),
    );
    state = session;
    return session.requireValue;
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final session = await AsyncValue.guard<AuthSession>(
      () => ref
          .read(authRepositoryProvider)
          .register(email: email, password: password),
    );
    state = session;
    return session.requireValue;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount({required String confirmationText}) async {
    await ref
        .read(authRepositoryProvider)
        .deleteAccount(confirmationText: confirmationText);
    state = const AsyncData(null);
  }

  Future<void> updateUser(UserSummary user) async {
    await ref.read(authRepositoryProvider).updateUser(user);
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(user: user));
  }
}
