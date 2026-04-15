import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionGateScreen extends ConsumerStatefulWidget {
  const SessionGateScreen({super.key});

  @override
  ConsumerState<SessionGateScreen> createState() => _SessionGateScreenState();
}

class _SessionGateScreenState extends ConsumerState<SessionGateScreen> {
  static const _demoEmail = 'demo@clindiary.app';
  static const _demoPassword = 'ChangeMe123!';

  bool _demoLoginScheduled = false;

  void _redirectAfterFrame(String target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(target);
      }
    });
  }

  void _startDemoLoginIfNeeded(AuthSession? session) {
    if (_demoLoginScheduled) {
      return;
    }

    final config = ref.read(appConfigProvider);
    if (!config.hackathonDemoMode || session != null) {
      return;
    }

    _demoLoginScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_runDemoLogin());
    });
  }

  Future<void> _runDemoLogin() async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: _demoEmail, password: _demoPassword);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _redirectAfterFrame('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final isHackathonDemoMode = ref.read(appConfigProvider).hackathonDemoMode;

    Widget loadingBody(String message) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClinDiaryLogo(size: 86),
            const SizedBox(height: 18),
            Text(
              l10n.appTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
        ),
      );
    }

    return Scaffold(
      body: authState.when(
        data: (session) {
          if (isHackathonDemoMode && session == null) {
            _startDemoLoginIfNeeded(session);
            return loadingBody(l10n.verifyingSession);
          }

          final target = session == null
              ? '/login'
              : session.user.onboardingCompleted
              ? '/app/home'
              : '/onboarding';
          _redirectAfterFrame(target);
          return loadingBody(l10n.verifyingSession);
        },
        loading: () => loadingBody(l10n.startingApp),
        error: (_, _) {
          _redirectAfterFrame('/login');
          return loadingBody(l10n.redirectingToLogin);
        },
      ),
    );
  }
}
