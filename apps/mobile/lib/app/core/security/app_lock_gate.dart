import 'package:clindiary/app/core/security/app_lock_controller.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref.read(appLockControllerProvider.notifier).lock();
    }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Incorrect PIN.')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock was not completed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    return lockState.when(
      data: (state) {
        if (!state.shouldBlock) {
          return widget.child;
        }
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
                        'ClinDiary is locked',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock to access local health data on this device.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '6 digit PIN',
                          counterText: '',
                        ),
                        onSubmitted: (_) => onPinSubmitted(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: submitting ? null : onPinSubmitted,
                        child: Text(submitting ? 'Unlocking...' : 'Unlock'),
                      ),
                      if (biometricAvailable) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: submitting ? null : onBiometricPressed,
                          icon: const Icon(Icons.fingerprint_outlined),
                          label: const Text('Use biometrics'),
                        ),
                      ],
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
