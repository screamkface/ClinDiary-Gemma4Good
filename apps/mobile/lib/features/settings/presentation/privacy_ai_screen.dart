import 'dart:io';

import 'package:clindiary/app/core/network/api_client.dart';
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
  bool _savingAiPrivacy = false;
  bool _exporting = false;
  bool _uploadingEncryptedBackup = false;
  bool _restoringEncryptedBackup = false;
  bool _deletingAccount = false;

  Future<void> _updateAiPrivacy(bool enabled) async {
    if (_savingAiPrivacy) {
      return;
    }

    setState(() => _savingAiPrivacy = true);
    try {
      final bundle = await ref
          .read(profileRepositoryProvider)
          .updateAiPrivacyConsent(enabled);
      final currentSession = ref.read(authControllerProvider).valueOrNull;
      if (currentSession != null) {
        await ref
            .read(authControllerProvider.notifier)
            .updateUser(
              currentSession.user.copyWith(
                aiExternalConsent: bundle.onboarding.aiExternalConsent,
                aiExternalConsentedAt: bundle.onboarding.aiExternalConsentedAt,
              ),
            );
      }
      ref.invalidate(profileBundleProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'External AI consent updated.'
                : 'External AI consent revoked.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _savingAiPrivacy = false);
      }
    }
  }

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
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
                  'This action deletes the account, profiles, AI recaps, share links, and associated cloud data. On the device we also remove cache and local documents for this account.',
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
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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

  Future<void> _uploadEncryptedBackupToDrive() async {
    if (_uploadingEncryptedBackup) {
      return;
    }

    setState(() => _uploadingEncryptedBackup = true);
    try {
      final result = await ref
          .read(encryptedBackupServiceProvider)
          .uploadEncryptedSnapshotToDrive();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Encrypted backup uploaded: ${result.fileName} (${result.encryptedBytes} bytes).',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _uploadingEncryptedBackup = false);
      }
    }
  }

  Future<void> _restoreEncryptedBackupFromDrive() async {
    if (_restoringEncryptedBackup) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore encrypted backup?'),
        content: const Text(
          'The latest encrypted backup from Google Drive app data will replace the local dossier snapshot for this profile.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _restoringEncryptedBackup = true);
    try {
      final result = await ref
          .read(encryptedBackupServiceProvider)
          .restoreLatestEncryptedSnapshotFromDrive(replaceExisting: true);

      ref.invalidate(healthDossierProvider);
      ref.invalidate(profileBundleProvider);
      ref.invalidate(screeningCatalogProvider);
      ref.invalidate(myScreeningsProvider);
      ref.invalidate(preventionCenterProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(timelineEventsProvider);
      ref.invalidate(documentsProvider);
      ref.invalidate(alertsProvider);
      ref.invalidate(dossierShareLinksProvider);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Encrypted backup restored: ${result.fileName}.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _restoringEncryptedBackup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileBundleProvider);
    final localOnlyMode = ref.read(appConfigProvider).localOnlyMode;
    final pendingOperationsAsync = ref.watch(pendingOperationsProvider);
    final onDeviceStatusAsync = ref.watch(onDeviceAiStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy AI')),
      body: profileAsync.when(
        data: (bundle) {
          if (bundle == null) {
            return const Center(
              child: Text('Completa l\'autenticazione per gestire la privacy.'),
            );
          }

          final consentEnabled = bundle.onboarding.aiExternalConsent;
          final consentAt = bundle.onboarding.aiExternalConsentedAt;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'External AI consent',
                subtitle: 'Control whether recaps may use external providers.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            consentEnabled
                                ? 'External AI enabled'
                                : 'External AI disabled',
                          ),
                        ),
                        if (consentEnabled && consentAt != null)
                          Chip(
                            label: Text(
                              'Last consent ${_dateLabel(consentAt.toLocal())}',
                            ),
                          ),
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
                          label: const Text('Beta privacy notice'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/legal/ai'),
                          icon: const Icon(Icons.psychology_alt_outlined),
                          label: const Text('Beta AI note'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: consentEnabled,
                      onChanged: _savingAiPrivacy ? null : _updateAiPrivacy,
                      title: const Text('Use external AI for recaps'),
                      subtitle: Text(
                        consentEnabled
                            ? 'The backend may use a configured external provider.'
                            : 'Recaps stay on the local cautious engine.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: consentEnabled || _savingAiPrivacy
                          ? () => _updateAiPrivacy(false)
                          : null,
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Revoke AI consent'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'What AI can see',
                subtitle: 'Send only the minimum context needed for the recap.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        Chip(label: Text('Clinical context')),
                        Chip(label: Text('Diary and symptoms')),
                        Chip(label: Text('Wearable')),
                        Chip(label: Text('Recent tests')),
                        Chip(label: Text('Alerts')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      consentEnabled
                          ? 'For recaps we use distinct payloads for day, week, month, and pre-visit. Minor profiles stay on the local cautious engine.'
                          : 'Without external AI consent, recaps stay on the local cautious engine.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Local-only diagnostics',
                subtitle:
                    'Quick health check for offline/local-first execution readiness.',
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
                        Chip(
                          label: Text(
                            localOnlyMode
                                ? 'Local-only mode: active'
                                : 'Local-only mode: inactive',
                          ),
                        ),
                        Chip(
                          label: Text(
                            pendingOperationsAsync.asData == null
                                ? 'Pending sync: checking...'
                                : 'Pending sync: ${pendingOperationsAsync.asData!.value.length}',
                          ),
                        ),
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
                                  filePrefix: 'clindiary-scheda-emergenza',
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
                        if (localOnlyMode)
                          FilledButton.tonalIcon(
                            onPressed: _uploadingEncryptedBackup || _exporting
                                ? null
                                : _uploadEncryptedBackupToDrive,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(
                              _uploadingEncryptedBackup
                                  ? 'Uploading encrypted backup...'
                                  : 'Encrypted backup to Drive',
                            ),
                          ),
                        if (localOnlyMode)
                          FilledButton.tonalIcon(
                            onPressed: _restoringEncryptedBackup || _exporting
                                ? null
                                : _restoreEncryptedBackupFromDrive,
                            icon: const Icon(Icons.restore_outlined),
                            label: Text(
                              _restoringEncryptedBackup
                                  ? 'Restoring encrypted backup...'
                                  : 'Restore encrypted backup',
                            ),
                          ),
                      ],
                    ),
                    if (localOnlyMode) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Backups are encrypted locally before upload and stored in Google Drive app data. Restore applies the latest encrypted snapshot to the active profile.',
                      ),
                    ],
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
                      'If you delete the account, we remove cloud data, tokens, recaps, and share links. On the device we also delete cache, local reminders, and free local documents saved for this account.',
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

String _dateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
