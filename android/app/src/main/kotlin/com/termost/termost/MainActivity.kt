package com.termost.termost

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.termost.termost/keepalive"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title") ?: "TerMost - 后台连接保活中"
                    val content = call.argument<String>("content") ?: "保持活动 SSH 会话与端口转发连接"
                    requestNotificationPermissionIfNeeded()
                    KeepAliveService.start(this, title, content)
                    result.success(true)
                }
                "update" -> {
                    val title = call.argument<String>("title") ?: "TerMost - 后台连接保活中"
                    val content = call.argument<String>("content") ?: "保持活动 SSH 会话与端口转发连接"
                    if (KeepAliveService.isServiceRunning) {
                        KeepAliveService.update(this, title, content)
                    } else {
                        requestNotificationPermissionIfNeeded()
                        KeepAliveService.start(this, title, content)
                    }
                    result.success(true)
                }
                "stop" -> {
                    KeepAliveService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }
}
