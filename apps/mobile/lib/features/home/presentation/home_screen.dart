import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/alerts/presentation/alert_ui.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

T _byBrightness<T>(BuildContext context, {required T light, required T dark}) {
  return Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final unreadNotificationsAsync = ref.watch(unreadNotificationsProvider);
    final pendingMedicationsAsync = ref.watch(pendingMedicationDosesProvider);
    final profileAsync = ref.watch(profileBundleProvider);
    final activeProfileIdAsync = ref.watch(activeProfileIdProvider);
    final l10n = AppLocalizations.of(context);

    final alertsCount = alertsAsync.asData?.value.length ?? 0;
    final hasUnreadNotifications =
        unreadNotificationsAsync.asData?.value ?? false;
    final hasPendingMedications =
        pendingMedicationsAsync.asData?.value ?? false;

    return RefreshIndicator(
      onRefresh: () async {
        invalidatePatientScopedProviders(ref);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          profileAsync.when(
            data: (bundle) => SectionCard(
              title: l10n.todayTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bundle?.profile.displayName ??
                                  l10n.profileSetupInProgress,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bundle == null
                                  ? l10n.completeOnboardingToStart
                                  : 'Start with one action below.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _HomeAvatar(label: bundle?.profile.displayName ?? 'CD'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusPill(
                        icon: alertsCount == 0
                            ? Icons.check_circle_outline
                            : Icons.notification_important_outlined,
                        onTap: () => context.push('/app/home/alerts'),
                        tone: alertsCount == 0
                            ? _byBrightness(
                                context,
                                light: Colors.green.shade50,
                                dark: Colors.green.shade900.withValues(
                                  alpha: 0.36,
                                ),
                              )
                            : _byBrightness(
                                context,
                                light: Colors.red.shade50,
                                dark: Colors.red.shade900.withValues(
                                  alpha: 0.36,
                                ),
                              ),
                        iconColor: alertsCount == 0
                            ? _byBrightness(
                                context,
                                light: Colors.green.shade700,
                                dark: Colors.green.shade100,
                              )
                            : _byBrightness(
                                context,
                                light: Colors.red.shade700,
                                dark: Colors.red.shade100,
                              ),
                        labelColor: alertsCount == 0
                            ? _byBrightness(
                                context,
                                light: Colors.green.shade900,
                                dark: Colors.green.shade100,
                              )
                            : _byBrightness(
                                context,
                                light: Colors.red.shade900,
                                dark: Colors.red.shade100,
                              ),
                        label: Text(
                          alertsCount == 0
                              ? l10n.alertsAllClear
                              : l10n.alertsCountLabel(alertsCount),
                        ),
                      ),
                      _StatusPill(
                        icon: hasUnreadNotifications
                            ? Icons.mark_email_unread_outlined
                            : Icons.notifications_none_outlined,
                        onTap: () => context.push('/app/home/notifications'),
                        tone: _byBrightness(
                          context,
                          light: Colors.lightBlue.shade50,
                          dark: Colors.lightBlue.shade900.withValues(
                            alpha: 0.36,
                          ),
                        ),
                        iconColor: _byBrightness(
                          context,
                          light: Colors.lightBlue.shade700,
                          dark: Colors.lightBlue.shade100,
                        ),
                        labelColor: _byBrightness(
                          context,
                          light: Colors.lightBlue.shade900,
                          dark: Colors.lightBlue.shade100,
                        ),
                        label: Text(
                          hasUnreadNotifications
                              ? l10n.notificationsUnread
                              : l10n.notificationsAllCaughtUp,
                        ),
                      ),
                      _StatusPill(
                        icon: hasPendingMedications
                            ? Icons.medication_outlined
                            : Icons.checklist_outlined,
                        onTap: () => context.push('/app/home/medications'),
                        tone: _byBrightness(
                          context,
                          light: Colors.amber.shade50,
                          dark: Colors.amber.shade900.withValues(alpha: 0.34),
                        ),
                        iconColor: _byBrightness(
                          context,
                          light: Colors.amber.shade800,
                          dark: Colors.amber.shade100,
                        ),
                        labelColor: _byBrightness(
                          context,
                          light: Colors.amber.shade900,
                          dark: Colors.amber.shade100,
                        ),
                        label: Text(
                          hasPendingMedications
                              ? l10n.medicationsDue
                              : l10n.medicationsAllCaughtUp,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _HomeProfileChooser(
                    bundle: bundle,
                    activeProfileId: activeProfileIdAsync.asData?.value,
                    onSelectProfile: (profileId) =>
                        _setActiveProfile(context, ref, profileId),
                    onManageProfiles: () => context.push('/app/profile/family'),
                  ),
                ],
              ),
            ),
            loading: () => SectionCard(
              title: l10n.todayTitle,
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: l10n.todayTitle,
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 12),
          _FriendlyShortcutSection(
            hasUnreadNotifications: hasUnreadNotifications,
            hasPendingMedications: hasPendingMedications,
          ),
          const SizedBox(height: 12),
          alertsAsync.when(
            data: (alerts) => _HomeAlertsSection(alerts: alerts),
            loading: () => const SectionCard(
              title: 'Alerts',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                SectionCard(title: 'Alerts', child: Text(error.toString())),
          ),
        ],
      ),
    );
  }
}

