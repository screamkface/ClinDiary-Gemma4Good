import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  String? _currentFolderId;
  String? _appliedQuery;
  int _lastParseActiveCount = 0;
  _DocumentArchiveFilter _documentFilter = _DocumentArchiveFilter.all;

  DocumentArchiveQuery get _archiveQuery => DocumentArchiveQuery(
    folderId: _currentFolderId,
    searchQuery: _appliedQuery,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoParsingIfNeeded();
    });
  }

  Future<void> _triggerAutoParsingIfNeeded() async {
    if (!mounted) return;

    try {
      final archive = await ref.read(
        documentArchiveProvider(_archiveQuery).future,
      );

      // Find all documents that need parsing
      final documentsNeedingParse = archive.documents.where((doc) {
        final parseProgress = ref
            .read(localDocumentParseProgressProvider)
            .asData
            ?.value
            .progressFor(doc.id);
        return (doc.parsedStatus == 'processing' ||
                doc.parsedStatus == 'local_only') &&
            parseProgress == null;
      }).toList();

      // Trigger parsing for each document that needs it
      for (final document in documentsNeedingParse) {
        if (!mounted) return;
        unawaited(ref.read(documentDetailProvider(document.id).future));
      }
    } catch (_) {
      // Silent fail - auto-parsing is best-effort
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    ref.invalidate(documentsProvider);
    ref.invalidate(documentArchiveProvider);
    ref.invalidate(documentFoldersProvider);
  }

  void _openFolder(String? folderId) {
    setState(() {
      _currentFolderId = folderId;
      _appliedQuery = null;
      _searchController.clear();
    });
  }

  void _applySearch() {
    final value = _searchController.text.trim();
    setState(() => _appliedQuery = value.isEmpty ? null : value);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _appliedQuery = null;
    });
  }

  void _setDocumentFilter(_DocumentArchiveFilter filter) {
    setState(() => _documentFilter = filter);
  }

  Future<void> _createFolder() async {
    var folderName = '';
    final createdName = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New folder'),
        content: TextFormField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'E.g. Blood tests',
          ),
          textInputAction: TextInputAction.done,
          onChanged: (value) => folderName = value,
          onFieldSubmitted: (_) => Navigator.of(
            dialogContext,
            rootNavigator: true,
          ).pop(folderName.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(folderName.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (!mounted || createdName == null || createdName.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(documentsRepositoryProvider)
          .createFolder(name: createdName, parentFolderId: _currentFolderId);
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Folder "$createdName" created.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _moveDocument(ClinicalDocumentSummary document) async {
    final folders = await ref.read(documentFoldersProvider.future);
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var nextFolderId = document.folderId ?? '';
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
                      'Move file',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document.title,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _FolderChoiceTile(
                      title: 'Main archive',
                      subtitle: 'Outside any folder',
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
                        child: const Text('Move'),
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
    if (selected == document.folderId ||
        (selected == null &&
            (document.folderId == null || document.folderId!.isEmpty))) {
      return;
    }

    try {
      await ref
          .read(documentsRepositoryProvider)
          .moveDocument(document.id, folderId: selected);
      await _refreshAll();
      ref.invalidate(documentDetailProvider(document.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document moved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _openUpload(
    DocumentArchiveView archive, {
    bool captureFromCamera = false,
  }) {
    final uri = Uri(
      path: '/app/documents/upload',
      queryParameters: {
        if (archive.currentFolder != null)
          'folderId': archive.currentFolder!.id,
        if (archive.currentFolder != null)
          'folderName': archive.currentFolder!.pathLabel,
        if (captureFromCamera) 'capture': 'camera',
      },
    );
    context.push(uri.toString());
  }

  void _openDocumentQuery(DocumentArchiveView archive) {
    final uri = Uri(
      path: '/app/documents/ask',
      queryParameters: {
        if (archive.currentFolder != null)
          'folderId': archive.currentFolder!.id,
        if (archive.currentFolder != null)
          'folderName': archive.currentFolder!.pathLabel,
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final archiveAsync = ref.watch(documentArchiveProvider(_archiveQuery));
    final pendingOperationsAsync = ref.watch(pendingOperationsProvider);
    final parseProgressAsync = ref.watch(localDocumentParseProgressProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            onPressed: () => _refreshAll(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: null,
      body: archiveAsync.when(
        data: (archive) {
          final pendingSyncCount =
              pendingOperationsAsync.asData?.value.length ?? 0;
          final parseSnapshot =
              parseProgressAsync.asData?.value ??
              const LocalDocumentParseProgressSnapshot.empty();

          if (_lastParseActiveCount > 0 && parseSnapshot.activeCount == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.invalidate(documentsProvider);
              ref.invalidate(documentArchiveProvider);
            });
          }
          _lastParseActiveCount = parseSnapshot.activeCount;

          final isDark = Theme.of(context).brightness == Brightness.dark;
          const storageAccent = Colors.teal;
          final storageButtonBackground = isDark
              ? storageAccent.shade500
              : storageAccent.shade700;
          final cameraButtonBackground = isDark
              ? Colors.orange.shade500
              : Colors.orange.shade700;
          final folderButtonForeground = isDark
              ? Colors.indigo.shade200
              : Colors.indigo.shade700;
          final folderButtonBorder = isDark
              ? Colors.indigo.shade400.withValues(alpha: 0.65)
              : Colors.indigo.shade200;
          final folderAvatarBackground = isDark
              ? Colors.indigo.shade900.withValues(alpha: 0.36)
              : Colors.indigo.shade50;
          final folderAvatarForeground = isDark
              ? Colors.indigo.shade100
              : Colors.indigo.shade700;
          final filteredDocuments = archive.documents.where((document) {
            final parseProgress = parseSnapshot.progressFor(document.id);
            switch (_documentFilter) {
              case _DocumentArchiveFilter.all:
                return true;
              case _DocumentArchiveFilter.needsReview:
                return document.parsedStatus == 'review_required' ||
                    (document.processingError != null &&
                        document.processingError!.isNotEmpty);
              case _DocumentArchiveFilter.parsing:
                return parseProgress != null ||
                    document.parsedStatus == 'processing';
              case _DocumentArchiveFilter.ready:
                return document.parsedStatus == 'parsed' &&
                    parseProgress == null &&
                    !document.pendingSync;
            }
          }).toList();

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: archive.currentFolder?.name ?? 'Archive',
                  subtitle: archive.isSearch
                      ? 'Search your files.'
                      : 'Everything important in one place.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _applySearch(),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: 'Search files',
                          hintText: 'Title, folder, source, file name...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _appliedQuery == null
                              ? IconButton(
                                  onPressed: _applySearch,
                                  icon: const Icon(Icons.arrow_forward),
                                )
                              : IconButton(
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _openUpload(archive),
                            style: FilledButton.styleFrom(
                              backgroundColor: storageButtonBackground,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.save_alt_outlined),
                            label: Text(
                              archive.currentFolder == null
                                  ? 'Upload file'
                                  : 'Save here',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _openUpload(archive, captureFromCamera: true),
                            style: FilledButton.styleFrom(
                              backgroundColor: cameraButtonBackground,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Take photo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _createFolder,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: folderButtonForeground,
                              side: BorderSide(color: folderButtonBorder),
                            ),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('New folder'),
                          ),
                          _GlowingAskFilesButton(
                            onPressed: () => _openDocumentQuery(archive),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected:
                                _documentFilter == _DocumentArchiveFilter.all,
                            onSelected: (_) =>
                                _setDocumentFilter(_DocumentArchiveFilter.all),
                          ),
                          ChoiceChip(
                            label: const Text('Needs review'),
                            selected:
                                _documentFilter ==
                                _DocumentArchiveFilter.needsReview,
                            onSelected: (_) => _setDocumentFilter(
                              _DocumentArchiveFilter.needsReview,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Parsing'),
                            selected:
                                _documentFilter ==
                                _DocumentArchiveFilter.parsing,
                            onSelected: (_) => _setDocumentFilter(
                              _DocumentArchiveFilter.parsing,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Ready'),
                            selected:
                                _documentFilter == _DocumentArchiveFilter.ready,
                            onSelected: (_) => _setDocumentFilter(
                              _DocumentArchiveFilter.ready,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (pendingSyncCount > 0)
                            Chip(
                              avatar: const Icon(
                                Icons.sync_problem_outlined,
                                size: 18,
                              ),
                              label: Text('Waiting: $pendingSyncCount'),
                            ),
                          if (parseSnapshot.activeCount > 0)
                            Chip(
                              avatar: const Icon(
                                Icons.auto_fix_high_outlined,
                                size: 18,
                              ),
                              label: Text(
                                'Background parsing: ${parseSnapshot.activeCount}',
                              ),
                            ),
                          Chip(
                            label: Text('${archive.folders.length} folders'),
                          ),
                          Chip(
                            label: Text('${archive.documents.length} files'),
                          ),
                          if (archive.isSearch)
                            const Chip(label: Text('Search active')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ArchiveBreadcrumbs(
                  archive: archive,
                  onOpenRoot: () => _openFolder(null),
                  onOpenFolder: _openFolder,
                  onClearSearch: _clearSearch,
                ),
                if (archive.folders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Folders',
                    subtitle: 'Tap a folder to open it.',
                    child: Column(
                      children: archive.folders
                          .map(
                            (folder) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card.outlined(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  onTap: () => _openFolder(folder.id),
                                  leading: CircleAvatar(
                                    backgroundColor: folderAvatarBackground,
                                    child: Icon(
                                      Icons.folder_outlined,
                                      color: folderAvatarForeground,
                                    ),
                                  ),
                                  title: Text(
                                    folder.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${folder.childFolderCount} subfolders • ${folder.documentCount} files',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (archive.documents.isEmpty && archive.folders.isEmpty)
                  SectionCard(
                    title: archive.isSearch ? 'No results' : 'Empty archive',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          archive.isSearch
                              ? 'Try different words or clear the search.'
                              : 'Start by saving a file or creating a folder.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (archive.isSearch)
                              FilledButton.tonalIcon(
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close),
                                label: const Text('Clear search'),
                              )
                            else ...[
                              FilledButton.icon(
                                onPressed: () => _openUpload(archive),
                                style: FilledButton.styleFrom(
                                  backgroundColor: storageButtonBackground,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.save_alt_outlined),
                                label: const Text('Upload file'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _createFolder,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: folderButtonForeground,
                                  side: BorderSide(color: folderButtonBorder),
                                ),
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                ),
                                label: const Text('New folder'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  )
                else if (filteredDocuments.isNotEmpty)
                  SectionCard(
                    title: archive.isSearch ? 'Found files' : 'Files',
                    subtitle: archive.isSearch ? 'Search results.' : null,
                    child: Column(
                      children: filteredDocuments
                          .map(
                            (document) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DocumentArchiveTile(
                                document: document,
                                parseProgress: parseSnapshot.progressFor(
                                  document.id,
                                ),
                                dateFormat: dateFormat,
                                showFolderName: archive.isSearch,
                                allowMove: true,
                                onOpen: () => context.push(
                                  '/app/documents/${document.id}',
                                ),
                                onMove: () => _moveDocument(document),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                else if (archive.documents.isNotEmpty)
                  SectionCard(
                    title: 'No matching files',
                    subtitle: 'Try another filter or clear the search.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _setDocumentFilter(_DocumentArchiveFilter.all),
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Reset filter'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                          label: const Text('Clear search'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _ArchiveBreadcrumbs extends StatelessWidget {
  const _ArchiveBreadcrumbs({
    required this.archive,
    required this.onOpenRoot,
    required this.onOpenFolder,
    required this.onClearSearch,
  });

  final DocumentArchiveView archive;
  final VoidCallback onOpenRoot;
  final ValueChanged<String?> onOpenFolder;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    if (!archive.isSearch && archive.breadcrumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          onPressed: onOpenRoot,
          avatar: const Icon(Icons.home_outlined, size: 18),
          label: const Text('Archive'),
        ),
        ...archive.breadcrumbs.map(
          (folder) => ActionChip(
            onPressed: () => onOpenFolder(folder.id),
            avatar: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(folder.name),
          ),
        ),
        if (archive.isSearch)
          ActionChip(
            onPressed: onClearSearch,
            avatar: const Icon(Icons.close, size: 18),
            label: const Text('Close search'),
          ),
      ],
    );
  }
}

class _GlowingAskFilesButton extends StatelessWidget {
  const _GlowingAskFilesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const glow = Color(0xFF8E5CF7);
    const accent = Color(0xFF23A6D5);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: isDark ? 0.38 : 0.26),
            blurRadius: 22,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              glow.withValues(alpha: isDark ? 0.22 : 0.12),
              accent.withValues(alpha: isDark ? 0.2 : 0.1),
            ],
          ),
          border: Border.all(color: glow.withValues(alpha: 0.62), width: 1.4),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: glow, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    'Ask files',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isDark ? Colors.white : glow,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentArchiveTile extends StatelessWidget {
  const _DocumentArchiveTile({
    required this.document,
    this.parseProgress,
    required this.dateFormat,
    required this.showFolderName,
    required this.allowMove,
    required this.onOpen,
    required this.onMove,
  });

  final ClinicalDocumentSummary document;
  final LocalDocumentParseProgress? parseProgress;
  final DateFormat dateFormat;
  final bool showFolderName;
  final bool allowMove;
  final VoidCallback onOpen;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final statusColor = documentStatusColor(context, document.parsedStatus);
    final isParsing = parseProgress != null;

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.14),
          child: Icon(
            documentIcon(
              documentType: document.documentType,
              mimeType: document.mimeType,
            ),
            color: statusColor,
          ),
        ),
        title: Text(
          document.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${documentTypeLabel(document.documentType)} • ${dateFormat.format(document.uploadDate.toLocal())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              formatFileSize(document.fileSizeBytes),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showFolderName && document.folderName != null)
              Text(
                'Folder: ${document.folderName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (document.isOld || document.pendingSync || isParsing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (document.isOld)
                      Chip(
                        label: const Text('Old'),
                        backgroundColor: documentContextStatusColor(
                          context,
                          document.contextStatus,
                        ).withValues(alpha: 0.12),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (document.pendingSync)
                      Chip(
                        label: const Text('Sync pending'),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.tertiaryContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (isParsing)
                      Chip(
                        label: Text(
                          'Parsing ${(parseProgress!.progress * 100).round()}%',
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            if (document.processingError != null &&
                document.processingError!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  document.processingError!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (document.pendingSync)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Waiting for sync',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            if (isParsing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(value: parseProgress!.progress),
              ),
          ],
        ),
        trailing: _DocumentTileActions(
          statusLabel: documentStatusLabel(document.parsedStatus),
          statusColor: statusColor,
          allowMove: allowMove,
          onMove: onMove,
        ),
      ),
    );
  }
}

class _DocumentTileActions extends StatelessWidget {
  const _DocumentTileActions({
    required this.statusLabel,
    required this.statusColor,
    required this.allowMove,
    required this.onMove,
  });

  final String statusLabel;
  final Color statusColor;
  final bool allowMove;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(statusLabel),
            backgroundColor: statusColor.withValues(alpha: 0.12),
          ),
          if (allowMove) ...[
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Move file',
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DocumentArchiveFilter { all, needsReview, parsing, ready }

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
