import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
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
        title: const Text('Nuova cartella'),
        content: TextFormField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome cartella',
            hintText: 'Es. Esami sangue',
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
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(folderName.trim()),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    if (!mounted || createdName == null || createdName.trim().isEmpty) {
      return;
    }

    try {
      await ref.read(documentsRepositoryProvider).createFolder(
        name: createdName,
        parentFolderId: _currentFolderId,
      );
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cartella "$createdName" creata.')));
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
                      'Sposta file',
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
    if (selected == document.folderId ||
        (selected == null && (document.folderId == null || document.folderId!.isEmpty))) {
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
      ).showSnackBar(const SnackBar(content: Text('Documento spostato.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _openUpload(DocumentArchiveView archive) {
    final uri = Uri(
      path: '/app/documents/upload',
      queryParameters: {
        if (archive.currentFolder != null) 'folderId': archive.currentFolder!.id,
        if (archive.currentFolder != null)
          'folderName': archive.currentFolder!.pathLabel,
        'storageMode': archive.storageLocation,
      },
    );
    context.push(uri.toString());
  }

  void _openDocumentQuery(DocumentArchiveView archive) {
    if (archive.isLocal) {
      context.push('/app/home/billing?feature=cloud_document_storage');
      return;
    }
    final uri = Uri(
      path: '/app/documents/ask',
      queryParameters: {
        if (archive.currentFolder != null) 'folderId': archive.currentFolder!.id,
        if (archive.currentFolder != null)
          'folderName': archive.currentFolder!.pathLabel,
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final archiveAsync = ref.watch(documentArchiveProvider(_archiveQuery));
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documenti'),
        actions: [
          IconButton(
            onPressed: () => _refreshAll(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: archiveAsync.when(
        data: (archive) => RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: archive.currentFolder?.name ?? 'Archivio',
                subtitle: archive.isSearch
                    ? (archive.isLocal
                          ? 'Ricerca locale tra i file salvati su questo dispositivo.'
                          : 'Ricerca tra tutti i documenti caricati nel cloud.')
                    : (archive.isLocal
                          ? 'Cartelle e file salvati localmente su questo dispositivo.'
                          : 'Cartelle e file in un archivio cloud ordinato.'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _applySearch(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Cerca file',
                        hintText: archive.isLocal
                            ? 'Titolo, cartella, sorgente, nome file...'
                            : 'Titolo, nome file, testo estratto...',
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
                          avatar: Icon(
                            archive.isLocal
                                ? Icons.phone_android_outlined
                                : Icons.cloud_outlined,
                          ),
                          label: Text(documentStorageLabel(archive.storageLocation)),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _createFolder,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Nuova cartella'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _openUpload(archive),
                          icon: Icon(
                            archive.isLocal
                                ? Icons.save_alt_outlined
                                : Icons.upload_file,
                          ),
                          label: Text(
                            archive.currentFolder == null
                                ? (archive.isLocal
                                      ? 'Salva file'
                                      : 'Carica file')
                                : (archive.isLocal ? 'Salva qui' : 'Carica qui'),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _openDocumentQuery(archive),
                          icon: Icon(
                            archive.isLocal
                                ? Icons.workspace_premium_outlined
                                : Icons.chat_bubble_outline,
                          ),
                          label: Text(
                            archive.isLocal ? 'Sblocca cloud' : 'Chiedi ai file',
                          ),
                        ),
                      ],
                    ),
                    if (archive.isLocal)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Nel piano free i file restano sul dispositivo. OCR, parsing automatico, backup cloud e domande ai documenti si sbloccano con AI Plus.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('${archive.folders.length} cartelle')),
                        Chip(
                          label: Text(
                            '${archive.documents.length + archive.legacyCloudDocuments.length} file',
                          ),
                        ),
                        if (archive.isSearch)
                          const Chip(label: Text('Ricerca attiva')),
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
                  title: 'Cartelle',
                  subtitle: archive.isSearch
                      ? 'Le cartelle restano disponibili come destinazioni.'
                      : 'Apri una cartella per vedere solo i suoi file.',
                  child: Column(
                    children: archive.folders
                        .map(
                          (folder) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card.outlined(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                onTap: () => _openFolder(folder.id),
                                leading: const CircleAvatar(
                                  child: Icon(Icons.folder_outlined),
                                ),
                                title: Text(
                                  folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${folder.childFolderCount} sottocartelle • ${folder.documentCount} file',
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
              if (archive.documents.isEmpty &&
                  archive.folders.isEmpty &&
                  !archive.hasLegacyCloudDocuments)
                SectionCard(
                  title: archive.isSearch ? 'Nessun risultato' : 'Archivio vuoto',
                  child: Text(
                    archive.isSearch
                        ? 'Prova con parole diverse o svuota la ricerca.'
                        : 'Crea una cartella o carica il primo documento.',
                  ),
                )
              else if (archive.documents.isNotEmpty)
                SectionCard(
                  title: archive.isSearch ? 'File trovati' : 'File',
                  subtitle: archive.isSearch
                      ? 'Risultati trovati in tutto l\'archivio.'
                      : 'Apri un file o spostalo in un\'altra cartella.',
                  child: Column(
                    children: archive.documents
                        .map(
                          (document) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DocumentArchiveTile(
                              document: document,
                              dateFormat: dateFormat,
                              showFolderName: archive.isSearch,
                              allowMove: true,
                              onOpen: () =>
                                  context.push('/app/documents/${document.id}'),
                              onMove: () => _moveDocument(document),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (archive.hasLegacyCloudDocuments) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Archivio cloud in sola lettura',
                  subtitle:
                      'Questi file erano già nel cloud. Restano consultabili anche sul piano free, ma per modificarli serve AI Plus.',
                  child: Column(
                    children: archive.legacyCloudDocuments
                        .map(
                          (document) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DocumentArchiveTile(
                              document: document,
                              dateFormat: dateFormat,
                              showFolderName: true,
                              allowMove: false,
                              onOpen: () =>
                                  context.push('/app/documents/${document.id}'),
                              onMove: () {},
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
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
          label: const Text('Archivio'),
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
            label: const Text('Chiudi ricerca'),
          ),
      ],
    );
  }
}


class _DocumentArchiveTile extends StatelessWidget {
  const _DocumentArchiveTile({
    required this.document,
    required this.dateFormat,
    required this.showFolderName,
    required this.allowMove,
    required this.onOpen,
    required this.onMove,
  });

  final ClinicalDocumentSummary document;
  final DateFormat dateFormat;
  final bool showFolderName;
  final bool allowMove;
  final VoidCallback onOpen;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final statusColor = documentStatusColor(context, document.parsedStatus);

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
                'Cartella: ${document.folderName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (document.isLocal || document.isOld || document.pendingSync)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (document.isLocal)
                      const Chip(
                        label: Text('Sul dispositivo'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (document.isOld)
                      Chip(
                        label: const Text('Vecchio'),
                        backgroundColor: documentContextStatusColor(
                          context,
                          document.contextStatus,
                        ).withValues(alpha: 0.12),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (document.pendingSync)
                      Chip(
                        label: const Text('Sync in attesa'),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.tertiaryContainer,
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
                  'In attesa di sincronizzazione',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
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
                            'Sposta file',
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
