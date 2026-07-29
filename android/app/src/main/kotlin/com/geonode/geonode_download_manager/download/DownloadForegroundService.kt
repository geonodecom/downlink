package com.geonode.geonode_download_manager.download

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.geonode.geonode_download_manager.MainActivity
import com.geonode.geonode_download_manager.R
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class DownloadForegroundService : Service() {
    private lateinit var store: DownloadStore
    private val workers = ConcurrentHashMap<String, SegmentedDownloader>()
    private val executor = Executors.newCachedThreadPool()
    private var maxActive = 1
    private var defaultSplit = 4
    private var downloadDirectory = ""
    private var torrentSession: TorrentSession? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        store = DownloadStore(this)
        createChannel()
        torrentSession = TorrentSession { task ->
            store.put(task)
            updateNotification()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PAUSE -> intent.getStringExtra(EXTRA_GID)?.let { pause(it) }
            ACTION_RESUME -> intent.getStringExtra(EXTRA_GID)?.let { unpause(it) }
            ACTION_CANCEL -> intent.getStringExtra(EXTRA_GID)?.let { remove(it) }
            ACTION_CONFIGURE -> {
                maxActive = intent.getIntExtra(EXTRA_MAX_ACTIVE, maxActive)
                defaultSplit = intent.getIntExtra(EXTRA_DEFAULT_SPLIT, defaultSplit)
                downloadDirectory = intent.getStringExtra(EXTRA_DIRECTORY) ?: downloadDirectory
                startForeground(NOTIFICATION_ID, buildNotification("Ready"))
                fillQueue()
            }
            else -> {
                startForeground(NOTIFICATION_ID, buildNotification("Ready"))
                fillQueue()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        instance = null
        workers.values.forEach { it.cancel() }
        torrentSession?.shutdown()
        torrentSession = null
        executor.shutdownNow()
        super.onDestroy()
    }

    fun configure(directory: String, maxActiveDownloads: Int, split: Int) {
        downloadDirectory = directory
        maxActive = maxActiveDownloads.coerceAtLeast(1)
        defaultSplit = split.coerceIn(1, 32)
        startForeground(NOTIFICATION_ID, buildNotification("Engine ready"))
        fillQueue()
    }

    fun isHealthy(): Boolean = true

    fun addUri(
        url: String,
        directory: String,
        split: Int,
        fileName: String?,
        headers: Map<String, String>,
        position: Int?,
        options: Map<String, Any?> = emptyMap(),
    ): String {
        val kind = options["kind"]?.toString()
        if (kind == "magnet" || kind == "torrent") {
            return addTorrentJob(
                url = url,
                directory = directory,
                fileName = fileName,
                position = position,
                options = options,
            )
        }

        val gid = store.nextGid()
        val now = System.currentTimeMillis()
        val resolvedName =
            fileName?.takeIf { it.isNotBlank() }
                ?: url.substringAfterLast('/').ifBlank { "download.bin" }
        val task = DownloadTask(
            gid = gid,
            url = url,
            fileName = resolvedName,
            directory = directory.ifBlank { downloadDirectory },
            split = if (split > 0) split else defaultSplit,
            headers = headers,
            status = "waiting",
            totalLength = 0,
            completedLength = 0,
            downloadSpeed = 0,
            uploadSpeed = 0,
            connections = 0,
            pieceLength = 0,
            numPieces = 0,
            bitfield = null,
            errorMessage = null,
            contentUri = null,
            partPath = null,
            queuePosition = position ?: store.all().size,
            createdAt = now,
            updatedAt = now,
            isTorrent = false,
        )
        store.put(task)
        fillQueue()
        return gid
    }

    private fun addTorrentJob(
        url: String,
        directory: String,
        fileName: String?,
        position: Int?,
        options: Map<String, Any?>,
    ): String {
        val session = torrentSession ?: error("Torrent session unavailable")
        val gid = store.nextGid()
        val now = System.currentTimeMillis()
        val kind = options["kind"]?.toString() ?: "magnet"
        val seedMode = options["seedMode"]?.toString() ?: "stop"
        val seedRatio = (options["seedRatio"] as? Number)?.toDouble()
            ?: options["seedRatio"]?.toString()?.toDoubleOrNull()
            ?: 1.0
        val seedTimeMinutes = (options["seedTimeMinutes"] as? Number)?.toInt()
            ?: options["seedTimeMinutes"]?.toString()?.toIntOrNull()
            ?: 60
        val torrentPath = options["torrentPath"]?.toString().orEmpty()
        val resolvedName = fileName?.takeIf { it.isNotBlank() }
            ?: if (kind == "torrent") {
                File(torrentPath.ifBlank { url }).nameWithoutExtension
            } else {
                "Magnet download"
            }
        val task = DownloadTask(
            gid = gid,
            url = url,
            fileName = resolvedName,
            directory = directory.ifBlank { downloadDirectory },
            split = 1,
            headers = emptyMap(),
            status = "waiting",
            totalLength = 0,
            completedLength = 0,
            downloadSpeed = 0,
            uploadSpeed = 0,
            connections = 0,
            pieceLength = 0,
            numPieces = 0,
            bitfield = null,
            errorMessage = null,
            contentUri = null,
            partPath = null,
            queuePosition = position ?: store.all().size,
            createdAt = now,
            updatedAt = now,
            isTorrent = true,
        )
        store.put(task)
        try {
            if (kind == "torrent") {
                session.addTorrentFile(
                    task = task,
                    torrentPath = torrentPath.ifBlank { url },
                    seedMode = seedMode,
                    seedRatio = seedRatio,
                    seedTimeMinutes = seedTimeMinutes,
                )
            } else {
                session.addMagnet(
                    task = task,
                    seedMode = seedMode,
                    seedRatio = seedRatio,
                    seedTimeMinutes = seedTimeMinutes,
                )
            }
            store.put(task)
        } catch (error: Exception) {
            task.status = "error"
            task.errorMessage = error.message
            task.updatedAt = System.currentTimeMillis()
            store.put(task)
            throw error
        }
        updateNotification()
        return gid
    }

    fun pause(gid: String) {
        if (torrentSession?.has(gid) == true) {
            torrentSession?.pause(gid)
            store.get(gid)?.let { store.put(it) }
            updateNotification()
            return
        }
        workers[gid]?.pause()
        store.get(gid)?.let {
            it.status = "paused"
            it.downloadSpeed = 0
            it.uploadSpeed = 0
            it.connections = 0
            it.updatedAt = System.currentTimeMillis()
            store.put(it)
        }
        updateNotification()
    }

    fun unpause(gid: String) {
        val task = store.get(gid) ?: return
        if (task.isTorrent) {
            if (torrentSession?.has(gid) == true) {
                torrentSession?.resume(gid)
                store.put(task)
                updateNotification()
                return
            }
            // After process death the native session is gone — re-add the torrent.
            try {
                val options = mapOf(
                    "kind" to if (task.url.startsWith("magnet:?", ignoreCase = true)) {
                        "magnet"
                    } else {
                        "torrent"
                    },
                    "torrentPath" to task.url,
                    "seedMode" to "stop",
                    "seedRatio" to 1.0,
                    "seedTimeMinutes" to 60,
                )
                store.remove(gid)
                addTorrentJob(
                    url = task.url,
                    directory = task.directory,
                    fileName = task.fileName,
                    position = task.queuePosition,
                    options = options,
                )
            } catch (error: Exception) {
                task.status = "error"
                task.errorMessage = error.message
                task.updatedAt = System.currentTimeMillis()
                store.put(task)
            }
            return
        }
        task.status = "waiting"
        task.errorMessage = null
        task.updatedAt = System.currentTimeMillis()
        store.put(task)
        fillQueue()
    }

    fun remove(gid: String) {
        if (torrentSession?.has(gid) == true) {
            torrentSession?.remove(gid)
            store.remove(gid)
            fillQueue()
            updateNotification()
            return
        }
        workers[gid]?.cancel()
        workers.remove(gid)
        val task = store.get(gid)
        if (task != null) {
            task.partPath?.let { File(it).delete() }
            MediaStorePublisher.delete(this, task.contentUri)
            store.remove(gid)
        }
        fillQueue()
        updateNotification()
    }

    fun changePosition(gid: String, position: Int) {
        store.get(gid)?.let {
            it.queuePosition = position
            it.updatedAt = System.currentTimeMillis()
            store.put(it)
        }
    }

    fun tellStatus(gid: String): Map<String, Any?> {
        return store.get(gid)?.toStatusMap() ?: emptyMap()
    }

    fun tellActive(): List<Map<String, Any?>> = store.active().map { it.toStatusMap() }

    fun tellWaiting(offset: Int, limit: Int): List<Map<String, Any?>> =
        store.waiting().drop(offset).take(limit).map { it.toStatusMap() }

    fun tellStopped(offset: Int, limit: Int): List<Map<String, Any?>> =
        store.stopped().drop(offset).take(limit).map { it.toStatusMap() }

    fun resetSession() {
        workers.values.forEach { it.cancel() }
        workers.clear()
        torrentSession?.shutdown()
        torrentSession = TorrentSession { task ->
            store.put(task)
            updateNotification()
        }
        for (task in store.all()) {
            task.partPath?.let { File(it).delete() }
        }
        store.clear()
        updateNotification()
    }

    fun shutdownEngine() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun fillQueue() {
        while (store.activeCount() < maxActive) {
            val next = store.waiting().firstOrNull() ?: break
            startTask(next)
        }
        updateNotification()
    }

    private fun startTask(task: DownloadTask) {
        if (task.isTorrent) {
            // Torrents are started immediately in addTorrentJob.
            return
        }
        task.status = "active"
        task.updatedAt = System.currentTimeMillis()
        val partDir = File(cacheDir, "parts")
        partDir.mkdirs()
        val partFile = File(partDir, "${task.gid}.part")
        task.partPath = partFile.absolutePath
        store.put(task)

        val downloader = SegmentedDownloader(task, partFile) { completed, speed, connections ->
            task.completedLength = completed
            task.downloadSpeed = speed
            task.connections = connections
            task.updatedAt = System.currentTimeMillis()
            if (task.totalLength > 0 && task.numPieces > 0) {
                val ratio = completed.toDouble() / task.totalLength.toDouble()
                val filled = (ratio * task.numPieces).toInt().coerceIn(0, task.numPieces)
                task.bitfield = "f".repeat(filled) + "0".repeat(task.numPieces - filled)
            }
            store.put(task)
            updateNotification()
        }
        workers[task.gid] = downloader

        executor.execute {
            val result = downloader.download()
            workers.remove(task.gid)
            when (result) {
                SegmentedDownloader.Result.Complete -> {
                    try {
                        val uri = MediaStorePublisher.publish(this, partFile, task.fileName)
                        task.contentUri = uri.toString()
                        task.status = "complete"
                        task.completedLength =
                            task.totalLength.takeIf { it > 0 } ?: task.completedLength
                        task.downloadSpeed = 0
                        task.connections = 0
                        partFile.delete()
                    } catch (error: Exception) {
                        task.status = "error"
                        task.errorMessage = error.message
                    }
                }
                SegmentedDownloader.Result.Paused -> {
                    task.status = "paused"
                    task.downloadSpeed = 0
                    task.connections = 0
                }
                SegmentedDownloader.Result.Cancelled -> {
                    partFile.delete()
                    store.remove(task.gid)
                    fillQueue()
                    updateNotification()
                    return@execute
                }
                is SegmentedDownloader.Result.Failed -> {
                    task.status = "error"
                    task.errorMessage = result.message
                    task.downloadSpeed = 0
                    task.connections = 0
                }
            }
            task.updatedAt = System.currentTimeMillis()
            store.put(task)
            fillQueue()
            updateNotification()
        }
    }

    private fun updateNotification() {
        val active = store.active()
        val text = when {
            active.isEmpty() -> "Idle"
            active.size == 1 -> {
                val task = active.first()
                val seeding = task.isTorrent &&
                    task.totalLength > 0 &&
                    task.completedLength >= task.totalLength
                if (seeding) "Seeding ${task.fileName}" else "Downloading ${task.fileName}"
            }
            else -> "Downloading ${active.size} files"
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(text, active.firstOrNull()))
    }

    private fun buildNotification(text: String, task: DownloadTask? = null): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Geonode Download Manager")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        if (task != null && task.totalLength > 0) {
            val progress = ((task.completedLength * 100) / task.totalLength).toInt().coerceIn(0, 100)
            builder.setProgress(100, progress, false)
            builder.addAction(0, "Pause", actionPending(ACTION_PAUSE, task.gid, 1))
            builder.addAction(0, "Cancel", actionPending(ACTION_CANCEL, task.gid, 2))
        } else if (task != null) {
            builder.setProgress(0, 0, true)
        }
        return builder.build()
    }

    private fun actionPending(action: String, gid: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, DownloadForegroundService::class.java).apply {
            this.action = action
            putExtra(EXTRA_GID, gid)
        }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Downloads",
            NotificationManager.IMPORTANCE_LOW,
        )
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "geonode_downloads"
        const val NOTIFICATION_ID = 42
        const val ACTION_CONFIGURE = "configure"
        const val ACTION_PAUSE = "pause"
        const val ACTION_RESUME = "resume"
        const val ACTION_CANCEL = "cancel"
        const val EXTRA_GID = "gid"
        const val EXTRA_DIRECTORY = "directory"
        const val EXTRA_MAX_ACTIVE = "maxActive"
        const val EXTRA_DEFAULT_SPLIT = "defaultSplit"

        @Volatile
        var instance: DownloadForegroundService? = null
            private set

        fun start(context: Context, directory: String, maxActive: Int, split: Int) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_CONFIGURE
                putExtra(EXTRA_DIRECTORY, directory)
                putExtra(EXTRA_MAX_ACTIVE, maxActive)
                putExtra(EXTRA_DEFAULT_SPLIT, split)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
