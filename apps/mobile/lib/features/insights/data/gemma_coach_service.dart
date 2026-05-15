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

    final prompt = await _onDevicePromptBuilder.buildClinicalQuestionPrompt(
      question: normalizedQuestion,
      referenceDate: referenceDate ?? DateTime.now(),
      focusedDocument: focusedDocument,
    );
    if (prompt != null) {
      yield* _onDeviceAiService.generateTextStream(
        systemPrompt: prompt.systemPrompt,
        userPrompt: prompt.userPrompt,
      );
      return;
    }

    await _warmUpClinicalContext();
    final refreshedPrompt = await _onDevicePromptBuilder
        .buildClinicalQuestionPrompt(
          question: normalizedQuestion,
          referenceDate: referenceDate ?? DateTime.now(),
          focusedDocument: focusedDocument,
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
}
