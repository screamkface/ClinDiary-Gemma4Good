package it.clindiary.clindiary

import android.content.Context
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import java.io.File

class OnDeviceEmbeddingRuntime(
    private val context: Context,
) {
    private var embedder: TextEmbedder? = null
    private var loadedModelPath: String? = null
    private var lastError: String? = null

    @Synchronized
    fun getStatus(modelPath: String?): Map<String, Any?> {
        val modelFile = resolveModelFile(modelPath)
        val modelName = modelFile?.nameWithoutExtensionSafe()
        var isReady = false
        var statusError = lastError

        if (modelFile != null) {
            try {
                ensureEmbedder(modelFile)
                isReady = true
                statusError = null
            } catch (t: Throwable) {
                statusError = t.message ?: t::class.java.simpleName
                lastError = statusError
            }
        }

        return mapOf(
            "isSupported" to true,
            "isReady" to isReady,
            "runtime" to "MediaPipe Text Embedder",
            "provider" to "on_device_mediapipe",
            "activeProviderLabel" to if (isReady) "Local Embedding Ready" else "Embedding Not Ready",
            "modelName" to modelName,
            "modelPath" to modelFile?.absolutePath,
            "lastError" to statusError
        )
    }

    @Synchronized
    fun generateEmbedding(
        modelPath: String?,
        text: String,
    ): Map<String, Any?> {
        val modelFile = resolveModelFile(modelPath)
            ?: throw IllegalStateException(
                "Nessun modello di embedding trovato. Copia il file .tflite in ${defaultModelDirectory()?.absolutePath ?: "files/models"}."
            )

        val embedderInstance = ensureEmbedder(modelFile)

        try {
            val result = embedderInstance.embed(text)
            val embedding = result.embeddingResult().embeddings().firstOrNull()
                ?: throw IllegalStateException("L'embedder non ha restituito alcun vettore.")

            val floatArray = embedding.floatEmbedding()?.toList()
                ?: throw IllegalStateException("Il modello non ha restituito un embedding float.")

            return mapOf(
                "embedding" to floatArray,
                "model_name" to modelFile.nameWithoutExtensionSafe(),
                "provider_name" to "on_device_mediapipe"
            )
        } catch (t: Throwable) {
            lastError = t.message ?: t::class.java.simpleName
            throw t
        }
    }

    @Synchronized
    fun close() {
        embedder?.close()
        embedder = null
        loadedModelPath = null
    }

    private fun ensureEmbedder(modelFile: File): TextEmbedder {
        val currentEmbedder = embedder
        if (currentEmbedder != null && loadedModelPath == modelFile.absolutePath) {
            return currentEmbedder
        }

        close()
        val newEmbedder = createEmbedder(modelFile)
        embedder = newEmbedder
        loadedModelPath = modelFile.absolutePath
        lastError = null
        return newEmbedder
    }

    private fun createEmbedder(modelFile: File): TextEmbedder {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(modelFile.absolutePath)
                .build()

            val options = TextEmbedder.TextEmbedderOptions.builder()
                .setBaseOptions(baseOptions)
                .build()

            return TextEmbedder.createFromOptions(context, options)
        } catch (t: Throwable) {
            val message = "Impossibile inizializzare TextEmbedder: ${t.message ?: t::class.java.simpleName}"
            lastError = message
            throw IllegalStateException(message)
        }
    }

    private fun resolveModelFile(modelPath: String?): File? {
        val explicitPath = modelPath?.trim().orEmpty()
        if (explicitPath.isNotEmpty()) {
            val explicitFile = File(explicitPath)
            if (explicitFile.exists() && explicitFile.isFile) {
                return explicitFile
            }
        }

        val candidateDirectories = listOfNotNull(
            defaultModelDirectory(),
            File(context.filesDir, "models"),
        )

        val preferredNames = listOf(
            "embeddinggemma-300m.tflite",
            "nomic-embed-text.tflite",
            "bge-small.tflite"
        )

        for (directory in candidateDirectories) {
            for (name in preferredNames) {
                val file = File(directory, name)
                if (file.exists() && file.isFile) {
                    return file
                }
            }
        }

        for (directory in candidateDirectories) {
            val fallback = directory.listFiles()?.firstOrNull {
                it.isFile && it.extension.equals("tflite", ignoreCase = true)
            }
            if (fallback != null) {
                return fallback
            }
        }

        return null
    }

    private fun defaultModelDirectory(): File? {
        val externalDir = context.getExternalFilesDir(null) ?: return null
        return File(externalDir, "models")
    }

    private fun File.nameWithoutExtensionSafe(): String =
        if (name.endsWith(".tflite", ignoreCase = true)) {
            name.removeSuffix(".tflite")
        } else {
            nameWithoutExtension
        }
}
