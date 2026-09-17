package com.example.safescan_frontend

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val CHANNEL = "safescan/apk_auto_scan"
		private const val RESULT_EXTRA = "apk_scan_result"
	}

	private var pendingResult: String? = null
	private var channel: MethodChannel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
		channel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"start" -> {
					startApkService(ApkScanService.ACTION_START, call.arguments as? String)
					result.success(null)
				}
				"stop" -> {
					startApkService(ApkScanService.ACTION_STOP)
					result.success(null)
				}
				"isEnabled" -> result.success(
					getSharedPreferences("apk_scan", MODE_PRIVATE)
						.getBoolean("enabled", false)
				)
				"getPendingResult" -> {
					result.success(pendingResult)
					pendingResult = null
				}
				else -> result.notImplemented()
			}
		}
		handleResultIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		handleResultIntent(intent)
	}

	private fun handleResultIntent(intent: Intent?) {
		val result = intent?.getStringExtra(RESULT_EXTRA) ?: return
		pendingResult = result
		channel?.invokeMethod("apkScanResult", result)
		intent.removeExtra(RESULT_EXTRA)
	}

	private fun startApkService(action: String, token: String? = null) {
		val serviceIntent = Intent(this, ApkScanService::class.java).apply {
			this.action = action
			if (!token.isNullOrBlank()) putExtra(ApkScanService.AUTH_TOKEN_EXTRA, token)
		}
		if (action == ApkScanService.ACTION_START && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			startForegroundService(serviceIntent)
		} else {
			startService(serviceIntent)
		}
	}
}
