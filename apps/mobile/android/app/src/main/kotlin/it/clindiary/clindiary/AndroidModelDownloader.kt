package it.clindiary.clindiary

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import java.io.File

class AndroidModelDownloader(
    private val context: Context,
) {
    companion object {
        private const val MODEL_URL =
            "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true"
        private const val MODEL_FILE_NAME = "gemma-4-E2B-it.litertlm"
        private const val POLL_INTERVAL_MS = 1000L
    }

    fun downloadGemma4Model(onProgress: (Long, Long?) -> Unit): String {
        val targetDirectory = defaultModelDirectory()
            ?: throw IllegalStateException("Android model directory unavailable.")
        targetDirectory.mkdirs()

        val targetFile = File(targetDirectory, MODEL_FILE_NAME)
        val tempFile = File(targetDirectory, "$MODEL_FILE_NAME.download")
        if (tempFile.exists()) {
            tempFile.delete()
        }

        val downloadManager = context.getSystemService(DownloadManager::class.java)
            ?: throw IllegalStateException("Android DownloadManager unavailable.")
        val request = DownloadManager.Request(Uri.parse(MODEL_URL))
            .setTitle("ClinDiary Gemma 4 E2B")
            .setDescription("Downloading on-device model")
            .setMimeType("application/octet-stream")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .addRequestHeader("User-Agent", "ClinDiary/1.0")
            .addRequestHeader("Accept", "application/octet-stream")
            .setDestinationUri(Uri.fromFile(tempFile))

        val downloadId = downloadManager.enqueue(request)
        try {
            waitForDownload(downloadManager, downloadId, onProgress)

            if (!tempFile.exists() || tempFile.length() <= 0L) {
                throw IllegalStateException("Downloaded model file is empty.")
            }
            if (targetFile.exists()) {
                targetFile.delete()
            }
            if (!tempFile.renameTo(targetFile)) {
                throw IllegalStateException("Unable to finalize downloaded model file.")
            }
            removeExistingModelFiles(targetDirectory, keepFileName = targetFile.name)
            return targetFile.absolutePath
        } catch (t: Throwable) {
            downloadManager.remove(downloadId)
            if (tempFile.exists()) {
                tempFile.delete()
            }
            throw t
        }
    }

    private fun waitForDownload(
        downloadManager: DownloadManager,
        downloadId: Long,
        onProgress: (Long, Long?) -> Unit,
    ) {
        while (true) {
            val query = DownloadManager.Query().setFilterById(downloadId)
            downloadManager.query(query).use { cursor ->
                if (!cursor.moveToFirst()) {
                    throw IllegalStateException("Model download disappeared from DownloadManager.")
                }

                val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                val receivedBytes = cursor.getLong(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                )
                val totalRaw = cursor.getLong(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                )
                val totalBytes = totalRaw.takeIf { it > 0L }
                onProgress(receivedBytes, totalBytes)

                when (status) {
                    DownloadManager.STATUS_SUCCESSFUL -> return
                    DownloadManager.STATUS_FAILED -> {
                        val reason = cursor.getInt(
                            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
                        )
                        throw IllegalStateException("Model download failed: DownloadManager reason $reason")
                    }
                }
            }
            Thread.sleep(POLL_INTERVAL_MS)
        }
    }

    private fun defaultModelDirectory(): File? {
        val externalDir = context.getExternalFilesDir(null) ?: return null
        return File(externalDir, "models")
    }

    private fun removeExistingModelFiles(directory: File, keepFileName: String) {
        directory.listFiles()?.forEach { file ->
            if (
                file.isFile &&
                file.extension.equals("litertlm", ignoreCase = true) &&
                file.name != keepFileName
            ) {
                file.delete()
            }
        }
    }
}
