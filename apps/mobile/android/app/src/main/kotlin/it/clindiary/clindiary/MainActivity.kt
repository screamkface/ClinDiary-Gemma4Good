package it.clindiary.clindiary

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.database.Cursor
import androidx.health.connect.client.HealthConnectClient
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val DOWNLOAD_TITLE_PREFIX = "ClinDiary model download"
    }

    private val onDeviceExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val onDeviceGemmaRuntime by lazy { OnDeviceGemmaRuntime(this) }
    private val onDeviceEmbeddingRuntime by lazy { OnDeviceEmbeddingRuntime(this) }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        processGemmaRouteIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        processGemmaRouteIntent(intent)
    }

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

                "startGemmaDownload" -> runOnDevice(result) {
                    val url = call.argument<String>("url")
                        ?: throw IllegalArgumentException("url mancante")
                    val fileName = call.argument<String>("fileName")
                        ?: throw IllegalArgumentException("fileName mancante")
                    val targetDirectory = call.argument<String>("targetDirectory")
                        ?: throw IllegalArgumentException("targetDirectory mancante")
                    val route = call.argument<String>("route")
                    startGemmaDownload(url, fileName, targetDirectory, route)
                }

                "queryGemmaDownloadStatus" -> runOnDevice(result) {
                    GemmaDownloadRegistry.snapshot().toMap()
                }

                "cancelGemmaDownload" -> runOnDevice(result) {
                    cancelGemmaDownload()
                    mapOf("ok" to true)
                }

                "consumePendingGemmaRoute" -> runOnDevice(result) {
                    mapOf("route" to GemmaDownloadRegistry.consumePendingRoute())
                }

                "enqueuePersistentDownload" -> runOnDevice(result) {
                    val url = call.argument<String>("url")
                        ?: throw IllegalArgumentException("url mancante")
                    val fileName = call.argument<String>("fileName")
                        ?: throw IllegalArgumentException("fileName mancante")
                    val title = call.argument<String>("title")
                        ?: "$DOWNLOAD_TITLE_PREFIX: $fileName"
                    val description = call.argument<String>("description")
                    val targetDirectory = call.argument<String>("targetDirectory")
                    enqueuePersistentDownload(
                        url = url,
                        fileName = fileName,
                        title = title,
                        description = description,
                        targetDirectory = targetDirectory,
                    )
                }

                "findActivePersistentDownload" -> runOnDevice(result) {
                    val fileName = call.argument<String>("fileName")
                        ?: throw IllegalArgumentException("fileName mancante")
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title")
                    val targetDirectory = call.argument<String>("targetDirectory")
                    findActivePersistentDownload(
                        fileName = fileName,
                        url = url,
                        title = title,
                        targetDirectory = targetDirectory,
                    )
                }

                "queryPersistentDownload" -> runOnDevice(result) {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                        ?: throw IllegalArgumentException("downloadId mancante")
                    queryPersistentDownload(downloadId)
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
                val payloadForResult = if (payload === kotlin.Unit) null else payload
                runOnUiThread { result.success(payloadForResult) }
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

    private fun enqueuePersistentDownload(
        url: String,
        fileName: String,
        title: String,
        description: String?,
        targetDirectory: String?,
    ): Map<String, Any?> {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            setTitle(title)
            if (!description.isNullOrBlank()) {
                setDescription(description)
            }
            setMimeType("application/octet-stream")
            val targetDir = targetDirectory?.trim()
            if (!targetDir.isNullOrEmpty()) {
                val destinationFile = File(targetDir, fileName)
                destinationFile.parentFile?.mkdirs()
                if (destinationFile.exists()) {
                    destinationFile.delete()
                }
                setDestinationUri(Uri.fromFile(destinationFile))
            }
        }
        val downloadId = manager.enqueue(request)
        return mapOf("downloadId" to downloadId)
    }

    private fun findActivePersistentDownload(
        fileName: String,
        url: String?,
        title: String?,
        targetDirectory: String?,
    ): Map<String, Any?>? {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val expectedPath = targetDirectory
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.let { File(it, fileName).absolutePath }

        val query = DownloadManager.Query().setFilterByStatus(
            DownloadManager.STATUS_PENDING or
                DownloadManager.STATUS_RUNNING or
                DownloadManager.STATUS_PAUSED
        )

        val cursor = manager.query(query)
        cursor.use {
            while (it.moveToNext()) {
                val localUri = readString(it, DownloadManager.COLUMN_LOCAL_URI)
                val rowTitle = readString(it, DownloadManager.COLUMN_TITLE)
                val rowUrl = readString(it, DownloadManager.COLUMN_URI)
                val matchesPath = localUri?.let { uriText ->
                    runCatching { Uri.parse(uriText) }
                        .getOrNull()
                        ?.path
                        ?.let { localPath ->
                            expectedPath != null && File(localPath).absolutePath == expectedPath
                        } == true
                } ?: false
                val matchesTitle = !title.isNullOrBlank() && rowTitle == title
                val matchesUrl = !url.isNullOrBlank() && rowUrl == url
                val matchesFallbackTitle = rowTitle == "$DOWNLOAD_TITLE_PREFIX: $fileName"

                if (matchesPath || matchesTitle || matchesUrl || matchesFallbackTitle) {
                    return mapOf(
                        "downloadId" to readLong(it, DownloadManager.COLUMN_ID),
                        "status" to readInt(it, DownloadManager.COLUMN_STATUS),
                        "downloadedBytes" to readLong(
                            it,
                            DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                        ),
                        "totalBytes" to readLong(it, DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                        "localUri" to localUri,
                    )
                }
            }
        }

        return null
    }

    private fun queryPersistentDownload(downloadId: Long): Map<String, Any?> {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(downloadId)
        val cursor = manager.query(query)
        cursor.use {
            if (!it.moveToFirst()) {
                return mapOf("exists" to false)
            }
            return mapOf(
                "exists" to true,
                "downloadId" to readLong(it, DownloadManager.COLUMN_ID),
                "status" to readInt(it, DownloadManager.COLUMN_STATUS),
                "downloadedBytes" to readLong(
                    it,
                    DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                ),
                "totalBytes" to readLong(it, DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                "reason" to readInt(it, DownloadManager.COLUMN_REASON),
                "localUri" to readString(it, DownloadManager.COLUMN_LOCAL_URI),
            )
        }
    }

    private fun readString(cursor: Cursor, columnName: String): String? {
        val index = cursor.getColumnIndex(columnName)
        if (index < 0 || cursor.isNull(index)) {
            return null
        }
        return cursor.getString(index)
    }

    private fun readLong(cursor: Cursor, columnName: String): Long {
        val index = cursor.getColumnIndex(columnName)
        if (index < 0 || cursor.isNull(index)) {
            return 0L
        }
        return cursor.getLong(index)
    }

    private fun readInt(cursor: Cursor, columnName: String): Int {
        val index = cursor.getColumnIndex(columnName)
        if (index < 0 || cursor.isNull(index)) {
            return 0
        }
        return cursor.getInt(index)
    }

    private fun startGemmaDownload(
        url: String,
        fileName: String,
        targetDirectory: String,
        route: String?,
    ) {
        val intent = Intent(this, GemmaDownloadService::class.java).apply {
            action = GemmaDownloadService.ACTION_START
            putExtra(GemmaDownloadService.EXTRA_URL, url)
            putExtra(GemmaDownloadService.EXTRA_FILE_NAME, fileName)
            putExtra(GemmaDownloadService.EXTRA_TARGET_DIRECTORY, targetDirectory)
            putExtra(GemmaDownloadService.EXTRA_ROUTE, route ?: "/app/ai")
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun cancelGemmaDownload() {
        val intent = Intent(this, GemmaDownloadService::class.java).apply {
            action = GemmaDownloadService.ACTION_CANCEL
        }
        startService(intent)
    }

    private fun processGemmaRouteIntent(intent: Intent?) {
        val route = intent?.getStringExtra(GemmaDownloadService.EXTRA_ROUTE)
        if (!route.isNullOrBlank()) {
            GemmaDownloadRegistry.setPendingRoute(route)
        }
    }
}
