import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/notifications/gemma_download_notification_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({
    required this.navigationShell,
    required this.branchNavigatorKeys,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  static const List<_ShellDestination> _destinations = [
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _ShellDestination(
      label: 'Check-in',
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note_rounded,
    ),
    _ShellDestination(
      label: 'AI',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      isCenterAction: true,
    ),
    _ShellDestination(
      label: 'Files',
      icon: Icons.folder_open_outlined,
      selectedIcon: Icons.folder_open_rounded,
    ),
    _ShellDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  @override
  void initState() {
    super.initState();
    _preloadLocalExperience();
    _listenToGemmaDownloadRoute();
  }

  void _listenToGemmaDownloadRoute() {
    gemmaDownloadRouteNotifier.addListener(_handleGemmaDownloadRoute);
  }

  void _handleGemmaDownloadRoute() {
    final route = gemmaDownloadRouteNotifier.value;
    if (route != null && route.contains('/app/ai')) {
      // Navigate to AI branch (index 2) instead of relying on router redirect
      widget.navigationShell.goBranch(2, initialLocation: false);
      // Clear the notifier so it doesn't trigger again
      gemmaDownloadRouteNotifier.value = null;
    }
  }

  @override
  void dispose() {
    gemmaDownloadRouteNotifier.removeListener(_handleGemmaDownloadRoute);
    super.dispose();
  }

  void _preloadLocalExperience() {
    Future<void>(() async {
      try {
        await Future.wait<dynamic>([
          ref.read(profileBundleProvider.future),
          ref.read(alertsProvider.future),
          ref.read(dailyEntriesProvider.future),
          ref.read(
            documentArchiveProvider(const DocumentArchiveQuery()).future,
          ),
          ref.read(documentFoldersProvider.future),
          ref.read(pendingOperationsProvider.future),
          ref.read(onDeviceAiStatusProvider.future),
        ]);
      } catch (_) {
        // Preload is best-effort and should never block shell rendering.
      }
    });
  }

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleDestinations = RootShell._destinations
        .take(widget.branchNavigatorKeys.length)
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        final branchNavigatorState = widget
            .branchNavigatorKeys[widget.navigationShell.currentIndex]
            .currentState;
        if (branchNavigatorState != null && branchNavigatorState.canPop()) {
          branchNavigatorState.pop();
          return;
        }

        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0, initialLocation: true);
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(bottom: false, child: widget.navigationShell),
        bottomNavigationBar: visibleDestinations.length == 5
            ? _ClinDiaryBottomBar(
                currentIndex: widget.navigationShell.currentIndex,
                destinations: visibleDestinations,
                onSelected: _onDestinationSelected,
              )
            : _FallbackBottomBar(
                currentIndex: widget.navigationShell.currentIndex,
                destinations: visibleDestinations,
                onSelected: _onDestinationSelected,
              ),
      ),
    );
  }
}

class _ClinDiaryBottomBar extends StatelessWidget {
  const _ClinDiaryBottomBar({
    required this.currentIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int currentIndex;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final surface = colorScheme.surface.withValues(alpha: 0.96);
    final leftItems = [0, 1];
    final rightItems = [3, 4];
    final activeColor = colorScheme.primary;
    final aiEndColor = Color.lerp(
      colorScheme.primary,
      colorScheme.secondary,
      0.18,
    )!;

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: textScale > 1
            ? const TextScaler.linear(1)
            : mediaQuery.textScaler,
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? 8 : 12),
        child: SizedBox(
          height: 84,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                      child: Row(
                        children: [
                          for (final index in leftItems)
                            Expanded(
                              child: _ShellBarItem(
                                destination: destinations[index],
                                selected: currentIndex == index,
                                activeColor: activeColor,
                                onTap: () => onSelected(index),
                              ),
                            ),
                          const SizedBox(width: 70),
                          for (final index in rightItems)
                            Expanded(
                              child: _ShellBarItem(
                                destination: destinations[index],
                                selected: currentIndex == index,
                                activeColor: activeColor,
                                onTap: () => onSelected(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -4,
                child: _AiCenterButton(
                  selected: currentIndex == 2,
                  startColor: activeColor,
                  endColor: aiEndColor,
                  onTap: () => onSelected(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackBottomBar extends StatelessWidget {
  const _FallbackBottomBar({
    required this.currentIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int currentIndex;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }
}

class _AiCenterButton extends StatelessWidget {
  const _AiCenterButton({
    required this.selected,
    required this.startColor,
    required this.endColor,
    required this.onTap,
  });

  final bool selected;
  final Color startColor;
  final Color endColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outerColor = Theme.of(context).colorScheme.surface;
    return Tooltip(
      message: 'AI',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: startColor.withValues(alpha: selected ? 0.2 : 0.12),
                  blurRadius: selected ? 18 : 12,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: outerColor,
                border: Border.all(color: outerColor, width: 2),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [startColor, endColor],
                  ),
                ),
                child: Icon(
                  selected
                      ? Icons.auto_awesome_rounded
                      : Icons.auto_awesome_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellBarItem extends StatelessWidget {
  const _ShellBarItem({
    required this.destination,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.76);

    return Tooltip(
      message: destination.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      key: ValueKey<bool>(selected),
                      color: selected ? activeColor : inactiveColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? activeColor : inactiveColor,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.isCenterAction = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isCenterAction;
}
