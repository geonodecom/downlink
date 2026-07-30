package com.geonode.downlink.download

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class DownloadEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var appContext: android.content.Context
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methods = MethodChannel(
            binding.binaryMessenger,
            "com.geonode.downlink/engine",
        )
        events = EventChannel(
            binding.binaryMessenger,
            "com.geonode.downlink/engine_events",
        )
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        io.execute {
            try {
                val value = handle(call)
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post {
                    result.error("engine_error", error.message, null)
                }
            }
        }
    }

    private fun handle(call: MethodCall): Any? {
        return when (call.method) {
            "start" -> {
                val directory = call.argument<String>("downloadDirectory") ?: ""
                val maxActive = call.argument<Int>("maxActiveDownloads") ?: 1
                val split = call.argument<Int>("defaultSplit") ?: 4
                DownloadForegroundService.start(appContext, directory, maxActive, split)
                waitForService()?.configure(directory, maxActive, split)
                null
            }
            "shutdown" -> {
                service()?.shutdownEngine()
                null
            }
            "isHealthy" -> service()?.isHealthy() ?: false
            "addUri" -> {
                val headersArg = call.argument<Map<*, *>>("headers") ?: emptyMap<Any, Any>()
                val headers = headersArg.entries.associate {
                    it.key.toString() to it.value.toString()
                }
                val optionsArg = call.argument<Map<*, *>>("options") ?: emptyMap<Any, Any>()
                val options = optionsArg.entries.associate {
                    it.key.toString() to it.value
                }
                requireService().addUri(
                    url = call.argument<String>("url") ?: error("url required"),
                    directory = call.argument<String>("directory") ?: "",
                    split = call.argument<Int>("split") ?: 4,
                    fileName = call.argument<String>("fileName"),
                    headers = headers,
                    position = call.argument<Int>("position"),
                    options = options,
                )
            }
            "pause" -> {
                requireService().pause(call.argument<String>("gid") ?: error("gid required"))
                null
            }
            "unpause" -> {
                requireService().unpause(call.argument<String>("gid") ?: error("gid required"))
                null
            }
            "remove" -> {
                requireService().remove(call.argument<String>("gid") ?: error("gid required"))
                null
            }
            "changePosition" -> {
                requireService().changePosition(
                    call.argument<String>("gid") ?: error("gid required"),
                    call.argument<Int>("position") ?: 0,
                )
                null
            }
            "tellStatus" -> requireService().tellStatus(
                call.argument<String>("gid") ?: error("gid required"),
            )
            "tellActive" -> requireService().tellActive()
            "tellWaiting" -> requireService().tellWaiting(
                call.argument<Int>("offset") ?: 0,
                call.argument<Int>("limit") ?: 100,
            )
            "tellStopped" -> requireService().tellStopped(
                call.argument<Int>("offset") ?: 0,
                call.argument<Int>("limit") ?: 100,
            )
            "resetSession" -> {
                requireService().resetSession()
                null
            }
            "openUri" -> {
                val uri = call.argument<String>("uri") ?: return false
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(android.net.Uri.parse(uri), "*/*")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                appContext.startActivity(intent)
                true
            }
            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    true
                } else {
                    ContextCompat.checkSelfPermission(
                        appContext,
                        Manifest.permission.POST_NOTIFICATIONS,
                    ) == PackageManager.PERMISSION_GRANTED
                }
            }
            "getAbi" -> Build.SUPPORTED_ABIS.firstOrNull()
            "getFfmpegPath" -> {
                val path = "${appContext.applicationInfo.nativeLibraryDir}/libffmpeg.so"
                val file = java.io.File(path)
                if (!file.exists()) {
                    error(
                        "Bundled ffmpeg (libffmpeg.so) was not found. " +
                            "Rebuild with tool/android/fetch_deps.ps1.",
                    )
                }
                path
            }
            "mergeAv" -> {
                val videoPath = call.argument<String>("videoPath")
                    ?: error("videoPath required")
                val audioPath = call.argument<String>("audioPath")
                    ?: error("audioPath required")
                val outputPath = call.argument<String>("outputPath")
                    ?: error("outputPath required")
                MediaMerger.merge(videoPath, audioPath, outputPath)
                outputPath
            }
            "publishFile" -> {
                val sourcePath = call.argument<String>("sourcePath")
                    ?: error("sourcePath required")
                val displayName = call.argument<String>("displayName")
                    ?: error("displayName required")
                val uri = MediaStorePublisher.publish(
                    appContext,
                    java.io.File(sourcePath),
                    displayName,
                )
                uri.toString()
            }
            else -> throw IllegalArgumentException("Unknown method ${call.method}")
        }
    }

    private fun service(): DownloadForegroundService? = DownloadForegroundService.instance

    private fun requireService(): DownloadForegroundService {
        return waitForService() ?: error("Download service is not running")
    }

    private fun waitForService(): DownloadForegroundService? {
        repeat(50) {
            val current = service()
            if (current != null) return current
            Thread.sleep(100)
        }
        return service()
    }
}
