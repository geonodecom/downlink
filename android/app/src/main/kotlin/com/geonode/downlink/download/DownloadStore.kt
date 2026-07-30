package com.geonode.downlink.download

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class DownloadStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val tasks = ConcurrentHashMap<String, DownloadTask>()

    init {
        load()
    }

    fun all(): List<DownloadTask> = tasks.values.sortedBy { it.queuePosition }

    fun get(gid: String): DownloadTask? = tasks[gid]

    fun put(task: DownloadTask) {
        tasks[task.gid] = task
        persist()
    }

    fun remove(gid: String) {
        tasks.remove(gid)
        persist()
    }

    fun clear() {
        tasks.clear()
        persist()
    }

    fun nextGid(): String = UUID.randomUUID().toString().replace("-", "").take(16)

    fun activeCount(): Int = tasks.values.count { it.status == "active" }

    fun waiting(): List<DownloadTask> =
        tasks.values.filter { it.status == "waiting" }.sortedBy { it.queuePosition }

    fun active(): List<DownloadTask> =
        tasks.values.filter { it.status == "active" }.sortedBy { it.queuePosition }

    fun stopped(): List<DownloadTask> =
        tasks.values.filter {
            it.status == "complete" || it.status == "error" || it.status == "removed" || it.status == "paused"
        }.sortedByDescending { it.updatedAt }

    private fun persist() {
        val array = JSONArray()
        for (task in tasks.values) {
            array.put(
                JSONObject()
                    .put("gid", task.gid)
                    .put("url", task.url)
                    .put("fileName", task.fileName)
                    .put("directory", task.directory)
                    .put("split", task.split)
                    .put("headers", JSONObject(task.headers))
                    .put("status", task.status)
                    .put("totalLength", task.totalLength)
                    .put("completedLength", task.completedLength)
                    .put("downloadSpeed", task.downloadSpeed)
                    .put("uploadSpeed", task.uploadSpeed)
                    .put("connections", task.connections)
                    .put("pieceLength", task.pieceLength)
                    .put("numPieces", task.numPieces)
                    .put("bitfield", task.bitfield)
                    .put("errorMessage", task.errorMessage)
                    .put("contentUri", task.contentUri)
                    .put("partPath", task.partPath)
                    .put("queuePosition", task.queuePosition)
                    .put("createdAt", task.createdAt)
                    .put("updatedAt", task.updatedAt)
                    .put("isTorrent", task.isTorrent),
            )
        }
        prefs.edit().putString(KEY_TASKS, array.toString()).apply()
    }

    private fun load() {
        val raw = prefs.getString(KEY_TASKS, null) ?: return
        val array = JSONArray(raw)
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            val headersObj = obj.optJSONObject("headers") ?: JSONObject()
            val headers = mutableMapOf<String, String>()
            val keys = headersObj.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                headers[key] = headersObj.getString(key)
            }
            val task = DownloadTask(
                gid = obj.getString("gid"),
                url = obj.getString("url"),
                fileName = obj.getString("fileName"),
                directory = obj.getString("directory"),
                split = obj.optInt("split", 4),
                headers = headers,
                status = obj.optString("status", "waiting"),
                totalLength = obj.optLong("totalLength", 0),
                completedLength = obj.optLong("completedLength", 0),
                downloadSpeed = obj.optLong("downloadSpeed", 0),
                uploadSpeed = obj.optLong("uploadSpeed", 0),
                connections = obj.optInt("connections", 0),
                pieceLength = obj.optLong("pieceLength", 0),
                numPieces = obj.optInt("numPieces", 0),
                bitfield = if (obj.isNull("bitfield")) null else obj.optString("bitfield"),
                errorMessage = if (obj.isNull("errorMessage")) null else obj.optString("errorMessage"),
                contentUri = if (obj.isNull("contentUri")) null else obj.optString("contentUri"),
                partPath = if (obj.isNull("partPath")) null else obj.optString("partPath"),
                queuePosition = obj.optInt("queuePosition", 0),
                createdAt = obj.optLong("createdAt", System.currentTimeMillis()),
                updatedAt = obj.optLong("updatedAt", System.currentTimeMillis()),
                isTorrent = obj.optBoolean("isTorrent", false),
            )
            // Incomplete actives become waiting so they can be resumed after process death.
            if (task.status == "active") {
                task.status = "waiting"
                task.downloadSpeed = 0
                task.uploadSpeed = 0
                task.connections = 0
            }
            tasks[task.gid] = task
        }
    }

    companion object {
        private const val PREFS = "downlink_download_engine"
        private const val KEY_TASKS = "tasks"
    }
}
