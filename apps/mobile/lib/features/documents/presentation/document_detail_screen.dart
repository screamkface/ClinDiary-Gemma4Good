import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum _DocumentMenuAction { move, toggleOld, delete }

class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({required this.documentId, super.key});

  final String documentId;

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  bool _processing = false;
  bool _updatingContextStatus = false;
  bool _deleting = false;
  bool _moving = false;
  bool _showExtractedText = false;

  Future<void> _processDocument() async {
    setState(() => _processing = true);
    try {
      await ref
          .read(documentsRepositoryProvider)
          .processDocument(widget.documentId);
      ref.invalidate(documentsProvider);
      ref.invalidate(documentArchiveProvider);
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(timelineEventsProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _updateContextStatus(String nextStatus) async {
    setState(() => _updatingContextStatus = true);
    try {
      await ref
          .read(documentsRepositoryProvider)
          .updateDocumentContextStatus(
            widget.documentId,
            contextStatus: nextStatus,
          );
      ref.invalidate(documentsProvider);
      ref.invalidate(documentArchiveProvider);
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(notificationsProvider);
      if (!mounted) return;
      final message = nextStatus == 'old'
          ? 'Documento segnato come vecchio. Non verra usato nei recap AI.'
          : 'Documento riattivato per i recap AI.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _updatingContextStatus = false);
      }
    }
  }

  Future<void> _deleteDocument() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina documento'),
        content: const Text(
          'Il documento verra eliminato definitivamente. Vuoi continuare?',
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
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

    setState(() => _deleting = true);
    try {
      await ref
          .read(documentsRepositoryProvider)
          .deleteDocument(widget.documentId);
      ref.invalidate(documentsProvider);
      ref.invalidate(documentArchiveProvider);
      ref.invalidate(documentFoldersProvider);
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(timelineEventsProvider);
      ref.invalidate(notificationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documento eliminato.')));
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _openViewer(ClinicalDocumentDetail detail) async {
    if (detail.isLocal) {
      final localPath = await ref
          .read(documentsRepositoryProvider)
          .prepareLocalViewerFile(detail.id);
      final uri = Uri.file(localPath);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Documento ClinDiary',
            files: [XFile(localPath)],
          ),
        );
      }
      return;
    }
    if (detail.viewerUrl == null || detail.viewerUrl!.isEmpty) {
      return;
    }
    final config = ref.read(appConfigProvider);
    final uri = detail.viewerUrl!.startsWith('http')
        ? Uri.parse(detail.viewerUrl!)
        : Uri.parse('${config.apiBaseUrl}${detail.viewerUrl!}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il documento.')),
      );
    }
  }

  void _openBillingForCloudArchive() {
    context.push('/app/home/billing?feature=cloud_document_storage');
  }

  void _openGemmaCenter(ClinicalDocumentDetail detail) {
    final uri = Uri(
      path: '/app/ai',
      queryParameters: {
        'documentId': detail.id,
        'question': 'Spiega questo documento in parole semplici.',
      },
    );
    context.push(uri.toString());
  }

  Future<void> _moveDocument(ClinicalDocumentDetail detail) async {
    final folders = await ref.read(documentFoldersProvider.future);
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var nextFolderId = detail.folderId ?? '';
        final sheetHeight = (MediaQuery.sizeOf(sheetContext).height * 0.6)
            .clamp(280.0, 420.0);
        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: SizedBox(
              height: sheetHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sposta file',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail.title,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _FolderChoiceTile(
                      title: 'Archivio principale',
                      subtitle: 'Fuori da qualsiasi cartella',
                      selected: nextFolderId.isEmpty,
                      onTap: () => setModalState(() => nextFolderId = ''),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          ...folders.map((folder) {
                            return _FolderChoiceTile(
                              title: folder.name,
                              subtitle: folder.pathLabel,
                              selected: nextFolderId == folder.id,
                              onTap: () =>
                                  setModalState(() => nextFolderId = folder.id),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          sheetContext,
                        ).pop(nextFolderId.isEmpty ? null : nextFolderId),
                        child: const Text('Sposta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (selected == detail.folderId ||
        (selected == null && (detail.folderId == null || detail.folderId!.isEmpty))) {
      return;
    }

    setState(() => _moving = true);
    try {
      await ref
          .read(documentsRepositoryProvider)
          .moveDocument(widget.documentId, folderId: selected);
      ref.invalidate(documentsProvider);
      ref.invalidate(documentArchiveProvider);
      ref.invalidate(documentFoldersProvider);
      ref.invalidate(documentDetailProvider(widget.documentId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documento spostato.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _moving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(documentDetailProvider(widget.documentId));
    final detail = detailAsync.valueOrNull;
    final billingStatusAsync = ref.watch(billingStatusProvider);
    final hasCloudStorageAccess =
        billingStatusAsync.asData?.value?.hasFeature('cloud_document_storage') ??
        false;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio documento'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(documentDetailProvider(widget.documentId)),
            icon: const Icon(Icons.refresh),
          ),
          if (detail != null &&
              (detail.isLocal || (detail.isCloud && hasCloudStorageAccess)))
            PopupMenuButton<_DocumentMenuAction>(
              enabled:
                  !_processing &&
                  !_moving &&
                  !_updatingContextStatus &&
                  !_deleting &&
                  !detail.pendingSync,
              onSelected: (action) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  switch (action) {
                    case _DocumentMenuAction.move:
                      _moveDocument(detail);
                      break;
                    case _DocumentMenuAction.toggleOld:
                      _updateContextStatus(detail.isOld ? 'active' : 'old');
                      break;
                    case _DocumentMenuAction.delete:
                      _deleteDocument();
                      break;
                  }
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _DocumentMenuAction.move,
                  child: Row(
                    children: [
                      Icon(Icons.drive_file_move_outline),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Sposta file',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (detail.isCloud)
                  PopupMenuItem(
                    value: _DocumentMenuAction.toggleOld,
                    child: Row(
                      children: [
                        Icon(
                          detail.isOld
                              ? Icons.unarchive_outlined
                              : Icons.history_toggle_off_outlined,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            detail.isOld
                                ? 'Riattiva per AI'
                                : 'Segna come vecchio',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: _DocumentMenuAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Elimina documento',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          final canManageCloudDocument =
              detail.isCloud && hasCloudStorageAccess;
          final isReadOnlyCloudDocument =
              detail.isCloud && !hasCloudStorageAccess;
          final canAskGemmaAboutDocument =
            detail.ocrText != null && detail.ocrText!.trim().isNotEmpty ||
            detail.labPanels.isNotEmpty ||
            detail.imagingReports.isNotEmpty;

          return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: detail.title,
              subtitle: detail.isLocal
                  ? 'Metadati del file salvato sul dispositivo.'
                  : 'Metadati, stato e contenuti estratti.',
              action: FilledButton.tonalIcon(
                onPressed: (detail.isLocal ||
                        (detail.viewerUrl != null && detail.viewerUrl!.isNotEmpty))
                    ? () => _openViewer(detail)
                    : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Apri file'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(documentTypeLabel(detail.documentType))),
                      Chip(
                        label: Text(documentStorageLabel(detail.storageLocation)),
                      ),
                      if (detail.folderName != null && detail.folderName!.isNotEmpty)
                        Chip(label: Text('Cartella: ${detail.folderName}')),
                      Chip(
                        label: Text(documentStatusLabel(detail.parsedStatus)),
                      ),
                      Chip(
                        label: Text(
                          documentContextStatusLabel(detail.contextStatus),
                        ),
                        backgroundColor: documentContextStatusColor(
                          context,
                          detail.contextStatus,
                        ).withValues(alpha: 0.12),
                      ),
                      if (detail.classificationConfidence != null)
                        Chip(
                          label: Text(
                            'Classificazione ${(detail.classificationConfidence! * 100).round()}%',
                          ),
                        ),
                      if (detail.parsingConfidence != null)
                        Chip(
                          label: Text(
                            'Parsing ${(detail.parsingConfidence! * 100).round()}%',
                          ),
                        ),
                      if (detail.pendingSync)
                        Chip(
                          label: const Text('Sync in attesa'),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                        ),
                    ],
                  ),
                  if (detail.pendingSync)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Questo documento ha modifiche in attesa di sincronizzazione.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoTile(
                        label: 'Upload',
                        value: dateFormat.format(detail.uploadDate.toLocal()),
                      ),
                      _InfoTile(
                        label: 'Esame',
                        value: detail.examDate == null
                            ? 'n/d'
                            : detail.examDate!.toIso8601String().split('T').first,
                      ),
                      _InfoTile(
                        label: 'Sorgente',
                        value: detail.source ?? 'n/d',
                      ),
                      _InfoTile(
                        label: 'File',
                        value: detail.originalFilename,
                      ),
                      _InfoTile(
                        label: 'Dimensione',
                        value: formatFileSize(detail.fileSizeBytes),
                      ),
                    ],
                  ),
                  if (detail.isOld && detail.isCloud)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Questo documento e segnato come vecchio e non viene incluso nei recap AI.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  if (detail.processingError != null &&
                      detail.processingError!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        detail.processingError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (canAskGemmaAboutDocument)
                    FilledButton.tonalIcon(
                      onPressed: () => _openGemmaCenter(detail),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Spiega con Gemma'),
                    ),
                  if (canAskGemmaAboutDocument) const SizedBox(height: 12),
                  if (detail.isCloud)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              !canManageCloudDocument ||
                                  _processing ||
                                  !detail.canRetryProcessing
                              ? null
                              : _processDocument,
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: Text(_processing ? 'Processing...' : 'Processa'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              !canManageCloudDocument ||
                                  !detail.canOpenManualReview
                              ? null
                              : () => context.push(
                                  '/app/documents/${widget.documentId}/review',
                                ),
                          icon: const Icon(Icons.edit_note_outlined),
                          label: const Text('Revisione manuale'),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Questo documento e salvato solo sul dispositivo.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'OCR, parsing automatico, backup cloud e domande ai documenti sono disponibili con AI Plus.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: _openBillingForCloudArchive,
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: const Text('Sblocca archivio cloud'),
                          ),
                        ],
                      ),
                    ),
                  if (isReadOnlyCloudDocument)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Documento cloud in sola lettura',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Il file resta consultabile anche sul piano free, ma spostamento, processing e modifiche richiedono AI Plus.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _openBillingForCloudArchive,
                              icon: const Icon(Icons.workspace_premium_outlined),
                              label: const Text('Riattiva AI Plus'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (detail.ocrText != null && detail.ocrText!.trim().isNotEmpty)
              SectionCard(
                title: 'Testo estratto',
                subtitle: _showExtractedText
                    ? 'Testo OCR del documento.'
                    : 'Disponibile su richiesta.',
                action: TextButton.icon(
                  onPressed: () => setState(
                    () => _showExtractedText = !_showExtractedText,
                  ),
                  icon: Icon(
                    _showExtractedText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(
                    _showExtractedText ? 'Nascondi testo' : 'Mostra testo',
                  ),
                ),
                child: _showExtractedText
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SelectableText(detail.ocrText!),
                      )
                    : const Text(
                        'Il testo estratto è pronto ma resta nascosto finché non scegli di visualizzarlo.',
                      ),
              ),
            if (detail.labPanels.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: 'Risultati laboratorio',
                child: Column(
                  children: detail.labPanels
                      .map(
                        (panel) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _LabPanelView(panel: panel),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (detail.imagingReports.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: 'Referto imaging',
                child: Column(
                  children: detail.imagingReports
                      .map(
                        (report) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ImagingReportView(report: report),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _FolderChoiceTile extends StatelessWidget {
  const _FolderChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }
}

class _LabPanelView extends StatelessWidget {
  const _LabPanelView({required this.panel});

  final LabPanelItem panel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          panel.panelName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...panel.results.map(
          (result) {
            final isAbnormal = result.abnormalFlag == true;
            final statusColor = isAbnormal
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                result.analyteName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _valueLabel(result),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _referenceLabel(result),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Chip(
                label: Text(isAbnormal ? 'Fuori range' : 'OK'),
                visualDensity: VisualDensity.compact,
                backgroundColor: isAbnormal
                    ? Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.7)
                    : Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                labelStyle: TextStyle(color: statusColor),
              ),
            );
          },
        ),
      ],
    );
  }

  String _valueLabel(LabResultItem result) {
    final unit = result.unit?.trim();
    if (unit == null || unit.isEmpty) {
      return result.value;
    }
    return '${result.value} $unit';
  }

  String _referenceLabel(LabResultItem result) {
    if (result.refMin != null && result.refMax != null) {
      final unit = result.unit?.trim();
      return unit == null || unit.isEmpty
          ? 'Range ${result.refMin}-${result.refMax}'
          : 'Range ${result.refMin}-${result.refMax} $unit';
    }
    return 'Range non disponibile';
  }
}

class _ImagingReportView extends StatelessWidget {
  const _ImagingReportView({required this.report});

  final ImagingReportItem report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.examType != null)
          Text(
            report.examType!,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        if (report.bodyPart != null) Text('Distretto: ${report.bodyPart}'),
        const SizedBox(height: 8),
        if (report.impression != null && report.impression!.isNotEmpty)
          Text(
            'Conclusione: ${report.impression!}',
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        Text(report.reportText, maxLines: 8, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
