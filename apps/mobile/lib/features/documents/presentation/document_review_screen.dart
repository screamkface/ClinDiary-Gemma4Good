import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

AppLocalizations _documentsL10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

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
    final l10n = _documentsL10nOf(context);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.documentsManualReviewSaved)));
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
    final l10n = _documentsL10nOf(context);
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
          SnackBar(content: Text(l10n.documentsAddAtLeastOneValidLab)),
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
          SnackBar(content: Text(l10n.documentsEnterTheBodyOfTheImaging)),
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
    final l10n = _documentsL10nOf(context);
    final detailAsync = ref.watch(documentDetailProvider(widget.documentId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsManualReview)),
      body: detailAsync.when(
        data: (detail) {
          _hydrateFromDetail(detail);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: l10n.documentsCorrectAndConfirmTheDocument,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.documentsCorrectMetadataAndExtractedData,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: l10n.documentsDocumentTitle,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _documentType,
                        decoration: InputDecoration(
                          labelText: l10n.documentsDocumentType,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'generic_document',
                            child: Text(l10n.documentsGeneralDocument),
                          ),
                          DropdownMenuItem(
                            value: 'lab_report',
                            child: Text(l10n.documentsLabReport),
                          ),
                          DropdownMenuItem(
                            value: 'imaging_report',
                            child: Text(l10n.documentsImagingReport2),
                          ),
                          DropdownMenuItem(
                            value: 'discharge_letter',
                            child: Text(l10n.documentsDischargeSummary2),
                          ),
                          DropdownMenuItem(
                            value: 'specialist_visit',
                            child: Text(l10n.documentsSpecialistVisit),
                          ),
                          DropdownMenuItem(
                            value: 'prescription',
                            child: Text(l10n.documentsPrescription),
                          ),
                          DropdownMenuItem(
                            value: 'medical_certificate',
                            child: Text(l10n.documentsMedicalCertificate),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _documentType = value ?? 'generic_document',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _examDateController,
                        decoration: InputDecoration(
                          labelText: l10n.documentsExamDateYyyyMmDd,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null;
                          }
                          return DateTime.tryParse(value) == null
                              ? l10n.documentsInvalidDate
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sourceController,
                        decoration: InputDecoration(
                          labelText: l10n.documentsSource,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ocrTextController,
                        minLines: 6,
                        maxLines: 12,
                        decoration: InputDecoration(
                          labelText: l10n.documentsCorrectedOrAddedText,
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
                    _saving
                        ? l10n.documentsSaving
                        : l10n.documentsSaveManualReview,
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
    final l10n = _documentsL10nOf(context);
    return SectionCard(
      title: l10n.documentsLabResults,
      action: TextButton.icon(
        onPressed: () => setState(() => _labResults.add(_LabResultDraft())),
        icon: const Icon(Icons.add),
        label: Text(l10n.documentsAddResult),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _panelNameController,
            decoration: InputDecoration(labelText: l10n.documentsPanelName),
            validator: (value) {
              if (_documentType != 'lab_report') {
                return null;
              }
              if (value == null || value.trim().isEmpty) {
                return l10n.documentsEnterThePanelName;
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
    final l10n = _documentsL10nOf(context);
    return SectionCard(
      title: l10n.documentsImagingReport3,
      child: Column(
        children: [
          TextFormField(
            controller: _imagingExamTypeController,
            decoration: InputDecoration(labelText: l10n.documentsExamType),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imagingBodyPartController,
            decoration: InputDecoration(labelText: l10n.documentsBodyPart),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imagingImpressionController,
            decoration: InputDecoration(labelText: l10n.documentsImpression),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imagingReportTextController,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: l10n.documentsReportText,
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (_documentType != 'imaging_report') {
                return null;
              }
              if (value == null || value.trim().isEmpty) {
                return l10n.documentsEnterTheReportContent;
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
    final l10n = _documentsL10nOf(context);
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
                    l10n.documentsResultNumber(index + 1),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.documentsRemoveResult,
                  ),
              ],
            ),
            TextFormField(
              controller: draft.analyteController,
              decoration: InputDecoration(labelText: l10n.documentsAnalyte),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.valueController,
                    decoration: InputDecoration(labelText: l10n.documentsValue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: draft.unitController,
                    decoration: InputDecoration(labelText: l10n.documentsUnit),
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
                    decoration: InputDecoration(
                      labelText: l10n.documentsMinRange,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: draft.refMaxController,
                    decoration: InputDecoration(
                      labelText: l10n.documentsMaxRange,
                    ),
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
              decoration: InputDecoration(
                labelText: l10n.documentsOutOfRangeFlag,
              ),
              items: [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text(l10n.documentsAutomatic),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Text(l10n.documentsNormal),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text(l10n.documentsOutOfRange),
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
  }) : analyteController = TextEditingController(text: analyte),
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
