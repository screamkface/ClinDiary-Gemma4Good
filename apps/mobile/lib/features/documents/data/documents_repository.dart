import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/documents/data/local_document_vault_service.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';

class DocumentsRepository {
  static const int _defaultPromptCandidateCount = 3;
  static const int _maxReturnedCandidates = 8;
  static const int _maxDetailedCandidatesPerQuery = 12;

  DocumentsRepository({
    required LocalDatabase localDatabase,
    OnDeviceAiService? onDeviceAiService,
    LocalDocumentVaultService? localVaultService,
  }) : _localDatabase = localDatabase,
       _onDeviceAiService = onDeviceAiService ?? OnDeviceAiService(),
       _localVaultService = localVaultService ?? LocalDocumentVaultService();

  final LocalDatabase _localDatabase;
  final OnDeviceAiService _onDeviceAiService;
  final LocalDocumentVaultService _localVaultService;

  Future<List<ClinicalDocumentSummary>> fetchDocuments() async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchDocumentsForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<ClinicalDocumentDetail> fetchDocumentDetail(String documentId) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchDocumentDetailForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<DocumentArchiveView> fetchArchive({
    String? folderId,
    String? query,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchArchiveForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      folderId: folderId,
      query: query,
    );
  }

  Future<List<DocumentFolderItem>> fetchFolders() async {
    final scope = await _resolveLocalScope();
    return _localVaultService.fetchFoldersForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<ClinicalDocumentSummary> uploadDocument({
    required SelectedUploadDocument file,
    required Map<String, String> fields,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.uploadDocumentForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      file: file,
      fields: fields,
    );
  }

  Future<DocumentFolderItem> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.createFolderForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      name: name,
      parentFolderId: parentFolderId,
    );
  }

  Future<DocumentQueryResult> queryDocuments({
    required String question,
    String? folderId,
    int? topK,
  }) async {
    return _queryLocalDocuments(
      question: question,
      folderId: folderId,
      topK: topK,
    );
  }

  Future<int> reindexDocuments() async {
    final localDocuments = await _listLocalDocuments();
    if (localDocuments.isEmpty) {
      return 0;
    }

    final shouldWarmEmbeddings = await _onDeviceAiService
        .hasActiveEmbeddingModel()
        .catchError((_) => false);

    for (final summary in localDocuments) {
      try {
        final detail = await fetchDocumentDetail(summary.id);
        if (shouldWarmEmbeddings) {
          await _getDocumentEmbedding(detail);
        }
      } catch (_) {
        // Reindex is best-effort. Individual failures should not abort the pass.
      }
    }

    return localDocuments.length;
  }

  Future<int> reindexDocument(String documentId) async {
    try {
      final detail = await fetchDocumentDetail(documentId);
      final shouldWarmEmbeddings = await _onDeviceAiService
          .hasActiveEmbeddingModel()
          .catchError((_) => false);
      if (shouldWarmEmbeddings) {
        await _getDocumentEmbedding(detail);
      }
      return 1;
    } catch (_) {
      return 0;
    }
  }

  Future<ClinicalDocumentDetail> processDocument(String documentId) async {
    return fetchDocumentDetail(documentId);
  }

  Future<ClinicalDocumentDetail> submitManualReview(
    String documentId,
    DocumentManualReviewInput input,
  ) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.submitManualReviewForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      input: input,
    );
  }

  Future<ClinicalDocumentDetail> updateDocumentContextStatus(
    String documentId, {
    required String contextStatus,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.updateDocumentContextStatusForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      contextStatus: contextStatus,
    );
  }

  Future<void> deleteDocument(String documentId) async {
    final scope = await _resolveLocalScope();
    await _localVaultService.deleteDocumentForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  Future<ClinicalDocumentDetail> moveDocument(
    String documentId, {
    String? folderId,
  }) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.moveDocumentForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      folderId: folderId,
    );
  }

  Future<String> prepareLocalViewerFile(String documentId) async {
    final scope = await _resolveLocalScope();
    return _localVaultService.prepareViewerFileForScope(
      documentId,
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
    );
  }

  /// Query local documents using semantic search with Gecko 110M.
  ///
  /// Flow:
  /// 1. Generate embedding for user question using Gecko 110M (LiteRT-LM TextEmbedder)
  /// 2. For each local document: extract clinical fragments and generate embedding
  /// 3. Rank documents by cosine similarity between question and document embeddings
  /// 4. Pass top 3-8 most relevant documents to Gemma 4 (LiteRT) for answer generation
  /// 5. Return DocumentQueryResult with answer and citations
  ///
  /// Models used:
  /// - Embedding: Gecko 110M via LiteRT-LM (on_device_litertlm)
  /// - Generation: Gemma 4 E2B via LiteRT (on_device_litertlm)
  /// - Ranking: Local cosine similarity + heuristics (local-semantic-ranker)
  ///
  /// All processing happens on-device. No data is sent to external servers.
  Future<DocumentQueryResult> _queryLocalDocuments({
    required String question,
    String? folderId,
    int? topK,
  }) async {
    final normalizedQuestion = question.trim();
    final languageCode = await readStoredAppLanguageCode(_localDatabase);
    final isItalian = isItalianLanguageCode(languageCode);
    final searchScopeLabel = folderId == null
        ? (isItalian ? 'Tutto l\'archivio' : 'Entire archive')
        : (isItalian ? 'Cartella selezionata' : 'Selected folder');
    if (normalizedQuestion.isEmpty) {
      throw Exception(
        isItalian
            ? 'Inserisci una domanda prima di cercare nei documenti.'
            : 'Please enter a question before searching documents.',
      );
    }

    final localDocuments = await _listLocalDocuments(folderId: folderId);
    if (localDocuments.isEmpty) {
      return DocumentQueryResult(
        answer: isItalian
            ? 'Non ci sono ancora documenti disponibili. Importa almeno un file per usare Ask Files.'
            : 'No local documents are available yet. Import at least one file to use Ask Files.',
        citations: const [],
        providerName: 'on_device_litertlm',
        modelName: 'gemma-4-E2B-it.litertlm',
        embeddingModelName: 'local-keyword-index',
        rerankerModelName: 'local-heuristic-ranker',
        retrievedChunks: 0,
        retrievedDocuments: 0,
        searchScopeLabel: searchScopeLabel,
        coverageNote: isItalian
            ? 'Nessun documento utile trovato.'
            : 'No matching local documents found.',
        usedFallback: true,
      );
    }

    final ranking = await _rankLocalDocuments(
      localDocuments: localDocuments,
      question: normalizedQuestion,
    );
    final resolvedTopK = (topK ?? _defaultPromptCandidateCount).clamp(
      1,
      _maxReturnedCandidates,
    );
    final limited = ranking.candidates
        .take(resolvedTopK)
        .toList(growable: false);
    if (limited.isEmpty) {
      return DocumentQueryResult(
        answer: isItalian
            ? 'Non ho trovato informazioni rilevanti nei documenti per questa domanda. Prova ad aggiungere parole chiave come esame, data, valore o sintomo.'
            : 'I could not find relevant information in local documents for this question. Try adding key terms (exam name, date, analyte, or symptom).',
        citations: const [],
        providerName: 'on_device_litertlm',
        modelName: 'gemma-4-E2B-it.litertlm',
        embeddingModelName: _embeddingModelName(ranking.embeddingAvailable),
        rerankerModelName: _rerankerModelName(ranking.embeddingAvailable),
        retrievedChunks: 0,
        retrievedDocuments: 0,
        searchScopeLabel: searchScopeLabel,
        coverageNote: _noMatchCoverageNote(
          isItalian: isItalian,
          embeddingAvailable: ranking.embeddingAvailable,
        ),
        usedFallback: true,
      );
    }

    final citations = limited
        .map(
          (candidate) => DocumentQueryCitation(
            documentId: candidate.summary.id,
            documentTitle: candidate.summary.title,
            documentType: candidate.summary.documentType,
            folderName: candidate.summary.folderName,
            examDate: candidate.summary.examDate,
            chunkKind: candidate.chunkKind,
            chunkLabel: candidate.chunkLabel,
            excerpt: candidate.excerpt,
            score: candidate.score,
            viewerUrl: candidate.detail.viewerUrl,
          ),
        )
        .toList();

    final answer = await _generateLocalQueryAnswer(
      question: normalizedQuestion,
      candidates: limited,
      languageCode: languageCode,
    );

    return DocumentQueryResult(
      answer: answer.text,
      citations: citations,
      providerName: answer.usedFallback
          ? 'local_fallback'
          : 'on_device_litertlm',
      modelName: answer.usedFallback
          ? 'deterministic-local'
          : 'gemma-4-E2B-it.litertlm',
      embeddingModelName: _embeddingModelName(ranking.embeddingAvailable),
      rerankerModelName: _rerankerModelName(ranking.embeddingAvailable),
      retrievedChunks: limited.length,
      retrievedDocuments: limited.map((item) => item.summary.id).toSet().length,
      searchScopeLabel: searchScopeLabel,
      coverageNote: answer.usedFallback
          ? _fallbackCoverageNote(
              isItalian: isItalian,
              embeddingAvailable: ranking.embeddingAvailable,
            )
          : _successCoverageNote(
              isItalian: isItalian,
              embeddingAvailable: ranking.embeddingAvailable,
            ),
      usedFallback: answer.usedFallback,
    );
  }

  /// Generate embedding vector for clinical document using Gecko 110M.
  ///
  /// Extracts clinical fragments (title, OCR, lab results, imaging reports) and
  /// generates a semantic embedding using Gecko 110M via LiteRT-LM TextEmbedder.
  /// Results are cached in local SQLite to avoid redundant computation.
  ///
  /// Model: Gecko 110M (768-dimensional dense vectors)
  /// Provider: MediaPipe Text Embedder (on-device, no network)
  /// Cache: SQLite with key 'doc_embed_{documentId}'
  Future<List<double>> _getDocumentEmbedding(
    ClinicalDocumentDetail detail,
  ) async {
    final cacheKey = 'doc_embed_${detail.id}';
    final cached = await _localDatabase.readCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List<dynamic>;
        return decoded.map((e) => (e as num).toDouble()).toList();
      } catch (_) {}
    }

    final fragments = <String>[
      detail.title,
      detail.documentType,
      if (detail.source != null) detail.source!,
      if (detail.ocrText != null && detail.ocrText!.trim().isNotEmpty)
        detail.ocrText!,
      for (final panel in detail.labPanels)
        '${panel.panelName} ${panel.results.map((item) => '${item.analyteName} ${item.value}${item.unit == null ? '' : ' ${item.unit}'}').join(' ')}',
      for (final report in detail.imagingReports)
        '${report.examType ?? 'imaging'} ${report.bodyPart ?? ''} ${report.impression ?? report.reportText}',
    ];
    final corpus = fragments.join(' ');

    try {
      final embedding = await _onDeviceAiService.generateEmbedding(
        text: corpus,
      );
      await _localDatabase.putCache(
        key: cacheKey,
        payload: jsonEncode(embedding),
      );
      return embedding;
    } catch (_) {
      return [];
    }
  }

  /// Compute cosine similarity between two Gecko 110M vectors.
  ///
  /// Formula: similarity(A, B) = (A · B) / (||A|| × ||B||)
  /// Range: 0.0 (orthogonal/dissimilar) to 1.0 (identical)
  ///
  /// Used for ranking documents by semantic relevance to user questions.
  /// Higher scores indicate better semantic match.
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Build a ranked candidate document for local query using Gecko 110M.
  ///
  /// Scoring strategy:
  /// 1. PRIMARY: Semantic search using Gecko 110M
  ///    - Generate embeddings for both question and document
  ///    - Compute cosine similarity (0.0 to 1.0)
  /// 2. FALLBACK/BOOST: Always include keyword matching for exact demo queries
  /// 3. HEURISTICS: Boost scores for lab/imaging relevance
  ///
  /// Result score determines ranking in final answer.
  /// Candidates with score > 0 are included in top-K results.
  Future<_LocalQueryCandidate> _buildLocalQueryCandidate(
    ClinicalDocumentSummary summary,
    ClinicalDocumentDetail detail,
    String question,
    List<double> questionEmbedding,
  ) async {
    var score = 0.0;

    // Semantic search using Gecko 110M
    if (questionEmbedding.isNotEmpty) {
      final documentEmbedding = await _getDocumentEmbedding(detail);
      score = _cosineSimilarity(questionEmbedding, documentEmbedding);
    }

    score += _keywordScore(summary, detail, question);

    final excerpt = _buildExcerpt(detail);
    return _LocalQueryCandidate(
      summary: summary,
      detail: detail,
      score: score,
      excerpt: excerpt,
      chunkKind: detail.labPanels.isNotEmpty
          ? 'lab_panel'
          : detail.imagingReports.isNotEmpty
          ? 'imaging_report'
          : 'ocr_text',
      chunkLabel: detail.labPanels.isNotEmpty
          ? detail.labPanels.first.panelName
          : detail.imagingReports.isNotEmpty
          ? detail.imagingReports.first.examType
          : 'Extracted text',
    );
  }

  double _keywordScore(
    ClinicalDocumentSummary summary,
    ClinicalDocumentDetail detail,
    String question,
  ) {
    var score = 0.0;
    final fragments = <String>[
      summary.title,
      summary.documentType,
      if (summary.source != null) summary.source!,
      if (detail.ocrText != null && detail.ocrText!.trim().isNotEmpty)
        detail.ocrText!,
      for (final panel in detail.labPanels)
        '${panel.panelName} ${panel.results.map((item) => '${item.analyteName} ${item.value}${item.unit == null ? '' : ' ${item.unit}'}').join(' ')}',
      for (final report in detail.imagingReports)
        '${report.examType ?? 'imaging'} ${report.bodyPart ?? ''} ${report.impression ?? report.reportText}',
    ];

    final corpus = fragments.join(' ').toLowerCase();
    final normalizedQuestion = question.toLowerCase();
    final tokens = normalizedQuestion
        .split(RegExp(r'[^a-z0-9]+'))
        .where((item) => item.trim().length >= 3)
        .toSet();

    for (final token in tokens) {
      if (corpus.contains(token)) {
        score += 1.0;
      }
    }

    if (summary.title.toLowerCase().contains(normalizedQuestion)) {
      score += 2.0;
    }
    if (detail.labPanels.isNotEmpty && normalizedQuestion.contains('lab')) {
      score += 0.8;
    }
    if (detail.imagingReports.isNotEmpty &&
        normalizedQuestion.contains('imaging')) {
      score += 0.8;
    }
    return score;
  }

  Future<_GeneratedLocalQueryAnswer> _generateLocalQueryAnswer({
    required String question,
    required List<_LocalQueryCandidate> candidates,
    required String languageCode,
  }) async {
    final isItalian = isItalianLanguageCode(languageCode);
    final context = candidates
        .asMap()
        .entries
        .map(
          (entry) =>
              '[${entry.key + 1}] ${entry.value.summary.title}: ${entry.value.excerpt}',
        )
        .join('\n\n');

    final systemPrompt = isItalian
        ? 'Sei un assistente clinico prudente. Usa solo il contesto dei documenti locali fornito. Non inventare dati e segnala chiaramente l\'incertezza quando le informazioni sono incomplete. Quando vedi valori segnati con [ABNORMAL] o intervalli di riferimento come (ref: 70-100), devi indicarli esplicitamente come fuori intervallo. Se l\'utente chiede valori alterati o fuori range, elencali in modo chiaro. Non dire "nessun valore alterato" se i documenti contengono valori marcati [ABNORMAL].'
        : 'You are a careful clinical assistant. Use only the provided local document context. Do not invent data, and clearly mention uncertainty when information is incomplete. When you see lab values marked with [ABNORMAL] or reference ranges like (ref: 70-100), you MUST identify and clearly report these as out-of-range values in your answer. If the user asks about abnormal/out-of-range values, explicitly list which values are abnormal. Do not say "no abnormal values" if the documents contain values marked [ABNORMAL].';
    final userPrompt = isItalian
        ? 'Domanda: $question\n\n'
              'Contesto dei documenti locali:\n$context\n\n'
              'IMPORTANTE: I valori di laboratorio marcati con [ABNORMAL] sono fuori intervallo. Gli intervalli di riferimento sono mostrati come (ref: min-max). Se la domanda riguarda valori alterati o fuori range, riportali sempre in modo esplicito.\n\n'
              'Scrivi una risposta concisa in italiano usando solo testo semplice.\n'
              'Non usare Markdown, LaTeX, \$, blocchi di codice o formattazioni speciali.\n'
              'Usa esattamente queste righe:\n'
              'Risposta diretta: ...\n'
              'Punti chiave: ...\n'
              'Nota di cautela: ...'
        : 'Question: $question\n\n'
              'Local document context:\n$context\n\n'
              'IMPORTANT: Lab values marked with [ABNORMAL] are out of range. Reference ranges are shown as (ref: min-max). If the question asks about abnormal/out-of-range values, always explicitly report them.\n\n'
              'Write a concise answer in English using plain text only.\n'
              'Do not use Markdown, LaTeX, \$, code fences, or special formatting markers.\n'
              'Use exactly these lines:\n'
              'Direct answer: ...\n'
              'Key findings: ...\n'
              'Caution: ...';

    try {
      return _GeneratedLocalQueryAnswer(
        text: await _onDeviceAiService.generateText(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        ),
        usedFallback: false,
      );
    } catch (_) {
      final top = candidates.first;
      return _GeneratedLocalQueryAnswer(
        text: _fallbackLocalQueryAnswer(isItalian: isItalian, top: top),
        usedFallback: true,
      );
    }
  }

  /// Same as [queryDocuments] but streams answer tokens in real time.
  /// The returned [QueryDocumentsStreamResult.result] completes once streaming finishes.
  Future<QueryDocumentsStreamResult> queryDocumentsStream({
    required String question,
    String? folderId,
  }) async {
    final normalizedQuestion = question.trim();
    final languageCode = await readStoredAppLanguageCode(_localDatabase);
    final localDocuments = await _listLocalDocuments(folderId: folderId);
    final hasLocalDocuments = localDocuments.isNotEmpty;

    // Phase 1: embedding, ranking, prompt building (no streaming)
    final ranking = await _rankLocalDocuments(
      localDocuments: localDocuments,
      question: normalizedQuestion,
    );
    final candidates = ranking.candidates;

    if (candidates.isEmpty) {
      return QueryDocumentsStreamResult.identity(
        answer: !hasLocalDocuments
            ? (languageCode == 'it'
                  ? 'Non ci sono ancora documenti disponibili.'
                  : 'No local documents are available yet.')
            : (languageCode == 'it'
                  ? 'Non ho trovato informazioni rilevanti nei documenti per questa domanda. Prova ad aggiungere parole chiave come esame, data, valore o sintomo.'
                  : 'I could not find relevant information in local documents for this question. Try adding key terms like exam, date, value, or symptom.'),
        languageCode: languageCode,
        hasMatchingDocuments: hasLocalDocuments,
      );
    }

    final limited = candidates
        .take(_defaultPromptCandidateCount)
        .toList(growable: false);

    // Build the prompt
    final context = limited
        .asMap()
        .entries
        .map(
          (entry) =>
              '[${entry.key + 1}] ${entry.value.summary.title}: ${entry.value.excerpt}',
        )
        .join('\n\n');

    final isItalian = isItalianLanguageCode(languageCode);
    final systemPrompt = isItalian
        ? 'Sei un assistente clinico prudente. Usa solo il contesto dei documenti locali fornito. Non inventare dati e segnala chiaramente l\'incertezza quando le informazioni sono incomplete. Quando vedi valori segnati con [ABNORMAL] o intervalli di riferimento come (ref: 70-100), devi indicarli esplicitamente come fuori intervallo. Se l\'utente chiede valori alterati o fuori range, elencali in modo chiaro. Non dire "nessun valore alterato" se i documenti contengono valori marcati [ABNORMAL].'
        : 'You are a careful clinical assistant. Use only the provided local document context. Do not invent data, and clearly mention uncertainty when information is incomplete. When you see lab values marked with [ABNORMAL] or reference ranges like (ref: 70-100), you MUST identify and clearly report these as out-of-range values in your answer. If the user asks about abnormal/out-of-range values, explicitly list which values are abnormal. Do not say "no abnormal values" if the documents contain values marked [ABNORMAL].';
    final userPrompt = isItalian
        ? 'Domanda: $question\n\n'
              'Contesto dei documenti locali:\n$context\n\n'
              'IMPORTANTE: I valori di laboratorio marcati con [ABNORMAL] sono fuori intervallo. Gli intervalli di riferimento sono mostrati come (ref: min-max). Se la domanda riguarda valori alterati o fuori range, riportali sempre in modo esplicito.\n\n'
              'Scrivi una risposta concisa in italiano.\n'
              'Usa esattamente queste righe:\n'
              'Risposta diretta: ...\n'
              'Punti chiave: ...\n'
              'Nota di cautela: ...'
        : 'Question: $question\n\n'
              'Local document context:\n$context\n\n'
              'IMPORTANT: Lab values marked with [ABNORMAL] are out of range. Reference ranges are shown as (ref: min-max). If the question asks about abnormal/out-of-range values, always explicitly report them.\n\n'
              'Write a concise answer in English.\n'
              'Use exactly these lines:\n'
              'Direct answer: ...\n'
              'Key findings: ...\n'
              'Caution: ...';

    // Phase 2: stream answer from the LLM
    final answerController = StreamController<String>();
    final resultCompleter = Completer<DocumentQueryResult>();
    final answerBuffer = StringBuffer();
    final citations = _citationsForCandidates(limited);

    _onDeviceAiService
        .generateTextStream(systemPrompt: systemPrompt, userPrompt: userPrompt)
        .listen(
          (token) {
            answerBuffer.write(token);
            answerController.add(token);
          },
          onDone: () async {
            if (resultCompleter.isCompleted) {
              if (!answerController.isClosed) {
                await answerController.close();
              }
              return;
            }

            var answer = answerBuffer.toString().trim();
            var usedFallback = false;
            if (answer.isEmpty) {
              usedFallback = true;
              answer = _fallbackLocalQueryAnswer(
                isItalian: isItalian,
                top: limited.first,
              );
              if (!answerController.isClosed) {
                answerController.add(answer);
              }
            }

            if (!answerController.isClosed) {
              await answerController.close();
            }

            resultCompleter.complete(
              DocumentQueryResult(
                answer: answer,
                citations: citations,
                providerName: usedFallback
                    ? 'local_fallback'
                    : 'on_device_litertlm',
                modelName: usedFallback
                    ? 'deterministic-local'
                    : 'gemma-4-E2B-it.litertlm',
                embeddingModelName: _embeddingModelName(
                  ranking.embeddingAvailable,
                ),
                rerankerModelName: _rerankerModelName(
                  ranking.embeddingAvailable,
                ),
                retrievedChunks: limited.length,
                retrievedDocuments: limited
                    .map((item) => item.summary.id)
                    .toSet()
                    .length,
                searchScopeLabel: folderId == null
                    ? (isItalian ? 'Tutto l\'archivio' : 'Entire archive')
                    : (isItalian ? 'Cartella selezionata' : 'Selected folder'),
                coverageNote: usedFallback
                    ? _fallbackCoverageNote(
                        isItalian: isItalian,
                        embeddingAvailable: ranking.embeddingAvailable,
                      )
                    : _successCoverageNote(
                        isItalian: isItalian,
                        embeddingAvailable: ranking.embeddingAvailable,
                      ),
                usedFallback: usedFallback,
              ),
            );
          },
          onError: (error) {
            final fallbackAnswer = _fallbackLocalQueryAnswer(
              isItalian: isItalian,
              top: limited.first,
            );
            if (answerBuffer.length == 0 && !answerController.isClosed) {
              answerController.add(fallbackAnswer);
            }
            if (!answerController.isClosed) {
              answerController.close();
            }
            if (!resultCompleter.isCompleted) {
              resultCompleter.complete(
                DocumentQueryResult(
                  answer: answerBuffer.length == 0
                      ? fallbackAnswer
                      : answerBuffer.toString().trim(),
                  citations: citations,
                  providerName: 'local_fallback',
                  modelName: 'deterministic-local',
                  embeddingModelName: _embeddingModelName(
                    ranking.embeddingAvailable,
                  ),
                  rerankerModelName: _rerankerModelName(
                    ranking.embeddingAvailable,
                  ),
                  retrievedChunks: limited.length,
                  retrievedDocuments: limited
                      .map((item) => item.summary.id)
                      .toSet()
                      .length,
                  searchScopeLabel: folderId == null
                      ? (isItalian ? 'Tutto l\'archivio' : 'Entire archive')
                      : (isItalian
                            ? 'Cartella selezionata'
                            : 'Selected folder'),
                  coverageNote: _fallbackCoverageNote(
                    isItalian: isItalian,
                    embeddingAvailable: ranking.embeddingAvailable,
                  ),
                  usedFallback: true,
                ),
              );
            }
          },
        );

    return QueryDocumentsStreamResult(
      answerStream: answerController.stream,
      result: resultCompleter.future,
    );
  }

  List<DocumentQueryCitation> _citationsForCandidates(
    List<_LocalQueryCandidate> candidates,
  ) {
    return candidates
        .map(
          (c) => DocumentQueryCitation(
            documentId: c.summary.id,
            documentTitle: c.summary.title,
            documentType: c.summary.documentType,
            folderName: c.summary.folderName,
            examDate: c.summary.examDate,
            chunkKind: c.chunkKind,
            chunkLabel: c.chunkLabel,
            excerpt: c.excerpt,
            score: c.score,
            viewerUrl: c.detail.viewerUrl,
          ),
        )
        .toList();
  }

  String _fallbackLocalQueryAnswer({
    required bool isItalian,
    required _LocalQueryCandidate top,
  }) {
    return isItalian
        ? 'In base ai documenti locali, il file piu rilevante e "${top.summary.title}". Evidenza principale: ${top.excerpt}. Controlla i passaggi citati per il contesto completo prima di prendere decisioni cliniche.'
        : 'Based on local documents, the most relevant file is "${top.summary.title}". Key extracted evidence: ${top.excerpt}. Review the cited snippets for full context before making clinical decisions.';
  }

  /// Embedding + ranking phase (shared between streaming and non-streaming paths).
  Future<_RankedLocalDocuments> _rankLocalDocuments({
    required List<ClinicalDocumentSummary> localDocuments,
    required String question,
  }) async {
    if (localDocuments.isEmpty) {
      return const _RankedLocalDocuments(
        candidates: <_LocalQueryCandidate>[],
        embeddingAvailable: false,
      );
    }

    final shortlisted = _shortlistDocumentsForQuery(localDocuments, question);

    final questionEmbedding = await _onDeviceAiService
        .generateEmbedding(text: question)
        .catchError((_) => <double>[]);
    final embeddingAvailable = questionEmbedding.isNotEmpty;

    final details = await Future.wait(
      shortlisted.map((summary) async {
        try {
          return await fetchDocumentDetail(summary.id);
        } catch (_) {
          return null;
        }
      }),
    );

    final ranked = <_LocalQueryCandidate>[];
    for (var index = 0; index < shortlisted.length; index++) {
      final detail = details[index];
      if (detail == null) {
        continue;
      }
      final summary = shortlisted[index];
      final candidate = await _buildLocalQueryCandidate(
        summary,
        detail,
        question,
        questionEmbedding,
      );
      if (candidate.score > 0) {
        ranked.add(candidate);
      }
    }

    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      return b.summary.uploadDate.compareTo(a.summary.uploadDate);
    });

    return _RankedLocalDocuments(
      candidates: ranked.take(_maxReturnedCandidates).toList(growable: false),
      embeddingAvailable: embeddingAvailable,
    );
  }

  Future<List<ClinicalDocumentSummary>> _listLocalDocuments({
    String? folderId,
  }) async {
    final scope = await _resolveLocalScope();
    final archive = await _localVaultService.fetchArchiveForScope(
      userScopeId: scope.userId,
      profileScopeId: scope.profileId,
      folderId: folderId,
      query: null,
    );
    return archive.documents
        .where((item) => item.isLocal)
        .toList(growable: false);
  }

  List<ClinicalDocumentSummary> _shortlistDocumentsForQuery(
    List<ClinicalDocumentSummary> documents,
    String question,
  ) {
    if (documents.length <= _maxDetailedCandidatesPerQuery) {
      return documents;
    }

    final normalizedQuestion = question.trim().toLowerCase();
    final tokens = normalizedQuestion
        .split(RegExp(r'[^a-z0-9]+'))
        .where((item) => item.trim().length >= 3)
        .toSet();
    if (tokens.isEmpty) {
      return documents
          .take(_maxDetailedCandidatesPerQuery)
          .toList(growable: false);
    }

    final scored =
        documents
            .map(
              (document) => (
                summary: document,
                score: _summaryKeywordScore(
                  document,
                  normalizedQuestion,
                  tokens,
                ),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final scoreOrder = b.score.compareTo(a.score);
            if (scoreOrder != 0) {
              return scoreOrder;
            }
            return b.summary.uploadDate.compareTo(a.summary.uploadDate);
          });

    final selected = <ClinicalDocumentSummary>[];
    for (final item in scored) {
      if (item.score <= 0 && selected.isNotEmpty) {
        continue;
      }
      selected.add(item.summary);
      if (selected.length >= _maxDetailedCandidatesPerQuery) {
        return selected;
      }
    }

    for (final document in documents) {
      if (selected.any((item) => item.id == document.id)) {
        continue;
      }
      selected.add(document);
      if (selected.length >= _maxDetailedCandidatesPerQuery) {
        break;
      }
    }

    return selected;
  }

  double _summaryKeywordScore(
    ClinicalDocumentSummary summary,
    String normalizedQuestion,
    Set<String> tokens,
  ) {
    var score = 0.0;
    final haystack = [
      summary.title,
      summary.documentType,
      summary.source,
      summary.folderName,
      summary.originalFilename,
    ].whereType<String>().join(' ').toLowerCase();

    for (final token in tokens) {
      if (haystack.contains(token)) {
        score += 1.0;
      }
    }

    if (summary.title.toLowerCase().contains(normalizedQuestion)) {
      score += 2.0;
    }
    if (haystack.contains(normalizedQuestion)) {
      score += 1.5;
    }
    if (summary.documentType.toLowerCase().contains('lab') &&
        normalizedQuestion.contains('lab')) {
      score += 0.8;
    }
    if (summary.documentType.toLowerCase().contains('imaging') &&
        normalizedQuestion.contains('imaging')) {
      score += 0.8;
    }

    return score;
  }

  String _embeddingModelName(bool embeddingAvailable) {
    return embeddingAvailable ? 'gecko-110m-en' : 'local-keyword-index';
  }

  String _rerankerModelName(bool embeddingAvailable) {
    return embeddingAvailable
        ? 'local-semantic-ranker'
        : 'local-keyword-ranker';
  }

  String _successCoverageNote({
    required bool isItalian,
    required bool embeddingAvailable,
  }) {
    if (embeddingAvailable) {
      return isItalian
          ? 'Risposta generata da estratti locali dei documenti.'
          : 'Answer generated from local encrypted document snippets.';
    }
    return isItalian
        ? 'Risposta generata da estratti locali dei documenti con ranking a parole chiave, perche il modello di embedding non era disponibile.'
        : 'Answer generated from local encrypted document snippets using keyword ranking because the embedding model was unavailable.';
  }

  String _fallbackCoverageNote({
    required bool isItalian,
    required bool embeddingAvailable,
  }) {
    if (embeddingAvailable) {
      return isItalian
          ? 'Gemma non ha prodotto una risposta utile in tempo: e stata costruita una risposta locale dagli estratti citati.'
          : 'Gemma did not produce a useful answer in time: a local fallback was built from cited snippets.';
    }
    return isItalian
        ? 'Gemma non ha prodotto una risposta utile in tempo e il modello di embedding non era disponibile: e stata costruita una risposta locale con ranking a parole chiave.'
        : 'Gemma did not produce a useful answer in time and the embedding model was unavailable: a local keyword-ranked fallback was built from cited snippets.';
  }

  String _noMatchCoverageNote({
    required bool isItalian,
    required bool embeddingAvailable,
  }) {
    if (embeddingAvailable) {
      return isItalian
          ? 'Nessun estratto rilevante trovato nei documenti.'
          : 'No relevant excerpts were found in local documents.';
    }
    return isItalian
        ? 'Nessun estratto rilevante trovato nei documenti con il ranking a parole chiave.'
        : 'No relevant excerpts were found in local documents with keyword ranking.';
  }

  Future<_LocalVaultScope> _resolveLocalScope() async {
    final userId =
        await _localDatabase.readCache(activeUserIdCacheKey) ?? 'anonymous';
    final profileId = await _localDatabase.readCache(activeProfileIdCacheKey);
    return _LocalVaultScope(userId: userId, profileId: profileId);
  }
}

