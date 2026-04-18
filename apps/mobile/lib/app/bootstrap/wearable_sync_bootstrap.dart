import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WearableSyncBootstrap extends ConsumerStatefulWidget {
  const WearableSyncBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WearableSyncBootstrap> createState() =>
      _WearableSyncBootstrapState();
}

class _WearableSyncBootstrapState extends ConsumerState<WearableSyncBootstrap>
    with WidgetsBindingObserver {
  static const _minSyncInterval = Duration(minutes: 15);

  DateTime? _lastAttemptAt;
  String? _lastUserId;
  Timer? _syncTimer;
  ProviderSubscription<AsyncValue<AuthSession?>>? _authSubscription;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(_minSyncInterval, (_) => _maybeSync());
    _authSubscription = ref.listenManual<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (previous, next) {
        final hadSession = previous?.asData?.value != null;
        final hasSession = next.asData?.value != null;
        if (!hadSession && hasSession) {
          unawaited(_maybeSync(force: true));
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeSync(force: true));
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeSync());
    }
  }

  Future<void> _maybeSync({bool force = false}) async {
    if (_syncing) {
      return;
    }

    final authState = ref.read(authControllerProvider);
    final session = authState.asData?.value;
    if (session == null) {
      _lastAttemptAt = null;
      _lastUserId = null;
      return;
    }

    if (_lastUserId != session.user.id) {
      _lastUserId = session.user.id;
      _lastAttemptAt = null;
    }

    final now = DateTime.now().toUtc();
    if (!force &&
        _lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < _minSyncInterval) {
      return;
    }

    _syncing = true;
    _lastAttemptAt = now;
    try {
      final status = await ref.read(wearableHealthServiceProvider).getStatus();
      ref.invalidate(wearableSyncStatusProvider);
      if (!status.isSupported ||
          !status.isAvailable ||
          !status.permissionGranted) {
        return;
      }

      final summaries = await ref
          .read(wearableHealthServiceProvider)
          .collectDailySummaries(days: 30);
      if (summaries.isEmpty) {
        return;
      }

      await ref.read(wearablesRepositoryProvider).syncDailySummaries(summaries);
      ref.invalidate(wearableDailySummariesProvider);
      ref.invalidate(historyDayProvider);
      ref.invalidate(insightSummaryProvider);
    } catch (_) {
      // Best effort sync to keep wearable data fresh for backend insights.
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
