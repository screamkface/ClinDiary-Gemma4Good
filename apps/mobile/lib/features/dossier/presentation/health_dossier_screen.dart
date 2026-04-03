import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:nfc_manager/nfc_manager.dart';
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_android/tags/ndef.dart';
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_android/tags/ndef_formatable.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:share_plus/share_plus.dart';

class HealthDossierScreen extends ConsumerWidget {
  const HealthDossierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossierAsync = ref.watch(healthDossierProvider);
    final shareLinksAsync = ref.watch(dossierShareLinksProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm', 'it_IT');

    Future<void> sharePdfDossier() async {
      try {
        final bytes = await ref.read(dossierRepositoryProvider).exportDossier();
        final directory = await getTemporaryDirectory();
        final filename =
            'clindiary-dossier-${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(path.join(directory.path, filename));
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            text: 'Dossier salute ClinDiary',
            subject: 'Dossier salute ClinDiary',
          ),
        );
      } on ApiException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    Future<void> shareJsonBackup() async {
      try {
        final bytes = await ref
            .read(dossierRepositoryProvider)
            .exportDossierJson();
        final directory = await getTemporaryDirectory();
        final filename =
            'clindiary-dossier-backup-${DateTime.now().millisecondsSinceEpoch}.json';
        final file = File(path.join(directory.path, filename));
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            text: 'Backup strutturato ClinDiary',
            subject: 'Backup strutturato ClinDiary',
          ),
        );
      } on ApiException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    Future<void> shareEmergencyPdf() async {
      try {
        final bytes = await ref
            .read(dossierRepositoryProvider)
            .exportEmergencyDossier();
        final directory = await getTemporaryDirectory();
        final filename =
            'clindiary-scheda-emergenza-${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(path.join(directory.path, filename));
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            text: 'Scheda emergenza ClinDiary',
            subject: 'Scheda emergenza ClinDiary',
          ),
        );
      } on ApiException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    Future<void> shareEmergencyViaNfc() async {
      if (!Platform.isAndroid) {
        await shareEmergencyPdf();
        return;
      }

      DossierShareLinkItem? createdLink;
      try {
        final availability = await NfcManager.instance.checkAvailability();
        if (availability != NfcAvailability.enabled) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'NFC non disponibile su questo dispositivo. Uso il PDF della scheda emergenza.',
              ),
            ),
          );
          await shareEmergencyPdf();
          return;
        }

        createdLink = await ref
            .read(dossierRepositoryProvider)
            .createShareLink(
              scope: 'emergency',
              label: 'Scheda emergenza NFC',
              expiresInDays: 7,
            );
        ref.invalidate(dossierShareLinksProvider);

        final shareUrl = createdLink.shareUrl;
        if (shareUrl == null || shareUrl.isEmpty) {
          throw StateError('Link emergenza non disponibile.');
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Avvicina un tag NFC o una card compatibile.'),
            action: SnackBarAction(
              label: 'Annulla',
              onPressed: () => unawaited(NfcManager.instance.stopSession()),
            ),
          ),
        );

        var sessionHandled = false;

        Future<void> handleDiscoveredTag(NfcTag tag) async {
          try {
            await _writeEmergencyLinkToTag(tag, shareUrl);
            await NfcManager.instance.stopSession();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Scheda emergenza scritta su NFC.')),
            );
          } catch (error) {
            try {
              if (createdLink != null) {
                await ref
                    .read(dossierRepositoryProvider)
                    .revokeShareLink(createdLink.id);
              }
            } catch (_) {
              // Ignore cleanup errors.
            }
            ref.invalidate(dossierShareLinksProvider);
            await NfcManager.instance.stopSession();
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('NFC non riuscito: $error')));
            await shareEmergencyPdf();
          }
        }

        await NfcManager.instance.startSession(
          pollingOptions: const {
            NfcPollingOption.iso14443,
            NfcPollingOption.iso15693,
            NfcPollingOption.iso18092,
          },
          noPlatformSoundsAndroid: true,
          onDiscovered: (tag) {
            if (sessionHandled) {
              return;
            }
            sessionHandled = true;
            unawaited(handleDiscoveredTag(tag));
          },
        );
      } catch (error) {
        if (createdLink != null) {
          try {
            await ref
                .read(dossierRepositoryProvider)
                .revokeShareLink(createdLink.id);
          } catch (_) {
            // Ignore cleanup errors.
          }
          ref.invalidate(dossierShareLinksProvider);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NFC non disponibile o non riuscito: $error')),
        );
        await shareEmergencyPdf();
      }
    }

    Future<void> importJsonBackup() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importazione annullata.')),
          );
          return;
        }
        final file = result.files.first;
        if (file.bytes == null) {
          return;
        }
        final snapshot =
            jsonDecode(utf8.decode(file.bytes!)) as Map<String, dynamic>;
        await ref
            .read(dossierRepositoryProvider)
            .importDossier(snapshot: snapshot, replaceExisting: true);
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
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup JSON importato.')));
      } on ApiException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    Future<void> copyEmergencySummary(
      DossierEmergencySummary summary,
      String displayName,
    ) async {
      await Clipboard.setData(
        ClipboardData(text: summary.toShareText(displayName: displayName)),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheda emergenza copiata.')),
      );
    }

    Future<void> shareEmergencySummary(
      DossierEmergencySummary summary,
      String displayName,
    ) async {
      await SharePlus.instance.share(
        ShareParams(
          text: summary.toShareText(displayName: displayName),
          subject: 'Scheda emergenza ClinDiary',
        ),
      );
    }

    Future<void> createShareLink(String scope) async {
      try {
        final link = await ref
            .read(dossierRepositoryProvider)
            .createShareLink(
              scope: scope,
              label: scope == 'full' ? 'Dossier completo' : 'Scheda emergenza',
            );
        if (link.shareUrl != null && link.shareUrl!.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: link.shareUrl!));
          await SharePlus.instance.share(
            ShareParams(
              text: link.shareUrl!,
              subject: scope == 'full'
                  ? 'Dossier completo ClinDiary'
                  : 'Scheda emergenza ClinDiary',
            ),
          );
        }
        ref.invalidate(dossierShareLinksProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link sicuro creato.')));
      } on ApiException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    Future<void> revokeShareLink(DossierShareLinkItem link) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Revocare il link?'),
          content: const Text('Il link non sara piu utilizzabile.'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(true),
              child: const Text('Revoca'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      try {
        await ref.read(dossierRepositoryProvider).revokeShareLink(link.id);
        ref.invalidate(dossierShareLinksProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link revocato.')));
      } on ApiException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }

    Future<void> refreshDossier() async {
      ref.invalidate(healthDossierProvider);
      ref.invalidate(profileBundleProvider);
      ref.invalidate(documentsProvider);
      ref.invalidate(alertsProvider);
      ref.invalidate(dossierShareLinksProvider);
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dossier salute'),
          actions: [
            IconButton(
              onPressed: sharePdfDossier,
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: 'Esporta e condividi',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Altre azioni',
              onSelected: (value) async {
                switch (value) {
                  case 'json':
                    await shareJsonBackup();
                    break;
                  case 'copy-emergency':
                    await dossierAsync.when(
                      data: (dossier) => copyEmergencySummary(
                        dossier.emergencySummary,
                        dossier.displayName,
                      ),
                      loading: () async {},
                      error: (_, __) async {},
                    );
                    break;
                  case 'import-json':
                    await importJsonBackup();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'json', child: Text('Backup JSON')),
                PopupMenuItem(
                  value: 'import-json',
                  child: Text('Importa backup JSON'),
                ),
                PopupMenuItem(
                  value: 'copy-emergency',
                  child: Text('Copia scheda emergenza'),
                ),
              ],
            ),
            IconButton(
              onPressed: refreshDossier,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Sintesi'),
              Tab(text: 'Clinico'),
              Tab(text: 'Referti'),
              Tab(text: 'Diario'),
              Tab(text: 'Condividi'),
            ],
          ),
        ),
        body: dossierAsync.when(
          data: (dossier) => TabBarView(
            children: [
              _DossierTabList(
                onRefresh: refreshDossier,
                children: [
                  SectionCard(
                    title: 'Profilo',
                    subtitle: 'Riepilogo rapido del dossier attivo.',
                    action: Text(
                      dateTimeFormat.format(dossier.generatedAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dossier.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    [
                                          if (dossier.age != null)
                                            '${dossier.age} anni',
                                          if (dossier.biologicalSex != null)
                                            _sexLabel(dossier.biologicalSex!),
                                        ].join(' • ').isEmpty
                                        ? 'Cartella personale ordinata'
                                        : [
                                            if (dossier.age != null)
                                              '${dossier.age} anni',
                                            if (dossier.biologicalSex != null)
                                              _sexLabel(dossier.biologicalSex!),
                                          ].join(' • '),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _DossierHeaderAvatar(label: dossier.displayName),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DossierMetricPill(
                              label: 'Problemi',
                              value:
                                  '${dossier.medicalConditions.length + dossier.clinicalEpisodes.length}',
                            ),
                            _DossierMetricPill(
                              label: 'Farmaci',
                              value: '${dossier.medications.length}',
                            ),
                            _DossierMetricPill(
                              label: 'Documenti',
                              value: '${dossier.recentDocuments.length}',
                            ),
                            _DossierMetricPill(
                              label: 'Alert',
                              value: '${dossier.alerts.length}',
                            ),
                            if (dossier.deviceMeasurementSummaries.isNotEmpty)
                              _DossierMetricPill(
                                label: 'Device',
                                value:
                                    '${dossier.deviceMeasurementSummaries.length}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (dossier.profileFacts.isEmpty)
                          const Text('Nessun dettaglio profilo disponibile.')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dossier.profileFacts
                                .map(
                                  (fact) => Chip(
                                    label: Text('${fact.label}: ${fact.value}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Scheda emergenza',
                    subtitle: 'Versione rapida da copiare o condividere.',
                    action: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => copyEmergencySummary(
                            dossier.emergencySummary,
                            dossier.displayName,
                          ),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copia'),
                        ),
                        TextButton.icon(
                          onPressed: () => shareEmergencySummary(
                            dossier.emergencySummary,
                            dossier.displayName,
                          ),
                          icon: const Icon(Icons.ios_share_outlined),
                          label: const Text('Condividi'),
                        ),
                        TextButton.icon(
                          key: const ValueKey('dossier-emergency-nfc'),
                          onPressed: shareEmergencyViaNfc,
                          icon: const Icon(Icons.nfc_outlined),
                          label: const Text('NFC'),
                        ),
                        TextButton.icon(
                          onPressed: shareEmergencyPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('PDF'),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dossier.emergencySummary.headline,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Aggiornata ${dateTimeFormat.format(dossier.emergencySummary.generatedAt.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        ...dossier.emergencySummary.keyPoints.map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CompactBulletCard(text: point),
                          ),
                        ),
                        if (dossier
                            .emergencySummary
                            .activeProblems
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Problemi attivi',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dossier.emergencySummary.activeProblems
                                .map((item) => Chip(label: Text(item)))
                                .toList(),
                          ),
                        ],
                        if ((dossier.emergencySummary.latestReportSummary ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Report recente',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(dossier.emergencySummary.latestReportSummary!),
                        ],
                        if ((dossier.emergencySummary.latestWearableSummary ??
                                '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Wearable',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(dossier.emergencySummary.latestWearableSummary!),
                        ],
                        if (dossier
                            .emergencySummary
                            .activeMedications
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Farmaci attivi',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dossier.emergencySummary.activeMedications
                                .map((item) => Chip(label: Text(item)))
                                .toList(),
                          ),
                        ],
                        if (dossier.emergencySummary.allergies.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Allergie',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dossier.emergencySummary.allergies
                                .map((item) => Chip(label: Text(item)))
                                .toList(),
                          ),
                        ],
                        if (dossier.emergencySummary.conditions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Patologie note',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dossier.emergencySummary.conditions
                                .map((item) => Chip(label: Text(item)))
                                .toList(),
                          ),
                        ],
                        if (dossier.emergencySummary.openAlerts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Alert aperti',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dossier.emergencySummary.openAlerts
                                .map((item) => Chip(label: Text(item)))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Provenienza dati',
                    subtitle: 'Origine e aggiornamento dei dati aggregati.',
                    child: dossier.provenanceFacts.isEmpty
                        ? const Text('Nessuna provenienza disponibile.')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dossier.provenanceFacts
                                .map(
                                  (fact) => Chip(
                                    label: Text('${fact.label}: ${fact.value}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
              _DossierTabList(
                onRefresh: refreshDossier,
                children: [
                  _SimpleListSection(
                    title: 'Patologie, allergie e familiarita',
                    items: [
                      ...dossier.medicalConditions.map(
                        (item) =>
                            '${item.name}${item.status == null ? '' : ' • ${item.status}'}',
                      ),
                      ...dossier.allergies.map(
                        (item) =>
                            '${item.allergen}${item.severity == null ? '' : ' • ${item.severity}'}',
                      ),
                      ...dossier.familyHistory.map(
                        (item) => '${item.relation}: ${item.conditionName}',
                      ),
                    ],
                    emptyLabel: 'Nessun elemento registrato.',
                    action: TextButton(
                      onPressed: () => context.go('/app/profile'),
                      child: const Text('Apri profilo'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Problemi clinici',
                    action: TextButton(
                      onPressed: () => context.push('/app/profile/problems'),
                      child: const Text('Apri'),
                    ),
                    child: dossier.clinicalEpisodes.isEmpty
                        ? const Text('Nessun problema clinico registrato.')
                        : Column(
                            children: dossier.clinicalEpisodes
                                .map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.title),
                                    subtitle: Text(
                                      [
                                        if (item.pendingSync)
                                          'In attesa di sincronizzazione',
                                        if (item.status != null) item.status!,
                                        if (item.onsetDate != null)
                                          'Inizio ${dateFormat.format(item.onsetDate!)}',
                                        if (item.resolvedDate != null)
                                          'Risolto ${dateFormat.format(item.resolvedDate!)}',
                                        if (item.nextReviewDate != null)
                                          'Controllo ${dateFormat.format(item.nextReviewDate!)}',
                                        if ((item.summary ?? '').isNotEmpty)
                                          item.summary!,
                                        if ((item.notes ?? '').isNotEmpty)
                                          item.notes!,
                                      ].join(' • '),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Farmaci attuali',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/medications'),
                      child: const Text('Apri'),
                    ),
                    child: dossier.medications.isEmpty
                        ? const Text('Nessuna terapia registrata.')
                        : Column(
                            children: dossier.medications
                                .map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.name),
                                    subtitle: Text(
                                      [
                                        if ((item.dosage ?? '').isNotEmpty)
                                          item.dosage!,
                                        if ((item.frequency ?? '').isNotEmpty)
                                          item.frequency!,
                                        if (item.schedules.isNotEmpty)
                                          item.schedules.first.compactLabel,
                                      ].join(' • '),
                                    ),
                                    trailing: Text(
                                      item.active ? 'Attivo' : 'Stop',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Dispositivi clinici',
                    subtitle:
                        'Sintesi compatta delle misure recenti dai connettori collegati.',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/devices'),
                      child: const Text('Apri'),
                    ),
                    child: dossier.deviceMeasurementSummaries.isEmpty
                        ? const Text(
                            'Nessuna misura da dispositivi clinici nel dossier.',
                          )
                        : Column(
                            children: dossier.deviceMeasurementSummaries
                                .map(
                                  (item) => _DossierDeviceMeasurementCard(
                                    item: item,
                                    dateFormat: dateTimeFormat,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Storico vaccinale',
                    action: TextButton(
                      onPressed: () =>
                          context.push('/app/profile/vaccinations'),
                      child: const Text('Gestisci'),
                    ),
                    child: dossier.vaccinations.isEmpty
                        ? const Text('Nessun vaccino nel dossier.')
                        : Column(
                            children: dossier.vaccinations
                                .map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.vaccineName),
                                    subtitle: Text(
                                      [
                                        if (item.administeredOn != null)
                                          'Somministrato ${dateFormat.format(item.administeredOn!)}',
                                        if (item.doseNumber != null)
                                          'Dose ${item.doseNumber}',
                                        if (item.nextDueDate != null)
                                          'Richiamo ${dateFormat.format(item.nextDueDate!)}',
                                        if (item.providerName != null &&
                                            item.providerName!.isNotEmpty)
                                          item.providerName!,
                                      ].join(' • '),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
              _DossierTabList(
                onRefresh: refreshDossier,
                children: [
                  SectionCard(
                    title: 'Documenti e referti',
                    action: TextButton(
                      onPressed: () => context.go('/app/documents'),
                      child: const Text('Apri'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dossier.recentDocuments.isEmpty)
                          const Text('Nessun documento nel dossier.')
                        else
                          ...dossier.recentDocuments.map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.title),
                              subtitle: Text(
                                [
                                  item.documentType.replaceAll('_', ' '),
                                  if (item.examDate != null)
                                    dateFormat.format(item.examDate!),
                                ].join(' • '),
                              ),
                              trailing: Text(
                                item.parsedStatus.replaceAll('_', ' '),
                              ),
                            ),
                          ),
                        if (dossier.recentLabPanels.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Esami del sangue recenti',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...dossier.recentLabPanels.map(
                            (panel) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      panel.panelName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(panel.documentTitle),
                                    const SizedBox(height: 8),
                                    ...panel.keyResults.map(
                                      (result) => Text('• $result'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (dossier.recentImagingReports.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Imaging recente',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...dossier.recentImagingReports.map(
                            (report) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                report.examType ?? report.documentTitle,
                              ),
                              subtitle: Text(
                                [
                                  if ((report.bodyPart ?? '').isNotEmpty)
                                    report.bodyPart!,
                                  if ((report.impression ?? '').isNotEmpty)
                                    report.impression!,
                                ].join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              _DossierTabList(
                onRefresh: refreshDossier,
                children: [
                  SectionCard(
                    title: 'Diario recente',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/history'),
                      child: const Text('Storico'),
                    ),
                    child: dossier.recentDailyEntries.isEmpty
                        ? const Text('Nessun check-up recente.')
                        : Column(
                            children: dossier.recentDailyEntries
                                .map(
                                  (entry) => Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateFormat.format(entry.entryDate),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              if (entry.energyLevel != null)
                                                Chip(
                                                  label: Text(
                                                    'Energia ${entry.energyLevel}/10',
                                                  ),
                                                ),
                                              if (entry.moodLevel != null)
                                                Chip(
                                                  label: Text(
                                                    'Umore ${entry.moodLevel}/10',
                                                  ),
                                                ),
                                              if (entry.generalPain != null)
                                                Chip(
                                                  label: Text(
                                                    'Dolore ${entry.generalPain}/10',
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if ((entry.generalNotes ?? '')
                                              .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(entry.generalNotes!),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Insight, report e alert',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dossier.recentInsights.isNotEmpty) ...[
                          Text(
                            'Insight recenti',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...dossier.recentInsights.map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_insightLabel(item.summaryType)),
                              subtitle: Text(
                                item.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (dossier.recentReports.isNotEmpty) ...[
                          Text(
                            'Report recenti',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...dossier.recentReports.map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.title),
                              subtitle: Text(
                                '${dateFormat.format(item.periodStart)} - ${dateFormat.format(item.periodEnd)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (dossier.alerts.isEmpty)
                          const Text('Nessun alert aperto.')
                        else ...[
                          Text(
                            'Alert aperti',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...dossier.alerts.map(
                            (item) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(item.title),
                                subtitle: Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(item.severity),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Dati smartwatch',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/wearables'),
                      child: const Text('Apri'),
                    ),
                    child: dossier.wearableSummaries.isEmpty
                        ? const Text('Nessun dato wearable nel dossier.')
                        : Column(
                            children: dossier.wearableSummaries
                                .take(4)
                                .map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      dateFormat.format(item.summaryDate),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (item.stepsCount != null)
                                          '${item.stepsCount} passi',
                                        if (item.sleepMinutes != null)
                                          '${item.sleepMinutes!.round()} min sonno',
                                        if (item.heartRateAvgBpm != null)
                                          '${item.heartRateAvgBpm!.round()} bpm medi',
                                      ].join(' • '),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
              _DossierTabList(
                onRefresh: refreshDossier,
                children: [
                  SectionCard(
                    title: 'Condivisioni sicure',
                    subtitle:
                        'Link revocabili e temporanei, massimo 30 giorni.',
                    action: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => createShareLink('emergency'),
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Emergenza'),
                        ),
                        TextButton.icon(
                          onPressed: () => createShareLink('full'),
                          icon: const Icon(Icons.folder_shared_outlined),
                          label: const Text('Dossier'),
                        ),
                      ],
                    ),
                    child: shareLinksAsync.when(
                      data: (links) => links.isEmpty
                          ? const Text('Nessun link sicuro attivo.')
                          : Column(
                              children: links
                                  .map(
                                    (link) => Card.outlined(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                          [
                                            link.label ?? link.scope,
                                            if (!link.isActive) 'Scaduto',
                                          ].join(' • '),
                                        ),
                                        subtitle: Text(
                                          [
                                            link.filename,
                                            link.mimeType,
                                            'Scade ${dateTimeFormat.format(link.expiresAt.toLocal())}',
                                            if (link.lastAccessedAt != null)
                                              'Ultimo accesso ${dateTimeFormat.format(link.lastAccessedAt!.toLocal())}',
                                          ].join(' • '),
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              tooltip: 'Copia link',
                                              onPressed: link.shareUrl == null
                                                  ? null
                                                  : () async {
                                                      await Clipboard.setData(
                                                        ClipboardData(
                                                          text: link.shareUrl!,
                                                        ),
                                                      );
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Link copiato.',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              icon: const Icon(
                                                Icons.copy_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Revoca',
                                              onPressed: link.isActive
                                                  ? () => revokeShareLink(link)
                                                  : null,
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (error, _) => Text(error.toString()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}

class _DossierTabList extends StatelessWidget {
  const _DossierTabList({required this.children, required this.onRefresh});

  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}

class _SimpleListSection extends StatelessWidget {
  const _SimpleListSection({
    required this.title,
    required this.items,
    required this.emptyLabel,
    this.action,
  });

  final String title;
  final List<String> items;
  final String emptyLabel;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      action: action,
      child: items.isEmpty
          ? Text(emptyLabel)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => _CompactBulletCard(text: item))
                  .toList(),
            ),
    );
  }
}

class _DossierHeaderAvatar extends StatelessWidget {
  const _DossierHeaderAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    final initials = parts.isEmpty
        ? 'CD'
        : parts.map((part) => part.substring(0, 1).toUpperCase()).join();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DossierMetricPill extends StatelessWidget {
  const _DossierMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CompactBulletCard extends StatelessWidget {
  const _CompactBulletCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _DossierDeviceMeasurementCard extends StatelessWidget {
  const _DossierDeviceMeasurementCard({
    required this.item,
    required this.dateFormat,
  });

  final DossierDeviceMeasurementSummary item;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final concernColor = switch (item.concernLevel) {
      'high' => Theme.of(context).colorScheme.error,
      'attention' => Colors.orange.shade700,
      _ => null,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.metricLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  item.providerName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('Ultima ${item.latestValue}'),
                  visualDensity: VisualDensity.compact,
                ),
                if ((item.trendLabel ?? '').isNotEmpty)
                  Chip(
                    label: Text(item.trendLabel!),
                    visualDensity: VisualDensity.compact,
                  ),
                if ((item.concernLevel ?? '').isNotEmpty)
                  Chip(
                    label: Text(
                      item.concernLevel == 'high'
                          ? 'Attenzione alta'
                          : 'Da monitorare',
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: concernColor?.withValues(alpha: 0.12),
                    labelStyle: TextStyle(color: concernColor),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.summary, style: Theme.of(context).textTheme.bodyMedium),
            if ((item.concernNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.concernNote!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      concernColor ??
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Ultima misura ${dateFormat.format(item.latestMeasuredAt.toLocal())} • ${item.measurementCount} registrazioni',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _sexLabel(String value) {
  switch (value) {
    case 'female':
      return 'Femmina';
    case 'male':
      return 'Maschio';
    case 'intersex':
      return 'Intersex';
    default:
      return 'Non specificato';
  }
}

String _insightLabel(String type) {
  switch (type) {
    case 'daily':
      return 'Report giornaliero';
    case 'weekly':
      return 'Report settimanale';
    case 'monthly':
      return 'Report mensile';
    default:
      return 'Report pre-visita';
  }
}

Future<void> _writeEmergencyLinkToTag(NfcTag tag, String url) async {
  final message = _buildEmergencyLinkMessage(url);
  final ndef = NdefAndroid.from(tag);
  if (ndef != null) {
    if (!ndef.isWritable) {
      throw StateError('Questo tag NFC non e scrivibile.');
    }
    if (ndef.maxSize < message.byteLength) {
      throw StateError(
        'Questo tag NFC e troppo piccolo per la scheda emergenza.',
      );
    }
    await ndef.writeNdefMessage(message);
    return;
  }

  final formatable = NdefFormatableAndroid.from(tag);
  if (formatable != null) {
    await formatable.format(message);
    return;
  }

  throw StateError('Questo tag NFC non supporta NDEF.');
}

NdefMessage _buildEmergencyLinkMessage(String url) {
  return NdefMessage(
    records: [
      NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x55]),
        identifier: Uint8List(0),
        payload: Uint8List.fromList([0x00, ...utf8.encode(url)]),
      ),
    ],
  );
}
