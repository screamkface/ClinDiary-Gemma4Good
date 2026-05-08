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
    this.initialCaptureMode,
    super.key,
  });

  final String? initialFolderId;
  final String? initialFolderName;
  final String? initialCaptureMode;

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
  bool get _shouldOpenCameraOnStart =>
      widget.initialCaptureMode?.toLowerCase() == 'camera';

  @override
  void initState() {
    super.initState();
    if (_shouldOpenCameraOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pickPhotoFromCamera();
        }
      });
    }
  }

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

  Future<void> _pickPhotoFromCamera() async {
    final selected = await ref
        .read(documentPickerServiceProvider)
        .pickPhotoFromCamera();
    if (!mounted) {
      return;
    }
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
      helpText: 'Select exam date',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Select a file first.')));
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add file')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'File',
                subtitle: widget.initialFolderName == null
                    ? 'Choose what you want to add.'
                    : 'It will go in this folder.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.initialFolderName != null &&
                        widget.initialFolderName!.trim().isNotEmpty) ...[
                      Chip(
                        avatar: const Icon(Icons.folder_open_outlined),
                        label: Text(widget.initialFolderName!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _uploading ? null : _pickDocument,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Select file'),
                        ),
                        FilledButton.icon(
                          onPressed: _uploading ? null : _pickPhotoFromCamera,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Take photo'),
                        ),
                      ],
                    ),
                    if (_selectedDocument == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'PDF, JPG or PNG.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    if (_selectedDocument != null) ...[
                      const SizedBox(height: 12),
                      _UploadInfoTile(
                        label: 'Selected',
                        value:
                            '${_selectedDocument!.name} • ${_selectedDocument!.mimeType}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Details',
                subtitle: 'Add only the useful information.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Document title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Document type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'generic_document',
                          child: Text('General document'),
                        ),
                        DropdownMenuItem(
                          value: 'lab_report',
                          child: Text('Lab report'),
                        ),
                        DropdownMenuItem(
                          value: 'imaging_report',
                          child: Text('Imaging report'),
                        ),
                        DropdownMenuItem(
                          value: 'discharge_letter',
                          child: Text('Discharge summary'),
                        ),
                        DropdownMenuItem(
                          value: 'specialist_visit',
                          child: Text('Specialist visit'),
                        ),
                        DropdownMenuItem(
                          value: 'prescription',
                          child: Text('Prescription'),
                        ),
                        DropdownMenuItem(
                          value: 'medical_certificate',
                          child: Text('Medical certificate'),
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
                        labelText: 'Exam date',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null;
                        }
                        return DateTime.tryParse(value) == null
                            ? 'Invalid date'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sourceController,
                      decoration: const InputDecoration(labelText: 'Source'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _uploading ? null : _submit,
                icon: const Icon(Icons.save_alt_outlined),
                label: Text(_uploading ? 'Saving...' : 'Save on device'),
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
