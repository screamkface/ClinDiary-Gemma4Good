import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/auth/presentation/login_screen.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('login screen submits and navigates to home', (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
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
          authControllerProvider.overrideWith(FakeAuthController.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('it'),
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

    final textFields = find.byType(TextFormField);
    final passwordField = textFields.at(1);

    expect(
      tester.widget<TextFormField>(passwordField).controller?.text,
      'ChangeMe123!',
    );

    final emailField = textFields.at(0);

    await tester.enterText(emailField, 'patient@example.com');
    await tester.enterText(passwordField, 'StrongPass123!');
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Home reached'), findsOneWidget);
  });
}
