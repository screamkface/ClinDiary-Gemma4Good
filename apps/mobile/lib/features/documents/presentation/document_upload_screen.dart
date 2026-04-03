import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({
    this.initialFolderId,
    this.initialFolderName,
    this.initialStorageLocation,
    super.key,
  });

  final String? initialFolderId;
  final String? initialFolderName;
  final String? initialStorageLocation;

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _examDateController = TextEditingController();
  final _sourceController = TextEditingController();
  String _documentType = 'generic_document';
  SelectedUploadDocument? _selectedDocument;
  bool _uploading = false;

  bool get _isLocalStorage => widget.initialStorageLocation == 'local';

  @override
  void dispose() {
    _titleController.dispose();
    _examDateController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final selected = await ref
        .read(documentPickerServiceProvider)
        .pickDocument();
    if (!mounted) return;
    setState(() => _selectedDocument = selected);
  }

  Future<void> _pickExamDate() async {
    final parsed = DateTime.tryParse(_examDateController.text.trim());
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Seleziona data esame',
    );
    if (selected == null || !mounted) {
      return;
    }
    final yyyy = selected.year.toString().padLeft(4, '0');
    final mm = selected.month.toString().padLeft(2, '0');
    final dd = selected.day.toString().padLeft(2, '0');
    setState(() => _examDateController.text = '$yyyy-$mm-$dd');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDocument == null) {
      if (_selectedDocument == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleziona prima un file.')),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final document = await ref
          .read(documentsRepositoryProvider)
          .uploadDocument(
            file: _selectedDocument!,
            fields: {
              if (_titleController.text.trim().isNotEmpty)
                'title': _titleController.text.trim(),
              if (_documentType.isNotEmpty) 'document_type': _documentType,
              if (_examDateController.text.trim().isNotEmpty)
                'exam_date': _examDateController.text.trim(),
              if (_sourceController.text.trim().isNotEmpty)
                'source': _sourceController.text.trim(),
              if (widget.initialFolderId != null &&
                  widget.initialFolderId!.isNotEmpty)
                'folder_id': widget.initialFolderId!,
            },
          );
      ref.invalidate(documentsProvider);
      ref.invalidate(documentArchiveProvider);
      ref.invalidate(documentFoldersProvider);
      ref.invalidate(timelineEventsProvider);
      if (!mounted) return;
      context.pushReplacement('/app/documents/${document.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carica documento')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'File',
                subtitle: widget.initialFolderName == null
                    ? (_isLocalStorage
                          ? 'Scegli il documento da salvare sul dispositivo.'
                          : 'Scegli il documento da caricare nel cloud ClinDiary.')
                    : (_isLocalStorage
                          ? 'Il file verra salvato localmente nella cartella corrente.'
                          : 'Il file verra caricato nella cartella cloud corrente.'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      avatar: Icon(
                        _isLocalStorage
                            ? Icons.phone_android_outlined
                            : Icons.cloud_outlined,
                      ),
                      label: Text(
                        _isLocalStorage
                            ? 'Archivio sul dispositivo'
                            : 'Archivio cloud',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.initialFolderName != null &&
                        widget.initialFolderName!.trim().isNotEmpty) ...[
                      Chip(
                        avatar: const Icon(Icons.folder_open_outlined),
                        label: Text(widget.initialFolderName!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _uploading ? null : _pickDocument,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _selectedDocument == null
                            ? 'Seleziona file'
                            : _selectedDocument!.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedDocument != null) ...[
                      const SizedBox(height: 12),
                      _UploadInfoTile(
                        label: 'Selezionato',
                        value:
                            '${_selectedDocument!.name} • ${_selectedDocument!.mimeType}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Dettagli',
                subtitle: 'Aggiungi solo le informazioni utili.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titolo documento',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo documento',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'generic_document',
                          child: Text('Documento generico'),
                        ),
                        DropdownMenuItem(
                          value: 'lab_report',
                          child: Text('Referto laboratorio'),
                        ),
                        DropdownMenuItem(
                          value: 'imaging_report',
                          child: Text('Referto imaging'),
                        ),
                        DropdownMenuItem(
                          value: 'discharge_letter',
                          child: Text('Lettera dimissione'),
                        ),
                        DropdownMenuItem(
                          value: 'specialist_visit',
                          child: Text('Visita specialistica'),
                        ),
                        DropdownMenuItem(
                          value: 'prescription',
                          child: Text('Prescrizione'),
                        ),
                        DropdownMenuItem(
                          value: 'medical_certificate',
                          child: Text('Certificato medico'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _documentType = value ?? 'generic_document',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _examDateController,
                      readOnly: true,
                      onTap: _uploading ? null : _pickExamDate,
                      decoration: const InputDecoration(
                        labelText: 'Data esame',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null;
                        }
                        return DateTime.tryParse(value) == null
                            ? 'Data non valida'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sourceController,
                      decoration: const InputDecoration(labelText: 'Fonte'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _uploading ? null : _submit,
                icon: Icon(
                  _isLocalStorage
                      ? Icons.save_alt_outlined
                      : Icons.cloud_upload_outlined,
                ),
                label: Text(
                  _uploading
                      ? (_isLocalStorage
                            ? 'Salvataggio in corso...'
                            : 'Upload in corso...')
                      : (_isLocalStorage
                            ? 'Salva sul dispositivo'
                            : 'Carica documento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadInfoTile extends StatelessWidget {
  const _UploadInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
