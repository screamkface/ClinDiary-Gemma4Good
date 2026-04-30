package it.clindiary.clindiary

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.health.connect.client.HealthConnectClient
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val onDeviceExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val onDeviceGemmaRuntime by lazy { OnDeviceGemmaRuntime(this) }
    private val onDeviceEmbeddingRuntime by lazy { OnDeviceEmbeddingRuntime(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "clindiary/wearables"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openHealthConnectSettings" -> result.success(openHealthConnectSettings())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "clindiary/on_device_ai"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> runOnDevice(result) {
                    val modelPath = call.argument<String>("modelPath")
                    onDeviceGemmaRuntime.getStatus(modelPath)
                }
                
                "getEmbeddingStatus" -> runOnDevice(result) {
                    val modelPath = call.argument<String>("modelPath")
                    onDeviceEmbeddingRuntime.getStatus(modelPath)
                }

                "generateDailyRecap" -> runOnDevice(result) {
                    val systemPrompt = call.argument<String>("systemPrompt")
                        ?: throw IllegalArgumentException("systemPrompt mancante")
                    val userPrompt = call.argument<String>("userPrompt")
                        ?: throw IllegalArgumentException("userPrompt mancante")
                    val modelPath = call.argument<String>("modelPath")
                    onDeviceGemmaRuntime.generateDailyRecap(
                        modelPath = modelPath,
                        systemPrompt = systemPrompt,
                        userPrompt = userPrompt,
                    )
                }

                "generateText" -> runOnDevice(result) {
                    val systemPrompt = call.argument<String>("systemPrompt")
                        ?: throw IllegalArgumentException("systemPrompt mancante")
                    val userPrompt = call.argument<String>("userPrompt")
                        ?: throw IllegalArgumentException("userPrompt mancante")
                    val modelPath = call.argument<String>("modelPath")
                    onDeviceGemmaRuntime.generateText(
                        modelPath = modelPath,
                        systemPrompt = systemPrompt,
                        userPrompt = userPrompt,
                    )
                }

                "generateEmbedding" -> runOnDevice(result) {
                    val text = call.argument<String>("text")
                        ?: throw IllegalArgumentException("text mancante")
                    val modelPath = call.argument<String>("modelPath")
                    onDeviceEmbeddingRuntime.generateEmbedding(
                        modelPath = modelPath,
                        text = text,
                    )
                }

                "resetRuntime" -> runOnDevice(result) {
                    onDeviceGemmaRuntime.close()
                    onDeviceEmbeddingRuntime.close()
                    mapOf("ok" to true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        onDeviceGemmaRuntime.close()
        onDeviceEmbeddingRuntime.close()
        onDeviceExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun openHealthConnectSettings(): Boolean {
        val intents = listOf(
            runCatching {
                HealthConnectClient.getHealthConnectManageDataIntent(this)
            }.getOrNull(),
            Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:com.google.android.apps.healthdata")
            },
        ).filterNotNull()

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }

        return false
    }

    private fun runOnDevice(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        onDeviceExecutor.execute {
            try {
                val payload = block()
                runOnUiThread { result.success(payload) }
            } catch (t: Throwable) {
                runOnUiThread {
                    result.error(
                        "ON_DEVICE_AI_ERROR",
                        t.message ?: t::class.java.simpleName,
                        null,
                    )
                }
            }
        }
    }
}
