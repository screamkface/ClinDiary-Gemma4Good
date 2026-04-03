import 'package:clindiary/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('authControllerProvider espone la sessione attiva', () async {
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(FakeAuthController.new)],
    );
    addTearDown(container.dispose);

    final session = await container.read(authControllerProvider.future);

    expect(session, isNotNull);
    expect(session!.user.email, 'patient@example.com');
  });
}
