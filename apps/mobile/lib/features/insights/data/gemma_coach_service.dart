import 'package:clindiary/features/alerts/data/alerts_repository.dart';
import 'package:clindiary/features/daily_journal/data/daily_journal_repository.dart';
import 'package:clindiary/features/dossier/data/dossier_repository.dart';
import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:clindiary/features/insights/domain/on_device_text_prompt.dart';
import 'package:clindiary/features/medications/data/medications_repository.dart';
import 'package:clindiary/features/profile/data/profile_repository.dart';
import 'package:clindiary/features/timeline/data/timeline_repository.dart';
import 'package:clindiary/features/wearables/data/wearables_repository.dart';

class GemmaCoachService {
  GemmaCoachService({
    required OnDeviceAiService onDeviceAiService,
    required OnDevicePromptBuilder onDevicePromptBuilder,
    required DocumentsRepository documentsRepository,
    required ProfileRepository profileRepository,
    required DailyJournalRepository dailyJournalRepository,
    required AlertsRepository alertsRepository,
    required MedicationsRepository medicationsRepository,
    required TimelineRepository timelineRepository,
    required WearablesRepository wearablesRepository,
    required DossierRepository dossierRepository,
  }) : _onDeviceAiService = onDeviceAiService,
       _onDevicePromptBuilder = onDevicePromptBuilder,
       _documentsRepository = documentsRepository,
       _profileRepository = profileRepository,
       _dailyJournalRepository = dailyJournalRepository,
       _alertsRepository = alertsRepository,
       _medicationsRepository = medicationsRepository,
       _timelineRepository = timelineRepository,
       _wearablesRepository = wearablesRepository,
       _dossierRepository = dossierRepository;

  final OnDeviceAiService _onDeviceAiService;
  final OnDevicePromptBuilder _onDevicePromptBuilder;
  final DocumentsRepository _documentsRepository;
  final ProfileRepository _profileRepository;
  final DailyJournalRepository _dailyJournalRepository;
  final AlertsRepository _alertsRepository;
  final MedicationsRepository _medicationsRepository;
  final TimelineRepository _timelineRepository;
  final WearablesRepository _wearablesRepository;
  final DossierRepository _dossierRepository;

  Future<String> answerQuestion({
    required String question,
    DateTime? referenceDate,
    String? documentId,
  }) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw Exception('Write a more specific question.');
    }
    final focusedDocument = await _resolveFocusedDocument(documentId);

    return _generateWithWarmup(
      promptBuilder: () => _onDevicePromptBuilder.buildClinicalQuestionPrompt(
        question: normalizedQuestion,
        referenceDate: referenceDate ?? DateTime.now(),
        focusedDocument: focusedDocument,
      ),
      warmUp: _warmUpClinicalContext,
    );
  }

Stream<String> answerQuestionStream({
  required String question,
  DateTime? referenceDate,
  String? documentId,
}) async* {
  final normalizedQuestion = question.trim();

  if (normalizedQuestion.isEmpty) {
    throw Exception('Write a more specific question.');
  }

  final focusedDocument = await _resolveFocusedDocument(documentId);

  // Important: if the user came from "Ask about this file",
  // answer directly from the selected document instead of requiring
  // the full clinical diary prompt to be available.
  if (focusedDocument != null) {
    final prompt = _buildFocusedDocumentQuestionPrompt(
      question: normalizedQuestion,
      detail: focusedDocument,
    );

    yield* _onDeviceAiService.generateTextStream(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
    );
    return;
  }

  final prompt = await _onDevicePromptBuilder.buildClinicalQuestionPrompt(
    question: normalizedQuestion,
    referenceDate: referenceDate ?? DateTime.now(),
    focusedDocument: null,
  );

  if (prompt != null) {
    yield* _onDeviceAiService.generateTextStream(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
    );
    return;
  }

  await _warmUpClinicalContext();

  final refreshedPrompt = await _onDevicePromptBuilder.buildClinicalQuestionPrompt(
    question: normalizedQuestion,
    referenceDate: referenceDate ?? DateTime.now(),
    focusedDocument: null,
  );

  if (refreshedPrompt == null) {
    throw Exception(
      'I do not have enough local data to generate a useful answer.',
    );
  }

  yield* _onDeviceAiService.generateTextStream(
    systemPrompt: refreshedPrompt.systemPrompt,
    userPrompt: refreshedPrompt.userPrompt,
  );
}

  Future<String> explainTrend({DateTime? referenceDate}) async {
    return _generateWithWarmup(
      promptBuilder: () => _onDevicePromptBuilder.buildTrendExplanationPrompt(
        referenceDate: referenceDate ?? DateTime.now(),
      ),
      warmUp: _warmUpClinicalContext,
    );
  }

  Stream<String> explainTrendStream({DateTime? referenceDate}) async* {
    yield* _streamForPrompt(
      promptBuilder: () => _onDevicePromptBuilder.buildTrendExplanationPrompt(
        referenceDate: referenceDate ?? DateTime.now(),
      ),
    );
  }

  Future<String> buildPreVisitBrief({DateTime? referenceDate}) async {
    return _generateWithWarmup(
      promptBuilder: () => _onDevicePromptBuilder.buildPreVisitBriefPrompt(
        referenceDate: referenceDate ?? DateTime.now(),
      ),
      warmUp: _warmUpClinicalContext,
    );
  }

  Stream<String> buildPreVisitBriefStream({DateTime? referenceDate}) async* {
    yield* _streamForPrompt(
      promptBuilder: () => _onDevicePromptBuilder.buildPreVisitBriefPrompt(
        referenceDate: referenceDate ?? DateTime.now(),
      ),
    );
  }

  Future<String> summarizeDocument({
    required ClinicalDocumentDetail detail,
  }) async {
    final prompt = await _onDevicePromptBuilder.buildDocumentSummaryPrompt(
      detail: detail,
    );
    return _generate(prompt);
  }

  Future<String> summarizeDocumentById(String documentId) async {
    final detail = await _documentsRepository.fetchDocumentDetail(documentId);
    return summarizeDocument(detail: detail);
  }

  Future<String> _generateWithWarmup({
    required Future<OnDeviceTextPrompt?> Function() promptBuilder,
    required Future<void> Function() warmUp,
  }) async {
    final prompt = await promptBuilder();
    if (prompt != null) {
      return _onDeviceAiService.generateText(
        systemPrompt: prompt.systemPrompt,
        userPrompt: prompt.userPrompt,
      );
    }

    await warmUp();
    final refreshedPrompt = await promptBuilder();
    return _generate(refreshedPrompt);
  }

  Future<String> _generate(OnDeviceTextPrompt? prompt) async {
    if (prompt == null) {
      throw Exception(
        'I do not have enough local data to generate a useful answer.',
      );
    }
    return _onDeviceAiService.generateText(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
    );
  }

  Stream<String> _streamForPrompt({
    required Future<OnDeviceTextPrompt?> Function() promptBuilder,
  }) async* {
    var prompt = await promptBuilder();
    if (prompt == null) {
      await _warmUpClinicalContext();
      prompt = await promptBuilder();
    }
    if (prompt == null) {
      throw Exception(
        'I do not have enough local data to generate a useful answer.',
      );
    }
    yield* _onDeviceAiService.generateTextStream(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
    );
  }

  Future<void> _warmUpClinicalContext() async {
    await Future.wait(<Future<void>>[
      _profileRepository.fetchProfile().then((_) {}, onError: (_) {}),
      _dossierRepository.fetchDossier().then((_) {}, onError: (_) {}),
      _dailyJournalRepository.fetchEntries().then((_) {}, onError: (_) {}),
      _alertsRepository.fetchAlerts().then((_) {}, onError: (_) {}),
      _medicationsRepository.fetchLogs().then((_) {}, onError: (_) {}),
      _timelineRepository.fetchEvents().then((_) {}, onError: (_) {}),
      _wearablesRepository.fetchDailySummaries().then((_) {}, onError: (_) {}),
    ]);
  }

  Future<ClinicalDocumentDetail?> _resolveFocusedDocument(
    String? documentId,
  ) async {
    final normalizedDocumentId = documentId?.trim();
    if (normalizedDocumentId == null || normalizedDocumentId.isEmpty) {
      return null;
    }
    try {
      return await _documentsRepository.fetchDocumentDetail(
        normalizedDocumentId,
      );
    } catch (_) {
      return null;
    }
  }


