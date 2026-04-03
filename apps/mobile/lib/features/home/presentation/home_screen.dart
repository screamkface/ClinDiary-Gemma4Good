import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final unreadNotificationsAsync = ref.watch(unreadNotificationsProvider);
    final pendingMedicationsAsync = ref.watch(pendingMedicationDosesProvider);
    final profileAsync = ref.watch(profileBundleProvider);
    final activeProfileIdAsync = ref.watch(activeProfileIdProvider);

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
              title: 'Oggi',
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
                                  'Profilo in configurazione',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bundle == null
                                  ? 'Completa l\'onboarding per iniziare.'
                                  : 'Scegli un recap oppure salva un check-up.',
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
                        label: Text(
                          alertsCount == 0 ? 'Alert ok' : '$alertsCount alert',
                        ),
                      ),
                      _StatusPill(
                        icon: hasUnreadNotifications
                            ? Icons.mark_email_unread_outlined
                            : Icons.notifications_none_outlined,
                        label: Text(
                          hasUnreadNotifications
                              ? 'Da leggere'
                              : 'Notifiche ok',
                        ),
                      ),
                      _StatusPill(
                        icon: hasPendingMedications
                            ? Icons.medication_outlined
                            : Icons.checklist_outlined,
                        label: Text(
                          hasPendingMedications
                              ? 'Terapie da fare'
                              : 'Terapie ok',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 380;
                      final aiButton = FilledButton.icon(
                        onPressed: () => context.go('/app/ai'),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Recap AI'),
                      );
                      final checkUpButton = FilledButton.tonalIcon(
                        onPressed: () => context.push('/app/diary/check-up'),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Check-up'),
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            aiButton,
                            const SizedBox(height: 12),
                            checkUpButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: aiButton),
                          const SizedBox(width: 12, height: 12),
                          Expanded(child: checkUpButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            loading: () => const SectionCard(
              title: 'Oggi',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                SectionCard(title: 'Oggi', child: Text(error.toString())),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Vai a',
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _DashboardActionCard(
                  title: 'Documenti',
                  subtitle: 'Referti',
                  icon: Icons.description_outlined,
                  onTap: () => context.go('/app/documents'),
                ),
                _DashboardActionCard(
                  title: 'Farmaci',
                  subtitle: 'Terapie',
                  icon: Icons.medication_outlined,
                  onTap: () => context.push('/app/home/medications'),
                  showBadge: hasPendingMedications,
                  badgeKey: const ValueKey('home-medications-badge'),
                ),
                _DashboardActionCard(
                  title: 'Prevenzione',
                  subtitle: 'Controlli',
                  icon: Icons.health_and_safety_outlined,
                  onTap: () => context.push('/app/home/prevention-center'),
                ),
                _DashboardActionCard(
                  title: 'Dispositivi',
                  subtitle: 'Wave 1',
                  icon: Icons.device_hub_outlined,
                  onTap: () => context.push('/app/home/devices'),
                ),
                _DashboardActionCard(
                  title: 'Dossier',
                  subtitle: 'Storico',
                  icon: Icons.folder_shared_outlined,
                  onTap: () => context.push('/app/home/dossier'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          profileAsync.when(
            data: (bundle) {
              if (bundle == null) {
                return const SectionCard(
                  title: 'Profili',
                  child: Text('Completa l\'onboarding per iniziare.'),
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
                title: 'Profili',
                subtitle: 'Stai usando ${activeProfile.displayName}',
                action: TextButton.icon(
                  onPressed: () => context.push('/app/profile/family'),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Gestisci'),
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
                      label: const Text('Aggiungi'),
                      onPressed: () => context.push('/app/profile/family'),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SectionCard(
              title: 'Profili',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                SectionCard(title: 'Profili', child: Text(error.toString())),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Altro',
            subtitle: 'Strumenti secondari',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniActionChip(
                  label: 'Timeline',
                  icon: Icons.timeline_outlined,
                  onPressed: () => context.push('/app/home/timeline'),
                ),
                _MiniActionChip(
                  label: 'Notifiche',
                  icon: Icons.notifications_outlined,
                  onPressed: () => context.push('/app/home/notifications'),
                  showBadge: hasUnreadNotifications,
                  badgeKey: const ValueKey('home-notifications-badge'),
                ),
                _MiniActionChip(
                  label: 'Smartwatch',
                  icon: Icons.watch_outlined,
                  onPressed: () => context.push('/app/home/wearables'),
                ),
                _MiniActionChip(
                  label: 'AI Plus',
                  icon: Icons.workspace_premium_outlined,
                  onPressed: () => context.push('/app/home/billing'),
                ),
                _MiniActionChip(
                  label: 'Alert',
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
  final profiles = bundle.managedProfiles.isNotEmpty
      ? bundle.managedProfiles
      : <PatientProfile>[bundle.profile];
  final selectedId = activeProfileId?.trim().isNotEmpty == true
      ? activeProfileId!.trim()
      : bundle.profile.id;

  return profiles.map((profile) {
    final label = _profileChipLabel(profile);
    return FilterChip(
      selected: profile.id == selectedId,
      label: Text(label),
      onSelected: (_) => _setActiveProfile(context, ref, profile.id),
    );
  }).toList();
}

String _profileChipLabel(PatientProfile profile) {
  final parts = <String>[profile.displayName];
  if (profile.relationshipLabel != null &&
      profile.relationshipLabel!.isNotEmpty) {
    parts.add(profile.relationshipLabel!);
  }
  if (profile.isPrimary) {
    parts.add('principale');
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

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.showBadge = false,
    this.badgeKey,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: colorScheme.primary),
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

class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
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
  const _StatusPill({required this.label, this.icon});

  final Widget label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
          ],
          DefaultTextStyle(
            style: Theme.of(
              context,
            ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700),
            child: label,
          ),
        ],
      ),
    );
  }
}
