import 'dart:async';

import 'package:flutter/material.dart';

import 'player_device_stats.dart';

/// 播放器顶部状态 OSD · 与控制栏分离, 不参与手势命中测试。
class PlayerStatusOverlay extends StatefulWidget {
  const PlayerStatusOverlay({
    super.key,
    required this.title,
    required this.stats,
    required this.showSystemTime,
    required this.showNetworkSpeed,
    required this.showCpuUsage,
    required this.showBattery,
  });

  final String title;
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
    return IgnorePointer(
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            if (widget.showSystemTime) _item(null, _formatClock(_now)),
            if (widget.showNetworkSpeed)
              _item(
                _networkIcon(widget.stats.networkType),
                formatPlayerNetworkRate(widget.stats.downloadBytesPerSecond),
                semanticLabel:
                    '${widget.stats.networkType.label} '
                    '${formatPlayerNetworkRate(widget.stats.downloadBytesPerSecond)}',
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (widget.showCpuUsage)
              _item(
                Icons.memory,
                widget.stats.cpuPercent == null
                    ? '--'
                    : '${widget.stats.cpuPercent!.clamp(0, 100).toStringAsFixed(0)}%',
                semanticLabel: widget.stats.cpuPercent == null
                    ? 'CPU --'
                    : 'CPU ${widget.stats.cpuPercent!.clamp(0, 100).toStringAsFixed(0)}%',
              ),
            if (widget.showBattery)
              _item(_batteryIcon(widget.stats.batteryPercent), _batteryLabel()),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData? icon, String label, {String? semanticLabel}) {
    return Semantics(
      label: semanticLabel ?? label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 15),
              if (label.isNotEmpty) const SizedBox(width: 4),
            ],
            if (label.isNotEmpty)
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

  IconData _networkIcon(PlayerNetworkType type) {
    return switch (type) {
      PlayerNetworkType.wifi => Icons.wifi,
      PlayerNetworkType.cellular4G ||
      PlayerNetworkType.cellular5G ||
      PlayerNetworkType.mobile ||
      PlayerNetworkType.offline => Icons.signal_cellular_alt,
      PlayerNetworkType.ethernet => Icons.settings_ethernet,
      PlayerNetworkType.unknown => Icons.network_check,
    };
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
