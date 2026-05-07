# Embedding Gemma Implementation in ClinDiary

## Overview
**Embedding Gemma 300M** (via MediaPipe TextEmbedder) è integrato in ClinDiary per **semantic search** sui documenti locali. Fornisce embeddings vettoriali ad alta dimensione per il matching semantico tra domande e documenti clinici.

## What We're Using

### Model Details
- **Model**: `embeddinggemma-300m.tflite` (MediaPipe TextEmbedder compatible)
- **File Size**: ~170 MB
- **Location**: Bundled in `apps/mobile/assets/models/`
- **Runtime**: Android MediaPipe Text Embedder
- **Provider**: `on_device_mediapipe`
- **Execution**: Entirely on-device, no cloud calls

## How It's Used

### 1. Document Query with Citations
**File**: [lib/features/documents/data/documents_repository.dart](lib/features/documents/data/documents_repository.dart)

When a user asks a question in **"Chiedi ai file"** (Ask files), the flow is:

```dart
// Line 202: Generate embedding for the question
final questionEmbedding = await _onDeviceAiService.generateEmbedding(text: normalizedQuestion)
  .catchError((_) => <double>[]);

// Lines 289-314: For each local document, generate its embedding
final embedding = await _onDeviceAiService.generateEmbedding(text: corpus);

// Lines 334+: Compute cosine similarity between question and document embeddings
score = _cosineSimilarity(questionEmbedding, documentEmbedding);

// Sort documents by semantic similarity
ranked.sort((a, b) => b.score.compareTo(a.score));
```

**Result**: 
- Retrieves the **top 3-8 most semantically similar documents**
- Provides citations with relevance scores
- Uses Gemma 4 to generate an answer from the retrieved context

### 2. Semantic Scoring Algorithm
**File**: [lib/features/documents/data/documents_repository.dart](lib/features/documents/data/documents_repository.dart) (lines 334-376)

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

### Fallback Mechanism
**File**: [lib/features/insights/data/on_device_ai_service.dart](lib/features/insights/data/on_device_ai_service.dart)

The `downloadEmbeddingModel()` function now:

1. **First attempts**: Load from bundled assets (`_copyEmbeddingModelFromAssets()`)
   - ✅ Fast (~170 MB extracted from APK)
   - ✅ No network dependency
   - ✅ Avoids Hugging Face 401 auth errors

2. **Fallback**: Download from Hugging Face if asset not present
   - Downloads from: `https://huggingface.co/litert-community/embeddinggemma-300m/`
   - Requires Hugging Face authentication token

### Asset Bundle Configuration
**File**: [pubspec.yaml](apps/mobile/pubspec.yaml)

```yaml
flutter:
  assets:
    - assets/legal/
    - assets/models/  # ← includes embeddinggemma-300m.tflite
```

## Android Runtime

### MediaPipe Text Embedder
**File**: [android/app/src/main/kotlin/it/clindiary/clindiary/OnDeviceEmbeddingRuntime.kt](android/app/src/main/kotlin/it/clindiary/clindiary/OnDeviceEmbeddingRuntime.kt)

```kotlin
// Creates a TextEmbedder from the .tflite model file
private fun createEmbedder(modelFile: File): TextEmbedder {
    val baseOptions = BaseOptions.builder()
        .setModelAssetPath(modelFile.absolutePath)
        .build()
    
    val options = TextEmbedder.TextEmbedderOptions.builder()
        .setBaseOptions(baseOptions)
        .build()
    
    return TextEmbedder.createFromOptions(context, options)
}

// Generates a vector embedding for text
fun generateEmbedding(modelPath: String?, text: String): Map<String, Any?> {
    val embedderInstance = ensureEmbedder(modelFile)
    val result = embedderInstance.embed(text)
    val embedding = result.embeddingResult().embeddings().firstOrNull()
    
    return mapOf(
        "embedding" to embedding.floatEmbedding().toList(),
        "model_name" to "embeddinggemma-300m",
        "provider_name" to "on_device_mediapipe"
    )
}
```

## Dart Service Integration

**File**: [lib/features/insights/data/on_device_ai_service.dart](lib/features/insights/data/on_device_ai_service.dart)

```dart
Future<List<double>> generateEmbedding({
  required String text,
  String? modelPath,
}) async {
  final response = await _invokePrompt('generateEmbedding', {
    'text': text,
    if (modelPath != null) 'modelPath': modelPath,
  });
  
  final rawEmbedding = response['embedding'] as List<dynamic>;
  return rawEmbedding.map((e) => (e as num).toDouble()).toList();
}
```

## Document Query Flow (Complete)

```
User asks question
    ↓
1. Generate embedding for question (Embedding Gemma)
2. For each local document:
   a. Extract clinical fragments (lab results, OCR, imaging)
   b. Generate embedding for document (Embedding Gemma)
   c. Calculate cosine similarity
   d. Apply heuristic boosts (lab/imaging relevance)
3. Rank documents by combined score
4. Take top 3-8 most relevant
5. Pass to Gemma 4 (LiteRT) with context
6. Gemma 4 generates answer with citations
7. Return DocumentQueryResult with:
   - answer: Gemma 4 generated text
   - citations: Top matched documents + excerpts
   - providerName: "on_device_litertlm"
   - embeddingModelName: "on_device_mediapipe"
   - rerankerModelName: "local-semantic-ranker"
```

## Performance Notes

- **Embedding Generation**: ~100-200ms per text fragment (device-dependent)
- **Cosine Similarity Calculations**: O(n) where n = number of documents
- **Caching**: Document embeddings are cached in local SQLite after first generation
- **No Network**: All operations run locally on the device

## UI Integration

### Document Query Screen
**File**: [lib/features/documents/presentation/document_query_screen.dart](lib/features/documents/presentation/document_query_screen.dart)

Shows embedding model info in results:
```dart
if (_result!.embeddingModelName != null)
  Chip(label: Text('Embedding: ${_result!.embeddingModelName}'))
  // Displays: "Embedding: on_device_mediapipe"
```

## Summary

✅ **What's implemented**:
- Embedding Gemma 300M (MediaPipe) for semantic document search
- Bundled in app assets (no download needed)
- Cosine similarity matching for question-document relevance
- Cache layer to avoid redundant embeddings
- Hybrid scoring (semantic + keyword fallback)
- Full on-device, zero cloud calls

✅ **Security & Privacy**:
- No embeddings or documents sent to external servers
- All computation happens on Android device
- Embedded in encrypted local SQLite database
- Patient data remains on device

✅ **Failure handling**:
- If embedding generation fails → falls back to keyword search
- Gracefully degrades to title/type matching
- User can still get answers, just with lower accuracy
