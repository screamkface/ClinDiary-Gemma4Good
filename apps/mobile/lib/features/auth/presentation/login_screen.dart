import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Future<void>? _googleSignInInitialization;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      context.go(
        session.user.onboardingCompleted ? '/app/home' : '/onboarding',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.signInFailed(error.message))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.signInFailed(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    final clientId = ref.read(appConfigProvider).googleAuthClientId.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.googleAuthNotConfigured)),
      );
      return;
    }

    setState(() => _isGoogleSubmitting = true);
    try {
      await _ensureGoogleSignInInitialized(clientId);
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'openid', 'profile'],
      );
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(l10n.googleIdTokenInvalid);
      }
      final session = await ref
          .read(authControllerProvider.notifier)
          .loginWithGoogle(idToken: idToken);
      if (!mounted) return;
      context.go(
        session.user.onboardingCompleted ? '/app/home' : '/onboarding',
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.googleSignInFailed(error.toString()))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.googleSignInFailed(error.message))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.googleSignInFailed(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleSubmitting = false);
      }
    }
  }

  Future<void> _ensureGoogleSignInInitialized(String clientId) {
    final existing = _googleSignInInitialization;
    if (existing != null) {
      return existing;
    }
    _googleSignInInitialization = GoogleSignIn.instance.initialize(
      serverClientId: clientId,
    );
    return _googleSignInInitialization!;
  }

  Future<void> _requestPasswordReset() async {
    final l10n = AppLocalizations.of(context)!;
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordResetPrompt)),
      );
      return;
    }

    try {
      final previewToken = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      final message = previewToken == null
          ? l10n.passwordResetStarted
          : l10n.passwordResetStartedToken(previewToken);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordResetFailed(error.message))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.passwordResetFailed(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleAuthClientId = ref.watch(appConfigProvider).googleAuthClientId.trim();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF2FB), Color(0xFFF8F2EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const ClinDiaryLogo(size: 58),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.appTitle,
                                    style: Theme.of(context).textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.appSubtitle,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: l10n.emailLabel),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return l10n.emailInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: l10n.passwordLabel,
                          ),
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return l10n.passwordMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: Text(
                              _isSubmitting ? l10n.signingIn : l10n.signIn,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (googleAuthClientId.isNotEmpty) ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _isGoogleSubmitting
                                  ? null
                                  : _submitWithGoogle,
                              icon: const Icon(Icons.account_circle_outlined),
                              label: Text(
                                _isGoogleSubmitting
                                    ? l10n.signingInWithGoogle
                                    : l10n.signInWithGoogle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : _requestPasswordReset,
                          child: Text(l10n.resetPassword),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(l10n.noAccountPrompt),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => context.go('/register'),
                              child: Text(l10n.register),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
