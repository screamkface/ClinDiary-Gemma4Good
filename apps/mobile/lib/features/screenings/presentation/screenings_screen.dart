import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/screenings/domain/screening.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ScreeningsScreen extends ConsumerStatefulWidget {
  const ScreeningsScreen({super.key});

  @override
  ConsumerState<ScreeningsScreen> createState() => _ScreeningsScreenState();
}

class _ScreeningsScreenState extends ConsumerState<ScreeningsScreen> {
  bool _isRecomputing = false;
  String? _busyScreeningId;

  Future<void> _recompute() async {
    final regionCode = await ref.read(profileRegionCodeProvider.future);
    if (!mounted) return;
    setState(() => _isRecomputing = true);
    try {
      await ref
          .read(screeningsRepositoryProvider)
          .recompute(regionCode: regionCode);
      ref.invalidate(myScreeningsProvider);
      ref.invalidate(screeningCatalogProvider);
      ref.invalidate(preventionCenterProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(timelineEventsProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isRecomputing = false);
      }
    }
  }

  Future<void> _markDone(PatientScreeningStatusItem item) async {
    final regionCode = await ref.read(profileRegionCodeProvider.future);
    if (!mounted) return;
    setState(() => _busyScreeningId = item.id);
    try {
      await ref
          .read(screeningsRepositoryProvider)
          .markDone(item.id, regionCode: regionCode);
      ref.invalidate(myScreeningsProvider);
      ref.invalidate(preventionCenterProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(timelineEventsProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyScreeningId = null);
      }
    }
  }

