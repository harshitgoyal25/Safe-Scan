package com.example.safescan_frontend

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors
import android.os.FileObserver

class ApkScanService : Service() {
    companion object {
        const val ACTION_START = "com.example.safescan_frontend.START_APK_SCAN"
        const val ACTION_STOP = "com.example.safescan_frontend.STOP_APK_SCAN"
        const val AUTH_TOKEN_EXTRA = "auth_token"
        private const val SERVICE_CHANNEL = "safescan_apk_monitor"
        private const val RESULT_CHANNEL = "safescan_apk_results"
        private const val SERVICE_NOTIFICATION_ID = 4101
        private const val SCAN_PATH = "/scan"
        private const val HISTORY_PATH = "/scan/history"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val observers = mutableListOf<FileObserver>()

    override fun onCreate() {
        super.onCreate()
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra(AUTH_TOKEN_EXTRA)?.let { token ->
            getSharedPreferences("apk_scan", MODE_PRIVATE)
                .edit()
                .putString(AUTH_TOKEN_EXTRA, token)
                .apply()
        }
        when (intent?.action) {
            ACTION_STOP -> stopMonitoring()
            else -> startMonitoring()
        }
        return START_STICKY
    }

    private fun startMonitoring() {
        if (observers.isNotEmpty()) return

        startForeground(SERVICE_NOTIFICATION_ID, monitoringNotification())
        getWatchedDirectories().forEach { directory ->
            val observer = object : FileObserver(
                directory.absolutePath,
                CLOSE_WRITE or MOVED_TO or CREATE
            ) {
                override fun onEvent(event: Int, path: String?) {
                    if (path.isNullOrBlank() || !path.lowercase().endsWith(".apk")) return
                    queueScan(File(directory, path))
                }
            }
            observer.startWatching()
            observers.add(observer)
        }
        getSharedPreferences("apk_scan", MODE_PRIVATE)
            .edit()
            .putBoolean("enabled", true)
            .apply()
    }

    private fun stopMonitoring() {
        observers.forEach { it.stopWatching() }
        observers.clear()
        getSharedPreferences("apk_scan", MODE_PRIVATE)
            .edit()
            .putBoolean("enabled", false)
            .remove(AUTH_TOKEN_EXTRA)
            .apply()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun getWatchedDirectories(): List<File> {
        val externalRoot = Environment.getExternalStorageDirectory()
        return listOf(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            File(externalRoot, "Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents"),
            File(externalRoot, "WhatsApp/Media/WhatsApp Documents"),
            File(externalRoot, "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Documents")
        ).filter { it.isDirectory }
    }

    private fun queueScan(file: File) {
        executor.execute {
            try {
                if (!waitUntilStable(file)) return@execute
                scanFile(file)
            } catch (error: Exception) {
                android.util.Log.e("SafeScan", "Automatic APK scan failed", error)
            }
        }
    }

    private fun waitUntilStable(file: File): Boolean {
        var previousSize = -1L
        repeat(60) {
            if (!file.exists()) return false
            val currentSize = file.length()
            if (currentSize > 0 && currentSize == previousSize) return true
            previousSize = currentSize
            Thread.sleep(1000)
        }
        return false
    }

    private fun scanFile(file: File) {
        val key = "${file.absolutePath}:${file.length()}:${file.lastModified()}"
        val preferences = getSharedPreferences("apk_scan", MODE_PRIVATE)
        if (preferences.getBoolean(key, false)) return

        val response = uploadApk(file)
        preferences.edit().putBoolean(key, true).apply()
        showResultNotification(response)
    }

    private fun uploadApk(file: File): JSONObject {
        val boundary = "SafeScan-${UUID.randomUUID()}"
        val connection = (URL(BuildConfig.SAFESCAN_API_URL + SCAN_PATH).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 30_000
            readTimeout = 180_000
            setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
            setRequestProperty("Authorization", "Bearer ${getAuthToken()}")
        }

        try {
            BufferedOutputStream(connection.outputStream).use { output ->
                output.write("--$boundary\r\n".toByteArray())
                output.write(
                    "Content-Disposition: form-data; name=\"file\"; filename=\"${file.name}\"\r\n".toByteArray()
                )
                output.write("Content-Type: application/vnd.android.package-archive\r\n\r\n".toByteArray())
                BufferedInputStream(file.inputStream()).use { input ->
                    val buffer = ByteArray(8192)
                    var count: Int
                    while (input.read(buffer).also { count = it } != -1) {
                        output.write(buffer, 0, count)
                    }
                }
                output.write("\r\n--$boundary--\r\n".toByteArray())
            }

            val responseCode = connection.responseCode
            val responseStream = if (responseCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }
            val body = responseStream.bufferedReader().use { it.readText() }
            if (responseCode !in 200..299) {
                throw IllegalStateException("APK scan returned HTTP $responseCode: $body")
            }
            return JSONObject(body).also { result ->
                saveHistory(file, result)
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun getAuthToken(): String {
        val firebaseUser = FirebaseAuth.getInstance().currentUser
        if (firebaseUser != null) {
            return Tasks.await(firebaseUser.getIdToken(false)).token
                ?: throw IllegalStateException("Firebase token unavailable")
        }
        throw IllegalStateException("No signed-in Firebase user")
    }

    private fun saveHistory(file: File, result: JSONObject) {
        val connection = (URL(BuildConfig.SAFESCAN_API_URL + HISTORY_PATH).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 30_000
            readTimeout = 30_000
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer ${getAuthToken()}")
        }
        try {
            val body = JSONObject().apply {
                put("scan_type", "apk")
                put("input_label", "APK file")
                put("input_value", file.name)
                put("result", result)
            }.toString()
            connection.outputStream.use { it.write(body.toByteArray()) }
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("History save returned HTTP ${connection.responseCode}")
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun showResultNotification(result: JSONObject) {
        val filename = result.optString("filename", "APK file")
        val prediction = result.optString("prediction", "Unknown")
        val isMalware = prediction.equals("Malware", ignoreCase = true)
        val title = if (isMalware) "Malware detected" else "APK scan complete"
        val body = if (isMalware) "$filename may be malicious." else "$filename appears safe."

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("apk_scan_result", result.toString())
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            filename.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, RESULT_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(filename.hashCode(), notification)
    }

    private fun monitoringNotification(): Notification {
        return NotificationCompat.Builder(this, SERVICE_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SafeScan automatic APK scan")
            .setContentText("Monitoring Downloads and WhatsApp documents")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                SERVICE_CHANNEL,
                "Automatic APK monitoring",
                NotificationManager.IMPORTANCE_LOW
            )
        )
        manager.createNotificationChannel(
            NotificationChannel(
                RESULT_CHANNEL,
                "APK scan results",
                NotificationManager.IMPORTANCE_HIGH
            )
        )
    }

    override fun onDestroy() {
        observers.forEach { it.stopWatching() }
        observers.clear()
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
