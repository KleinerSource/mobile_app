import 'dart:async';

import 'package:flutter/material.dart';

import 'player_device_stats.dart';

/// 播放器右上角 OSD · 与控制栏分离, 不参与手势命中测试。
class PlayerStatusOverlay extends StatefulWidget {
  const PlayerStatusOverlay({
    super.key,
    required this.stats,
    required this.showSystemTime,
    required this.showNetworkSpeed,
    required this.showCpuUsage,
    required this.showBattery,
  });

  final PlayerDeviceStats stats;
  final bool showSystemTime;
  final bool showNetworkSpeed;
  final bool showCpuUsage;
  final bool showBattery;

  @override
  State<PlayerStatusOverlay> createState() => _PlayerStatusOverlayState();
}

class _PlayerStatusOverlayState extends State<PlayerStatusOverlay> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncClockTimer();
  }

  @override
  void didUpdateWidget(covariant PlayerStatusOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSystemTime != widget.showSystemTime) {
      _syncClockTimer();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _syncClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = null;
    if (!widget.showSystemTime) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (widget.showSystemTime)
        _chip(Icons.access_time, _formatClock(_now)),
      if (widget.showNetworkSpeed)
        _chip(
          Icons.download,
          formatPlayerNetworkRate(widget.stats.downloadBytesPerSecond),
        ),
      if (widget.showCpuUsage)
        _chip(
          Icons.memory,
          widget.stats.cpuPercent == null
              ? 'CPU --'
              : 'CPU ${widget.stats.cpuPercent!.clamp(0, 100).toStringAsFixed(0)}%',
        ),
      if (widget.showBattery)
        _chip(_batteryIcon(widget.stats.batteryPercent), _batteryLabel()),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: chips,
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _batteryLabel() {
    final value = widget.stats.batteryPercent;
    return value == null ? '--' : '${value.clamp(0, 100)}%';
  }

  IconData _batteryIcon(int? value) {
    if (value == null) return Icons.battery_unknown;
    if (value <= 15) return Icons.battery_alert;
    if (value >= 85) return Icons.battery_full;
    return Icons.battery_std;
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
