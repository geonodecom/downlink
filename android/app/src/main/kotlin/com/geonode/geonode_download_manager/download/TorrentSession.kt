package com.geonode.geonode_download_manager.download

import android.os.Handler
import android.os.Looper
import org.libtorrent4j.AlertListener
import org.libtorrent4j.SessionManager
import org.libtorrent4j.TorrentHandle
import org.libtorrent4j.TorrentInfo
import org.libtorrent4j.alerts.AddTorrentAlert
import org.libtorrent4j.alerts.Alert
import org.libtorrent4j.alerts.AlertType
import org.libtorrent4j.alerts.MetadataReceivedAlert
import org.libtorrent4j.alerts.TorrentFinishedAlert
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * BitTorrent session backed by libtorrent4j.
 * Status is mirrored into [DownloadTask] maps that Flutter already understands.
 */
class TorrentSession(
    private val onTaskUpdated: (DownloadTask) -> Unit,
) {
    private val session = SessionManager()
    private val handles = ConcurrentHashMap<String, TorrentHandle>()
    private val tasks = ConcurrentHashMap<String, DownloadTask>()
    private val seedGoals = ConcurrentHashMap<String, SeedGoal>()
    private val main = Handler(Looper.getMainLooper())
    private var started = false

    private val ticker = object : Runnable {
        override fun run() {
            refreshAll()
            if (started) {
                main.postDelayed(this, 1000L)
            }
        }
    }

    fun ensureStarted() {
        if (started) return
        val settings = org.libtorrent4j.SettingsPack()
        // Match a common whitelisted client fingerprint for private trackers.
        settings.setString(
            org.libtorrent4j.swig.settings_pack.string_types.user_agent.swigValue(),
            "qBittorrent/4.6.2",
        )
        settings.setString(
            org.libtorrent4j.swig.settings_pack.string_types.peer_fingerprint.swigValue(),
            "-qB4620-",
        )
        session.start(settings)
        session.addListener(object : AlertListener {
            override fun types(): IntArray? = null

            override fun alert(alert: Alert<*>) {
                when (alert.type()) {
                    AlertType.ADD_TORRENT -> {
                        val a = alert as AddTorrentAlert
                        val handle = a.handle()
                        bindHandle(handle)
                    }
                    AlertType.METADATA_RECEIVED -> {
                        val a = alert as MetadataReceivedAlert
                        bindHandle(a.handle())
                    }
                    AlertType.TORRENT_FINISHED -> {
                        val a = alert as TorrentFinishedAlert
                        onFinished(a.handle())
                    }
                    else -> Unit
                }
            }
        })
        started = true
        main.post(ticker)
    }

    fun shutdown() {
        started = false
        main.removeCallbacks(ticker)
        try {
            session.stop()
        } catch (_: Exception) {
        }
        handles.clear()
        tasks.clear()
        seedGoals.clear()
    }

    fun addMagnet(
        task: DownloadTask,
        seedMode: String,
        seedRatio: Double,
        seedTimeMinutes: Int,
    ): String {
        ensureStarted()
        tasks[task.gid] = task
        seedGoals[task.gid] = SeedGoal(seedMode, seedRatio, seedTimeMinutes)
        val dir = File(task.directory).apply { mkdirs() }
        session.download(task.url, dir)
        task.status = "active"
        task.updatedAt = System.currentTimeMillis()
        onTaskUpdated(task)
        return task.gid
    }

    fun addTorrentFile(
        task: DownloadTask,
        torrentPath: String,
        seedMode: String,
        seedRatio: Double,
        seedTimeMinutes: Int,
    ): String {
        ensureStarted()
        val file = File(torrentPath)
        if (!file.exists()) {
            throw IllegalArgumentException("Torrent file not found: $torrentPath")
        }
        tasks[task.gid] = task
        seedGoals[task.gid] = SeedGoal(seedMode, seedRatio, seedTimeMinutes)
        val dir = File(task.directory).apply { mkdirs() }
        val info = TorrentInfo(file)
        session.download(info, dir)
        task.fileName = info.name()
        task.status = "active"
        task.updatedAt = System.currentTimeMillis()
        onTaskUpdated(task)
        // Bind immediately when possible
        session.find(info.infoHash())?.let { bindHandle(it, task.gid) }
        return task.gid
    }

    fun pause(gid: String) {
        handles[gid]?.pause()
        tasks[gid]?.let {
            it.status = "paused"
            it.downloadSpeed = 0
            it.uploadSpeed = 0
            it.updatedAt = System.currentTimeMillis()
            onTaskUpdated(it)
        }
    }

    fun resume(gid: String) {
        handles[gid]?.resume()
        tasks[gid]?.let {
            it.status = "active"
            it.updatedAt = System.currentTimeMillis()
            onTaskUpdated(it)
        }
    }

    fun remove(gid: String) {
        val handle = handles.remove(gid)
        if (handle != null && handle.isValid) {
            session.remove(handle)
        }
        tasks.remove(gid)
        seedGoals.remove(gid)
    }

    fun has(gid: String): Boolean = tasks.containsKey(gid)

    fun getTask(gid: String): DownloadTask? = tasks[gid]

    fun allTasks(): Collection<DownloadTask> = tasks.values

    private fun bindHandle(handle: TorrentHandle, preferredGid: String? = null) {
        if (!handle.isValid) return
        val gid = preferredGid ?: findGidForHandle(handle) ?: return
        handles[gid] = handle
        refresh(gid, handle)
    }

    private fun findGidForHandle(handle: TorrentHandle): String? {
        val name = try {
            handle.name()
        } catch (_: Exception) {
            null
        }
        // Prefer unmatched active magnet/torrent tasks.
        val candidates = tasks.entries.filter { !handles.containsKey(it.key) }
        if (candidates.size == 1) return candidates.first().key
        if (name != null) {
            candidates.firstOrNull { it.value.fileName == name || it.value.url.contains(name) }
                ?.key
                ?.let { return it }
        }
        return candidates.firstOrNull()?.key
    }

    private fun onFinished(handle: TorrentHandle) {
        val gid = findGidForHandle(handle) ?: handles.entries.firstOrNull { it.value == handle }?.key
            ?: return
        handles[gid] = handle
        val task = tasks[gid] ?: return
        val goal = seedGoals[gid] ?: SeedGoal("stop", 0.0, 0)
        when (goal.mode) {
            "ratio", "time" -> {
                task.status = "active"
                goal.finishedAt = System.currentTimeMillis()
                refresh(gid, handle)
            }
            else -> {
                handle.pause()
                task.status = "complete"
                task.downloadSpeed = 0
                task.uploadSpeed = 0
                task.updatedAt = System.currentTimeMillis()
                onTaskUpdated(task)
            }
        }
    }

    private fun refreshAll() {
        for ((gid, handle) in handles) {
            if (!handle.isValid) continue
            refresh(gid, handle)
        }
    }

    private fun refresh(gid: String, handle: TorrentHandle) {
        val task = tasks[gid] ?: return
        if (!handle.isValid) return
        try {
            val status = handle.status()
            val total = status.totalWanted()
            val done = status.totalWantedDone()
            task.totalLength = total
            task.completedLength = done
            task.downloadSpeed = status.downloadRate().toLong()
            task.uploadSpeed = status.uploadRate().toLong()
            task.connections = status.numPeers()
            task.numPieces = status.numPieces()
            task.pieceLength = 0
            if (handle.hasMetadata()) {
                val name = handle.name()
                if (name.isNotBlank()) task.fileName = name
            }
            val goal = seedGoals[gid]
            if (goal != null &&
                task.status == "active" &&
                total > 0 &&
                done >= total
            ) {
                maybeStopSeeding(gid, handle, task, goal, status)
            }
            task.updatedAt = System.currentTimeMillis()
            onTaskUpdated(task)
        } catch (_: Exception) {
        }
    }

    private fun maybeStopSeeding(
        gid: String,
        handle: TorrentHandle,
        task: DownloadTask,
        goal: SeedGoal,
        status: org.libtorrent4j.TorrentStatus,
    ) {
        val stop = when (goal.mode) {
            "ratio" -> {
                val downloaded = status.totalWanted().coerceAtLeast(1)
                val uploaded = status.allTimeUpload()
                uploaded.toDouble() / downloaded.toDouble() >= goal.ratio
            }
            "time" -> {
                val finishedAt = goal.finishedAt ?: System.currentTimeMillis().also {
                    goal.finishedAt = it
                }
                System.currentTimeMillis() - finishedAt >= goal.timeMinutes * 60_000L
            }
            else -> true
        }
        if (stop) {
            handle.pause()
            task.status = "complete"
            task.downloadSpeed = 0
            task.uploadSpeed = 0
            task.updatedAt = System.currentTimeMillis()
            onTaskUpdated(task)
        }
    }

    data class SeedGoal(
        val mode: String,
        val ratio: Double,
        val timeMinutes: Int,
        var finishedAt: Long? = null,
    )
}
