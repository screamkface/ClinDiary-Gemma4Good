import 'dart:io';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/dossier/data/dossier_repository.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PrivacyAiScreen extends ConsumerStatefulWidget {
  const PrivacyAiScreen({super.key});

  @override
  ConsumerState<PrivacyAiScreen> createState() => _PrivacyAiScreenState();
}

class _PrivacyAiScreenState extends ConsumerState<PrivacyAiScreen> {
  bool _exporting = false;
  bool _deletingAccount = false;

  Future<void> _shareExport({
    required Future<List<int>> Function(DossierRepository repository) loadBytes,
    required String filePrefix,
    required String filenameExtension,
    required String mimeType,
    required String shareText,
    required String shareSubject,
    required String successMessage,
  }) async {
    if (_exporting) {
      return;
    }

    setState(() => _exporting = true);
    try {
      final repository = ref.read(dossierRepositoryProvider);
      final bytes = await loadBytes(repository);
      final directory = await getTemporaryDirectory();
      final filename =
          '$filePrefix-${DateTime.now().millisecondsSinceEpoch}.$filenameExtension';
      final file = File(path.join(directory.path, filename));
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          text: shareText,
          subject: shareSubject,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) {
      return;
    }

    var confirmationInput = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('Delete account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action deletes the account, profiles, AI recaps, share links, and associated local data on this device.',
                ),
                const SizedBox(height: 12),
                const Text('To confirm, type DELETE.'),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) => setModalState(
                    () => confirmationInput = value.trim().toUpperCase(),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: confirmationInput == 'DELETE'
                    ? () => Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(true)
                    : null,
                child: const Text('Delete account'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _deletingAccount = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(confirmationText: 'ELIMINA');
      invalidatePatientScopedProviders(ref);
      if (!mounted) {
        return;
      }
      context.go('/');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileBundleProvider);
    final onDeviceStatusAsync = ref.watch(onDeviceAiStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Local AI')),
      body: profileAsync.when(
        data: (bundle) {
          if (bundle == null) {
            return const Center(
              child: Text('Complete sign-in to manage settings.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Local AI',
                subtitle: 'All AI processing stays on your device.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Local AI only')),
                        Chip(label: Text('No external providers')),
                        Chip(label: Text('No data leaves device')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/legal/privacy'),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Privacy notice'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/legal/ai'),
                          icon: const Icon(Icons.psychology_alt_outlined),
                          label: const Text('AI note'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Recaps are generated on-device by Gemma via LiteRT. No recap content or health data is sent to any external server.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'What AI can see',
                subtitle: 'Minimum context passed to the on-device model.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Clinical context')),
                        Chip(label: Text('Diary and symptoms')),
                        Chip(label: Text('Wearable')),
                        Chip(label: Text('Recent tests')),
                        Chip(label: Text('Alerts')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Distinct payloads for day, week, month, and pre-visit recaps. All processing runs locally — Gemma runs on-device via LiteRT.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'On-device AI status',
                subtitle: 'Local-first execution readiness.',
                action: TextButton.icon(
                  onPressed: () {
                    ref.invalidate(onDeviceAiStatusProvider);
                    ref.invalidate(pendingOperationsProvider);
                  },
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Refresh'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Chip(label: Text('Local-only: always active')),
                        Chip(
                          label: Text(
                            onDeviceStatusAsync.asData == null
                                ? 'On-device AI: checking...'
                                : (onDeviceStatusAsync.asData!.value.isReady
                                      ? 'On-device AI: ready'
                                      : 'On-device AI: not ready'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      onDeviceStatusAsync.asData?.value.activeProviderLabel ??
                          'No on-device provider detected yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Document search models',
                subtitle: 'Semantic search and ranking for clinical documents.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Embedding: Gemma 300M')),
                        Chip(label: Text('Provider: MediaPipe')),
                        Chip(label: Text('Ranking: On-device')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'When you ask questions about your documents, the app uses Embedding Gemma 300M (via MediaPipe TextEmbedder) to understand semantic meaning. The embedding model runs entirely on-device — your question and document context are never sent to external servers. Results are ranked locally and passed to Gemma 4 for answer generation with citations.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Data portability',
                subtitle:
                    'Export dossier, emergency data, and structured backups.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/legal/portability'),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Read portability and retention'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _exporting
                              ? null
                              : () => _shareExport(
                                  loadBytes: (repository) =>
                                      repository.exportDossier(),
                                  filePrefix: 'clindiary-dossier',
                                  filenameExtension: 'pdf',
                                  mimeType: 'application/pdf',
                                  shareText: 'ClinDiary health dossier',
                                  shareSubject: 'ClinDiary health dossier',
                                  successMessage:
                                      'Dossier PDF exported and shared.',
                                ),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Dossier PDF'),
                        ),
                        FilledButton.icon(
                          onPressed: _exporting
                              ? null
                              : () => _shareExport(
                                  loadBytes: (repository) =>
                                      repository.exportDossierJson(),
                                  filePrefix: 'clindiary-dossier-backup',
                                  filenameExtension: 'json',
                                  mimeType: 'application/json',
                                  shareText: 'ClinDiary structured backup',
                                  shareSubject: 'ClinDiary structured backup',
                                  successMessage:
                                      'JSON backup exported and shared.',
                                ),
                          icon: const Icon(Icons.data_object_outlined),
                          label: const Text('Backup JSON'),
                        ),
                        FilledButton.icon(
                          onPressed: _exporting
                              ? null
                              : () => _shareExport(
                                  loadBytes: (repository) =>
                                      repository.exportEmergencyDossier(),
                                  filePrefix: 'clindiary-emergency-card',
                                  filenameExtension: 'pdf',
                                  mimeType: 'application/pdf',
                                  shareText: 'ClinDiary emergency card',
                                  shareSubject: 'ClinDiary emergency card',
                                  successMessage:
                                      'Emergency card exported and shared.',
                                ),
                          icon: const Icon(Icons.emergency_outlined),
                          label: const Text('Emergency card'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Exports are generated locally from on-device data.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Account control',
                subtitle: 'Manage the lifecycle of your data.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deleting the account removes all local data, tokens, AI recaps, cache, reminders, and local documents on this device.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _deletingAccount ? null : _deleteAccount,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        _deletingAccount ? 'Deleting...' : 'Delete account',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Operational note',
                subtitle: 'Reminder for production use.',
                child: const Text(
                  'Before production, a full legal review is still required for privacy, DPIA, DPA, and extra-EU transfers.',
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
