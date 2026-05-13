# Embedding Implementation in ClinDiary (Current)

## Overview
**Gecko 110M** (via LiteRT-LM TextEmbedder) è integrato in ClinDiary per **semantic search** sui documenti locali. Fornisce embeddings vettoriali a 768 dimensioni per il matching semantico tra domande e documenti clinici.

## What We're Using

### Model Details
- **Model**: `gecko-110m-en.tflite` (LiteRT-LM TextEmbedder compatible)
- **Parameters**: ~110 million (110M)
- **Source**: Hugging Face (`litert-community/Gecko-110m-en`)
- **Runtime**: flutter_gemma / LiteRT-LM
- **Provider**: `on_device_litertlm`
- **Execution**: Entirely on-device, no cloud calls

### Tokenizer
- **File**: `tokenizer.model`
- **Source**: Hugging Face (`litert-community/Gecko-110m-en`)

## How It's Used

### 1. Document Query with Citations
**File**: [lib/features/documents/data/documents_repository.dart](lib/features/documents/data/documents_repository.dart)

When a user asks a question in **"Chiedi ai file"** (Ask files), the flow is:

```dart
// Generate embedding for the question
final questionEmbedding = await _onDeviceAiService.generateEmbedding(text: normalizedQuestion)
  .catchError((_) => <double>[]);

// For each local document, generate its embedding
final embedding = await _onDeviceAiService.generateEmbedding(text: corpus);

// Then compute cosine similarity between question and document embeddings
score = _cosineSimilarity(questionEmbedding, documentEmbedding);

// Sort documents by semantic similarity
ranked.sort((a, b) => b.score.compareTo(a.score));
```

**Result**: 
- Retrieves the **top 3-8 most semantically similar documents**
- Provides citations with relevance scores
- Uses Gemma 4 to generate an answer from the retrieved context

### 2. Semantic Scoring Algorithm

For each document, a **hybrid score** is calculated:

```dart
// Semantic search via embedding similarity
if (questionEmbedding.isNotEmpty) {
  score = _cosineSimilarity(questionEmbedding, documentEmbedding);
} else {
  // Fallback: keyword matching if embeddings fail
  score = _keywordMatchScore(...);
}

// Heuristics boost (lab/imaging relevance)
if (detail.labPanels.isNotEmpty && question.contains('lab')) {
  score += 0.8;
}
```

The **cosine similarity** formula:
```
similarity = (A · B) / (||A|| × ||B||)
```

Where `A` = question embedding, `B` = document embedding.

## Loading Strategy

The embedding model is downloaded at runtime from Hugging Face:
- `https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/gecko-110m-en.tflite`
- `https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/tokenizer.model`

Installation uses `flutter_gemma`:
```dart
await FlutterGemma.installEmbedder()
    .modelFromNetwork(geckoModelUrl)
    .tokenizerFromNetwork(geckoTokenizerUrl)
    .install();
```

The model is NOT bundled in the APK. It is downloaded on first use or installed upfront via `installGeckoEmbedding()`.

## Dart Service Integration

**File**: [lib/features/insights/data/on_device_ai_service.dart](lib/features/insights/data/on_device_ai_service.dart)

```dart
Future<List<double>> generateEmbedding({required String text}) async {
  await _ensureInitialized();
  final embedder = await _getOrCreateEmbedder();
  return embedder.generateEmbedding(text, taskType: TaskType.retrievalQuery);
}
```

## Document Query Flow (Complete)

```
User asks question
    ↓
1. Generate embedding for question (Gecko 110M via LiteRT-LM)
2. For each local document:
   a. Extract clinical fragments (lab results, OCR, imaging)
   b. Generate embedding for document (Gecko 110M)
   c. Calculate cosine similarity
   d. Apply heuristic boosts (lab/imaging relevance)
3. Rank documents by combined score
4. Take top 3-8 most relevant
5. Pass to Gemma 4 E2B (LiteRT-LM) with context
6. Gemma 4 generates answer with citations
7. Return DocumentQueryResult with citations
```

## Performance Notes

- **Embedding Generation**: ~100-200ms per text fragment (device-dependent)
- **Cosine Similarity Calculations**: O(n) where n = number of documents
- **Caching**: Document embeddings are cached in local SQLite after first generation
- **No Network**: All operations run locally on the device

## Summary

✅ **What's implemented**:
- Gecko 110M (LiteRT-LM) for semantic document search
- Downloaded at runtime from Hugging Face (not bundled in APK)
- Cosine similarity matching for question-document relevance
- Cache layer to avoid redundant embeddings
- Hybrid scoring (semantic + keyword fallback)
- Full on-device, zero cloud calls

✅ **Security & Privacy**:
- No embeddings or documents sent to external servers
- All computation happens on device
- Patient data remains on device

✅ **Failure handling**:
- If embedding generation fails → falls back to keyword search
- Gracefully degrades to title/type matching
