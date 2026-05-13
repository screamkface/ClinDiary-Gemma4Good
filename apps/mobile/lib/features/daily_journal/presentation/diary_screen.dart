import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _DiaryEntryAction { addSymptom, deleteCheckUp }

enum _DiaryQuickAction { checkUp, addSymptomLatest, history }

T _toneByBrightness<T>(
  BuildContext context, {
  required T light,
  required T dark,
}) {
  return Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  DailyEntry? _latestEntry(List<DailyEntry> entries) {
    if (entries.isEmpty) {
      return null;
    }
    return entries.reduce(
      (current, next) =>
          next.entryDate.isAfter(current.entryDate) ? next : current,
    );
  }

  Future<void> _openQuickAddSheet(
    BuildContext context,
    List<DailyEntry> entries,
  ) async {
    final action = await showModalBottomSheet<_DiaryQuickAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('New check-up'),
                subtitle: const Text('Quick daily recap and notes'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_DiaryQuickAction.checkUp),
              ),
              ListTile(
                leading: const Icon(Icons.sick_outlined),
                title: const Text('Add symptom'),
                subtitle: Text(
                  entries.isEmpty
                      ? 'Create a check-up first'
                      : 'Attach to latest check-up',
                ),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_DiaryQuickAction.addSymptomLatest),
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('Open history'),
                subtitle: const Text('See previous days and events'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_DiaryQuickAction.history),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case _DiaryQuickAction.checkUp:
        context.push('/app/diary/check-up');
        return;
      case _DiaryQuickAction.history:
        context.push('/app/home/history');
        return;
      case _DiaryQuickAction.addSymptomLatest:
        final latest = _latestEntry(entries);
        if (latest == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Create a check-up first, then add symptoms.'),
            ),
          );
          context.push('/app/diary/check-up');
          return;
        }
        context.push('/app/diary/${latest.id}/symptom');
        return;
    }
  }

  Future<void> _handleEntryAction(
    BuildContext context,
    WidgetRef ref,
    DailyEntry entry,
    _DiaryEntryAction action,
  ) async {
    switch (action) {
      case _DiaryEntryAction.addSymptom:
        context.push('/app/diary/${entry.id}/symptom');
        return;
      case _DiaryEntryAction.deleteCheckUp:
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete check-up?'),
            content: const Text(
              'This removes the check-up and related symptom/vital events.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (shouldDelete != true || !context.mounted) {
          return;
        }

        try {
          await ref
              .read(dailyJournalRepositoryProvider)
              .deleteEntry(entryId: entry.id);
          ref.invalidate(dailyEntriesProvider);
          ref.invalidate(insightSummaryProvider);
          ref.invalidate(timelineEventsProvider);
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Check-up deleted')));
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final entries = entriesAsync.asData?.value ?? const <DailyEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () => context.push('/app/home/history'),
            icon: const Icon(Icons.event_note_outlined),
          ),
          IconButton(
            onPressed: () => ref.invalidate(dailyEntriesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQuickAddSheet(context, entries),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: entriesAsync.when(
        data: (entries) {
          final latest = _latestEntry(entries);
          final latestChipBackground = _toneByBrightness(
            context,
            light: Colors.indigo.shade50,
            dark: Colors.indigo.shade900.withValues(alpha: 0.36),
          );
          final latestChipForeground = _toneByBrightness(
            context,
            light: Colors.indigo.shade700,
            dark: Colors.indigo.shade100,
          );
          final countChipBackground = entries.isEmpty
              ? _toneByBrightness(
                  context,
                  light: Colors.orange.shade50,
                  dark: Colors.orange.shade900.withValues(alpha: 0.36),
                )
              : _toneByBrightness(
                  context,
                  light: Colors.teal.shade50,
                  dark: Colors.teal.shade900.withValues(alpha: 0.36),
                );
          final countChipForeground = entries.isEmpty
              ? _toneByBrightness(
                  context,
                  light: Colors.orange.shade700,
                  dark: Colors.orange.shade100,
                )
              : _toneByBrightness(
                  context,
                  light: Colors.teal.shade700,
                  dark: Colors.teal.shade100,
                );
          final countChipLabelColor = entries.isEmpty
              ? _toneByBrightness(
                  context,
                  light: Colors.orange.shade900,
                  dark: Colors.orange.shade100,
                )
              : _toneByBrightness(
                  context,
                  light: Colors.teal.shade900,
                  dark: Colors.teal.shade100,
                );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Today',
                subtitle: 'Start quickly from one action.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: Icon(
                            entries.isEmpty
                                ? Icons.radio_button_unchecked
                                : Icons.check_circle_outline,
                            size: 18,
                            color: countChipForeground,
                          ),
                          backgroundColor: countChipBackground,
                          labelStyle: TextStyle(
                            color: countChipLabelColor,
                            fontWeight: FontWeight.w600,
                          ),
                          label: Text(
                            entries.isEmpty
                                ? 'No check-ups'
                                : '${entries.length} check-ups',
                          ),
                        ),
                        if (latest != null)
                          Chip(
                            avatar: Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: latestChipForeground,
                            ),
                            backgroundColor: latestChipBackground,
                            labelStyle: TextStyle(
                              color: latestChipForeground,
                              fontWeight: FontWeight.w600,
                            ),
                            label: Text(
                              'Latest ${dateFormat.format(latest.entryDate)}',
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: () => context.push('/app/diary/check-up'),
                          icon: const Icon(Icons.add),
                          label: const Text('New check-up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Latest check-ups',
                child: entries.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('No check-up recorded yet.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                context.push('/app/diary/check-up'),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Create first check-up'),
                          ),
                        ],
                      )
                    : Column(
                        children: entries
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Card.outlined(
                                  child: ListTile(
                                    titleAlignment:
                                        ListTileTitleAlignment.center,
                                    leading: Builder(
                                      builder: (context) {
                                        final hasNotes =
                                            (entry.generalNotes ?? '')
                                                .trim()
                                                .isNotEmpty;
                                        final avatarBackground = hasNotes
                                            ? _toneByBrightness(
                                                context,
                                                light: Colors.teal.shade50,
                                                dark: Colors.teal.shade900
                                                    .withValues(alpha: 0.36),
                                              )
                                            : _toneByBrightness(
                                                context,
                                                light: Colors.blueGrey.shade100,
                                                dark: Colors.blueGrey.shade800,
                                              );
                                        final avatarForeground = hasNotes
                                            ? _toneByBrightness(
                                                context,
                                                light: Colors.teal.shade700,
                                                dark: Colors.teal.shade100,
                                              )
                                            : _toneByBrightness(
                                                context,
                                                light: Colors.blueGrey.shade700,
                                                dark: Colors.blueGrey.shade100,
                                              );
                                        return CircleAvatar(
                                          backgroundColor: avatarBackground,
                                          child: Icon(
                                            Icons.fact_check_outlined,
                                            color: avatarForeground,
                                          ),
                                        );
                                      },
                                    ),
                                    title: Text(
                                      dateFormat.format(entry.entryDate),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.generalNotes ?? 'No notes',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (entry.pendingSync ||
                                            entry.isPendingDraft)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (entry.isPendingDraft)
                                                  const Chip(
                                                    label: Text('Local draft'),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                if (entry.pendingSync)
                                                  Chip(
                                                    label: const Text(
                                                      'Sync pending',
                                                    ),
                                                    backgroundColor:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .tertiaryContainer,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    onTap: () => context.push(
                                      '/app/diary/${entry.id}/symptom',
                                    ),
                                    trailing:
                                        PopupMenuButton<_DiaryEntryAction>(
                                          onSelected: (action) =>
                                              _handleEntryAction(
                                                context,
                                                ref,
                                                entry,
                                                action,
                                              ),
                                          itemBuilder: (context) => const [
                                            PopupMenuItem<_DiaryEntryAction>(
                                              value:
                                                  _DiaryEntryAction.addSymptom,
                                              child: Text('Add symptom'),
                                            ),
                                            PopupMenuItem<_DiaryEntryAction>(
                                              value: _DiaryEntryAction
                                                  .deleteCheckUp,
                                              child: Text('Delete check-up'),
                                            ),
                                          ],
                                        ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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
