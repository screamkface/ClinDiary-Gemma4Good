import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/l10n/app_localizations.dart';
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
  bool _showTechnicalDetails = false;
  bool _wasParsingInBackground = false;

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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _updateContextStatus(String nextStatus) async {
    final l10n = AppLocalizations.of(context);
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
          ? l10n.documentsDocumentMarkedAsOldItWill
          : l10n.documentsDocumentReactivatedForAiRecaps;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _updatingContextStatus = false);
      }
    }
  }

  Future<void> _deleteDocument() async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.documentsDeleteDocument),
        content: Text(l10n.documentsDeleteDocumentBody),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: Text(l10n.documentsCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: Text(l10n.documentsDelete),
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
      ).showSnackBar(SnackBar(content: Text(l10n.documentsDocumentDeleted)));
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _openViewer(ClinicalDocumentDetail detail) async {
    final l10n = AppLocalizations.of(context);
    if (detail.isLocal) {
      final localPath = await ref
          .read(documentsRepositoryProvider)
          .prepareLocalViewerFile(detail.id);
      final uri = Uri.file(localPath);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await SharePlus.instance.share(
          ShareParams(
            text: l10n.documentsClindiaryDocument,
            files: [XFile(localPath)],
          ),
        );
      }
      return;
    }
    if (detail.viewerUrl == null || detail.viewerUrl!.isEmpty) {
      return;
    }
    if (!detail.viewerUrl!.startsWith('http')) {
      return;
    }
    final uri = Uri.parse(detail.viewerUrl!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.documentsUnableToOpenTheDocument)),
      );
    }
  }

  void _openGemmaCenter(ClinicalDocumentDetail detail) {
    final uri = Uri(
      path: '/app/ai',
      queryParameters: {
        'documentId': detail.id,
        'question': AppLocalizations.of(
          context,
        ).documentsExplainThisDocumentInSimpleTerms,
      },
    );
    context.push(uri.toString());
  }

  Future<void> _moveDocument(ClinicalDocumentDetail detail) async {
    final l10n = AppLocalizations.of(context);
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
                      l10n.documentsMoveFile,
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
                      title: l10n.documentsMainArchive,
                      subtitle: l10n.documentsOutsideAnyFolder,
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
                        child: Text(l10n.documentsMove),
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
        (selected == null &&
            (detail.folderId == null || detail.folderId!.isEmpty))) {
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
      ).showSnackBar(SnackBar(content: Text(l10n.documentsDocumentMoved)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _moving = false);
      }
    }
  }

  String _nextStepHint(AppLocalizations l10n, ClinicalDocumentDetail detail) {
    if (detail.parsedStatus == 'processing') {
      return l10n.documentsProcessingIsRunningRefreshInA;
    }
    if (detail.parsedStatus == 'review_required') {
      return l10n.documentsOpenManualReviewToAddOrConfirmKeyValues;
    }
    if (detail.parsedStatus == 'parsed') {
      return l10n.documentsAskForAQuickExplanationOr;
    }
    if (detail.isLocal && (detail.ocrText == null || detail.ocrText!.isEmpty)) {
      return l10n.documentsAddAFewDetailsSoAnswers;
    }
    return l10n.documentsOpenTheFileAndConfirmDetailsIfNeeded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(documentDetailProvider(widget.documentId));
    final parseProgressAsync = ref.watch(localDocumentParseProgressProvider);
    final parseSnapshot =
        parseProgressAsync.asData?.value ??
        const LocalDocumentParseProgressSnapshot.empty();
    final parseProgress = parseSnapshot.progressFor(widget.documentId);
    final isParsingInBackground = parseProgress != null;

    if (_wasParsingInBackground && !isParsingInBackground) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(documentDetailProvider(widget.documentId));
        ref.invalidate(documentsProvider);
        ref.invalidate(documentArchiveProvider);
      });
    }
    _wasParsingInBackground = isParsingInBackground;

    final detail = detailAsync.valueOrNull;
    final hasCloudStorageAccess = !ref.read(appConfigProvider).localOnlyMode;
    final dateFormat = DateFormat(l10n.documentsDdMmmYyyyHhMm, l10n.localeName);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.documentsDocumentDetails),
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
                PopupMenuItem(
                  value: _DocumentMenuAction.move,
                  child: Row(
                    children: [
                      const Icon(Icons.drive_file_move_outline),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          l10n.documentsMoveFile,
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
                                ? l10n.documentsReactivateForAi
                                : l10n.documentsMarkAsOld,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: _DocumentMenuAction.delete,
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          l10n.documentsDeleteDocument,
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
                subtitle: l10n.documentsOpenItMoveItOrAskForAQuickExplanation,
                action: FilledButton.tonalIcon(
                  onPressed:
                      (detail.isLocal ||
                          (detail.viewerUrl != null &&
                              detail.viewerUrl!.isNotEmpty))
                      ? () => _openViewer(detail)
                      : null,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.documentsOpenFile),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(documentTypeLabel(detail.documentType)),
                        ),
                        if (detail.folderName != null &&
                            detail.folderName!.isNotEmpty)
                          Chip(label: Text(detail.folderName!)),
                        Chip(
                          label: Text(documentStatusLabel(detail.parsedStatus)),
                        ),
                        if (isParsingInBackground)
                          Chip(
                            label: Text(
                              l10n.documentsParsingPercent(
                                (parseProgress.progress * 100).round(),
                              ),
                            ),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.7),
                          ),
                      ],
                    ),
                    if (isParsingInBackground)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(
                          value: parseProgress.progress,
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _showTechnicalDetails = !_showTechnicalDetails,
                      ),
                      icon: Icon(
                        _showTechnicalDetails
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      label: Text(
                        _showTechnicalDetails
                            ? l10n.documentsHideTechnicalDetails
                            : l10n.documentsShowTechnicalDetails,
                      ),
                    ),
                    if (_showTechnicalDetails)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
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
                                l10n.documentsClassificationPercent(
                                  (detail.classificationConfidence! * 100)
                                      .round(),
                                ),
                              ),
                            ),
                          if (detail.parsingConfidence != null)
                            Chip(
                              label: Text(
                                l10n.documentsParsingPercent(
                                  (detail.parsingConfidence! * 100).round(),
                                ),
                              ),
                            ),
                          if (detail.pendingSync)
                            Chip(
                              label: Text(l10n.documentsSyncPending),
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
                          l10n.documentsThisDocumentHasChangesWaitingTo,
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
                          label: l10n.documentsAdded,
                          value: dateFormat.format(detail.uploadDate.toLocal()),
                        ),
                        _InfoTile(
                          label: l10n.documentsExam,
                          value: detail.examDate == null
                              ? l10n.documentsNotAdded
                              : DateFormat(
                                  l10n.documentsDdMmmYyyy,
                                  l10n.localeName,
                                ).format(detail.examDate!),
                        ),
                        if (detail.source?.trim().isNotEmpty == true)
                          _InfoTile(
                            label: l10n.documentsFrom,
                            value: detail.source!,
                          ),
                        _InfoTile(
                          label: l10n.documentsSize,
                          value: formatFileSize(detail.fileSizeBytes),
                        ),
                      ],
                    ),
                    if (detail.isOld && detail.isCloud)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.documentsThisDocumentIsMarkedAsOldAnd,
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
                    const SizedBox(height: 12),
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
                          Text(
                            l10n.documentsNextStep,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(_nextStepHint(l10n, detail)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canAskGemmaAboutDocument)
                      FilledButton.tonalIcon(
                        onPressed: () => _openGemmaCenter(detail),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(l10n.documentsAskAboutThisFile),
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
                            label: Text(
                              _processing
                                  ? l10n.documentsProcessing
                                  : l10n.documentsProcess,
                            ),
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
                            label: Text(l10n.documentsManualReview),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                Text(
                                  l10n.documentsReadyToUse,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.documentsYouCanOpenItReviewItOrAskForASimpleExplanation,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: !detail.canOpenManualReview
                                ? null
                                : () => context.push(
                                    '/app/documents/${widget.documentId}/review',
                                  ),
                            icon: const Icon(Icons.edit_note_outlined),
                            label: Text(l10n.documentsManualReview),
                          ),
                        ],
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
                              Text(
                                l10n.documentsViewOnly,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.documentsYouCanReadThisFileButEditingIsDisabled,
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
                  title: l10n.documentsExtractedText,
                  subtitle: _showExtractedText
                      ? l10n.documentsOcrTextForTheDocument
                      : l10n.documentsAvailableOnDemand,
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
                      _showExtractedText
                          ? l10n.documentsHideText
                          : l10n.documentsShowText,
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
                      : Text(
                          l10n.documentsTheExtractedTextStaysHiddenUntilView,
                        ),
                ),
              if (detail.labPanels.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: l10n.documentsLabResults,
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
                  title: l10n.documentsImagingReport,
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
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.documentsUnableToLoadThisDocument,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      ref.invalidate(documentDetailProvider(widget.documentId)),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.documentsTryAgain),
                ),
              ],
            ),
          ),
        ),
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
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.35)
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
    final l10n = AppLocalizations.of(context);
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
        ...panel.results.map((result) {
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
                  _referenceLabel(l10n, result),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Chip(
              label: Text(
                isAbnormal ? l10n.documentsOutOfRange : l10n.documentsOk,
              ),
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
        }),
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

  String _referenceLabel(AppLocalizations l10n, LabResultItem result) {
    if (result.refMin != null && result.refMax != null) {
      final unit = result.unit?.trim();
      return unit == null || unit.isEmpty
          ? l10n.documentsRangeWithoutUnit(result.refMin!, result.refMax!)
          : l10n.documentsRangeWithUnit(result.refMin!, result.refMax!, unit);
    }
    return l10n.documentsRangeUnavailable;
  }
}

class _ImagingReportView extends StatelessWidget {
  const _ImagingReportView({required this.report});

  final ImagingReportItem report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        if (report.bodyPart != null)
          Text(l10n.documentsBodyArea(report.bodyPart!)),
        const SizedBox(height: 8),
        if (report.impression != null && report.impression!.isNotEmpty)
          Text(
            l10n.documentsConclusion(report.impression!),
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
