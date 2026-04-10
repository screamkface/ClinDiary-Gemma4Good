import 'package:clindiary/app/providers.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionGateScreen extends ConsumerWidget {
  const SessionGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    Widget loadingBody(String message) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClinDiaryLogo(size: 86),
            const SizedBox(height: 18),
            Text(
              l10n.appTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
        ),
      );
    }

    return Scaffold(
      body: authState.when(
        data: (session) {
          final target = session == null
              ? '/login'
              : session.user.onboardingCompleted
              ? '/app/home'
              : '/onboarding';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(target);
            }
          });
          return loadingBody(l10n.verifyingSession);
        },
        loading: () => loadingBody(l10n.startingApp),
        error: (_, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/login');
            }
          });
          return loadingBody(l10n.redirectingToLogin);
        },
      ),
    );
  }
}