OnDeviceTextPrompt _buildFocusedDocumentQuestionPrompt({
  required String question,
  required ClinicalDocumentDetail detail,
}) {
  final context = _focusedDocumentContext(detail);
  final documentDate = detail.examDate ?? DateTime.now();

  final systemPrompt = '''
You are a careful clinical document assistant.

Use only the selected document context provided by the app.
Do not invent values, dates, diagnoses, medications, or recommendations.
Do not diagnose.
Do not prescribe.
Do not suggest changing medication dosage.
If the document text is incomplete, say that clearly.
If the user asks for a summary, explain the document in simple terms.
If the user asks about abnormal lab values, mention only values present in the document.
''';

  final userPrompt = '''
User question:
$question

Selected document:
Title: ${detail.title}
Type: ${detail.documentType}
Date: ${detail.examDate?.toIso8601String() ?? 'unknown'}

Document context:
$context

Answer in the same language as the user question.
Use this structure:

Direct answer:
Key points:
Caution:
''';



  return OnDeviceTextPrompt(
    contextType: 'focused_document',
    periodStart: documentDate,
    periodEnd: documentDate,
    systemPrompt: systemPrompt,
    userPrompt: userPrompt,
    providerName: 'on_device_litertlm',
    suggestedModelFamily: 'Gemma 4',
    isCloudBypassedForThisRequest: true,
  );
}

String _focusedDocumentContext(ClinicalDocumentDetail detail) {
  final parts = <String>[];

  final ocr = detail.ocrText?.trim();
  if (ocr != null && ocr.isNotEmpty) {
    final clippedOcr = ocr.length > 6000 ? '${ocr.substring(0, 6000)}...' : ocr;
    parts.add('Extracted document text:\n$clippedOcr');
  }

  for (final panel in detail.labPanels) {
    final rows = panel.results.map((item) {
      final unit = item.unit == null || item.unit!.trim().isEmpty
          ? ''
          : ' ${item.unit}';

      final range = item.refMin != null && item.refMax != null
          ? ' (ref: ${item.refMin}-${item.refMax})'
          : '';

      final abnormal = item.abnormalFlag == true ? ' [ABNORMAL]' : '';

      return '- ${item.analyteName}: ${item.value}$unit$range$abnormal';
    }).join('\n');

    if (rows.trim().isNotEmpty) {
      parts.add('Lab panel: ${panel.panelName}\n$rows');
    }
  }

  for (final report in detail.imagingReports) {
    parts.add('''
Imaging report:
Exam type: ${report.examType ?? 'unknown'}
Body part: ${report.bodyPart ?? 'unknown'}
Impression: ${report.impression ?? 'not provided'}
Report text:
${report.reportText}
''');
  }

  if (parts.isEmpty) {
    return '''
No extracted text, lab values, or imaging report text is available for this document.

Document metadata:
Title: ${detail.title}
Type: ${detail.documentType}
Parsed status: ${detail.parsedStatus}
Processing error: ${detail.processingError ?? 'none'}
''';
  }

  return parts.join('\n\n---\n\n');
}
}
