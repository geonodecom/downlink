package com.geonode.downlink.download

import java.io.File
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.min

class SegmentedDownloader(
    private val task: DownloadTask,
    private val partFile: File,
    private val onProgress: (completed: Long, speed: Long, connections: Int) -> Unit,
) {
    private val cancelled = AtomicBoolean(false)
    private val paused = AtomicBoolean(false)
    private val completed = AtomicLong(task.completedLength)
    private var executor = Executors.newFixedThreadPool(task.split.coerceIn(1, 16))

    fun pause() {
        paused.set(true)
    }

    fun cancel() {
        cancelled.set(true)
        paused.set(false)
    }

    fun download(): Result {
        try {
            val meta = probe()
            task.totalLength = meta.totalLength
            if (task.fileName.isBlank() || task.fileName == "download.bin") {
                task.fileName = meta.fileName
            }
            val supportsRanges = meta.acceptRanges && meta.totalLength > 0
            val split = if (supportsRanges) task.split.coerceIn(1, 16) else 1
            task.connections = split
            task.pieceLength = if (supportsRanges && split > 0) {
                (meta.totalLength + split - 1) / split
            } else {
                meta.totalLength
            }
            task.numPieces = split
            task.bitfield = "0".repeat(split)

            if (!partFile.exists()) {
                partFile.parentFile?.mkdirs()
                partFile.createNewFile()
            }
            RandomAccessFile(partFile, "rw").use { raf ->
                if (meta.totalLength > 0) {
                    raf.setLength(meta.totalLength)
                }
            }

            if (!supportsRanges || split == 1) {
                downloadSingle(meta.totalLength)
            } else {
                downloadSegments(meta.totalLength, split)
            }

            if (cancelled.get()) return Result.Cancelled
            if (paused.get()) return Result.Paused
            return Result.Complete
        } catch (error: Exception) {
            if (cancelled.get()) return Result.Cancelled
            if (paused.get()) return Result.Paused
            return Result.Failed(error.message ?: "Download failed")
        } finally {
            executor.shutdownNow()
        }
    }

    private fun downloadSingle(totalLength: Long) {
        val connection = openConnection(0, -1)
        try {
            RandomAccessFile(partFile, "rw").use { raf ->
                raf.seek(0)
                val buffer = ByteArray(64 * 1024)
                var lastReport = System.currentTimeMillis()
                var windowBytes = 0L
                while (true) {
                    waitIfPaused()
                    if (cancelled.get()) return
                    val read = connection.inputStream.read(buffer)
                    if (read < 0) break
                    raf.write(buffer, 0, read)
                    completed.addAndGet(read.toLong())
                    windowBytes += read
                    val now = System.currentTimeMillis()
                    if (now - lastReport >= 500) {
                        val speed = windowBytes * 1000 / (now - lastReport).coerceAtLeast(1)
                        onProgress(completed.get(), speed, 1)
                        lastReport = now
                        windowBytes = 0
                    }
                }
            }
            onProgress(completed.get().coerceAtLeast(totalLength), 0, 0)
        } finally {
            connection.disconnect()
        }
    }

    private fun downloadSegments(totalLength: Long, split: Int) {
        executor = Executors.newFixedThreadPool(split)
        val piece = (totalLength + split - 1) / split
        val futures = ArrayList<Future<*>>()
        val lastReport = AtomicLong(System.currentTimeMillis())
        val windowBytes = AtomicLong(0)

        for (index in 0 until split) {
            val start = index * piece
            if (start >= totalLength) break
            val end = min(totalLength - 1, start + piece - 1)
            futures.add(
                executor.submit {
                    downloadRange(start, end) { bytes ->
                        completed.addAndGet(bytes)
                        windowBytes.addAndGet(bytes)
                        val now = System.currentTimeMillis()
                        val prev = lastReport.get()
                        if (now - prev >= 500 && lastReport.compareAndSet(prev, now)) {
                            val speed = windowBytes.getAndSet(0) * 1000 / (now - prev).coerceAtLeast(1)
                            onProgress(completed.get(), speed, split)
                        }
                    }
                },
            )
        }

        for (future in futures) {
            future.get()
        }
        onProgress(completed.get(), 0, 0)
    }

    private fun downloadRange(start: Long, end: Long, onBytes: (Long) -> Unit) {
        val connection = openConnection(start, end)
        try {
            RandomAccessFile(partFile, "rw").use { raf ->
                raf.seek(start)
                val buffer = ByteArray(64 * 1024)
                var remaining = end - start + 1
                while (remaining > 0) {
                    waitIfPaused()
                    if (cancelled.get()) return
                    val toRead = min(buffer.size.toLong(), remaining).toInt()
                    val read = connection.inputStream.read(buffer, 0, toRead)
                    if (read < 0) break
                    raf.write(buffer, 0, read)
                    remaining -= read
                    onBytes(read.toLong())
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun waitIfPaused() {
        while (paused.get() && !cancelled.get()) {
            Thread.sleep(200)
        }
    }

    private fun openConnection(start: Long, end: Long): HttpURLConnection {
        val connection = URL(task.url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connectTimeout = 30_000
        connection.readTimeout = 60_000
        applyHeaders(connection)
        if (end >= start && start >= 0) {
            connection.setRequestProperty("Range", "bytes=$start-$end")
        }
        connection.connect()
        val code = connection.responseCode
        if (code !in 200..299) {
            throw IllegalStateException("HTTP $code")
        }
        return connection
    }

    private fun probe(): ProbeMeta {
        val head = URL(task.url).openConnection() as HttpURLConnection
        head.requestMethod = "HEAD"
        head.instanceFollowRedirects = true
        head.connectTimeout = 20_000
        head.readTimeout = 20_000
        applyHeaders(head)
        try {
            head.connect()
            val code = head.responseCode
            // TikTok/CDN often rejects HEAD with 403/405; fall back to unknown size.
            if (code !in 200..299) {
                return ProbeMeta(0, false, fileNameFromUrl(task.url))
            }
            val length = head.getHeaderField("Content-Length")?.toLongOrNull() ?: 0L
            val acceptRanges = head.getHeaderField("Accept-Ranges")?.contains("bytes") == true
            val disposition = head.getHeaderField("Content-Disposition")
            val name = parseFileName(disposition) ?: fileNameFromUrl(task.url)
            return ProbeMeta(length, acceptRanges || length > 0, name)
        } catch (_: Exception) {
            return ProbeMeta(0, false, fileNameFromUrl(task.url))
        } finally {
            head.disconnect()
        }
    }

    private fun applyHeaders(connection: HttpURLConnection) {
        val hasUserAgent = task.headers.keys.any { it.equals("User-Agent", ignoreCase = true) }
        if (!hasUserAgent) {
            connection.setRequestProperty("User-Agent", "Downlink/0.1")
        }
        for ((key, value) in task.headers) {
            connection.setRequestProperty(key, value)
        }
    }

    private fun parseFileName(disposition: String?): String? {
        if (disposition.isNullOrBlank()) return null
        val match = Regex("filename\\*?=(?:UTF-8''|\\\")?([^\";]+)", RegexOption.IGNORE_CASE)
            .find(disposition)
        return match?.groupValues?.getOrNull(1)?.trim()?.trim('"')
    }

    private fun fileNameFromUrl(url: String): String {
        val path = URL(url).path
        val name = path.substringAfterLast('/').ifBlank { "download.bin" }
        return name
    }

    data class ProbeMeta(
        val totalLength: Long,
        val acceptRanges: Boolean,
        val fileName: String,
    )

    sealed class Result {
        data object Complete : Result()
        data object Paused : Result()
        data object Cancelled : Result()
        data class Failed(val message: String) : Result()
    }
}
