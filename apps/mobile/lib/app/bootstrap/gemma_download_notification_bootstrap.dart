import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/notifications/gemma_download_notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GemmaDownloadNotificationBootstrap extends ConsumerStatefulWidget {
  const GemmaDownloadNotificationBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GemmaDownloadNotificationBootstrap> createState() =>
      _GemmaDownloadNotificationBootstrapState();
}

class _GemmaDownloadNotificationBootstrapState
    extends ConsumerState<GemmaDownloadNotificationBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gemmaDownloadNotificationServiceProvider).initialize();
      _consumePendingRoute();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumePendingRoute();
    }
  }

  Future<void> _consumePendingRoute() async {
    final service = ref.read(onDeviceAiServiceProvider);
    final response = await service.consumePendingGemmaRoute();
    final route = response?.trim();
    if (route != null && route.isNotEmpty) {
      gemmaDownloadRouteNotifier.value = route;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
