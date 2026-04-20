import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _DiaryEntryAction { addSymptom, deleteCheckUp }

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

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
          ref.invalidate(timelineEventsProvider);
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Check-up deleted')));
        } on ApiException catch (error) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        } catch (_) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to delete check-up now')),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/app/home/history'),
            icon: const Icon(Icons.event_note_outlined),
            label: const Text('History'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          IconButton(
            onPressed: () => ref.invalidate(dailyEntriesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: entriesAsync.when(
        data: (entries) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Today',
              subtitle: 'Save a check-up or open history.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          entries.isEmpty
                              ? 'No check-ups'
                              : '${entries.length} check-ups',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.push('/app/diary/check-up'),
                        icon: const Icon(Icons.add),
                        label: const Text('Check-up'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/app/home/history'),
                        icon: const Icon(Icons.event_note_outlined),
                        label: const Text('History'),
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
                  ? const Text('You have not recorded anything yet.')
                  : Column(
                      children: entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card.outlined(
                                child: ListTile(
                                  title: Text(
                                    dateFormat.format(entry.entryDate),
                                  ),
                                  subtitle: Text(
                                    entry.generalNotes ?? 'No notes',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => context.push(
                                    '/app/diary/${entry.id}/symptom',
                                  ),
                                  trailing: PopupMenuButton<_DiaryEntryAction>(
                                    onSelected: (action) => _handleEntryAction(
                                      context,
                                      ref,
                                      entry,
                                      action,
                                    ),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<_DiaryEntryAction>(
                                        value: _DiaryEntryAction.addSymptom,
                                        child: Text('Add symptom'),
                                      ),
                                      PopupMenuItem<_DiaryEntryAction>(
                                        value: _DiaryEntryAction.deleteCheckUp,
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
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
