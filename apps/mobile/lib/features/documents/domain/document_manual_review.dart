class ManualLabResultDraft {
  const ManualLabResultDraft({
    required this.analyteName,
    required this.value,
    this.unit,
    this.refMin,
    this.refMax,
    this.abnormalFlag,
  });

  final String analyteName;
  final String value;
  final String? unit;
  final double? refMin;
  final double? refMax;
  final bool? abnormalFlag;

  Map<String, dynamic> toJson() => {
    'analyte_name': analyteName,
    'value': value,
    if (unit != null && unit!.isNotEmpty) 'unit': unit,
    if (refMin != null) 'ref_min': refMin,
    if (refMax != null) 'ref_max': refMax,
    if (abnormalFlag != null) 'abnormal_flag': abnormalFlag,
  };
}

class ManualLabPanelDraft {
  const ManualLabPanelDraft({
    required this.panelName,
    this.panelDate,
    required this.results,
  });

  final String panelName;
  final String? panelDate;
  final List<ManualLabResultDraft> results;

  Map<String, dynamic> toJson() => {
    'panel_name': panelName,
    if (panelDate != null && panelDate!.isNotEmpty) 'panel_date': panelDate,
    'results': results.map((result) => result.toJson()).toList(),
  };
}

class ManualImagingReportDraft {
  const ManualImagingReportDraft({
    this.examType,
    this.bodyPart,
    required this.reportText,
    this.impression,
  });

  final String? examType;
  final String? bodyPart;
  final String reportText;
  final String? impression;

  Map<String, dynamic> toJson() => {
    if (examType != null && examType!.isNotEmpty) 'exam_type': examType,
    if (bodyPart != null && bodyPart!.isNotEmpty) 'body_part': bodyPart,
    'report_text': reportText,
    if (impression != null && impression!.isNotEmpty) 'impression': impression,
  };
}

class DocumentManualReviewInput {
  const DocumentManualReviewInput({
    this.title,
    this.documentType,
    this.examDate,
    this.source,
    this.ocrText,
    this.labPanel,
    this.imagingReport,
  });

  final String? title;
  final String? documentType;
  final String? examDate;
  final String? source;
  final String? ocrText;
  final ManualLabPanelDraft? labPanel;
  final ManualImagingReportDraft? imagingReport;

  Map<String, dynamic> toJson() => {
    if (title != null && title!.isNotEmpty) 'title': title,
    if (documentType != null && documentType!.isNotEmpty)
      'document_type': documentType,
    if (examDate != null && examDate!.isNotEmpty) 'exam_date': examDate,
    if (source != null) 'source': source,
    if (ocrText != null) 'ocr_text': ocrText,
    if (labPanel != null) 'lab_panel': labPanel!.toJson(),
    if (imagingReport != null) 'imaging_report': imagingReport!.toJson(),
  };
}