String _profileChipLabel(PatientProfile profile, AppLocalizations l10n) {
  final parts = <String>[profile.displayName];
  if (profile.relationshipLabel != null &&
      profile.relationshipLabel!.isNotEmpty) {
    parts.add(profile.relationshipLabel!);
  }
  if (profile.isPrimary) {
    parts.add(l10n.primaryProfileLabel);
  }
  return parts.join(' · ');
}

Future<void> _setActiveProfile(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  try {
    await ref.read(profileRepositoryProvider).setActiveProfileId(profileId);
    invalidatePatientScopedProviders(ref);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _HomeProfileChooser extends StatelessWidget {
  const _HomeProfileChooser({
    required this.bundle,
    required this.activeProfileId,
    required this.onSelectProfile,
    required this.onManageProfiles,
  });

  final ProfileBundle? bundle;
  final String? activeProfileId;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onManageProfiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (bundle == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profiles, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(l10n.completeOnboardingToStart),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onManageProfiles,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(l10n.add),
            ),
          ],
        ),
      );
    }

    final profiles = bundle!.managedProfiles.isNotEmpty
        ? bundle!.managedProfiles
        : <PatientProfile>[bundle!.profile];
    final selectedId = activeProfileId?.trim().isNotEmpty == true
        ? activeProfileId!.trim()
        : bundle!.profile.id;
    final activeProfile = profiles.firstWhere(
      (profile) => profile.id == selectedId,
      orElse: () => bundle!.profile,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.switch_account_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profiles,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.activeProfileLabel(activeProfile.displayName),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onManageProfiles,
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: Text(l10n.manage),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final profile in profiles)
                FilterChip(
                  selected: profile.id == selectedId,
                  label: Text(_profileChipLabel(profile, l10n)),
                  onSelected: (_) => onSelectProfile(profile.id),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l10n.add),
                onPressed: onManageProfiles,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendlyShortcutSection extends StatelessWidget {
  const _FriendlyShortcutSection({
    required this.hasUnreadNotifications,
    required this.hasPendingMedications,
  });

  final bool hasUnreadNotifications;
  final bool hasPendingMedications;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <_FriendlyShortcut>[
      _FriendlyShortcut(
        title: 'Add check-up',
        subtitle: 'How are you today?',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF5B5CE2),
        route: '/app/diary/check-up',
      ),
      _FriendlyShortcut(
        title: 'Vaccines',
        subtitle: 'History and boosters',
        icon: Icons.vaccines_rounded,
        color: const Color(0xFFFF7A59),
        route: '/app/profile/vaccinations',
      ),
      _FriendlyShortcut(
        title: 'Documents',
        subtitle: 'Reports and files',
        icon: Icons.folder_rounded,
        color: const Color(0xFF23A6D5),
        route: '/app/documents',
        useGo: true,
      ),
      _FriendlyShortcut(
        title: 'Ask AI',
        subtitle: 'Summaries and help',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF8E5CF7),
        route: '/app/ai',
        useGo: true,
      ),
      _FriendlyShortcut(
        title: 'Medications',
        subtitle: 'Today schedule',
        icon: Icons.medication_rounded,
        color: const Color(0xFF18A999),
        route: '/app/home/medications',
        showBadge: hasPendingMedications,
        badgeKey: const ValueKey('home-medications-badge'),
      ),
      _FriendlyShortcut(
        title: 'Prevention',
        subtitle: 'Checks to plan',
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFFF4A62A),
        route: '/app/home/prevention-center',
      ),
      _FriendlyShortcut(
        title: 'History',
        subtitle: 'Diary timeline',
        icon: Icons.event_note_rounded,
        color: const Color(0xFF6C8AE4),
        route: '/app/home/history',
      ),
      _FriendlyShortcut(
        title: 'Dossier',
        subtitle: 'Health profile',
        icon: Icons.folder_shared_rounded,
        color: const Color(0xFF4B9F72),
        route: '/app/home/dossier',
      ),
      _FriendlyShortcut(
        title: 'Timeline',
        subtitle: 'All events',
        icon: Icons.timeline_rounded,
        color: const Color(0xFFEF6F6C),
        route: '/app/home/timeline',
      ),
      _FriendlyShortcut(
        title: 'Notifications',
        subtitle: 'Reminders and alerts',
        icon: Icons.notifications_rounded,
        color: const Color(0xFFDF7FD2),
        route: '/app/home/notifications',
        showBadge: hasUnreadNotifications,
        badgeKey: const ValueKey('home-notifications-badge'),
      ),
      _FriendlyShortcut(
        title: 'Smartwatch',
        subtitle: 'Daily data sync',
        icon: Icons.watch_rounded,
        color: const Color(0xFF17A2B8),
        route: '/app/home/wearables',
      ),
      _FriendlyShortcut(
        title: 'Devices',
        subtitle: 'Connected tools',
        icon: Icons.device_hub_rounded,
        color: const Color(0xFF7A7FD1),
        route: '/app/home/devices',
      ),
      _FriendlyShortcut(
        title: 'Alerts',
        subtitle: 'Open checks',
        icon: Icons.notification_important_rounded,
        color: const Color(0xFFE05A47),
        route: '/app/home/alerts',
      ),
      _FriendlyShortcut(
        title: 'Privacy & AI',
        subtitle: 'Local controls',
        icon: Icons.shield_rounded,
        color: const Color(0xFF657786),
        route: '/app/profile/settings/privacy-ai',
      ),
    ];

    return SectionCard(
      title: 'What do you need?',
      subtitle: 'The important sections are now one tap away.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 760 ? 3 : 2;
          return GridView.builder(
            itemCount: shortcuts.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: constraints.maxWidth >= 760 ? 1.9 : 1.24,
            ),
            itemBuilder: (context, index) {
              final item = shortcuts[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.96, end: 1),
                duration: Duration(milliseconds: 260 + index * 36),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: _FriendlyShortcutCard(
                  item: item,
                  onTap: () {
                    if (item.useGo) {
                      context.go(item.route);
                    } else {
                      context.push(item.route);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FriendlyShortcut {
  const _FriendlyShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.useGo = false,
    this.showBadge = false,
    this.badgeKey,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool useGo;
  final bool showBadge;
  final Key? badgeKey;
}

class _FriendlyShortcutCard extends StatelessWidget {
  const _FriendlyShortcutCard({required this.item, required this.onTap});

  final _FriendlyShortcut item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF20262F);
    return Semantics(
      button: true,
      label: item.title,
      child: Material(
        color: item.color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: item.color.withValues(alpha: 0.24),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(item.icon, color: Colors.white),
                        ),
                        if (item.showBadge)
                          Positioned(
                            key: item.badgeKey,
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: item.color,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeAlertsSection extends StatelessWidget {
  const _HomeAlertsSection({required this.alerts});

  final List<ClinicalAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final openAlerts = alerts.where((alert) => !alert.isResolved).toList();
    if (openAlerts.isEmpty) {
      return SectionCard(
        title: 'Alerts',
        subtitle: 'Everything looks stable right now.',
        action: TextButton.icon(
          onPressed: () => context.push('/app/home/alerts'),
          icon: const Icon(Icons.open_in_new_outlined),
          label: const Text('Open center'),
        ),
        child: const Text('No active alerts to review.'),
      );
    }

    final topAlerts = openAlerts.take(3).toList();
    final dateFormat = DateFormat('dd MMM · HH:mm', 'en_US');

    return SectionCard(
      title: 'Alerts',
      subtitle: 'Tap an alert to open the relevant section.',
      action: TextButton.icon(
        onPressed: () => context.push('/app/home/alerts'),
        icon: const Icon(Icons.open_in_new_outlined),
        label: const Text('View all'),
      ),
      child: Column(
        children: topAlerts
            .map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card.outlined(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    key: ValueKey('home-alert-${alert.id}'),
                    onTap: () => context.push(_routeForAlert(alert)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: alertSeverityColor(
                        context,
                        alert.severity,
                      ).withValues(alpha: 0.14),
                      child: Icon(
                        alertSeverityIcon(alert.severity),
                        color: alertSeverityColor(context, alert.severity),
                      ),
                    ),
                    title: Text(
                      alert.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          alert.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${alertSeverityLabel(alert.severity)} · ${dateFormat.format(alert.triggeredAt.toLocal())}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _routeForAlert(ClinicalAlert alert) {
    final marker =
        '${alert.alertType} ${alert.ruleCode ?? ''} ${alert.title} ${alert.description}'
            .toLowerCase();
    final isCheckUpAlert =
        marker.contains('check-up') ||
        marker.contains('check up') ||
        marker.contains('checkup') ||
        marker.contains('screening') ||
        marker.contains('annual visit') ||
        marker.contains('prevention');
    return isCheckUpAlert ? '/app/home/screenings' : '/app/home/alerts';
  }
}

class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.isEmpty
        ? 'CD'
        : parts.map((part) => part.substring(0, 1).toUpperCase()).join();

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.icon,
    this.onTap,
    this.tone,
    this.iconColor,
    this.labelColor,
  });

  final Widget label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? tone;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseLabelStyle =
        Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    final background =
        tone ?? colorScheme.surfaceContainerHighest.withValues(alpha: 0.52);
    final resolvedIconColor = iconColor ?? colorScheme.primary;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: resolvedIconColor),
            const SizedBox(width: 6),
          ],
          DefaultTextStyle(
            style: baseLabelStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: labelColor ?? baseLabelStyle.color,
            ),
            child: label,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
