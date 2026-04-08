package it.clindiary.clindiary

import android.content.Context
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.LogSeverity
import java.io.File
import java.time.Instant
import java.util.UUID

class OnDeviceGemmaRuntime(
    private val context: Context,
) {
    private data class BackendCandidate(
        val label: String,
        val factory: () -> Backend,
    )

    private var engine: Engine? = null
    private var loadedModelPath: String? = null
    private var backendResolved: String? = null
    private var lastError: String? = null

    init {
        Engine.setNativeMinLogSeverity(LogSeverity.ERROR)
    }

    @Synchronized
    fun getStatus(modelPath: String?): Map<String, Any?> {
        val modelFile = resolveModelFile(modelPath)
        val modelName = modelFile?.nameWithoutExtensionSafe()
        var isReady = false
        var statusError = lastError

        if (modelFile != null) {
            try {
                ensureEngine(modelFile)
                isReady = true
                statusError = null
            } catch (t: Throwable) {
                statusError = t.message ?: t::class.java.simpleName
                lastError = statusError
            }
        }

        val activeProviderLabel =
            when {
                modelFile == null -> "On-device non configurato"
                !isReady -> "On-device non pronto"
                supportsGemma4Label(modelName) -> "Gemma 4 On-device"
                else -> "On-device locale"
            }

        return mapOf(
            "isSupported" to true,
            "isReady" to isReady,
            "runtime" to "LiteRT-LM Android",
            "provider" to "on_device_litertlm",
            "activeProviderLabel" to activeProviderLabel,
            "backendPreference" to "GPU",
            "backendResolved" to backendResolved,
            "modelName" to modelName,
            "modelPath" to modelFile?.absolutePath,
            "modelFileSizeBytes" to modelFile?.length(),
            "modelLastModifiedAt" to modelFile?.takeIf { it.exists() }?.lastModified()?.let {
                Instant.ofEpochMilli(it).toString()
            },
            "defaultModelDirectory" to defaultModelDirectory()?.absolutePath,
            "lastError" to statusError,
            "isCloudBypassedForThisRequest" to true,
        )
    }

    @Synchronized
    fun generateDailyRecap(
        modelPath: String?,
        systemPrompt: String,
        userPrompt: String,
    ): Map<String, Any?> {
        val completion = runPrompt(modelPath, systemPrompt, userPrompt)
        return mapOf(
            "id" to UUID.randomUUID().toString(),
            "content" to completion.content,
            "provider_name" to "on_device_litertlm",
            "model_name" to completion.modelName,
            "generated_at" to Instant.now().toString(),
            "runtime" to "LiteRT-LM Android",
            "backendResolved" to backendResolved,
            "activeProviderLabel" to if (supportsGemma4Label(completion.modelName)) "Gemma 4 On-device" else "On-device locale",
            "isCloudBypassedForThisRequest" to true,
        )
    }

    @Synchronized
    fun generateText(
        modelPath: String?,
        systemPrompt: String,
        userPrompt: String,
    ): Map<String, Any?> {
        val completion = runPrompt(modelPath, systemPrompt, userPrompt)
        return mapOf(
            "id" to UUID.randomUUID().toString(),
            "content" to completion.content,
            "provider_name" to "on_device_litertlm",
            "model_name" to completion.modelName,
            "generated_at" to Instant.now().toString(),
            "runtime" to "LiteRT-LM Android",
            "backendResolved" to backendResolved,
            "activeProviderLabel" to if (supportsGemma4Label(completion.modelName)) "Gemma 4 On-device" else "On-device locale",
            "isCloudBypassedForThisRequest" to true,
        )
    }

    @Synchronized
    fun close() {
        engine?.close()
        engine = null
        loadedModelPath = null
        backendResolved = null
    }

    private fun ensureEngine(modelFile: File): Engine {
        val currentEngine = engine
        if (currentEngine != null && loadedModelPath == modelFile.absolutePath) {
            return currentEngine
        }

        close()
        val (newEngine, resolvedBackendLabel) = createEngine(modelFile)
        engine = newEngine
        loadedModelPath = modelFile.absolutePath
        backendResolved = resolvedBackendLabel
        lastError = null
        return newEngine
    }

    private fun createEngine(modelFile: File): Pair<Engine, String> {
        val errors = mutableListOf<String>()
        for (candidate in backendCandidates()) {
            try {
                val createdEngine = Engine(
                    EngineConfig(
                        modelPath = modelFile.absolutePath,
                        backend = candidate.factory(),
                        cacheDir = context.cacheDir.absolutePath,
                    )
                )
                createdEngine.initialize()
                return createdEngine to candidate.label
            } catch (t: Throwable) {
                errors += "${candidate.label}: ${t.message ?: t::class.java.simpleName}"
            }
        }

        val message =
            "Impossibile inizializzare LiteRT-LM. ${errors.joinToString(" | ")}"
        lastError = message
        throw IllegalStateException(message)
    }

    private fun runPrompt(
        modelPath: String?,
        systemPrompt: String,
        userPrompt: String,
    ): GeneratedCompletion {
        val modelFile = resolveModelFile(modelPath)
            ?: throw IllegalStateException(
                "Nessun modello LiteRT-LM trovato. Copia il file .litertlm in ${defaultModelDirectory()?.absolutePath ?: "files/models"}."
            )

        val engine = ensureEngine(modelFile)
        val conversationConfig =
            ConversationConfig(systemInstruction = Contents.of(systemPrompt))
        val conversation = engine.createConversation(conversationConfig)
        try {
            val reply = conversation.sendMessage(userPrompt).toString().trim()
            if (reply.isBlank()) {
                throw IllegalStateException("Il modello on-device ha restituito una risposta vuota.")
            }
            return GeneratedCompletion(
                content = reply,
                modelName = modelFile.nameWithoutExtensionSafe(),
            )
        } catch (t: Throwable) {
            lastError = t.message ?: t::class.java.simpleName
            throw t
        } finally {
            conversation.close()
        }
    }

    private fun backendCandidates(): List<BackendCandidate> =
        listOf(
            BackendCandidate(label = "GPU", factory = { Backend.GPU() }),
            BackendCandidate(label = "CPU", factory = { Backend.CPU() }),
        )

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
            "gemma-4-E2B-it.litertlm",
            "gemma-4-E2B-it-int4.litertlm",
            "gemma4-e2b-it.litertlm",
            "gemma-3n-E2B-it-int4.litertlm",
            "gemma-3n-E2B-it.litertlm",
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
                it.isFile && it.extension.equals("litertlm", ignoreCase = true)
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

    private fun supportsGemma4Label(modelName: String?): Boolean {
        val normalized = modelName?.trim()?.lowercase().orEmpty()
        return normalized.contains("gemma-4") || normalized.contains("gemma4")
    }

    private fun File.nameWithoutExtensionSafe(): String =
        if (name.endsWith(".litertlm", ignoreCase = true)) {
            name.removeSuffix(".litertlm")
        } else {
            nameWithoutExtension
        }

    private data class GeneratedCompletion(
        val content: String,
        val modelName: String,
    )
}
