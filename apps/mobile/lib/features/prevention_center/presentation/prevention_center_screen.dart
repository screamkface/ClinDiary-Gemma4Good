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
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'it_IT');
    Future<void> refreshAll() async {
      ref.invalidate(preventionCenterProvider);
      ref.invalidate(myScreeningsProvider);
      ref.invalidate(notificationsProvider);
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Centro prevenzione'),
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
              Tab(text: 'Sintesi'),
              Tab(text: 'Controlli'),
              Tab(text: 'Vaccini'),
              Tab(text: 'Percorsi'),
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
                    title: 'Prevenzione personale',
                    message:
                        'Queste indicazioni aiutano a organizzare controlli e follow-up. Non sono una prescrizione automatica e vanno contestualizzate con il medico.',
                    icon: Icons.health_and_safety_outlined,
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Sintesi personale',
                    subtitle: 'Priorità rapide.',
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
                                if (center.age != null) '${center.age} anni',
                                if (center.biologicalSex != null)
                                  _sexLabel(center.biologicalSex!),
                              ].join(' • ').isEmpty
                              ? 'Profilo prevenzione personale'
                              : [
                                  if (center.age != null) '${center.age} anni',
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
                                  'Regione ${center.regionName ?? 'Italia (generale)'}',
                              icon: Icons.place_outlined,
                            ),
                            _OverviewChip(
                              label:
                                  '${center.overview.actionableScreenings} controlli',
                              icon: Icons.health_and_safety_outlined,
                            ),
                            _OverviewChip(
                              label: '${center.overview.vaccineReviews} vaccini',
                              icon: Icons.vaccines_outlined,
                            ),
                            _OverviewChip(
                              label:
                                  '${center.overview.vaccineRegistryItems} registro',
                              icon: Icons.fact_check_outlined,
                            ),
                            if (center.overview.pregnancyItems > 0)
                              _OverviewChip(
                                label:
                                    '${center.overview.pregnancyItems} gravidanza',
                                icon: Icons.pregnant_woman_outlined,
                              ),
                            if (center.overview.sharedDecisionItems > 0)
                              _OverviewChip(
                                label:
                                    '${center.overview.sharedDecisionItems} condivise',
                                icon: Icons.balance_outlined,
                              ),
                            _OverviewChip(
                              label:
                                  '${center.overview.seasonalChecks} stagionali',
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
                      title: 'Visita annuale consigliata',
                      subtitle: 'Controllo generale.',
                      items: [center.annualVisit!],
                    ),
                  ],
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Visite e controlli per il tuo profilo',
                    subtitle: 'Guidati dal profilo.',
                    items: center.visitsAndControls,
                    emptyLabel:
                        'Nessun controllo periodico aggiuntivo da mostrare.',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/screenings'),
                      child: const Text('Apri screening'),
                    ),
                  ),
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Vaccini consigliati',
                    subtitle: 'Da verificare con il tuo storico.',
                    items: center.vaccines,
                    emptyLabel:
                        'Nessun vaccino da evidenziare con i dati attuali.',
                  ),
                  const SizedBox(height: 12),
                  _RecommendationSection(
                    title: 'Registro vaccinale',
                    subtitle: 'Stato sintetico del tuo storico.',
                    items: center.vaccineRegistry,
                    emptyLabel: 'Nessun riepilogo vaccinale disponibile.',
                    action: TextButton(
                      onPressed: () => context.push('/app/profile/vaccinations'),
                      child: const Text('Apri storico'),
                    ),
                  ),
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Gravidanza e preconcezione',
                    subtitle: 'Solo se il profilo lo richiede.',
                    items: center.pregnancyAndPreconception,
                    emptyLabel:
                        'Nessun percorso preconcezionale o gravidanza attivo nel profilo.',
                  ),
                  const SizedBox(height: 12),
                  _RecommendationSection(
                    title: 'Decisioni condivise',
                    subtitle: 'Aree dove ClinDiary resta prudente.',
                    items: center.sharedDecisions,
                    emptyLabel:
                        'Nessuna decisione condivisa specifica da mostrare con i dati attuali.',
                  ),
                ],
              ),
              _TabList(
                onRefresh: refreshAll,
                children: [
                  _RecommendationSection(
                    title: 'Controlli stagionali',
                    subtitle: 'Promemoria stagionali.',
                    items: center.seasonalChecks,
                    emptyLabel:
                        'Nessun controllo stagionale attivo in questo momento.',
                  ),
                  const SizedBox(height: 12),
                  _RecommendationSection(
                    title: 'Reminder di follow-up',
                    subtitle: 'Cose da chiudere.',
                    items: center.followUpReminders,
                    emptyLabel: 'Nessun follow-up aperto.',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/notifications'),
                      child: const Text('Apri notifiche'),
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
            Text(emptyLabel ?? 'Nessun elemento disponibile.')
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
      return 'Consigliato';
    case 'overdue':
      return 'In ritardo';
    case 'attention':
      return 'Attenzione';
    case 'ready':
      return 'Pronto';
    case 'seasonal':
      return 'Stagionale';
    case 'up_to_date':
      return 'In regola';
    case 'shared_decision':
      return 'Condivisa';
    default:
      return 'Da rivedere';
  }
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'vaccine':
      return 'Vaccino';
    case 'vaccine_registry':
      return 'Registro';
    case 'pregnancy':
      return 'Gravidanza';
    case 'seasonal_check':
      return 'Stagionale';
    case 'follow_up':
      return 'Follow-up';
    default:
      return 'Controllo';
  }
}

String _sexLabel(String value) {
  switch (value) {
    case 'female':
      return 'Femmina';
    case 'male':
      return 'Maschio';
    case 'intersex':
      return 'Intersex';
    default:
      return 'Non specificato';
  }
}
