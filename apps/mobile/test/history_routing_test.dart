import 'package:clindiary/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Routing to history test', (tester) async {
    FlutterError.onError = (details) {
      print('FLUTTER_ERROR_MSG: ' + details.exception.toString());
      print(details.stack);
    };

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(appRouterProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    // It redirects to /login. But let's mock auth or just go directly
    // Actually, we can bypass Auth by taking the HistoryScreen directly
  });
}
