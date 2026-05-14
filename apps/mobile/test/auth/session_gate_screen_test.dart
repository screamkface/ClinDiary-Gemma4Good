import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/auth/presentation/auth_controller.dart';
import 'package:clindiary/features/auth/presentation/session_gate_screen.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';

class _SessionGateTestAuthController extends AuthController {
  static int loginCalls = 0;

  @override
  Future<AuthSession?> build() async {
    final cfg = ref.read(appConfigProvider);
    return cfg.hackathonDemoMode ? fakeSession : null;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    state = AsyncData(fakeSession);
    return fakeSession;
  }
}

void main() {
  testWidgets('session gate in demo mode opens home directly', (tester) async {
    _SessionGateTestAuthController.loginCalls = 0;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SessionGateScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login reached')),
        ),
        GoRoute(
          path: '/app/home',
          builder: (_, __) => const Scaffold(body: Text('Home reached')),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('Onboarding reached')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            (ref) => const AppConfig(hackathonDemoMode: true),
          ),
          authControllerProvider.overrideWith(
            _SessionGateTestAuthController.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_SessionGateTestAuthController.loginCalls, 0);
    expect(find.text('Home reached'), findsOneWidget);
  });

  testWidgets('session gate keeps the standard flow to login', (tester) async {
    _SessionGateTestAuthController.loginCalls = 0;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SessionGateScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login reached')),
        ),
        GoRoute(
          path: '/app/home',
          builder: (_, __) => const Scaffold(body: Text('Home reached')),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('Onboarding reached')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith((ref) => const AppConfig()),
          authControllerProvider.overrideWith(
            _SessionGateTestAuthController.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_SessionGateTestAuthController.loginCalls, 0);
    expect(find.text('Login reached'), findsOneWidget);
  });
}
