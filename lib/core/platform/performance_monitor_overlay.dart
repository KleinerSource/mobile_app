import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';

import '../../features/player/video/player_device_stats.dart';

/// 全局性能监视器，仅在 Debug 设置和性能监视器开关同时开启时挂载。
class PerformanceMonitorOverlay extends StatefulWidget {
  const PerformanceMonitorOverlay({super.key, this.statsReader});

  final PlayerDeviceStatsReader? statsReader;

  @override
  State<PerformanceMonitorOverlay> createState() =>
      _PerformanceMonitorOverlayState();
}

class _PerformanceMonitorOverlayState extends State<PerformanceMonitorOverlay>
    with WidgetsBindingObserver {
  static const _sampleInterval = Duration(seconds: 1);

  Timer? _sampleTimer;
  PlayerDeviceStats _stats = const PlayerDeviceStats();
  final Stopwatch _fpsWindow = Stopwatch()..start();
  int _frameCount = 0;
  double? _fps;
  bool _hasSampledFps = false;
  bool _sampleInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
      ..addObserver(this)
      ..addTimingsCallback(_onTimings);
    _startSampling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSampling();
    } else {
      _stopSampling();
    }
  }

  @override
  void dispose() {
    _stopSampling();
    WidgetsBinding.instance
      ..removeTimingsCallback(_onTimings)
      ..removeObserver(this);
    super.dispose();
  }

  void _startSampling() {
    if (!mounted || _sampleTimer != null) return;
    _fpsWindow
      ..reset()
      ..start();
    _frameCount = 0;
    _sampleTimer = Timer.periodic(_sampleInterval, (_) {
      unawaited(_sample());
    });
    unawaited(_sample());
  }

  void _stopSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _sampleInFlight = false;
    _fpsWindow.stop();
    _frameCount = 0;
    _fps = null;
    _hasSampledFps = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_sampleTimer == null) return;
    _frameCount += timings.length;
  }

  Future<void> _sample() async {
    if (!mounted || _sampleInFlight || _sampleTimer == null) return;
    _sampleInFlight = true;
    final elapsedMs = _fpsWindow.elapsedMilliseconds;
    final frameCount = _frameCount;
    _fpsWindow
      ..reset()
      ..start();
    _frameCount = 0;
    final fps = !_hasSampledFps || elapsedMs <= 0
        ? null
        : frameCount * 1000 / elapsedMs;
    _hasSampledFps = true;

    try {
      final stats =
          await (widget.statsReader ?? const PlayerDeviceStatsReader()).read();
      if (!mounted || _sampleTimer == null) return;
      setState(() {
        _fps = fps;
        _stats = stats;
      });
    } finally {
      _sampleInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fps = _fps == null ? '--' : _fps!.toStringAsFixed(0);
    final cpu = _stats.processCpuPercent == null
        ? '--'
        : _stats.processCpuPercent!.clamp(0, 100).toStringAsFixed(0);
    final ram = _stats.ramUsedMegabytes?.toString() ?? '--';
    const label = 'FPS';

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Semantics(
                  container: true,
                  label: 'FPS $fps，CPU $cpu%，RAM ${ram}M',
                  child: Text(
                    '$label $fps · CPU $cpu% · RAM ${ram}M',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
