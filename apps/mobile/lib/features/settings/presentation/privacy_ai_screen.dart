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
                ? 'Consenso per AI esterna aggiornato.'
                : 'Consenso per AI esterna revocato.',
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
            title: const Text('Elimina account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Questa azione elimina account, profili, recap AI, share link e dati cloud associati. Sul dispositivo verranno rimossi anche cache e documenti locali del tuo account.',
                ),
                const SizedBox(height: 12),
                const Text('Per confermare scrivi ELIMINA.'),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) => setModalState(
                    () => confirmationInput = value.trim().toUpperCase(),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'ELIMINA',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                  rootNavigator: true,
                ).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: confirmationInput == 'ELIMINA'
                    ? () => Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(true)
                    : null,
                child: const Text('Elimina account'),
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
      ref.invalidate(billingStatusProvider);
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileBundleProvider);

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
                title: 'Consenso AI esterna',
                subtitle: 'Qui controlli se i recap possono usare provider esterni.',
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
                                ? 'AI esterna attiva'
                                : 'AI esterna disattivata',
                          ),
                        ),
                        if (consentEnabled && consentAt != null)
                          Chip(
                            label: Text(
                              'Ultimo consenso ${_dateLabel(consentAt.toLocal())}',
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
                          label: const Text('Privacy beta'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/legal/ai'),
                          icon: const Icon(Icons.psychology_alt_outlined),
                          label: const Text('Nota AI beta'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: consentEnabled,
                      onChanged: _savingAiPrivacy ? null : _updateAiPrivacy,
                      title: const Text('Usa AI esterna per i recap'),
                      subtitle: Text(
                        consentEnabled
                            ? 'Il backend può usare un provider esterno configurato.'
                            : 'I recap restano sul motore prudente locale.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: consentEnabled || _savingAiPrivacy
                          ? () => _updateAiPrivacy(false)
                          : null,
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Revoca consenso AI'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Cosa può vedere l\'AI',
                subtitle: 'Invia solo il contesto minimo utile al recap.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        Chip(label: Text('Contesto clinico')),
                        Chip(label: Text('Diario e sintomi')),
                        Chip(label: Text('Wearable')),
                        Chip(label: Text('Esami recenti')),
                        Chip(label: Text('Alert')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      consentEnabled
                          ? 'Per i recap usiamo payload distinti per giorno, settimana, mese e pre-visita. I profili minorenni restano sul motore prudente locale.'
                          : 'Senza consenso AI esterna i recap restano sul motore prudente locale.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Portabilità dei dati',
                subtitle: 'Esporta dossier, emergenza e backup strutturato.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/legal/portability'),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Leggi portabilità e retention'),
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
                                  shareText: 'Dossier salute ClinDiary',
                                  shareSubject: 'Dossier salute ClinDiary',
                                  successMessage:
                                      'Dossier PDF esportato e condiviso.',
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
                                  shareText: 'Backup strutturato ClinDiary',
                                  shareSubject: 'Backup strutturato ClinDiary',
                                  successMessage:
                                      'Backup JSON esportato e condiviso.',
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
                                  shareText: 'Scheda emergenza ClinDiary',
                                  shareSubject: 'Scheda emergenza ClinDiary',
                                  successMessage:
                                      'Scheda emergenza esportata e condivisa.',
                                ),
                          icon: const Icon(Icons.emergency_outlined),
                          label: const Text('Scheda emergenza'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Controllo account',
                subtitle: 'Gestisci il lifecycle dei tuoi dati.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Se elimini l\'account rimuoviamo dati cloud, token, recap e share link. Sul dispositivo cancelliamo anche cache, reminder locali e documenti free salvati in locale per questo account.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _deletingAccount ? null : _deleteAccount,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        _deletingAccount
                            ? 'Eliminazione in corso...'
                            : 'Elimina account',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Nota operativa',
                subtitle: 'Promemoria per l\'uso in produzione.',
                child: const Text(
                  'Prima della produzione serve comunque una revisione legale completa su privacy, DPIA, DPA e trasferimenti extra UE.',
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
