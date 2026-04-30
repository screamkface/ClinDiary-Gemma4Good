import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/alerts/presentation/alert_ui.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
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
    final dailyEntriesAsync = ref.watch(dailyEntriesProvider);
    final pendingOperationsAsync = ref.watch(pendingOperationsProvider);
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
    final pendingSyncCount = pendingOperationsAsync.asData?.value.length ?? 0;
    final config = ref.read(appConfigProvider);
    final isDemoMode = config.hackathonDemoMode || config.localOnlyMode;

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
                        icon: pendingSyncCount > 0
                            ? Icons.sync_problem_outlined
                            : Icons.cloud_done_outlined,
                        onTap: () =>
                            context.push('/app/profile/settings/privacy-ai'),
                        tone: pendingSyncCount > 0
                            ? _byBrightness(
                                context,
                                light: Colors.deepOrange.shade50,
                                dark: Colors.deepOrange.shade900.withValues(
                                  alpha: 0.34,
                                ),
                              )
                            : _byBrightness(
                                context,
                                light: Colors.teal.shade50,
                                dark: Colors.teal.shade900.withValues(
                                  alpha: 0.34,
                                ),
                              ),
                        iconColor: pendingSyncCount > 0
                            ? _byBrightness(
                                context,
                                light: Colors.deepOrange.shade700,
                                dark: Colors.deepOrange.shade100,
                              )
                            : _byBrightness(
                                context,
                                light: Colors.teal.shade700,
                                dark: Colors.teal.shade100,
                              ),
                        labelColor: pendingSyncCount > 0
                            ? _byBrightness(
                                context,
                                light: Colors.deepOrange.shade900,
                                dark: Colors.deepOrange.shade100,
                              )
                            : _byBrightness(
                                context,
                                light: Colors.teal.shade900,
                                dark: Colors.teal.shade100,
                              ),
                        label: Text(
                          pendingSyncCount > 0
                              ? 'Sync pending: $pendingSyncCount'
                              : 'Local sync up to date',
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.push('/app/diary/check-up'),
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(l10n.checkUp),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/app/ai'),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(l10n.aiRecap),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/app/home/history'),
                        icon: const Icon(Icons.event_note_outlined),
                        label: const Text('History'),
                      ),
                    ],
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
          if (isDemoMode) ...[
            const SizedBox(height: 12),
            profileAsync.when(
              data: (bundle) {
                if (bundle == null) {
                  return const SizedBox.shrink();
                }
                final profiles = bundle.managedProfiles.isNotEmpty
                    ? bundle.managedProfiles
                    : <PatientProfile>[bundle.profile];
                if (profiles.length < 3) {
                  return const SizedBox.shrink();
                }
                final selectedId = activeProfileIdAsync.asData?.value;
                return SectionCard(
                  title: l10n.demoScenarios,
                  subtitle: l10n.judgeModeSubtitle,
                  action: FilledButton.tonalIcon(
                    onPressed: () => context.go('/app/ai'),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(l10n.openAiRecap),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (
                        var index = 0;
                        index < profiles.length && index < 3;
                        index++
                      )
                        FilterChip(
                          selected: profiles[index].id == selectedId,
                          label: Text(
                            _hackathonScenarioLabel(index, profiles[index]),
                          ),
                          onSelected: (_) => _setActiveProfile(
                            context,
                            ref,
                            profiles[index].id,
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
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
          const SizedBox(height: 12),
          dailyEntriesAsync.when(
            data: (entries) => _RecentCheckUpsSection(entries: entries),
            loading: () => const SectionCard(
              title: 'Recent check-ups',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Recent check-ups',
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Quick actions',
            subtitle: 'Use these most of the time.',
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _DashboardActionCard(
                  title: l10n.documents,
                  subtitle: 'Save and review files',
                  icon: Icons.description_outlined,
                  accentColor: _byBrightness(
                    context,
                    light: Colors.blue.shade700,
                    dark: Colors.blue.shade300,
                  ),
                  onTap: () => context.go('/app/documents'),
                ),
                _DashboardActionCard(
                  title: l10n.medications,
                  subtitle: 'Today and schedule',
                  icon: Icons.medication_outlined,
                  accentColor: _byBrightness(
                    context,
                    light: Colors.green.shade700,
                    dark: Colors.green.shade300,
                  ),
                  onTap: () => context.push('/app/home/medications'),
                  showBadge: hasPendingMedications,
                  badgeKey: const ValueKey('home-medications-badge'),
                ),
                _DashboardActionCard(
                  title: l10n.prevention,
                  subtitle: 'Next recommended checks',
                  icon: Icons.health_and_safety_outlined,
                  accentColor: _byBrightness(
                    context,
                    light: Colors.orange.shade700,
                    dark: Colors.orange.shade300,
                  ),
                  onTap: () => context.push('/app/home/prevention-center'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          profileAsync.when(
            data: (bundle) {
              if (bundle == null) {
                return SectionCard(
                  title: l10n.profiles,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.completeOnboardingToStart),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/app/profile/family'),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add profile'),
                      ),
                    ],
                  ),
                );
              }
              final selectedId = activeProfileIdAsync.asData?.value;
              final managedProfiles = bundle.managedProfiles.isNotEmpty
                  ? bundle.managedProfiles
                  : <PatientProfile>[bundle.profile];
              final activeProfile = managedProfiles.firstWhere(
                (profile) => profile.id == selectedId,
                orElse: () => bundle.profile,
              );
              return SectionCard(
                title: l10n.profiles,
                subtitle: l10n.activeProfileLabel(activeProfile.displayName),
                action: TextButton.icon(
                  onPressed: () => context.push('/app/profile/family'),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: Text(l10n.manage),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._buildProfileChips(
                      context,
                      ref,
                      bundle,
                      activeProfileIdAsync.asData?.value,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(l10n.add),
                      onPressed: () => context.push('/app/profile/family'),
                    ),
                  ],
                ),
              );
            },
            loading: () => SectionCard(
              title: l10n.profiles,
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: l10n.profiles,
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Secondary tools',
            subtitle: 'Less frequent actions and settings.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniActionChip(
                  label: l10n.devices,
                  icon: Icons.device_hub_outlined,
                  onPressed: () => context.push('/app/home/devices'),
                ),
                _MiniActionChip(
                  label: l10n.dossier,
                  icon: Icons.folder_shared_outlined,
                  onPressed: () => context.push('/app/home/dossier'),
                ),
                _MiniActionChip(
                  label: l10n.timeline,
                  icon: Icons.timeline_outlined,
                  onPressed: () => context.push('/app/home/timeline'),
                ),
                _MiniActionChip(
                  label: l10n.notifications,
                  icon: Icons.notifications_outlined,
                  onPressed: () => context.push('/app/home/notifications'),
                  showBadge: hasUnreadNotifications,
                  badgeKey: const ValueKey('home-notifications-badge'),
                ),
                _MiniActionChip(
                  label: l10n.smartwatch,
                  icon: Icons.watch_outlined,
                  onPressed: () => context.push('/app/home/wearables'),
                ),
                _MiniActionChip(
                  label: 'Privacy and AI',
                  icon: Icons.shield_outlined,
                  onPressed: () =>
                      context.push('/app/profile/settings/privacy-ai'),
                ),
                _MiniActionChip(
                  label: l10n.alerts,
                  icon: Icons.notification_important_outlined,
                  onPressed: () => context.push('/app/home/alerts'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildProfileChips(
  BuildContext context,
  WidgetRef ref,
  ProfileBundle? bundle,
  String? activeProfileId,
) {
  if (bundle == null) {
    return const [];
  }
  final l10n = AppLocalizations.of(context);
  final profiles = bundle.managedProfiles.isNotEmpty
      ? bundle.managedProfiles
      : <PatientProfile>[bundle.profile];
  final selectedId = activeProfileId?.trim().isNotEmpty == true
      ? activeProfileId!.trim()
      : bundle.profile.id;

  return profiles.map((profile) {
    final label = _profileChipLabel(profile, l10n);
    return FilterChip(
      selected: profile.id == selectedId,
      label: Text(label),
      onSelected: (_) => _setActiveProfile(context, ref, profile.id),
    );
  }).toList();
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

String _hackathonScenarioLabel(int index, PatientProfile profile) {
  const prefixes = ['Scenario A', 'Scenario B', 'Scenario C'];
  final prefix = index < prefixes.length
      ? prefixes[index]
      : 'Scenario ${index + 1}';
  return '$prefix · ${profile.displayName}';
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

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentColor,
    this.showBadge = false,
    this.badgeKey,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool showBadge;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? colorScheme.primary;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: effectiveAccent.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: effectiveAccent),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -1,
                      right: -2,
                      child: Container(
                        key: badgeKey,
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ],
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

class _RecentCheckUpsSection extends StatelessWidget {
  const _RecentCheckUpsSection({required this.entries});

  final List<DailyEntry> entries;

  DailyEntry? _todayEntry() {
    final today = DateTime.now();
    for (final entry in entries) {
      if (DateUtils.isSameDay(entry.entryDate, today)) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return SectionCard(
        title: 'Recent check-ups',
        subtitle: 'The latest check-ins appear here right after saving.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No check-up saved yet.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/app/diary/check-up'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create first check-up'),
            ),
          ],
        ),
      );
    }

    final sortedEntries = [...entries]
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    final previewEntries = sortedEntries.take(3).toList();
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');
    final checkUpAvatarBackground = _byBrightness(
      context,
      light: Colors.teal.shade50,
      dark: Colors.teal.shade900.withValues(alpha: 0.36),
    );
    final checkUpAvatarColor = _byBrightness(
      context,
      light: Colors.teal.shade700,
      dark: Colors.teal.shade100,
    );
    final todayEntry = _todayEntry();

    return SectionCard(
      title: 'Recent check-ups',
      subtitle: 'Latest saved check-ins in your diary.',
      action: TextButton.icon(
        onPressed: () => context.push('/app/diary'),
        icon: const Icon(Icons.open_in_new_outlined),
        label: const Text('Open diary'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TodayCheckUpCard(entry: todayEntry),
          const SizedBox(height: 12),
          ...previewEntries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card.outlined(
                margin: EdgeInsets.zero,
                child: ListTile(
                  key: ValueKey('home-checkup-${entry.id}'),
                  onTap: () => context.push('/app/diary/${entry.id}/symptom'),
                  leading: CircleAvatar(
                    backgroundColor: checkUpAvatarBackground,
                    child: Icon(
                      Icons.fact_check_outlined,
                      color: checkUpAvatarColor,
                    ),
                  ),
                  title: Text(dateFormat.format(entry.entryDate)),
                  subtitle: Text(
                    (entry.generalNotes ?? '').trim().isEmpty
                        ? 'No notes'
                        : entry.generalNotes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCheckUpCard extends StatelessWidget {
  const _TodayCheckUpCard({required this.entry});

  final DailyEntry? entry;

  @override
  Widget build(BuildContext context) {
    final hasEntry = entry != null;
    final completedAt = hasEntry
        ? DateFormat('HH:mm', 'en_US').format(entry!.entryDate.toLocal())
        : null;

    return SectionCard(
      title: 'Today',
      subtitle: hasEntry
          ? 'Check-up completed for today.'
          : 'Today still needs a check-up.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasEntry
                ? 'Completed at $completedAt'
                : 'Complete it now to stop today\'s reminders.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/app/diary/check-up'),
            icon: Icon(
              hasEntry ? Icons.edit_note_outlined : Icons.add_circle_outline,
            ),
            label: Text(hasEntry ? 'Update check-up' : 'Complete check-up'),
          ),
        ],
      ),
    );
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

class _MiniActionChip extends StatelessWidget {
  const _MiniActionChip({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.showBadge = false,
    this.badgeKey,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool showBadge;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActionChip(
          avatar: Icon(icon, size: 18, color: colorScheme.primary),
          label: Text(label),
          onPressed: onPressed,
        ),
        if (showBadge)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              key: badgeKey,
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
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
