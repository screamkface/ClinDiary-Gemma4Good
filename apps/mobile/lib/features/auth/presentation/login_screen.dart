import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Accesso non riuscito: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitWithGoogle() async {
    final clientId = ref.read(appConfigProvider).googleAuthClientId.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google auth non configurato in questa build.'),
        ),
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
        throw Exception('Google non ha restituito un id token valido.');
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
        SnackBar(content: Text('Accesso Google non riuscito: $error')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accesso Google non riuscito: $error')),
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
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci prima l’email per avviare il reset.'),
        ),
      );
      return;
    }

    try {
      final previewToken = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      final message = previewToken == null
          ? 'Reset avviato. Controlla il canale previsto.'
          : 'Reset avviato. Token sviluppo: $previewToken';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset non riuscito: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleAuthClientId = ref.watch(appConfigProvider).googleAuthClientId.trim();

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
                                    'ClinDiary',
                                    style: Theme.of(context).textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Diario clinico personale.',
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
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return 'Inserisci una email valida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return 'Minimo 8 caratteri';
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
                              _isSubmitting ? 'Accesso...' : 'Accedi',
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
                                    ? 'Accesso Google...'
                                    : 'Accedi con Google',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : _requestPasswordReset,
                          child: const Text('Avvia reset password'),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Non hai un account?'),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => context.go('/register'),
                              child: const Text('Registrati'),
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
