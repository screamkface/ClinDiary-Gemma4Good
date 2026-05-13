package it.clindiary.clindiary

import android.app.NotificationChannel
import android.app.NotificationManager
import android.util.Log
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class GemmaDownloadService : Service() {
    companion object {
        const val ACTION_START = "it.clindiary.clindiary.action.START_GEMMA_DOWNLOAD"
        const val ACTION_CANCEL = "it.clindiary.clindiary.action.CANCEL_GEMMA_DOWNLOAD"
        const val EXTRA_URL = "extra_url"
        const val EXTRA_FILE_NAME = "extra_file_name"
        const val EXTRA_TARGET_DIRECTORY = "extra_target_directory"
        const val EXTRA_ROUTE = "extra_route"

        private const val NOTIFICATION_CHANNEL_ID = "clindiary_gemma_downloads"
        private const val NOTIFICATION_CHANNEL_NAME = "Gemma model download"
        private const val NOTIFICATION_ID = 42042
    }

    private val executor = Executors.newSingleThreadExecutor()
    @Volatile private var cancelRequested = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL -> {
                cancelRequested = true
                GemmaDownloadRegistry.reset()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START -> {
                if (GemmaDownloadRegistry.snapshot().isRunning) {
                    return START_STICKY
                }

                val url = intent.getStringExtra(EXTRA_URL)
                    ?: return START_NOT_STICKY
                val fileName = intent.getStringExtra(EXTRA_FILE_NAME)
                    ?: return START_NOT_STICKY
                val targetDirectory = intent.getStringExtra(EXTRA_TARGET_DIRECTORY)
                    ?: return START_NOT_STICKY
                val route = intent.getStringExtra(EXTRA_ROUTE)
                if (!route.isNullOrBlank()) {
                    GemmaDownloadRegistry.setPendingRoute(route)
                }

                cancelRequested = false
                val targetFile = File(targetDirectory, fileName)
                targetFile.parentFile?.mkdirs()
                startForeground(NOTIFICATION_ID, buildNotification(0, null))
                Log.i("GemmaDownloadService", "startForeground invoked with id=$NOTIFICATION_ID")
                executor.execute {
                    download(url = url, targetFile = targetFile)
                }
                return START_STICKY
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun download(url: String, targetFile: File) {
        var connection: HttpURLConnection? = null
        var tempFile: File? = null
        try {
            GemmaDownloadRegistry.update {
                it.copy(
                    isRunning = true,
                    isCompleted = false,
                    isFailed = false,
                    downloadedBytes = 0L,
                    totalBytes = null,
                    filePath = targetFile.absolutePath,
                    errorMessage = null,
                )
            }

            tempFile = File(targetFile.absolutePath + ".download")
            if (tempFile.exists()) {
                tempFile.delete()
            }

            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 30_000
                readTimeout = 30_000
                instanceFollowRedirects = true
                setRequestProperty("User-Agent", "ClinDiary/1.0")
                setRequestProperty("Accept", "application/octet-stream")
            }

            val responseCode = connection.responseCode
            if (responseCode < 200 || responseCode >= 300) {
                throw IllegalStateException("HTTP $responseCode")
            }

            val totalBytes = connection.contentLengthLong.takeIf { it > 0 }
            GemmaDownloadRegistry.update { current ->
                current.copy(totalBytes = totalBytes)
            }

            connection.inputStream.use { input ->
                tempFile.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var downloadedBytes = 0L
                    while (true) {
                        if (cancelRequested) {
                            throw IllegalStateException("cancelled")
                        }
                        val read = input.read(buffer)
                        if (read < 0) {
                            break
                        }
                        output.write(buffer, 0, read)
                        downloadedBytes += read.toLong()
                        GemmaDownloadRegistry.update { current ->
                            current.copy(
                                isRunning = true,
                                downloadedBytes = downloadedBytes,
                                totalBytes = totalBytes,
                                filePath = targetFile.absolutePath,
                            )
                        }
                        updateNotification(downloadedBytes, totalBytes)
                    }
                }
            }

            if (targetFile.exists()) {
                targetFile.delete()
            }
            if (tempFile.exists()) {
                tempFile.renameTo(targetFile)
            }

            GemmaDownloadRegistry.update { current ->
                current.copy(
                    isRunning = false,
                    isCompleted = true,
                    downloadedBytes = targetFile.length(),
                    totalBytes = targetFile.length(),
                    filePath = targetFile.absolutePath,
                )
            }
            updateNotification(targetFile.length(), targetFile.length())
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } catch (error: Throwable) {
            tempFile?.let {
                if (it.exists()) {
                    it.delete()
                }
            }
            GemmaDownloadRegistry.update { current ->
                current.copy(
                    isRunning = false,
                    isFailed = true,
                    errorMessage = error.message ?: error::class.java.simpleName,
                )
            }
            updateErrorNotification(error.message ?: error::class.java.simpleName)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } finally {
            connection?.disconnect()
        }
    }

    private fun updateNotification(downloadedBytes: Long, totalBytes: Long?) {
        val percent = if (totalBytes != null && totalBytes > 0) {
            ((downloadedBytes * 100) / totalBytes).toInt().coerceIn(0, 100)
        } else {
            0
        }
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Gemma 4 download in progress")
            .setContentText(buildBody(downloadedBytes, totalBytes))
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(100, percent, totalBytes == null)
            .setContentIntent(buildOpenAppPendingIntent())

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notif = builder.build()
        notificationManager.notify(NOTIFICATION_ID, notif)
        Log.i("GemmaDownloadService", "Posted notification id=$NOTIFICATION_ID percent=$percent")
    }

    private fun updateErrorNotification(message: String) {
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("Gemma 4 download failed")
            .setContentText(message)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(buildOpenAppPendingIntent())

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun buildNotification(downloadedBytes: Long, totalBytes: Long?): android.app.Notification {
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Gemma 4 download in progress")
            .setContentText(buildBody(downloadedBytes, totalBytes))
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(100, 0, true)
            .setContentIntent(buildOpenAppPendingIntent())

        return builder.build()
    }

    private fun buildBody(downloadedBytes: Long, totalBytes: Long?): String {
        return if (totalBytes != null && totalBytes > 0) {
            "Downloaded ${formatBytes(downloadedBytes)} of ${formatBytes(totalBytes)}"
        } else {
            "Downloaded ${formatBytes(downloadedBytes)}"
        }
    }

    private fun buildOpenAppPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ROUTE, "/app/ai")
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 0, intent, flags)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // If a channel with the same id exists, delete it so we can recreate with new importance.
        val existing = notificationManager.getNotificationChannel(NOTIFICATION_CHANNEL_ID)
        if (existing != null) {
            notificationManager.deleteNotificationChannel(NOTIFICATION_CHANNEL_ID)
            Log.i("GemmaDownloadService", "Deleted existing notification channel $NOTIFICATION_CHANNEL_ID")
        }
        notificationManager.createNotificationChannel(channel)
        Log.i("GemmaDownloadService", "Created notification channel $NOTIFICATION_CHANNEL_ID with importance ${channel.importance}")
    }

    private fun formatBytes(bytes: Long): String {
        val units = arrayOf("B", "KB", "MB", "GB")
        var value = bytes.toDouble()
        var unitIndex = 0
        while (value >= 1024 && unitIndex < units.lastIndex) {
            value /= 1024
            unitIndex++
        }
        val digits = if (value >= 10 || value % 1 == 0.0) 0 else 1
        return String.format("%.${digits}f %s", value, units[unitIndex])
    }
}
