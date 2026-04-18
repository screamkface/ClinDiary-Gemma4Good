import 'package:clindiary/shared/widgets/root_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('back gesture pops the current branch page first', (
    tester,
  ) async {
    final homeKey = GlobalKey<NavigatorState>();
    final secondaryKey = GlobalKey<NavigatorState>();

    final router = GoRouter(
      initialLocation: '/secondary/detail',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => RootShell(
            navigationShell: navigationShell,
            branchNavigatorKeys: [homeKey, secondaryKey],
          ),
          branches: [
            StatefulShellBranch(
              navigatorKey: homeKey,
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) =>
                      const Scaffold(body: Center(child: Text('Home Root'))),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: secondaryKey,
              routes: [
                GoRoute(
                  path: '/secondary',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Secondary Root')),
                  ),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (context, state) => const Scaffold(
                        body: Center(child: Text('Secondary Detail')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Secondary Detail'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Secondary Root'), findsOneWidget);
    expect(find.text('Secondary Detail'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Home Root'), findsOneWidget);
    expect(find.text('Secondary Root'), findsNothing);
  });

  testWidgets('bottom bar does not overflow with large text', (tester) async {
    final keys = List.generate(5, (_) => GlobalKey<NavigatorState>());

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => RootShell(
            navigationShell: navigationShell,
            branchNavigatorKeys: keys,
          ),
          branches: [
            for (final route in [
              '/home',
              '/journal',
              '/ai',
              '/documents',
              '/profile',
            ])
              StatefulShellBranch(
                navigatorKey:
                    keys[[
                      '/home',
                      '/journal',
                      '/ai',
                      '/documents',
                      '/profile',
                    ].indexOf(route)],
                routes: [
                  GoRoute(
                    path: route,
                    builder: (context, state) =>
                        Scaffold(body: Center(child: Text(route))),
                  ),
                ],
              ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
