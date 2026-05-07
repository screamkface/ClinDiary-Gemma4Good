package it.clindiary.clindiary

object GemmaDownloadRegistry {
    @Volatile
    private var state = GemmaDownloadState()

    @Volatile
    private var pendingRoute: String? = null

    @Synchronized
    fun update(stateUpdater: (GemmaDownloadState) -> GemmaDownloadState) {
        state = stateUpdater(state)
    }

    @Synchronized
    fun snapshot(): GemmaDownloadState = state

    @Synchronized
    fun reset() {
        state = GemmaDownloadState()
    }

    @Synchronized
    fun setPendingRoute(route: String?) {
        pendingRoute = route
    }

    @Synchronized
    fun consumePendingRoute(): String? {
        val route = pendingRoute
        pendingRoute = null
        return route
    }
}

data class GemmaDownloadState(
    val isRunning: Boolean = false,
    val isCompleted: Boolean = false,
    val isFailed: Boolean = false,
    val downloadedBytes: Long = 0L,
    val totalBytes: Long? = null,
    val filePath: String? = null,
    val errorMessage: String? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "isRunning" to isRunning,
        "isCompleted" to isCompleted,
        "isFailed" to isFailed,
        "downloadedBytes" to downloadedBytes,
        "totalBytes" to totalBytes,
        "filePath" to filePath,
        "errorMessage" to errorMessage,
    )
}
