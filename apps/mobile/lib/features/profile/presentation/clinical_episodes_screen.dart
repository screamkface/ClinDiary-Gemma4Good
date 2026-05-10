import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/l10n/app_localizations.dart';
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteEpisode(ClinicalEpisodeItem item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileRemoveClinicalIssue),
        content: Text(l10n.profileTheItemWillBeRemovedFromTheDossier),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: Text(l10n.profileRemove),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<Map<String, dynamic>?> _showEpisodeDialog({
    ClinicalEpisodeItem? initial,
  }) async {
    final l10n = AppLocalizations.of(context);
    final compactDateFormat = DateFormat(l10n.profileDdMmYyyy, l10n.localeName);
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
            initial == null
                ? l10n.profileNewClinicalIssue
                : l10n.profileEditClinicalIssue,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: l10n.profileTitle),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: l10n.profileStatus),
                  items: [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(l10n.profileActive),
                    ),
                    DropdownMenuItem(
                      value: 'monitoring',
                      child: Text(l10n.profileMonitoring),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text(l10n.profileResolved),
                    ),
                  ],
                  onChanged: (value) => setState(() => status = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileStartDate),
                  subtitle: Text(
                    onsetDate == null
                        ? l10n.profileNotSet
                        : compactDateFormat.format(onsetDate!),
                  ),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: onsetDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: l10n.profileSelectStartDate,
                    );
                    if (picked != null) {
                      setState(() => onsetDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileResolutionDate),
                  subtitle: Text(
                    resolvedDate == null
                        ? l10n.profileNotSet
                        : compactDateFormat.format(resolvedDate!),
                  ),
                  trailing: const Icon(Icons.check_circle_outline),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: resolvedDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: l10n.profileSelectResolutionDate,
                    );
                    if (picked != null) {
                      setState(() => resolvedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileNextReview),
                  subtitle: Text(
                    nextReviewDate == null
                        ? l10n.profileNotSet
                        : compactDateFormat.format(nextReviewDate!),
                  ),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: nextReviewDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: l10n.profileSelectNextReview,
                    );
                    if (picked != null) {
                      setState(() => nextReviewDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  decoration: InputDecoration(
                    labelText: l10n.profileSummaryDescription,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: l10n.profileNote),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).maybePop(),
              child: Text(l10n.profileCancel),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.profileEnterATitleForTheClinical),
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
              child: Text(l10n.profileSave),
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
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(profileBundleProvider);
    final dateFormat = DateFormat(l10n.profileDdMmmYyyy, l10n.localeName);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileClinicalIssues),
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
            return Center(
              child: Text(l10n.profileCompleteTheProfileToManageClinical),
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
                  title: l10n.profileIssuesAndEpisodes,
                  action: FilledButton.tonalIcon(
                    onPressed: () => _saveEpisode(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.add2),
                  ),
                  child: bundle.clinicalEpisodes.isEmpty
                      ? Text(l10n.profileNoClinicalIssueRecorded)
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
                                          if (item.pendingSync)
                                            l10n.profilePendingSync,
                                          if (item.status != null)
                                            _localizedEpisodeStatus(
                                              l10n,
                                              item.status!,
                                            ),
                                          if (item.onsetDate != null)
                                            '${l10n.profileStartDate} ${dateFormat.format(item.onsetDate!)}',
                                          if (item.resolvedDate != null)
                                            '${l10n.profileResolved} ${dateFormat.format(item.resolvedDate!)}',
                                          if (item.nextReviewDate != null)
                                            '${l10n.profileNextReview} ${dateFormat.format(item.nextReviewDate!)}',
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
                                              tooltip: l10n.profileEdit,
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
                                                  ? l10n.profilePendingSync
                                                  : l10n.profileRemove,
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

  String _localizedEpisodeStatus(AppLocalizations l10n, String status) {
    switch (status) {
      case 'active':
        return l10n.profileActive;
      case 'monitoring':
        return l10n.profileMonitoring;
      case 'resolved':
        return l10n.profileResolved;
      default:
        return status;
    }
  }
}
