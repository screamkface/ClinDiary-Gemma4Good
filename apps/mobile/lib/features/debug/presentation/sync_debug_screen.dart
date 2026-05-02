import 'package:clindiary/app/providers.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SyncDebugScreen extends ConsumerStatefulWidget {
  const SyncDebugScreen({super.key});

  @override
  ConsumerState<SyncDebugScreen> createState() => _SyncDebugScreenState();
}

class _SyncDebugScreenState extends ConsumerState<SyncDebugScreen> {
  bool _flushing = false;
  bool _clearing = false;

  Future<void> _flushQueue() async {
    // Network sync is disabled in local-only mode.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App is in local-only mode — no operations to sync.'),
      ),
    );
  }

  Future<void> _clearLocalDebugData() async {
    setState(() => _clearing = true);
    try {
      final database = ref.read(localDatabaseProvider);
      await database.clearPendingOperations();
      await database.clearRequestTraces();
      ref.invalidate(pendingOperationsProvider);
      ref.invalidate(requestTracesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local queue and traces cleared.')),
      );
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingOperationsProvider);
    final tracesAsync = ref.watch(requestTracesProvider);
    final formatter = DateFormat('dd MMM HH:mm', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local sync'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(pendingOperationsProvider);
              ref.invalidate(requestTracesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Actions',
            subtitle: 'Use these actions only for local debug.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _flushing ? null : _flushQueue,
                  icon: const Icon(Icons.sync_outlined),
                  label: Text(_flushing ? 'Sync...' : 'Sync'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearing ? null : _clearLocalDebugData,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(_clearing ? 'Cleaning...' : 'Clear debug'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          pendingAsync.when(
            data: (items) => Column(
              children: [
                SectionCard(
                  title: 'Queue summary',
                  subtitle: 'Quick status of offline operations.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SyncSummaryChip(
                        label: 'Total',
                        value: items.length.toString(),
                      ),
                      _SyncSummaryChip(
                        label: 'Profile',
                        value: _bucketCount(items, 'profile').toString(),
                      ),
                      _SyncSummaryChip(
                        label: 'Notifications',
                        value: _bucketCount(items, 'notifications').toString(),
                      ),
                      _SyncSummaryChip(
                        label: 'Medications',
                        value: _bucketCount(items, 'medications').toString(),
                      ),
                      _SyncSummaryChip(
                        label: 'Documents',
                        value: _bucketCount(items, 'documents').toString(),
                      ),
                      _SyncSummaryChip(
                        label: 'Other',
                        value: _bucketCount(items, 'other').toString(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Queued operations',
                  subtitle: items.isEmpty
                      ? 'No pending operations.'
                      : 'Latest ${items.length} local operations.',
                  child: items.isEmpty
                      ? const Text('No pending operations.')
                      : Column(
                          children: items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DebugRowCard(
                                title: '${item.method} ${item.path}',
                                subtitle:
                                    'Attempts ${item.attempts} - ${formatter.format(item.createdAt.toLocal())}'
                                    '${item.lastError == null || item.lastError!.isEmpty ? '' : '\n${item.lastError}'}',
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
            loading: () => const SectionCard(
              title: 'Queued operations',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Queued operations',
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 12),
          tracesAsync.when(
            data: (items) => SectionCard(
              title: 'Recent network traces',
              subtitle: items.isEmpty
                  ? 'No traces recorded.'
                  : 'Latest ${items.take(20).length} local requests.',
              child: items.isEmpty
                  ? const Text('No traces recorded.')
                  : Column(
                      children: items.take(20).map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DebugRowCard(
                            title: '${item.method} ${item.path}',
                            subtitle:
                                '${item.statusCode} ÔÇó ${formatter.format(item.createdAt.toLocal())}'
                                '${item.requestId == null ? '' : '\n${item.requestId}'}',
                            trailing: item.responseTimeMs == null
                                ? '-'
                                : '${item.responseTimeMs!.toStringAsFixed(0)} ms',
                          ),
                        );
                      }).toList(),
                    ),
            ),
            loading: () => const SectionCard(
              title: 'Trace rete recenti',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Trace rete recenti',
              child: Text(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  int _bucketCount(List<PendingOperation> items, String bucket) {
    return items.where((item) => _bucketForPath(item.path) == bucket).length;
  }

  String _bucketForPath(String path) {
    if (path.contains('/profile/')) {
      return 'profile';
    }
    if (path.contains('/notifications/')) {
      return 'notifications';
    }
    if (path.contains('/medications/')) {
      return 'medications';
    }
    if (path.contains('/documents/')) {
      return 'documents';
    }
    return 'other';
  }
}

class _SyncSummaryChip extends StatelessWidget {
  const _SyncSummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _DebugRowCard extends StatelessWidget {
  const _DebugRowCard({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Text(trailing!, style: Theme.of(context).textTheme.labelLarge),
          ],
        ],
      ),
    );
  }
}
