import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentReviewScreen extends ConsumerStatefulWidget {
  const DocumentReviewScreen({required this.documentId, super.key});

  final String documentId;

  @override
  ConsumerState<DocumentReviewScreen> createState() =>
      _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends ConsumerState<DocumentReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceController = TextEditingController();
  final _examDateController = TextEditingController();
  final _ocrTextController = TextEditingController();
  final _panelNameController = TextEditingController();
  final _imagingExamTypeController = TextEditingController();
  final _imagingBodyPartController = TextEditingController();
  final _imagingReportTextController = TextEditingController();
  final _imagingImpressionController = TextEditingController();
  final List<_LabResultDraft> _labResults = [];

  String _documentType = 'generic_document';
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _examDateController.dispose();
    _ocrTextController.dispose();
    _panelNameController.dispose();
    _imagingExamTypeController.dispose();
    _imagingBodyPartController.dispose();
    _imagingReportTextController.dispose();
    _imagingImpressionController.dispose();
    for (final row in _labResults) {
      row.dispose();
    }
    super.dispose();
  }

  void _hydrateFromDetail(ClinicalDocumentDetail detail) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    _titleController.text = detail.title;
    _sourceController.text = detail.source ?? '';
    _examDateController.text = detail.examDate == null
        ? ''
        : detail.examDate!.toIso8601String().split('T').first;
    _ocrTextController.text = detail.ocrText ?? '';
    _documentType = detail.documentType;

    if (detail.labPanels.isNotEmpty) {
      final panel = detail.labPanels.first;
      _panelNameController.text = panel.panelName;
      _labResults.addAll(panel.results.map(_LabResultDraft.fromExisting));
    }
    if (_labResults.isEmpty) {
      _labResults.add(_LabResultDraft());
    }

    if (detail.imagingReports.isNotEmpty) {
      final report = detail.imagingReports.first;
      _imagingExamTypeController.text = report.examType ?? '';
      _imagingBodyPartController.text = report.bodyPart ?? '';
      _imagingReportTextController.text = report.reportText;
      _imagingImpressionController.text = report.impression ?? '';
    } else if (detail.ocrText != null &&
        detail.documentType == 'imaging_report') {
      _imagingReportTextController.text = detail.ocrText!;
    }

    if (_panelNameController.text.isEmpty) {
      _panelNameController.text = detail.title;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final input = _buildReviewInput();
    if (input == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(documentsRepositoryProvider)
          .submitManualReview(widget.documentId, input);
      ref.invalidate(documentsProvider);
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(timelineEventsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual review saved.')),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  DocumentManualReviewInput? _buildReviewInput() {
    final title = _titleController.text.trim();
    final source = _sourceController.text.trim();
    final examDate = _examDateController.text.trim();
    final ocrText = _ocrTextController.text.trim();

    ManualLabPanelDraft? labPanel;
    ManualImagingReportDraft? imagingReport;

    if (_documentType == 'lab_report') {
      final results = _labResults
          .map((draft) => draft.toManualResult())
          .whereType<ManualLabResultDraft>()
          .toList();
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one valid lab result.'),
          ),
        );
        return null;
      }
      labPanel = ManualLabPanelDraft(
        panelName: _panelNameController.text.trim().isEmpty
            ? title
            : _panelNameController.text.trim(),
        panelDate: examDate.isEmpty ? null : examDate,
        results: results,
      );
    }

    if (_documentType == 'imaging_report') {
      if (_imagingReportTextController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter the body of the imaging report.'),
          ),
        );
        return null;
      }
      imagingReport = ManualImagingReportDraft(
        examType: _imagingExamTypeController.text.trim(),
        bodyPart: _imagingBodyPartController.text.trim(),
        reportText: _imagingReportTextController.text.trim(),
        impression: _imagingImpressionController.text.trim(),
      );
    }

    return DocumentManualReviewInput(
      title: title.isEmpty ? null : title,
      documentType: _documentType,
      examDate: examDate.isEmpty ? null : examDate,
      source: source,
      ocrText: ocrText,
      labPanel: labPanel,
      imagingReport: imagingReport,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(documentDetailProvider(widget.documentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Manual review')),
      body: detailAsync.when(
        data: (detail) {
          _hydrateFromDetail(detail);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Correct and confirm the document',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Correct metadata and extracted data.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
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
                        decoration: const InputDecoration(
                          labelText: 'Exam date (YYYY-MM-DD)',
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ocrTextController,
                        minLines: 6,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Corrected or added text',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_documentType == 'lab_report') _buildLabReviewSection(),
                if (_documentType == 'imaging_report') _buildImagingSection(),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    _saving ? 'Saving...' : 'Save manual review',
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Widget _buildLabReviewSection() {
    return SectionCard(
      title: 'Lab results',
      action: TextButton.icon(
        onPressed: () => setState(() => _labResults.add(_LabResultDraft())),
        icon: const Icon(Icons.add),
        label: const Text('Add result'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _panelNameController,
            decoration: const InputDecoration(labelText: 'Panel name'),
            validator: (value) {
              if (_documentType != 'lab_report') {
                return null;
              }
              if (value == null || value.trim().isEmpty) {
                return 'Enter the panel name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ..._labResults.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == _labResults.length - 1 ? 0 : 16,
              ),
              child: _LabResultCard(
                index: entry.key,
                draft: entry.value,
                onRemove: _labResults.length == 1
                    ? null
                    : () => setState(() {
                        final removed = _labResults.removeAt(entry.key);
                        removed.dispose();
                      }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagingSection() {
    return SectionCard(
      title: 'Imaging report',
      child: Column(
        children: [
          TextFormField(
            controller: _imagingExamTypeController,
            decoration: const InputDecoration(labelText: 'Exam type'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imagingBodyPartController,
            decoration: const InputDecoration(labelText: 'Body part'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imagingImpressionController,
            decoration: const InputDecoration(labelText: 'Impression'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imagingReportTextController,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Report text',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (_documentType != 'imaging_report') {
                return null;
              }
              if (value == null || value.trim().isEmpty) {
                return 'Enter the report content';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _LabResultCard extends StatelessWidget {
  const _LabResultCard({
    required this.index,
    required this.draft,
    this.onRemove,
  });

  final int index;
  final _LabResultDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Result ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove result',
                  ),
              ],
            ),
            TextFormField(
              controller: draft.analyteController,
              decoration: const InputDecoration(labelText: 'Analyte'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.valueController,
                    decoration: const InputDecoration(labelText: 'Value'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: draft.unitController,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.refMinController,
                    decoration: const InputDecoration(labelText: 'Min range'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: draft.refMaxController,
                    decoration: const InputDecoration(labelText: 'Max range'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<bool?>(
              initialValue: draft.abnormalFlag,
              decoration: const InputDecoration(labelText: 'Out-of-range flag'),
              items: const [
                DropdownMenuItem<bool?>(value: null, child: Text('Automatic')),
                DropdownMenuItem<bool?>(value: false, child: Text('Normal')),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text('Out of range'),
                ),
              ],
              onChanged: (value) => draft.abnormalFlag = value,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabResultDraft {
  _LabResultDraft({
    String analyte = '',
    String value = '',
    String unit = '',
    String refMin = '',
    String refMax = '',
    this.abnormalFlag,
  })  : analyteController = TextEditingController(text: analyte),
        valueController = TextEditingController(text: value),
        unitController = TextEditingController(text: unit),
        refMinController = TextEditingController(text: refMin),
        refMaxController = TextEditingController(text: refMax);

  factory _LabResultDraft.fromExisting(LabResultItem result) => _LabResultDraft(
    analyte: result.analyteName,
    value: result.value,
    unit: result.unit ?? '',
    refMin: result.refMin?.toString() ?? '',
    refMax: result.refMax?.toString() ?? '',
    abnormalFlag: result.abnormalFlag,
  );

  final TextEditingController analyteController;
  final TextEditingController valueController;
  final TextEditingController unitController;
  final TextEditingController refMinController;
  final TextEditingController refMaxController;
  bool? abnormalFlag;

  ManualLabResultDraft? toManualResult() {
    final analyte = analyteController.text.trim();
    final value = valueController.text.trim();
    if (analyte.isEmpty || value.isEmpty) {
      return null;
    }
    return ManualLabResultDraft(
      analyteName: analyte,
      value: value,
      unit: unitController.text.trim().isEmpty
          ? null
          : unitController.text.trim(),
      refMin: _parseNullableDouble(refMinController.text),
      refMax: _parseNullableDouble(refMaxController.text),
      abnormalFlag: abnormalFlag,
    );
  }

  void dispose() {
    analyteController.dispose();
    valueController.dispose();
    unitController.dispose();
    refMinController.dispose();
    refMaxController.dispose();
  }

  static double? _parseNullableDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
}