  Future<void> _toggleCurrentYearChecklist(
    PatientScreeningStatusItem item,
  ) async {
    final regionCode = await ref.read(profileRegionCodeProvider.future);
    if (!mounted) return;
    setState(() => _busyScreeningId = item.id);
    try {
      if (item.completedThisYear) {
        await ref
            .read(screeningsRepositoryProvider)
            .clearCurrentYearCompletion(item.id, regionCode: regionCode);
      } else {
        await ref
            .read(screeningsRepositoryProvider)
            .markDone(item.id, regionCode: regionCode);
      }
      ref.invalidate(myScreeningsProvider);
      ref.invalidate(preventionCenterProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(timelineEventsProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyScreeningId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myScreeningsAsync = ref.watch(myScreeningsProvider);
    final catalogAsync = ref.watch(screeningCatalogProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prevenzione'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(myScreeningsProvider);
              ref.invalidate(screeningCatalogProvider);
              ref.invalidate(notificationsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Catalogo prevenzione',
            subtitle: 'Visita annuale, controlli e note utili.',
            action: FilledButton.tonalIcon(
              onPressed: _isRecomputing ? null : _recompute,
              icon: const Icon(Icons.autorenew),
              label: Text(_isRecomputing ? 'Aggiorno...' : 'Ricalcola'),
            ),
            child: const Text('Controlli adattati al profilo e alla regione.'),
          ),
          const SizedBox(height: 12),
          myScreeningsAsync.when(
            data: (items) => _MyScreeningsSection(
              items: items,
              dateFormat: dateFormat,
              busyScreeningId: _busyScreeningId,
              onMarkDone: _markDone,
              onToggleChecklist: _toggleCurrentYearChecklist,
            ),
            loading: () => const SectionCard(
              title: 'Per il tuo profilo',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Per il tuo profilo',
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 12),
          catalogAsync.when(
            data: (items) => _CatalogSection(items: items),
            loading: () => const SectionCard(
              title: 'Catalogo completo',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Catalogo completo',
              child: Text(error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'completed':
      return 'Completato';
    case 'overdue':
      return 'In ritardo';
    case 'scheduled':
      return 'Programmato';
    case 'recommended':
      return 'Consigliato';
    case 'skipped':
      return 'Saltato';
    default:
      return 'Mai eseguito';
  }
}

class _MyScreeningsSection extends StatelessWidget {
  const _MyScreeningsSection({
    required this.items,
    required this.dateFormat,
    required this.busyScreeningId,
    required this.onMarkDone,
    required this.onToggleChecklist,
  });

  final List<PatientScreeningStatusItem> items;
  final DateFormat dateFormat;
  final String? busyScreeningId;
  final Future<void> Function(PatientScreeningStatusItem item) onMarkDone;
  final Future<void> Function(PatientScreeningStatusItem item)
  onToggleChecklist;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SectionCard(
        title: 'Per il tuo profilo',
        child: Text('Nessun controllo personalizzato da mostrare.'),
      );
    }

    final actionable = items.where((item) => item.isActionable).toList();
    final upToDate = items.where((item) => !item.isActionable).toList();
    final annualVisitItems = items
        .where((item) => item.carePathway == 'annual_visit')
        .toList();
    final discussItems = items
        .where((item) => item.carePathway == 'discuss_with_doctor')
        .toList();
    final annualIds = annualVisitItems.map((item) => item.id).toSet();
    final sharedDecisionItems = items
        .where((item) => item.carePathway == 'shared_decision')
        .toList();
    final actionableDiscuss = actionable
        .where(
          (item) =>
              !annualIds.contains(item.id) &&
              item.carePathway != 'shared_decision',
        )
        .toList();
    final upToDateDiscuss = upToDate
        .where(
          (item) =>
              !annualIds.contains(item.id) &&
              item.carePathway != 'shared_decision',
        )
        .toList();

    return SectionCard(
      title: 'Per il tuo profilo',
      subtitle: 'Quello che conta adesso.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                label: '${actionable.length} da fare',
                tone: Colors.orange,
              ),
              _SummaryChip(
                label: '${upToDate.length} in regola',
                tone: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CurrentYearChecklist(
            items: items,
            year: DateTime.now().year,
            busyScreeningId: busyScreeningId,
            onToggle: onToggleChecklist,
          ),
          const SizedBox(height: 16),
          if (annualVisitItems.isNotEmpty) ...[
            _SubsectionHeader(
              title: 'Visita annuale consigliata',
              subtitle: 'Controllo generale.',
            ),
            const SizedBox(height: 8),
            ...annualVisitItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StatusCard(
                  item: item,
                  dateFormat: dateFormat,
                  isSaving: busyScreeningId == item.id,
                  onMarkDone: () => onMarkDone(item),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (discussItems.isNotEmpty) ...[
            _SubsectionHeader(
              title: 'Esami e controlli da discutere col medico',
              subtitle: 'Da valutare insieme.',
            ),
            const SizedBox(height: 8),
          ],
          ...actionableDiscuss.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StatusCard(
                item: item,
                dateFormat: dateFormat,
                isSaving: busyScreeningId == item.id,
                onMarkDone: () => onMarkDone(item),
              ),
            ),
          ),
          if (upToDateDiscuss.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Gia registrati',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...upToDateDiscuss.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StatusCard(
                  item: item,
                  dateFormat: dateFormat,
                  isSaving: busyScreeningId == item.id,
                  onMarkDone: item.isActionable ? () => onMarkDone(item) : null,
                ),
              ),
            ),
          ],
          if (sharedDecisionItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SubsectionHeader(
              title: 'Decisioni condivise',
              subtitle: 'Aree dove conta il confronto col medico.',
            ),
            const SizedBox(height: 8),
            ...sharedDecisionItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StatusCard(
                  item: item,
                  dateFormat: dateFormat,
                  isSaving: busyScreeningId == item.id,
                  onMarkDone: item.isActionable ? () => onMarkDone(item) : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentYearChecklist extends StatelessWidget {
  const _CurrentYearChecklist({
    required this.items,
    required this.year,
    required this.busyScreeningId,
    required this.onToggle,
  });

  final List<PatientScreeningStatusItem> items;
  final int year;
  final String? busyScreeningId;
  final Future<void> Function(PatientScreeningStatusItem item) onToggle;

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items]
      ..sort((a, b) {
        final pathwayRank = _carePathwayRank(
          a.carePathway,
        ).compareTo(_carePathwayRank(b.carePathway));
        if (pathwayRank != 0) {
          return pathwayRank;
        }
        if (a.completedThisYear != b.completedThisYear) {
          return a.completedThisYear ? 1 : -1;
        }
        return a.screeningName.compareTo(b.screeningName);
      });
    final compactDateFormat = DateFormat('dd MMM', 'it_IT');

    String? currentSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checklist personale $year',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = sortedItems[index];
            final isBusy = busyScreeningId == item.id;
            final subtitle = item.currentYearLastCompletedOn != null
                ? 'Segnato il ${compactDateFormat.format(item.currentYearLastCompletedOn!.toLocal())}'
                : (item.cadenceLabel ??
                      _recommendationLevelLabel(item.recommendationLevel));
            final sectionTitle = _carePathwaySectionTitle(item.carePathway);
            final needsHeader = sectionTitle != currentSection;
            currentSection = sectionTitle;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (needsHeader) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      sectionTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                Card.outlined(
                  margin: EdgeInsets.zero,
                  child: CheckboxListTile(
                    value: item.completedThisYear,
                    onChanged: isBusy ? null : (_) => onToggle(item),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(item.screeningName),
                    subtitle: Text(subtitle),
                    secondary: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            item.completedThisYear
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.item,
    required this.dateFormat,
    required this.isSaving,
    required this.onMarkDone,
  });

  final PatientScreeningStatusItem item;
  final DateFormat dateFormat;
  final bool isSaving;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final dueText = item.nextDueDate == null
        ? 'Da definire'
        : dateFormat.format(item.nextDueDate!.toLocal());
    final availability = item.regionalAvailability.isEmpty
        ? null
        : item.regionalAvailability.first;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.screeningName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ToneChip(
                  label: _statusLabel(item.status),
                  tone: _statusTone(item.status),
                ),
                _ToneChip(
                  label: _recommendationLevelLabel(item.recommendationLevel),
                  tone: _recommendationTone(item.recommendationLevel),
                ),
                if (item.cadenceLabel != null)
                  _ToneChip(label: item.cadenceLabel!, tone: Colors.blueGrey),
                if (item.publicCoverageFlag)
                  const _ToneChip(
                    label: 'Copertura pubblica',
                    tone: Colors.teal,
                  ),
                if (availability != null)
                  _ToneChip(
                    label: availability.regionName,
                    tone: Colors.indigo,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.recommendationReason ??
                  item.explanation ??
                  'Raccomandazione disponibile.',
            ),
            const SizedBox(height: 10),
            Text(
              'Prossima data: $dueText',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.isActionable) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: isSaving ? null : onMarkDone,
                icon: const Icon(Icons.verified_outlined),
                label: Text(isSaving ? 'Salvataggio...' : 'Segna completato'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogSection extends StatelessWidget {
  const _CatalogSection({required this.items});

  final List<ScreeningCatalogItem> items;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ScreeningCatalogItem>>{
      'annual_visit': [],
      'discuss_with_doctor': [],
      'shared_decision': [],
      'not_routine': [],
    };
    for (final item in items) {
      grouped.putIfAbsent(item.carePathway, () => []).add(item);
    }

    return SectionCard(
      title: 'Catalogo completo',
      subtitle: 'Tutto il catalogo disponibile.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in grouped.entries)
            if (entry.value.isNotEmpty) ...[
              _SubsectionHeader(
                title: _carePathwaySectionTitle(entry.key),
                subtitle: _carePathwaySectionSubtitle(entry.key),
              ),
              const SizedBox(height: 8),
              ...entry.value.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CatalogCard(item: item),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _SubsectionHeader extends StatelessWidget {
  const _SubsectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item});

  final ScreeningCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final availability = item.regionalAvailability.isEmpty
        ? null
        : item.regionalAvailability.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ToneChip(
                  label: _recommendationLevelLabel(item.recommendationLevel),
                  tone: _recommendationTone(item.recommendationLevel),
                ),
                if (item.cadenceLabel != null)
                  _ToneChip(label: item.cadenceLabel!, tone: Colors.blueGrey),
                _ToneChip(label: item.category, tone: Colors.brown),
                if (item.catalogOnly)
                  const _ToneChip(label: 'Solo informativo', tone: Colors.grey),
                if (availability != null && item.publicCoverageFlag)
                  _ToneChip(label: availability.regionName, tone: Colors.teal),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.description),
            if ((item.explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.explanation!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: tone.withValues(alpha: 0.12),
      side: BorderSide(color: tone.withValues(alpha: 0.2)),
      label: Text(label),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

Color _statusTone(String status) {
  switch (status) {
    case 'completed':
      return Colors.green;
    case 'overdue':
      return Colors.redAccent;
    case 'recommended':
      return Colors.orange;
    case 'scheduled':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

Color _recommendationTone(String recommendationLevel) {
  switch (recommendationLevel) {
    case 'risk_based':
      return Colors.deepOrange;
    case 'not_routine':
      return Colors.blueGrey;
    default:
      return Colors.teal;
  }
}

String _recommendationLevelLabel(String recommendationLevel) {
  switch (recommendationLevel) {
    case 'risk_based':
      return 'Da valutare';
    case 'not_routine':
      return 'Non di routine';
    default:
      return 'Di routine';
  }
}

int _carePathwayRank(String carePathway) {
  switch (carePathway) {
    case 'annual_visit':
      return 0;
    case 'discuss_with_doctor':
      return 1;
    case 'not_routine':
      return 2;
    case 'shared_decision':
      return 2;
    default:
      return 3;
  }
}

String _carePathwaySectionTitle(String carePathway) {
  switch (carePathway) {
    case 'annual_visit':
      return 'Visita annuale consigliata';
    case 'shared_decision':
      return 'Decisioni condivise';
    case 'not_routine':
      return 'Non di routine';
    default:
      return 'Esami e controlli da discutere col medico';
  }
}

String _carePathwaySectionSubtitle(String carePathway) {
  switch (carePathway) {
    case 'annual_visit':
      return 'Il controllo generale annuale aiuta a mettere in ordine prevenzione, stile di vita e priorita cliniche.';
    case 'shared_decision':
      return 'Qui ClinDiary resta prudente: il senso del controllo dipende da una decisione condivisa, non da un reminder automatico forte.';
    case 'not_routine':
      return 'Queste voci restano informative e non vanno proposte come routine negli asintomatici.';
    default:
      return 'Qui trovi esami e controlli specifici da valutare insieme al medico in base al profilo.';
  }
}
