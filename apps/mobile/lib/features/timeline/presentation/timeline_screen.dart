import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(timelineEventsProvider);
    final dateTimeFormat = DateFormat('dd MMM · HH:mm', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(timelineEventsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: timelineAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Timeline is empty.'));
          }
          final filteredEvents = events
              .where((event) => _matchesFilter(event, _selectedFilter))
              .toList();
          final groups = _groupEventsByDay(filteredEvents);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Events',
                subtitle: 'Organized by day.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('${filteredEvents.length} events')),
                    Chip(label: Text('${groups.length} days')),
                    Chip(
                      label: Text(
                        'Latest ${dateTimeFormat.format(events.first.eventDate.toLocal())}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Filters',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TimelineFilterChip(
                      label: 'All',
                      selected: _selectedFilter == 'all',
                      onSelected: () => setState(() => _selectedFilter = 'all'),
                    ),
                    _TimelineFilterChip(
                      label: 'Check-up',
                      selected: _selectedFilter == 'journal',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'journal'),
                    ),
                    _TimelineFilterChip(
                      label: 'Documents',
                      selected: _selectedFilter == 'documents',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'documents'),
                    ),
                    _TimelineFilterChip(
                      label: 'Medications',
                      selected: _selectedFilter == 'medications',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'medications'),
                    ),
                    _TimelineFilterChip(
                      label: 'Prevention',
                      selected: _selectedFilter == 'prevention',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'prevention'),
                    ),
                    _TimelineFilterChip(
                      label: 'Alerts',
                      selected: _selectedFilter == 'alerts',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'alerts'),
                    ),
                    _TimelineFilterChip(
                      label: 'Reports',
                      selected: _selectedFilter == 'reports',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'reports'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filteredEvents.isEmpty)
                const SectionCard(
                  title: 'Result',
                  child: Text('No events for this filter.'),
                )
              else
                ...groups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TimelineDaySection(group: group),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _TimelineFilterChip extends StatelessWidget {
  const _TimelineFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(),
    );
  }
}

class _TimelineDaySection extends StatelessWidget {
  const _TimelineDaySection({required this.group});

  final _TimelineDayGroup group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dayFormat = DateFormat('EEEE dd MMMM', 'en_US');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                _timelineDayLabel(group.day, dayFormat),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.58,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${group.events.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: group.events
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TimelineEventCard(event: event),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  const _TimelineEventCard({required this.event});

  final TimelineEventItem event;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm', 'it_IT');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              _eventIcon(event.eventType),
              color: colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _EventTag(
                      label: timeFormat.format(event.eventDate.toLocal()),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EventTag(label: _eventLabel(event.eventType)),
                    if (event.severity != null)
                      _EventTag(label: event.severity!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTag extends StatelessWidget {
  const _EventTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

List<_TimelineDayGroup> _groupEventsByDay(List<TimelineEventItem> events) {
  final map = <DateTime, List<TimelineEventItem>>{};

  for (final event in events) {
    final local = event.eventDate.toLocal();
    final day = DateUtils.dateOnly(local);
    map.putIfAbsent(day, () => []).add(event);
  }

  final groups =
      map.entries
          .map(
            (entry) => _TimelineDayGroup(
              day: entry.key,
              events: [...entry.value]
                ..sort((a, b) => b.eventDate.compareTo(a.eventDate)),
            ),
          )
          .toList()
        ..sort((a, b) => b.day.compareTo(a.day));

  return groups;
}

String _timelineDayLabel(DateTime day, DateFormat formatter) {
  final today = DateUtils.dateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  if (day == today) {
    return 'Today';
  }
  if (day == yesterday) {
    return 'Yesterday';
  }
  return formatter.format(day);
}

class _TimelineDayGroup {
  const _TimelineDayGroup({required this.day, required this.events});

  final DateTime day;
  final List<TimelineEventItem> events;
}

bool _matchesFilter(TimelineEventItem event, String filter) {
  switch (filter) {
    case 'journal':
      return {
        'daily_entry',
        'daily_entry_created',
        'symptom_event',
        'vital_event',
      }.contains(event.eventType);
    case 'documents':
      return {
        'document_uploaded',
        'lab_result_summary',
        'imaging_summary',
      }.contains(event.eventType);
    case 'medications':
      return event.eventType == 'medication_logged';
    case 'prevention':
      return {'screening_due', 'screening_completed'}.contains(event.eventType);
    case 'alerts':
      return event.eventType == 'ai_alert';
    case 'reports':
      return event.eventType == 'report_generated';
    default:
      return true;
  }
}

String _eventLabel(String type) {
  switch (type) {
    case 'document_uploaded':
      return 'Document';
    case 'lab_result_summary':
      return 'Lab';
    case 'imaging_summary':
      return 'Imaging';
    case 'ai_alert':
      return 'Alert';
    case 'report_generated':
      return 'Report';
    case 'screening_due':
      return 'Screening';
    case 'screening_completed':
      return 'Prevention';
    case 'medication_logged':
      return 'Adherence';
    case 'daily_entry':
      return 'Check-up';
    case 'symptom_event':
      return 'Symptom';
    case 'vital_event':
      return 'Vital';
    default:
      return type;
  }
}

IconData _eventIcon(String type) {
  switch (type) {
    case 'document_uploaded':
      return Icons.upload_file_outlined;
    case 'lab_result_summary':
      return Icons.science_outlined;
    case 'imaging_summary':
      return Icons.image_search_outlined;
    case 'ai_alert':
      return Icons.notification_important_outlined;
    case 'report_generated':
      return Icons.picture_as_pdf_outlined;
    case 'screening_due':
      return Icons.health_and_safety_outlined;
    case 'screening_completed':
      return Icons.verified_outlined;
    case 'medication_logged':
      return Icons.medication_outlined;
    case 'symptom_event':
      return Icons.sick_outlined;
    case 'vital_event':
      return Icons.monitor_heart_outlined;
    default:
      return Icons.timeline_outlined;
  }
}
