import 'package:clindiary/app/core/security/app_lock_controller.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  final _pinController = TextEditingController();
  bool _submitting = false;
  bool _biometricPromptStarted = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    final success = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithPin(pin);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (success) {
      _pinController.clear();
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.appLockGateIncorrectPin)));
  }

  Future<void> _unlockWithBiometrics() async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    final success = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithBiometrics();
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (!success) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.appLockGateUnlockWasNotCompleted)),
      );
    }
  }

  void _startBiometricPromptIfNeeded(bool biometricAvailable) {
    if (!biometricAvailable || _biometricPromptStarted || _submitting) {
      return;
    }
    _biometricPromptStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _unlockWithBiometrics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    return lockState.when(
      data: (state) {
        if (!state.shouldBlock) {
          _biometricPromptStarted = false;
          return widget.child;
        }
        _startBiometricPromptIfNeeded(state.settings.biometricAvailable);
        return _LockScreen(
          pinController: _pinController,
          submitting: _submitting,
          biometricAvailable: state.settings.biometricAvailable,
          onPinSubmitted: _unlockWithPin,
          onBiometricPressed: _unlockWithBiometrics,
        );
      },
      loading: () => widget.child,
      error: (_, _) => widget.child,
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.pinController,
    required this.submitting,
    required this.biometricAvailable,
    required this.onPinSubmitted,
    required this.onBiometricPressed,
  });

  final TextEditingController pinController;
  final bool submitting;
  final bool biometricAvailable;
  final VoidCallback onPinSubmitted;
  final VoidCallback onBiometricPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: ClinDiaryLogo(size: 72)),
                      const SizedBox(height: 16),
                      Text(
                        l10n.appLockGateClindiaryIsLocked,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.appLockGateUnlockToAccessLocalHealthData,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      if (biometricAvailable) ...[
                        FilledButton.icon(
                          onPressed: submitting ? null : onBiometricPressed,
                          icon: const Icon(Icons.fingerprint_outlined),
                          label: Text(
                            submitting
                                ? l10n.appLockGateUnlocking
                                : l10n.appLockGateUseBiometrics,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: l10n.appLockGate6DigitPin,
                          counterText: '',
                        ),
                        onSubmitted: (_) => onPinSubmitted(),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: submitting ? null : onPinSubmitted,
                        child: Text(
                          submitting
                              ? l10n.appLockGateUnlocking
                              : l10n.appLockGateUnlock,
                        ),
                      ),
                    ],
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
