import 'package:clindiary/app/core/network/api_client.dart';
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

  DocumentArchiveQuery get _archiveQuery => DocumentArchiveQuery(
    folderId: _currentFolderId,
    searchQuery: _appliedQuery,
  );

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
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
          final storageChipBackground = isDark
              ? storageAccent.shade900.withValues(alpha: 0.36)
              : storageAccent.shade50;
          final storageChipForeground = isDark
              ? storageAccent.shade100
              : storageAccent.shade900;
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
          final askButtonForeground = isDark
              ? Colors.cyan.shade200
              : Colors.cyan.shade700;
          final askButtonBorder = isDark
              ? Colors.cyan.shade400.withValues(alpha: 0.65)
              : Colors.cyan.shade200;
          final localInfoBackground = isDark
              ? Colors.teal.shade900.withValues(alpha: 0.36)
              : Colors.teal.shade50;
          final localInfoForeground = isDark
              ? Colors.teal.shade100
              : Colors.teal.shade900;
          final folderAvatarBackground = isDark
              ? Colors.indigo.shade900.withValues(alpha: 0.36)
              : Colors.indigo.shade50;
          final folderAvatarForeground = isDark
              ? Colors.indigo.shade100
              : Colors.indigo.shade700;

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: archive.currentFolder?.name ?? 'Archive',
                  subtitle: archive.isSearch
                      ? 'Search files saved on this device.'
                      : 'Your encrypted local archive.',
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
                          Chip(
                            backgroundColor: storageChipBackground,
                            avatar: Icon(
                              Icons.phone_android_outlined,
                              color: storageChipForeground,
                            ),
                            label: Text(
                              documentStorageLabel(archive.storageLocation),
                              style: TextStyle(
                                color: storageChipForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                          OutlinedButton.icon(
                            onPressed: () => _openDocumentQuery(archive),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: askButtonForeground,
                              side: BorderSide(color: askButtonBorder),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Ask files'),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: localInfoBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: localInfoForeground,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Files stay encrypted on this device.',
                                  style: TextStyle(color: localInfoForeground),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(
                              pendingSyncCount > 0
                                  ? Icons.sync_problem_outlined
                                  : Icons.cloud_done_outlined,
                              size: 18,
                            ),
                            label: Text(
                              pendingSyncCount > 0
                                  ? 'Sync pending: $pendingSyncCount'
                                  : 'Local sync up to date',
                            ),
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
                    subtitle: archive.isSearch
                        ? 'Folders remain available as destinations.'
                        : 'Open a folder to see only its files.',
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
                else if (archive.documents.isNotEmpty)
                  SectionCard(
                    title: archive.isSearch ? 'Found files' : 'Files',
                    subtitle: archive.isSearch
                        ? 'Results found across the entire archive.'
                        : 'Open a file or move it to another folder.',
                    child: Column(
                      children: archive.documents
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = documentStatusColor(context, document.parsedStatus);
    final isParsing = parseProgress != null;
    final onDeviceBackground = isDark
        ? Colors.teal.shade900.withValues(alpha: 0.36)
        : Colors.teal.shade50;
    final onDeviceForeground = isDark
        ? Colors.teal.shade100
        : Colors.teal.shade900;

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
            if (document.isLocal ||
                document.isOld ||
                document.pendingSync ||
                isParsing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (document.isLocal)
                      Chip(
                        label: Text(
                          'On device',
                          style: TextStyle(
                            color: onDeviceForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: onDeviceBackground,
                        visualDensity: VisualDensity.compact,
                      ),
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
        trailing: allowMove
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'move') {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onMove();
                    });
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_move_outline),
                        SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Move file',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Chip(
                  label: Text(documentStatusLabel(document.parsedStatus)),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                ),
              )
            : Chip(
                label: Text(documentStatusLabel(document.parsedStatus)),
                backgroundColor: statusColor.withValues(alpha: 0.12),
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
