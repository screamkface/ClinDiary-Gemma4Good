import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/shared/widgets/clinical_scope_notice.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PreventionCenterScreen extends ConsumerWidget {
  const PreventionCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preventionAsync = ref.watch(preventionCenterProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');
    Future<void> refreshAll() async {
      ref.invalidate(preventionCenterProvider);
      ref.invalidate(myScreeningsProvider);
      ref.invalidate(notificationsProvider);
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prevention center'),
          actions: [
            IconButton(
              onPressed: () => ref.invalidate(preventionCenterProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Checks'),
              Tab(text: 'Vaccines'),
              Tab(text: 'Pathways'),
              Tab(text: 'Follow-up'),
            ],
          ),
        ),
        body: preventionAsync.when(
          data: (center) => TabBarView(
            children: [
              _TabList(
                onRefresh: refreshAll,
                children: [
                  const ClinicalScopeNotice(
                    title: 'Personal prevention',
                    message:
                        'These recommendations help organize checks and follow-up. They are not an automatic prescription and must be contextualized with the doctor.',
                    icon: Icons.health_and_safety_outlined,
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Personal summary',
                    subtitle: 'Quick priorities.',
                    action: Text(
                      dateFormat.format(center.generatedAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          center.displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                                if (center.age != null) '${center.age} years',
                                if (center.biologicalSex != null)
                                  _sexLabel(center.biologicalSex!),
                              ].join(' • ').isEmpty
                              ? 'Personal prevention profile'
                              : [
                                  if (center.age != null) '${center.age} years',
                                  if (center.biologicalSex != null)
                                    _sexLabel(center.biologicalSex!),
                                ].join(' • '),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _OverviewChip(
                              label:
                                  'Region ${center.regionName ?? 'Italy (general)'}',
                              icon: Icons.place_outlined,
                            ),
                            _OverviewChip(
                              label:
                                  '${center.overview.actionableScreenings} checks',
                              icon: Icons.health_and_safety_outlined,
                            ),
                            _OverviewChip(
                              label:
                                  '${center.overview.vaccineReviews} vaccines',
                              icon: Icons.vaccines_outlined,
                            ),
                            _OverviewChip(
                              label:
                                  '${center.overview.vaccineRegistryItems} registry',
                              icon: Icons.fact_check_outlined,
                            ),
                            if (center.overview.pregnancyItems > 0)
                              _OverviewChip(
                                label:
                                    '${center.overview.pregnancyItems} pregnancy',
                                icon: Icons.pregnant_woman_outlined,
                              ),
                            if (center.overview.sharedDecisionItems > 0)
                              _OverviewChip(
                                label:
                                    '${center.overview.sharedDecisionItems} shared',
                                icon: Icons.balance_outlined,
                              ),
                            _OverviewChip(
                              label:
                                  '${center.overview.seasonalChecks} seasonal',
                              icon: Icons.wb_sunny_outlined,
                            ),
                            _OverviewChip(
                              label:
                                  '${center.overview.followUpItems} follow-up',
                              icon: Icons.event_repeat_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (center.annualVisit != null) ...[
                    const SizedBox(height: 12),
                    _RecommendationSection(
                      title: 'Recommended annual visit',
                      subtitle: 'General check.',
                      items: [center.annualVisit!],
                    ),
                  ],
                  if (center.annualExams.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _RecommendationSection(
                      title: 'Annual exams',
                      subtitle: 'Suggested yearly exams based on profile.',
                      items: center.annualExams,
                    ),
                  ],
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Visits and checks for your profile',
                    subtitle: 'Driven by the profile.',
                    items: center.visitsAndControls,
                    emptyLabel: 'No additional periodic checks to show.',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/screenings'),
                      child: const Text('Open screenings'),
                    ),
                  ),
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Recommended vaccines',
                    subtitle: 'To verify with your history.',
                    items: center.vaccines,
                    emptyLabel:
                        'No vaccine to highlight with the current data.',
                  ),
                  const SizedBox(height: 12),
                  _RecommendationSection(
                    title: 'Vaccination registry',
                    subtitle: 'Summary status of your history.',
                    items: center.vaccineRegistry,
                    emptyLabel: 'No vaccination summary available.',
                    action: TextButton(
                      onPressed: () =>
                          context.push('/app/profile/vaccinations'),
                      child: const Text('Open history'),
                    ),
                  ),
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Pregnancy and preconception',
                    subtitle: 'Only if the profile requires it.',
                    items: center.pregnancyAndPreconception,
                    emptyLabel:
                        'No active preconception or pregnancy pathway in the profile.',
                  ),
                  const SizedBox(height: 12),
                  _RecommendationSection(
                    title: 'Shared decisions',
                    subtitle: 'Areas where ClinDiary stays cautious.',
                    items: center.sharedDecisions,
                    emptyLabel:
                        'No specific shared decision to show with the current data.',
                  ),
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Seasonal checks',
                    subtitle: 'Seasonal reminders.',
                    items: center.seasonalChecks,
                    emptyLabel: 'No active seasonal check at the moment.',
                  ),
                  const SizedBox(height: 12),
                  _RecommendationSection(
                    title: 'Follow-up reminders',
                    subtitle: 'Items to close.',
                    items: center.followUpReminders,
                    emptyLabel: 'No open follow-up.',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/notifications'),
                      child: const Text('Open notifications'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}

class _TabList extends StatelessWidget {
  const _TabList({required this.children, required this.onRefresh});

  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    required this.title,
    required this.subtitle,
    required this.items,
    this.emptyLabel,
    this.action,
  });

  final String title;
  final String subtitle;
  final List<PreventionRecommendationItem> items;
  final String? emptyLabel;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      action: action,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            Text(emptyLabel ?? 'No items available.')
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecommendationCard(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item});

  final PreventionRecommendationItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone = _toneForPriority(item.priority, colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Tag(label: _statusLabel(item.status), color: tone),
              ],
            ),
            if ((item.subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.subtitle!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((item.cadenceLabel ?? '').isNotEmpty)
                  _Tag(label: item.cadenceLabel!, color: colorScheme.primary),
                _Tag(
                  label: _kindLabel(item.kind),
                  color: colorScheme.secondary,
                ),
              ],
            ),
            if ((item.actionHint ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.actionHint!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _toneForPriority(String priority, ColorScheme colorScheme) {
  switch (priority) {
    case 'urgent':
    case 'high':
      return colorScheme.error;
    case 'low':
      return colorScheme.secondary;
    default:
      return colorScheme.primary;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'recommended':
      return 'Recommended';
    case 'overdue':
      return 'Overdue';
    case 'attention':
      return 'Attention';
    case 'ready':
      return 'Ready';
    case 'seasonal':
      return 'Seasonal';
    case 'up_to_date':
      return 'Up to date';
    case 'shared_decision':
      return 'Shared';
    default:
      return 'To review';
  }
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'vaccine':
      return 'Vaccine';
    case 'vaccine_registry':
      return 'Registry';
    case 'pregnancy':
      return 'Pregnancy';
    case 'seasonal_check':
      return 'Seasonal';
    case 'follow_up':
      return 'Follow-up';
    default:
      return 'Check';
  }
}

String _sexLabel(String value) {
  switch (value) {
    case 'female':
      return 'Female';
    case 'male':
      return 'Male';
    case 'intersex':
      return 'Intersex';
    default:
      return 'Not specified';
  }
}