class _LocalQueryCandidate {
  const _LocalQueryCandidate({
    required this.summary,
    required this.detail,
    required this.score,
    required this.excerpt,
    required this.chunkKind,
    required this.chunkLabel,
  });

  final ClinicalDocumentSummary summary;
  final ClinicalDocumentDetail detail;
  final double score;
  final String excerpt;
  final String chunkKind;
  final String? chunkLabel;
}

class _RankedLocalDocuments {
  const _RankedLocalDocuments({
    required this.candidates,
    required this.embeddingAvailable,
  });

  final List<_LocalQueryCandidate> candidates;
  final bool embeddingAvailable;
}

class _GeneratedLocalQueryAnswer {
  const _GeneratedLocalQueryAnswer({
    required this.text,
    required this.usedFallback,
  });

  final String text;
  final bool usedFallback;
}

String _buildExcerpt(ClinicalDocumentDetail detail) {
  if (detail.labPanels.isNotEmpty) {
    final panel = detail.labPanels.first;
    final values = panel.results
        .take(3)
        .map((item) {
          final unit = item.unit == null ? '' : ' ${item.unit}';
          final range = item.refMin != null && item.refMax != null
              ? ' (ref: ${item.refMin}-${item.refMax})'
              : '';
          final abnormalLabel = item.abnormalFlag == true ? ' [ABNORMAL]' : '';
          return '${item.analyteName}: ${item.value}$unit$range$abnormalLabel';
        })
        .join('; ');
    return '${panel.panelName}. $values';
  }

  if (detail.imagingReports.isNotEmpty) {
    final report = detail.imagingReports.first;
    final impression = report.impression?.trim();
    if (impression != null && impression.isNotEmpty) {
      return impression;
    }
    return report.reportText;
  }

  final ocrText = detail.ocrText?.trim();
  if (ocrText != null && ocrText.isNotEmpty) {
    return ocrText.length > 320 ? '${ocrText.substring(0, 320)}...' : ocrText;
  }

  return 'No extractable text available.';
}

