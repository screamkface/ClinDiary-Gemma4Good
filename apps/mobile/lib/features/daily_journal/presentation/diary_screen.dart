import 'package:clindiary/app/providers.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diario'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/app/home/history'),
            icon: const Icon(Icons.event_note_outlined),
            label: const Text('Storico'),
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
              title: 'Oggi',
              subtitle: 'Salva un check-up o apri lo storico.',
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
                              ? 'Nessun check-up'
                              : '${entries.length} check-up',
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
                        label: const Text('Storico'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Ultimi check-up',
              child: entries.isEmpty
                  ? const Text('Non hai ancora registrato nulla.')
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
                                    entry.generalNotes ?? 'Nessuna nota',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: FilledButton.tonal(
                                    onPressed: () => context.push(
                                      '/app/diary/${entry.id}/symptom',
                                    ),
                                    child: const Text('Sintomo'),
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
