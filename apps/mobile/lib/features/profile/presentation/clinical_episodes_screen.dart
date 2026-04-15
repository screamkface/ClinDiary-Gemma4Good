import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ClinicalEpisodesScreen extends ConsumerStatefulWidget {
  const ClinicalEpisodesScreen({super.key});

  @override
  ConsumerState<ClinicalEpisodesScreen> createState() =>
      _ClinicalEpisodesScreenState();
}

class _ClinicalEpisodesScreenState
    extends ConsumerState<ClinicalEpisodesScreen> {
  Future<void> _saveEpisode({ClinicalEpisodeItem? initial}) async {
    final result = await _showEpisodeDialog(initial: initial);
    if (!mounted || result == null) {
      return;
    }

    try {
      if (initial == null) {
        await ref.read(profileRepositoryProvider).addClinicalEpisode(result);
      } else {
        await ref
            .read(profileRepositoryProvider)
            .updateClinicalEpisode(initial.id, result);
      }
      ref.invalidate(profileBundleProvider);
      ref.invalidate(healthDossierProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteEpisode(ClinicalEpisodeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove clinical issue?'),
        content: const Text('The item will be removed from the dossier.'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(profileRepositoryProvider).deleteClinicalEpisode(item.id);
      ref.invalidate(profileBundleProvider);
      ref.invalidate(healthDossierProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<Map<String, dynamic>?> _showEpisodeDialog({
    ClinicalEpisodeItem? initial,
  }) async {
    final titleController = TextEditingController(text: initial?.title ?? '');
    final summaryController = TextEditingController(
      text: initial?.summary ?? '',
    );
    final notesController = TextEditingController(text: initial?.notes ?? '');
    DateTime? onsetDate = initial?.onsetDate;
    DateTime? resolvedDate = initial?.resolvedDate;
    DateTime? nextReviewDate = initial?.nextReviewDate;
    String? status = initial?.status;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            initial == null ? 'New clinical issue' : 'Edit clinical issue',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'monitoring',
                      child: Text('Monitoring'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                  ],
                  onChanged: (value) => setState(() => status = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start date'),
                  subtitle: Text(
                    onsetDate == null
                        ? 'Not set'
                        : DateFormat('dd/MM/yyyy').format(onsetDate!),
                  ),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: onsetDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: 'Select start date',
                    );
                    if (picked != null) {
                      setState(() => onsetDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resolution date'),
                  subtitle: Text(
                    resolvedDate == null
                        ? 'Not set'
                        : DateFormat('dd/MM/yyyy').format(resolvedDate!),
                  ),
                  trailing: const Icon(Icons.check_circle_outline),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: resolvedDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: 'Select resolution date',
                    );
                    if (picked != null) {
                      setState(() => resolvedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Next review'),
                  subtitle: Text(
                    nextReviewDate == null
                        ? 'Not set'
                        : DateFormat('dd/MM/yyyy').format(nextReviewDate!),
                  ),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: nextReviewDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: 'Select next review',
                    );
                    if (picked != null) {
                      setState(() => nextReviewDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Summary / description',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).maybePop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a title for the clinical issue.'),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext, rootNavigator: true).pop({
                  'title': title,
                  'summary': summaryController.text.trim().isEmpty
                      ? null
                      : summaryController.text.trim(),
                  'status': status,
                  'onset_date': onsetDate?.toIso8601String().split('T').first,
                  'resolved_date': resolvedDate
                      ?.toIso8601String()
                      .split('T')
                      .first,
                  'next_review_date': nextReviewDate
                      ?.toIso8601String()
                      .split('T')
                      .first,
                  'notes': notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    summaryController.dispose();
    notesController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileBundleProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical issues'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(profileBundleProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (bundle) {
          if (bundle == null) {
            return const Center(
              child: Text('Complete the profile to manage clinical issues.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileBundleProvider);
              ref.invalidate(healthDossierProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Issues and episodes',
                  action: FilledButton.tonalIcon(
                    onPressed: () => _saveEpisode(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                  child: bundle.clinicalEpisodes.isEmpty
                      ? const Text('No clinical issue recorded.')
                      : Column(
                          children: bundle.clinicalEpisodes
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Card.outlined(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      title: Text(item.title),
                                      subtitle: Text(
                                        [
                                          if (item.pendingSync) 'Pending sync',
                                          if (item.status != null) item.status!,
                                          if (item.onsetDate != null)
                                            'Start ${dateFormat.format(item.onsetDate!)}',
                                          if (item.resolvedDate != null)
                                            'Resolved ${dateFormat.format(item.resolvedDate!)}',
                                          if (item.nextReviewDate != null)
                                            'Review ${dateFormat.format(item.nextReviewDate!)}',
                                          if (item.summary?.isNotEmpty == true)
                                            item.summary!,
                                          if (item.notes?.isNotEmpty == true)
                                            item.notes!,
                                        ].join(' | '),
                                      ),
                                      trailing: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit',
                                              onPressed: item.pendingSync
                                                  ? null
                                                  : () => _saveEpisode(
                                                      initial: item,
                                                    ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: item.pendingSync
                                                  ? 'Pending sync'
                                                  : 'Remove',
                                              onPressed: item.pendingSync
                                                  ? null
                                                  : () => _deleteEpisode(item),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
