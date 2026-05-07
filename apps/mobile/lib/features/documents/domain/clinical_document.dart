class LabResultItem {
  const LabResultItem({
    required this.id,
    required this.analyteName,
    required this.value,
    this.unit,
    this.refMin,
    this.refMax,
    this.abnormalFlag,
    this.confidenceScore,
  });

  final String id;
  final String analyteName;
  final String value;
  final String? unit;
  final double? refMin;
  final double? refMax;
  final bool? abnormalFlag;
  final double? confidenceScore;

  factory LabResultItem.fromJson(Map<String, dynamic> json) => LabResultItem(
    id: json['id'].toString(),
    analyteName: json['analyte_name'].toString(),
    value: json['value'].toString(),
    unit: json['unit'] as String?,
    refMin: (json['ref_min'] as num?)?.toDouble(),
    refMax: (json['ref_max'] as num?)?.toDouble(),
    abnormalFlag: json['abnormal_flag'] as bool?,
    confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
  );
}

class LabPanelItem {
  const LabPanelItem({
    required this.id,
    required this.panelName,
    this.panelDate,
    this.confidenceScore,
    required this.results,
  });

  final String id;
  final String panelName;
  final DateTime? panelDate;
  final double? confidenceScore;
  final List<LabResultItem> results;

  factory LabPanelItem.fromJson(Map<String, dynamic> json) => LabPanelItem(
    id: json['id'].toString(),
    panelName: json['panel_name'].toString(),
    panelDate: json['panel_date'] == null
        ? null
        : DateTime.parse(json['panel_date'].toString()),
    confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
    results: (json['results'] as List<dynamic>)
        .map((item) => LabResultItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class ImagingReportItem {
  const ImagingReportItem({
    required this.id,
    this.examType,
    this.bodyPart,
    required this.reportText,
    this.impression,
    this.confidenceScore,
  });

  final String id;
  final String? examType;
  final String? bodyPart;
  final String reportText;
  final String? impression;
  final double? confidenceScore;

  factory ImagingReportItem.fromJson(Map<String, dynamic> json) =>
      ImagingReportItem(
        id: json['id'].toString(),
        examType: json['exam_type'] as String?,
        bodyPart: json['body_part'] as String?,
        reportText: json['report_text'].toString(),
        impression: json['impression'] as String?,
        confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      );
}

class ClinicalDocumentSummary {
  const ClinicalDocumentSummary({
    required this.id,
    this.folderId,
    this.folderName,
    required this.title,
    required this.documentType,
    required this.uploadDate,
    this.examDate,
    this.source,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.parsedStatus,
    this.contextStatus = 'active',
    this.classificationConfidence,
    this.parsingConfidence,
    this.processingError,
    this.pendingSync = false,
    this.storageLocation = 'cloud',
    this.localFilePath,
  });

  final String id;
  final String? folderId;
  final String? folderName;
  final String title;
  final String documentType;
  final DateTime uploadDate;
  final DateTime? examDate;
  final String? source;
  final String originalFilename;
  final String mimeType;
  final int fileSizeBytes;
  final String parsedStatus;
  final String contextStatus;
  final double? classificationConfidence;
  final double? parsingConfidence;
  final String? processingError;
  final bool pendingSync;
  final String storageLocation;
  final String? localFilePath;

  bool get isOld => contextStatus == 'old';
  bool get isLocal => storageLocation == 'local';
  bool get isCloud => !isLocal;

  factory ClinicalDocumentSummary.fromJson(Map<String, dynamic> json) =>
      ClinicalDocumentSummary(
        id: json['id'].toString(),
        folderId: json['folder_id']?.toString(),
        folderName: json['folder_name'] as String?,
        title: json['title'].toString(),
        documentType: json['document_type'].toString(),
        uploadDate: DateTime.parse(json['upload_date'].toString()),
        examDate: json['exam_date'] == null
            ? null
            : DateTime.parse(json['exam_date'].toString()),
        source: json['source'] as String?,
        originalFilename: json['original_filename'].toString(),
        mimeType: json['mime_type'].toString(),
        fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
        parsedStatus: json['parsed_status'].toString(),
        contextStatus: json['context_status']?.toString() ?? 'active',
        classificationConfidence: (json['classification_confidence'] as num?)
            ?.toDouble(),
        parsingConfidence: (json['parsing_confidence'] as num?)?.toDouble(),
        processingError: json['processing_error'] as String?,
        pendingSync: json['pending_sync'] as bool? ?? false,
        storageLocation: json['storage_location']?.toString() ?? 'cloud',
        localFilePath: json['local_file_path'] as String?,
      );
}

class ClinicalDocumentDetail extends ClinicalDocumentSummary {
  const ClinicalDocumentDetail({
    required super.id,
    super.folderId,
    super.folderName,
    required super.title,
    required super.documentType,
    required super.uploadDate,
    super.examDate,
    super.source,
    required super.originalFilename,
    required super.mimeType,
    required super.fileSizeBytes,
    required super.parsedStatus,
    super.contextStatus,
    super.classificationConfidence,
    super.parsingConfidence,
    super.processingError,
    super.pendingSync,
    required this.fileUrl,
    this.ocrText,
    this.viewerUrl,
    this.processedAt,
    required this.labPanels,
    required this.imagingReports,
    super.storageLocation,
    super.localFilePath,
  });

  final String fileUrl;
  final String? ocrText;
  final String? viewerUrl;
  final DateTime? processedAt;
  final List<LabPanelItem> labPanels;
  final List<ImagingReportItem> imagingReports;

  bool get canRetryProcessing => parsedStatus != 'processing';
  bool get canOpenManualReview => parsedStatus != 'processing';

  factory ClinicalDocumentDetail.fromJson(Map<String, dynamic> json) =>
      ClinicalDocumentDetail(
        id: json['id'].toString(),
        folderId: json['folder_id']?.toString(),
        folderName: json['folder_name'] as String?,
        title: json['title'].toString(),
        documentType: json['document_type'].toString(),
        uploadDate: DateTime.parse(json['upload_date'].toString()),
        examDate: json['exam_date'] == null
            ? null
            : DateTime.parse(json['exam_date'].toString()),
        source: json['source'] as String?,
        originalFilename: json['original_filename'].toString(),
        mimeType: json['mime_type'].toString(),
        fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
        parsedStatus: json['parsed_status'].toString(),
        contextStatus: json['context_status']?.toString() ?? 'active',
        classificationConfidence: (json['classification_confidence'] as num?)
            ?.toDouble(),
        parsingConfidence: (json['parsing_confidence'] as num?)?.toDouble(),
        processingError: json['processing_error'] as String?,
        pendingSync: json['pending_sync'] as bool? ?? false,
        fileUrl: json['file_url'].toString(),
        ocrText: json['ocr_text'] as String?,
        viewerUrl: json['viewer_url'] as String?,
        processedAt: json['processed_at'] == null
            ? null
            : DateTime.parse(json['processed_at'].toString()),
        labPanels: (json['lab_panels'] as List<dynamic>)
            .map((item) => LabPanelItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        imagingReports: (json['imaging_reports'] as List<dynamic>)
            .map(
              (item) =>
                  ImagingReportItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class SelectedUploadDocument {
  const SelectedUploadDocument({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final List<int> bytes;
  final String mimeType;
}

class DocumentFolderItem {
  const DocumentFolderItem({
    required this.id,
    required this.name,
    this.parentFolderId,
    required this.pathLabel,
    required this.childFolderCount,
    required this.documentCount,
  });

  final String id;
  final String name;
  final String? parentFolderId;
  final String pathLabel;
  final int childFolderCount;
  final int documentCount;

  factory DocumentFolderItem.fromJson(Map<String, dynamic> json) =>
      DocumentFolderItem(
        id: json['id'].toString(),
        name: json['name'].toString(),
        parentFolderId: json['parent_folder_id']?.toString(),
        pathLabel: json['path_label']?.toString() ?? json['name'].toString(),
        childFolderCount: json['child_folder_count'] as int? ?? 0,
        documentCount: json['document_count'] as int? ?? 0,
      );
}

class DocumentArchiveView {
  const DocumentArchiveView({
    this.currentFolder,
    required this.breadcrumbs,
    required this.folders,
    required this.documents,
    this.legacyCloudDocuments = const [],
    this.query,
    required this.isSearch,
    this.storageLocation = 'cloud',
  });

  final DocumentFolderItem? currentFolder;
  final List<DocumentFolderItem> breadcrumbs;
  final List<DocumentFolderItem> folders;
  final List<ClinicalDocumentSummary> documents;
  final List<ClinicalDocumentSummary> legacyCloudDocuments;
  final String? query;
  final bool isSearch;
  final String storageLocation;

  bool get isLocal => storageLocation == 'local';
  bool get isCloud => !isLocal;
  bool get hasLegacyCloudDocuments => legacyCloudDocuments.isNotEmpty;

  factory DocumentArchiveView.fromJson(Map<String, dynamic> json) =>
      DocumentArchiveView(
        currentFolder: json['current_folder'] == null
            ? null
            : DocumentFolderItem.fromJson(
                json['current_folder'] as Map<String, dynamic>,
              ),
        breadcrumbs: (json['breadcrumbs'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  DocumentFolderItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        folders: (json['folders'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  DocumentFolderItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        documents: (json['documents'] as List<dynamic>? ?? const [])
            .map(
              (item) => ClinicalDocumentSummary.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
        legacyCloudDocuments:
            (json['legacy_cloud_documents'] as List<dynamic>? ?? const [])
                .map(
                  (item) => ClinicalDocumentSummary.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList(),
        query: json['query'] as String?,
        isSearch: json['is_search'] as bool? ?? false,
        storageLocation: json['storage_location']?.toString() ?? 'cloud',
      );
}

class DocumentArchiveQuery {
  const DocumentArchiveQuery({this.folderId, this.searchQuery});

  final String? folderId;
  final String? searchQuery;

  @override
  bool operator ==(Object other) {
    return other is DocumentArchiveQuery &&
        other.folderId == folderId &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode => Object.hash(folderId, searchQuery);
}

class DocumentQueryCitation {
  const DocumentQueryCitation({
    required this.documentId,
    required this.documentTitle,
    required this.documentType,
    this.folderName,
    this.examDate,
    required this.chunkKind,
    this.chunkLabel,
    required this.excerpt,
    this.score,
    this.viewerUrl,
  });

  final String documentId;
  final String documentTitle;
  final String documentType;
  final String? folderName;
  final DateTime? examDate;
  final String chunkKind;
  final String? chunkLabel;
  final String excerpt;
  final double? score;
  final String? viewerUrl;

  factory DocumentQueryCitation.fromJson(Map<String, dynamic> json) =>
      DocumentQueryCitation(
        documentId: json['document_id'].toString(),
        documentTitle: json['document_title'].toString(),
        documentType: json['document_type'].toString(),
        folderName: json['folder_name'] as String?,
        examDate: json['exam_date'] == null
            ? null
            : DateTime.parse(json['exam_date'].toString()),
        chunkKind: json['chunk_kind'].toString(),
        chunkLabel: json['chunk_label'] as String?,
        excerpt: json['excerpt'].toString(),
        score: (json['score'] as num?)?.toDouble(),
        viewerUrl: json['viewer_url'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'document_id': documentId,
    'document_title': documentTitle,
    'document_type': documentType,
    'folder_name': folderName,
    'exam_date': examDate?.toIso8601String(),
    'chunk_kind': chunkKind,
    'chunk_label': chunkLabel,
    'excerpt': excerpt,
    'score': score,
    'viewer_url': viewerUrl,
  };
}

class DocumentQueryResult {
  const DocumentQueryResult({
    required this.answer,
    required this.citations,
    required this.providerName,
    required this.modelName,
    this.embeddingModelName,
    this.rerankerModelName,
    required this.retrievedChunks,
    required this.retrievedDocuments,
    required this.searchScopeLabel,
    this.coverageNote,
    required this.usedFallback,
  });

  final String answer;
  final List<DocumentQueryCitation> citations;
  final String providerName;
  final String modelName;
  final String? embeddingModelName;
  final String? rerankerModelName;
  final int retrievedChunks;
  final int retrievedDocuments;
  final String searchScopeLabel;
  final String? coverageNote;
  final bool usedFallback;

  factory DocumentQueryResult.fromJson(Map<String, dynamic> json) =>
      DocumentQueryResult(
        answer: json['answer'].toString(),
        citations: (json['citations'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  DocumentQueryCitation.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        providerName: json['provider_name'].toString(),
        modelName: json['model_name'].toString(),
        embeddingModelName: json['embedding_model_name'] as String?,
        rerankerModelName: json['reranker_model_name'] as String?,
        retrievedChunks: json['retrieved_chunks'] as int? ?? 0,
        retrievedDocuments: json['retrieved_documents'] as int? ?? 0,
        searchScopeLabel:
            json['search_scope_label']?.toString() ?? 'Tutto l archivio',
        coverageNote: json['coverage_note'] as String?,
        usedFallback: json['used_fallback'] as bool? ?? false,
      );
}
