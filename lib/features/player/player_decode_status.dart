import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PlayerDecodeLocation { local, server }

enum PlayerDecodeMode { hardware, software }

@immutable
class PlayerDecodeStatus {
  const PlayerDecodeStatus({
    required this.location,
    required this.mode,
    this.engine,
    this.isFallback = false,
  });

  const PlayerDecodeStatus.local({required bool hardware})
      : this(
          location: PlayerDecodeLocation.local,
          mode: hardware ? PlayerDecodeMode.hardware : PlayerDecodeMode.software,
        );

  factory PlayerDecodeStatus.server({
    String? engine,
    bool hardwareDecodeOk = true,
    bool isFallback = false,
  }) {
    final normalized = engine?.trim().toLowerCase() ?? '';
    final requestedHardware = normalized.isNotEmpty &&
        normalized != 'none' &&
        normalized != 'software' &&
        normalized != 'cpu';
    final hardware = requestedHardware && hardwareDecodeOk;
    return PlayerDecodeStatus(
      location: PlayerDecodeLocation.server,
      mode: hardware ? PlayerDecodeMode.hardware : PlayerDecodeMode.software,
      engine: engine,
      isFallback: isFallback || (requestedHardware && !hardwareDecodeOk),
    );
  }

  final PlayerDecodeLocation location;
  final PlayerDecodeMode mode;
  final String? engine;
  final bool isFallback;

  bool get isHardware => mode == PlayerDecodeMode.hardware;

  String get shortLabel {
    if (location == PlayerDecodeLocation.local) {
      return isHardware ? '本地硬解' : '本地软解';
    }
    if (isFallback) return '服务端软解回退';
    return isHardware ? '服务端硬解' : '服务端软解';
  }

  String get fullLabel {
    final engineName = _engineLabel;
    if (location == PlayerDecodeLocation.server &&
        isHardware &&
        engineName != null) {
      return '$shortLabel · $engineName';
    }
    return shortLabel;
  }

  IconData get icon {
    if (location == PlayerDecodeLocation.local) {
      return isHardware ? Icons.phone_android : Icons.phone_android_outlined;
    }
    return isHardware ? Icons.dns : Icons.dns_outlined;
  }

  Color get color {
    if (location == PlayerDecodeLocation.local) {
      return isHardware
          ? const Color(0xFF63D9FF)
          : const Color(0xFFFFC857);
    }
    return isHardware
        ? const Color(0xFF70E4A8)
        : const Color(0xFFFF8A65);
  }

  String? get _engineLabel {
    final normalized = engine?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty ||
        normalized == 'none' ||
        normalized == 'software' ||
        normalized == 'cpu') {
      return null;
    }
    return switch (normalized) {
      'videotoolbox' || 'vt' => 'VideoToolbox',
      'nvenc' => 'NVENC',
      'qsv' => 'Quick Sync',
      'amf' => 'AMF',
      _ => engine!.trim(),
    };
  }
}

class PlayerDecodeStatusBadge extends StatelessWidget {
  const PlayerDecodeStatusBadge({super.key, required this.status});

  final PlayerDecodeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Semantics(
      label: status.fullLabel,
      child: Tooltip(
        message: status.fullLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, color: color, size: 13),
                const SizedBox(width: 3),
                Text(
                  status.shortLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
