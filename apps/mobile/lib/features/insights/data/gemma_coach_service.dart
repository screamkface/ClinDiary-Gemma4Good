import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:clindiary/features/insights/domain/on_device_text_prompt.dart';

class GemmaCoachService {
  GemmaCoachService({
    required OnDeviceAiService onDeviceAiService,
    required OnDevicePromptBuilder onDevicePromptBuilder,
    required DocumentsRepository documentsRepository,
  }) : _onDeviceAiService = onDeviceAiService,
       _onDevicePromptBuilder = onDevicePromptBuilder,
       _documentsRepository = documentsRepository;

  final OnDeviceAiService _onDeviceAiService;
  final OnDevicePromptBuilder _onDevicePromptBuilder;
  final DocumentsRepository _documentsRepository;

  Future<String> answerQuestion({
    required String question,
    DateTime? referenceDate,
  }) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw Exception('Scrivi una domanda piu precisa.');
    }

    final prompt = await _onDevicePromptBuilder.buildClinicalQuestionPrompt(
      question: normalizedQuestion,
      referenceDate: referenceDate ?? DateTime.now(),
    );
    return _generate(prompt);
  }

  Future<String> explainTrend({DateTime? referenceDate}) async {
    final prompt = await _onDevicePromptBuilder.buildTrendExplanationPrompt(
      referenceDate: referenceDate ?? DateTime.now(),
    );
    return _generate(prompt);
  }

  Future<String> buildPreVisitBrief({DateTime? referenceDate}) async {
    final prompt = await _onDevicePromptBuilder.buildPreVisitBriefPrompt(
      referenceDate: referenceDate ?? DateTime.now(),
    );
    return _generate(prompt);
  }

  Future<String> summarizeDocument({required ClinicalDocumentDetail detail}) async {
    final prompt = await _onDevicePromptBuilder.buildDocumentSummaryPrompt(
      detail: detail,
    );
    return _generate(prompt);
  }

  Future<String> summarizeDocumentById(String documentId) async {
    final detail = await _documentsRepository.fetchDocumentDetail(documentId);
    return summarizeDocument(detail: detail);
  }

  Future<String> _generate(OnDeviceTextPrompt? prompt) async {
    if (prompt == null) {
      throw Exception('Non ho abbastanza dati locali per generare una risposta utile.');
    }
    return _onDeviceAiService.generateText(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
    );
  }
}
