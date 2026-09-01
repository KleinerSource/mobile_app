package com.ohmymedia

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.system.Os
import android.net.TrafficStats
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.WindowManager
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceFragmentActivity() {
    companion object {
        private const val STATS_CHANNEL = "omm/player_stats"
        private const val UPDATE_CHANNEL = "omm/app_update"
        private const val DEVICE_LOCK_CHANNEL = "omm/device_lock"
        private const val BRIGHTNESS_CHANNEL = "omm/screen_brightness"
        // Android SDK 未在所有版本暴露 NETWORK_TYPE_LTE_CA，但其标准值为 19。
        private const val NETWORK_TYPE_LTE_CA = 19
    }

    private var previousRxBytes: Long? = null
    private var previousTxBytes: Long? = null
    private var previousNetworkAtMs: Long? = null
    private var previousCpu: CpuSnapshot? = null
    private var previousProcessCpuTicks: Long? = null
    private var previousProcessCpuAtMs: Long? = null
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

        // 亮度直通通道：只做即时读写，不缓存、不监听生命周期、不恢复。
        // 写入窗口级 screenBrightness 覆盖值，不触碰系统设置（无需权限）。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BRIGHTNESS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBrightness" -> result.success(getCurrentBrightness().toDouble())
                "setBrightness" -> setWindowBrightness(
                    (call.argument<Number>("brightness"))?.toDouble(),
                    result,
                )
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

    private fun setWindowBrightness(value: Double?, result: MethodChannel.Result) {
        if (value == null) {
            result.error("-2", "Unexpected brightness argument", null)
            return
        }
        val lp = window.attributes
        lp.screenBrightness = value.toFloat().coerceIn(0f, 1f)
        window.attributes = lp
        result.success(null)
    }

    private fun getCurrentBrightness(): Float {
        // 窗口覆盖值优先；无覆盖（BRIGHTNESS_OVERRIDE_NONE = -1）时按系统设置换算。
        val override = window.attributes.screenBrightness
        if (override >= 0f) return override.coerceIn(0f, 1f)
        return try {
            val raw = Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS)
            (raw / getMaximumBrightness()).coerceIn(0f, 1f)
        } catch (_: Settings.SettingNotFoundException) {
            0.5f
        }
    }

    private fun getMaximumBrightness(): Float {
        // 各 ROM 的最大值不一定是 255（如 MIUI），与 screen_brightness 插件
        // 相同的反射读取 PowerManager.BRIGHTNESS_ON，失败回退 255。
        return try {
            val powerManager = getSystemService(PowerManager::class.java) ?: return 255f
            val field = powerManager.javaClass.declaredFields
                .firstOrNull { it.name == "BRIGHTNESS_ON" }
            field?.isAccessible = true
            (field?.get(powerManager) as? Int)?.toFloat() ?: 255f
        } catch (_: Exception) {
            255f
        }
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
        val currentCpu = readCpuSnapshot()
        val previousCpuSnapshot = previousCpu
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
            "cpu_percent" to readCpuUsage(currentCpu, previousCpuSnapshot),
            "process_cpu_percent" to readProcessCpuUsage(now),
            "ram_used_mb" to readProcessMemoryMegabytes(),
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

    private fun readCpuUsage(
        current: CpuSnapshot?,
        previous: CpuSnapshot?,
    ): Double? {
        if (current == null) return null
        previousCpu = current
        if (previous == null) return null
        val totalDelta = current.total - previous.total
        val idleDelta = current.idle - previous.idle
        if (totalDelta <= 0) return null
        return ((totalDelta - idleDelta).toDouble() / totalDelta * 100)
            .coerceIn(0.0, 100.0)
    }

    // /proc 时间字段的时钟粒度（USER_HZ），绝大多数 Android 设备为 100。
    private val clockTicksPerSecond: Long = try {
        Os.sysconf(Os._SC_CLK_TCK).coerceAtLeast(1)
    } catch (_: Exception) {
        100L
    }

    // 单核口径：100% = 跑满 1 个核，多线程可超过 100%。
    private fun readProcessCpuUsage(nowMs: Long): Double? {
        val processTicks = readProcessCpuTicks() ?: return null
        val previousTicks = previousProcessCpuTicks
        val previousAtMs = previousProcessCpuAtMs
        previousProcessCpuTicks = processTicks
        previousProcessCpuAtMs = nowMs
        if (previousTicks == null || previousAtMs == null) return null
        val elapsedMs = nowMs - previousAtMs
        val processDelta = processTicks - previousTicks
        if (elapsedMs <= 0 || processDelta < 0) return null
        val elapsedSeconds = elapsedMs / 1000.0
        val maxPercent = 100.0 * Runtime.getRuntime().availableProcessors()
        return (processDelta.toDouble() / (elapsedSeconds * clockTicksPerSecond) * 100)
            .coerceIn(0.0, maxPercent)
    }

    private fun readProcessCpuTicks(): Long? {
        return try {
            val line = File("/proc/self/stat").readText()
            val commandEnd = line.lastIndexOf(')')
            if (commandEnd < 0) return null
            val fields = line.substring(commandEnd + 2).trim().split(Regex("\\s+"))
            val user = fields.getOrNull(11)?.toLongOrNull() ?: return null
            val system = fields.getOrNull(12)?.toLongOrNull() ?: return null
            user + system
        } catch (_: Exception) {
            null
        }
    }

    private fun readProcessMemoryMegabytes(): Int? {
        val activityManager = getSystemService(ActivityManager::class.java)
            ?: return null
        val memoryInfo = activityManager
            .getProcessMemoryInfo(intArrayOf(Process.myPid()))
            .firstOrNull()
            ?: return null
        if (memoryInfo.totalPss < 0) return null
        return Math.round(memoryInfo.totalPss / 1024.0).toInt()
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
