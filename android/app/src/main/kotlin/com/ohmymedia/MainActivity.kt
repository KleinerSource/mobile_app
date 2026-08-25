package com.ohmymedia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.SystemClock
import android.net.TrafficStats
import android.telephony.TelephonyManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val STATS_CHANNEL = "omm/player_stats"
        private const val UPDATE_CHANNEL = "omm/app_update"
        private const val DEVICE_LOCK_CHANNEL = "omm/device_lock"
        // Android SDK 未在所有版本暴露 NETWORK_TYPE_LTE_CA，但其标准值为 19。
        private const val NETWORK_TYPE_LTE_CA = 19
    }

    private var previousRxBytes: Long? = null
    private var previousTxBytes: Long? = null
    private var previousNetworkAtMs: Long? = null
    private var previousCpu: CpuSnapshot? = null
    private var deviceLockSink: EventChannel.EventSink? = null
    private var deviceLockReceiverRegistered = false

    private val deviceLockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> deviceLockSink?.success("locked")
                Intent.ACTION_USER_PRESENT -> deviceLockSink?.success("unlocked")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STATS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readStats" -> result.success(readStats())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> installApk(call.argument<String>("path"), result)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_LOCK_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink?,
            ) {
                deviceLockSink = events
                if (deviceLockReceiverRegistered) return
                val filter = IntentFilter().apply {
                    addAction(Intent.ACTION_SCREEN_OFF)
                    addAction(Intent.ACTION_USER_PRESENT)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(
                        deviceLockReceiver,
                        filter,
                        Context.RECEIVER_NOT_EXPORTED,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    registerReceiver(deviceLockReceiver, filter)
                }
                deviceLockReceiverRegistered = true
            }

            override fun onCancel(arguments: Any?) {
                deviceLockSink = null
                unregisterDeviceLockReceiver()
            }
        })
    }

    override fun onDestroy() {
        unregisterDeviceLockReceiver()
        super.onDestroy()
    }

    private fun unregisterDeviceLockReceiver() {
        if (!deviceLockReceiverRegistered) return
        unregisterReceiver(deviceLockReceiver)
        deviceLockReceiverRegistered = false
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            val apk = File(path)
            if (!apk.exists()) {
                result.success(false)
                return
            }
            val authority = "${applicationContext.packageName}.fileprovider"
            val uri = FileProvider.getUriForFile(this, authority, apk)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun readStats(): Map<String, Any?> {
        val now = SystemClock.elapsedRealtime()
        val network = readNetworkBytes()
        val elapsed = previousNetworkAtMs?.let { now - it }
        val download = if (network != null && elapsed != null && elapsed > 0) {
            bytesPerSecond(network.first, previousRxBytes, elapsed)
        } else {
            null
        }
        val upload = if (network != null && elapsed != null && elapsed > 0) {
            bytesPerSecond(network.second, previousTxBytes, elapsed)
        } else {
            null
        }
        if (network != null) {
            previousRxBytes = network.first
            previousTxBytes = network.second
            previousNetworkAtMs = now
        }

        return mapOf(
            "cpu_percent" to readCpuUsage(),
            "battery_percent" to readBatteryPercent(),
            "download_bps" to download,
            "upload_bps" to upload,
            "network_type" to readNetworkType(),
        )
    }

    private fun readNetworkType(): String {
        val connectivity =
            getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return "unknown"
        val network = connectivity.activeNetwork ?: return "offline"
        val capabilities = connectivity.getNetworkCapabilities(network)
            ?: return "offline"

        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
                readCellularNetworkType()
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
                "ethernet"
            else -> "unknown"
        }
    }

    private fun readCellularNetworkType(): String {
        val telephony =
            getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                ?: return "mobile"
        val networkType = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                telephony.dataNetworkType
            } else {
                @Suppress("DEPRECATION")
                telephony.networkType
            }
        } catch (_: SecurityException) {
            return "mobile"
        }

        return when (networkType) {
            TelephonyManager.NETWORK_TYPE_NR -> "5g"
            TelephonyManager.NETWORK_TYPE_LTE,
            NETWORK_TYPE_LTE_CA -> "4g"
            else -> "mobile"
        }
    }

    private fun bytesPerSecond(
        current: Long,
        previous: Long?,
        elapsedMs: Long,
    ): Long? {
        if (previous == null || current < previous || elapsedMs <= 0) return null
        return ((current - previous).toDouble() * 1000 / elapsedMs).toLong()
    }

    private fun readBatteryPercent(): Int? {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return null
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) return null
        return (level * 100 / scale).coerceIn(0, 100)
    }

    private fun readNetworkBytes(): Pair<Long, Long>? {
        val rx = TrafficStats.getTotalRxBytes()
        val tx = TrafficStats.getTotalTxBytes()
        if (rx < 0 && tx < 0) return null
        return Pair(rx.coerceAtLeast(0), tx.coerceAtLeast(0))
    }

    private fun readCpuUsage(): Double? {
        val current = readCpuSnapshot() ?: return null
        val previous = previousCpu
        previousCpu = current
        if (previous == null) return null
        val totalDelta = current.total - previous.total
        val idleDelta = current.idle - previous.idle
        if (totalDelta <= 0) return null
        return ((totalDelta - idleDelta).toDouble() / totalDelta * 100)
            .coerceIn(0.0, 100.0)
    }

    private fun readCpuSnapshot(): CpuSnapshot? {
        return try {
            File("/proc/stat").bufferedReader().useLines { lines ->
                val parts = lines.firstOrNull()
                    ?.trim()
                    ?.split(Regex("\\s+"))
                    ?: return@useLines null
                if (parts.firstOrNull() != "cpu") return@useLines null
                val values = parts.drop(1).take(8).mapNotNull { it.toLongOrNull() }
                if (values.size < 4) return@useLines null
                val idle = values[3] + (values.getOrNull(4) ?: 0)
                CpuSnapshot(values.sum(), idle)
            }
        } catch (_: Exception) {
            null
        }
    }

    private data class CpuSnapshot(
        val total: Long,
        val idle: Long,
    )
}
