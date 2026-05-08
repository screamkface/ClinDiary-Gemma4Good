import 'package:clindiary/app/core/security/app_lock_service.dart';
import 'package:clindiary/app/dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLockState {
  const AppLockState({required this.settings, required this.unlocked});

  final AppLockSettings settings;
  final bool unlocked;

  bool get shouldBlock => settings.enabled && !unlocked;

  AppLockState copyWith({AppLockSettings? settings, bool? unlocked}) {
    return AppLockState(
      settings: settings ?? this.settings,
      unlocked: unlocked ?? this.unlocked,
    );
  }
}

final appLockServiceProvider = Provider<AppLockService>(
  (ref) =>
      AppLockService(secureStorage: ref.watch(flutterSecureStorageProvider)),
);

final appLockControllerProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(
      AppLockController.new,
    );

class AppLockController extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() async {
    final settings = await ref.watch(appLockServiceProvider).readSettings();
    return AppLockState(settings: settings, unlocked: !settings.enabled);
  }

  Future<void> setPin(String pin) async {
    await ref.read(appLockServiceProvider).setPin(pin);
    final settings = await ref.read(appLockServiceProvider).readSettings();
    state = AsyncData(AppLockState(settings: settings, unlocked: true));
  }

  Future<void> setEnabled(bool enabled) async {
    final service = ref.read(appLockServiceProvider);
    final current = state.valueOrNull;
    if (enabled && current?.settings.pinSet != true) {
      throw StateError('Set a PIN before enabling app lock.');
    }
    await service.setEnabled(enabled);
    final settings = await service.readSettings();
    state = AsyncData(AppLockState(settings: settings, unlocked: !enabled));
  }

  Future<void> disable() async {
    await ref.read(appLockServiceProvider).disable();
    final settings = await ref.read(appLockServiceProvider).readSettings();
    state = AsyncData(AppLockState(settings: settings, unlocked: true));
  }

  Future<bool> unlockWithPin(String pin) async {
    final success = await ref.read(appLockServiceProvider).verifyPin(pin);
    if (success) {
      _markUnlocked();
    }
    return success;
  }

  Future<bool> unlockWithBiometrics() async {
    final success = await ref
        .read(appLockServiceProvider)
        .authenticateWithBiometrics();
    if (success) {
      _markUnlocked();
    }
    return success;
  }

  void lock() {
    final current = state.valueOrNull;
    if (current == null || !current.settings.enabled) {
      return;
    }
    state = AsyncData(current.copyWith(unlocked: false));
  }

  void _markUnlocked() {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(unlocked: true));
  }
}