class _LocalVaultScope {
  const _LocalVaultScope({required this.userId, required this.profileId});

  final String userId;
  final String? profileId;
}

class QueryDocumentsStreamResult {
  const QueryDocumentsStreamResult({
    required this.answerStream,
    required this.result,
  });

  factory QueryDocumentsStreamResult.identity({
    required String answer,
    required String languageCode,
    bool hasMatchingDocuments = false,
  }) {
    final controller = StreamController<String>();
    controller.add(answer);
    controller.close();
    return QueryDocumentsStreamResult(
      answerStream: controller.stream,
      result: Future.value(
        DocumentQueryResult(
          answer: answer,
          citations: const [],
          providerName: 'on_device_litertlm',
          modelName: 'gemma-4-E2B-it.litertlm',
          embeddingModelName: 'gecko-110m-en',
          rerankerModelName: 'local-heuristic-ranker',
          retrievedChunks: 0,
          retrievedDocuments: 0,
          searchScopeLabel: languageCode == 'it'
              ? 'Tutto l\'archivio'
              : 'Entire archive',
          coverageNote: hasMatchingDocuments
              ? (languageCode == 'it'
                    ? 'Nessun estratto rilevante trovato nei documenti.'
                    : 'No relevant excerpts were found in local documents.')
              : (languageCode == 'it'
                    ? 'Nessun documento utile trovato.'
                    : 'No matching local documents found.'),
          usedFallback: true,
        ),
      ),
    );
  }

  final Stream<String> answerStream;
  final Future<DocumentQueryResult> result;
}
