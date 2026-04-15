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
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');
    final dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');

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
            text: 'ClinDiary emergency card',
            subject: 'ClinDiary emergency card',
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
                'NFC is not available on this device. Using the emergency card PDF.',
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
              label: 'NFC emergency card',
              expiresInDays: 7,
            );
        ref.invalidate(dossierShareLinksProvider);

        final shareUrl = createdLink.shareUrl;
        if (shareUrl == null || shareUrl.isEmpty) {
          throw StateError('Emergency link not available.');
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Bring an NFC tag or compatible card close to the device.',
            ),
            action: SnackBarAction(
              label: 'Cancel',
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
              const SnackBar(content: Text('Emergency card written to NFC.')),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Emergency card copied.')));
    }

    Future<void> shareEmergencySummary(
      DossierEmergencySummary summary,
      String displayName,
    ) async {
      await SharePlus.instance.share(
        ShareParams(
          text: summary.toShareText(displayName: displayName),
          subject: 'ClinDiary emergency card',
        ),
      );
    }

    Future<void> createShareLink(String scope) async {
      try {
        final link = await ref
            .read(dossierRepositoryProvider)
            .createShareLink(
              scope: scope,
              label: scope == 'full' ? 'Full dossier' : 'Emergency card',
            );
        if (link.shareUrl != null && link.shareUrl!.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: link.shareUrl!));
          await SharePlus.instance.share(
            ShareParams(
              text: link.shareUrl!,
              subject: scope == 'full'
                  ? 'ClinDiary full dossier'
                  : 'ClinDiary emergency card',
            ),
          );
        }
        ref.invalidate(dossierShareLinksProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Secure link created.')));
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
          title: const Text('Revoke the link?'),
          content: const Text('The link will no longer be usable.'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(false),
              child: const Text('Cancel'),
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
                  child: Text('Import JSON backup'),
                ),
                PopupMenuItem(
                  value: 'copy-emergency',
                  child: Text('Copy emergency card'),
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
              Tab(text: 'Summary'),
              Tab(text: 'Clinical'),
              Tab(text: 'Reports'),
              Tab(text: 'Diary'),
              Tab(text: 'Share'),
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
                    title: 'Profile',
                    subtitle: 'Quick summary of the active dossier.',
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
                                        ? 'Organized personal record'
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
                              label: 'Issues',
                              value:
                                  '${dossier.medicalConditions.length + dossier.clinicalEpisodes.length}',
                            ),
                            _DossierMetricPill(
                              label: 'Medications',
                              value: '${dossier.medications.length}',
                            ),
                            _DossierMetricPill(
                              label: 'Documents',
                              value: '${dossier.recentDocuments.length}',
                            ),
                            _DossierMetricPill(
                              label: 'Alerts',
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
                          const Text('No profile details available.')
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
                    title: 'Emergency card',
                    subtitle: 'Quick version to copy or share.',
                    action: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => copyEmergencySummary(
                            dossier.emergencySummary,
                            dossier.displayName,
                          ),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy'),
                        ),
                        TextButton.icon(
                          onPressed: () => shareEmergencySummary(
                            dossier.emergencySummary,
                            dossier.displayName,
                          ),
                          icon: const Icon(Icons.ios_share_outlined),
                          label: const Text('Share'),
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
                          'Updated ${dateTimeFormat.format(dossier.emergencySummary.generatedAt.toLocal())}',
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
                            'Active issues',
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
                            'Recent report',
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
                            'Active medications',
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
                            'Allergies',
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
                            'Known conditions',
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
                            'Open alerts',
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
                    title: 'Data provenance',
                    subtitle: 'Source and update time of aggregated data.',
                    child: dossier.provenanceFacts.isEmpty
                        ? const Text('No provenance available.')
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
                    title: 'Conditions, allergies, and family history',
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
                    emptyLabel: 'No items recorded.',
                    action: TextButton(
                      onPressed: () => context.go('/app/profile'),
                      child: const Text('Open profile'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Clinical issues',
                    action: TextButton(
                      onPressed: () => context.push('/app/profile/problems'),
                      child: const Text('Open'),
                    ),
                    child: dossier.clinicalEpisodes.isEmpty
                        ? const Text('No clinical issues recorded.')
                        : Column(
                            children: dossier.clinicalEpisodes
                                .map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.title),
                                    subtitle: Text(
                                      [
                                        if (item.pendingSync)
                                          'Waiting for sync',
                                        if (item.status != null) item.status!,
                                        if (item.onsetDate != null)
                                          'Started ${dateFormat.format(item.onsetDate!)}',
                                        if (item.resolvedDate != null)
                                          'Resolved ${dateFormat.format(item.resolvedDate!)}',
                                        if (item.nextReviewDate != null)
                                          'Review ${dateFormat.format(item.nextReviewDate!)}',
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
                    title: 'Current medications',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/medications'),
                      child: const Text('Open'),
                    ),
                    child: dossier.medications.isEmpty
                        ? const Text('No medications recorded.')
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
                                      item.active ? 'Active' : 'Stopped',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Clinical devices',
                    subtitle:
                        'Compact summary of recent measurements from connected providers.',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/devices'),
                      child: const Text('Open'),
                    ),
                    child: dossier.deviceMeasurementSummaries.isEmpty
                        ? const Text(
                            'No clinical device measurements in the dossier.',
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
                    title: 'Vaccination history',
                    action: TextButton(
                      onPressed: () =>
                          context.push('/app/profile/vaccinations'),
                      child: const Text('Manage'),
                    ),
                    child: dossier.vaccinations.isEmpty
                        ? const Text('No vaccines in the dossier.')
                        : Column(
                            children: dossier.vaccinations
                                .map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.vaccineName),
                                    subtitle: Text(
                                      [
                                        if (item.administeredOn != null)
                                          'Administered ${dateFormat.format(item.administeredOn!)}',
                                        if (item.doseNumber != null)
                                          'Dose ${item.doseNumber}',
                                        if (item.nextDueDate != null)
                                          'Booster ${dateFormat.format(item.nextDueDate!)}',
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
                    title: 'Documents and reports',
                    action: TextButton(
                      onPressed: () => context.go('/app/documents'),
                      child: const Text('Open'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dossier.recentDocuments.isEmpty)
                          const Text('No documents in the dossier.')
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
                            'Recent blood tests',
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
                            'Recent imaging',
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
                    title: 'Recent diary',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/history'),
                      child: const Text('History'),
                    ),
                    child: dossier.recentDailyEntries.isEmpty
                        ? const Text('No recent check-up.')
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
                                                    'Energy ${entry.energyLevel}/10',
                                                  ),
                                                ),
                                              if (entry.moodLevel != null)
                                                Chip(
                                                  label: Text(
                                                    'Mood ${entry.moodLevel}/10',
                                                  ),
                                                ),
                                              if (entry.generalPain != null)
                                                Chip(
                                                  label: Text(
                                                    'Pain ${entry.generalPain}/10',
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
                    title: 'Insights, reports, and alerts',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dossier.recentInsights.isNotEmpty) ...[
                          Text(
                            'Recent insights',
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
                            'Recent reports',
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
                          const Text('No open alerts.')
                        else ...[
                          Text(
                            'Open alerts',
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
                    title: 'Smartwatch data',
                    action: TextButton(
                      onPressed: () => context.push('/app/home/wearables'),
                      child: const Text('Open'),
                    ),
                    child: dossier.wearableSummaries.isEmpty
                        ? const Text('No wearable data in the dossier.')
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
                                          '${item.stepsCount} steps',
                                        if (item.sleepMinutes != null)
                                          '${item.sleepMinutes!.round()} sleep min',
                                        if (item.heartRateAvgBpm != null)
                                          '${item.heartRateAvgBpm!.round()} avg bpm',
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
                    title: 'Secure shares',
                    subtitle: 'Revocable temporary links, max 30 days.',
                    action: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => createShareLink('emergency'),
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Emergency'),
                        ),
                        TextButton.icon(
                          onPressed: () => createShareLink('full'),
                          icon: const Icon(Icons.folder_shared_outlined),
                          label: const Text('Record'),
                        ),
                      ],
                    ),
                    child: shareLinksAsync.when(
                      data: (links) => links.isEmpty
                          ? const Text('No active secure links.')
                          : Column(
                              children: links
                                  .map(
                                    (link) => Card.outlined(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                          [
                                            link.label ?? link.scope,
                                            if (!link.isActive) 'Expired',
                                          ].join(' • '),
                                        ),
                                        subtitle: Text(
                                          [
                                            link.filename,
                                            link.mimeType,
                                            'Expires ${dateTimeFormat.format(link.expiresAt.toLocal())}',
                                            if (link.lastAccessedAt != null)
                                              'Last access ${dateTimeFormat.format(link.lastAccessedAt!.toLocal())}',
                                          ].join(' • '),
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              tooltip: 'Copy link',
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
                                                            'Link copied.',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              icon: const Icon(
                                                Icons.copy_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Revoke',
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
      return 'Daily report';
    case 'weekly':
      return 'Weekly report';
    case 'monthly':
      return 'Monthly report';
    default:
      return 'Pre-visit report';
  }
}

Future<void> _writeEmergencyLinkToTag(NfcTag tag, String url) async {
  final message = _buildEmergencyLinkMessage(url);
  final ndef = NdefAndroid.from(tag);
  if (ndef != null) {
    if (!ndef.isWritable) {
      throw StateError('This NFC tag is not writable.');
    }
    if (ndef.maxSize < message.byteLength) {
      throw StateError('This NFC tag is too small for the emergency card.');
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
