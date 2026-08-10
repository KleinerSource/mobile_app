package com.mdcenter

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.SystemClock
import android.net.TrafficStats
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val STATS_CHANNEL = "md_center/player_stats"
        private const val CAPABILITIES_CHANNEL = "md_center/player_capabilities"
    }

    private var previousRxBytes: Long? = null
    private var previousTxBytes: Long? = null
    private var previousNetworkAtMs: Long? = null
    private var previousCpu: CpuSnapshot? = null

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
            CAPABILITIES_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPictureInPicture" -> enterPictureInPicture(result)
                else -> result.notImplemented()
            }
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
        )
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

    private fun enterPictureInPicture(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(false)
            return
        }
        if (isInPictureInPictureMode) {
            result.success(true)
            return
        }
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
        result.success(enterPictureInPictureMode(params))
    }

    private data class CpuSnapshot(
        val total: Long,
        val idle: Long,
    )
}
