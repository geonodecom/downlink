package com.geonode.downlink

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.geonode.downlink.download.DownloadEnginePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val shareChannelName = "com.geonode.downlink/share"
    private val appUpdateChannelName = "com.geonode.downlink/app_update"
    private var shareChannel: MethodChannel? = null
    private var appUpdateChannel: MethodChannel? = null
    private var pendingShareUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(DownloadEnginePlugin())
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingUrl" -> {
                    val url = pendingShareUrl
                    pendingShareUrl = null
                    result.success(url)
                }
                else -> result.notImplemented()
            }
        }
        appUpdateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appUpdateChannelName,
        )
        appUpdateChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_args", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(path)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        maybeCaptureShare(intent)
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("APK file not found")
        }
        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (intent.resolveActivity(packageManager) == null) {
            throw IllegalStateException("No app can install APK packages")
        }
        startActivity(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeCaptureShare(intent)
        requestNotificationPermission()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                1001,
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeCaptureShare(intent)
        pendingShareUrl?.let { url ->
            shareChannel?.invokeMethod("onShareUrl", url)
            pendingShareUrl = null
        }
    }

    private fun maybeCaptureShare(intent: Intent?) {
        if (intent == null) return
        val url = when (intent.action) {
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_VIEW -> intent.dataString
            else -> null
        }?.trim()
        if (url != null &&
            (url.startsWith("http://") ||
                url.startsWith("https://") ||
                url.startsWith("magnet:?"))
        ) {
            pendingShareUrl = url
        }
    }
}
