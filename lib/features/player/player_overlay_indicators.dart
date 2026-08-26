import 'package:flutter/material.dart';

/// mm:ss 或 h:mm:ss · 负值带前导 '-' (用于 seek 累计偏移)
String formatDuration(Duration d) {
  final neg = d.isNegative;
  final v = d.abs();
  final h = v.inHours;
  final mm = (v.inMinutes % 60).toString().padLeft(2, '0');
  final ss = (v.inSeconds % 60).toString().padLeft(2, '0');
  final base = h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  return neg ? '-$base' : base;
}

/// 指示器类别 · 供外部判断当前显示的是哪种调节提示
enum PlayerIndicatorKind { brightness, volume, speed, seek }

/// 中央指示器状态 · 四态互斥, 同一时刻只显示一种
@immutable
class PlayerIndicator {
  const PlayerIndicator._(
    this._kind, {
    this.value = 0,
    this.rate = 1,
    this.seekTarget = Duration.zero,
    this.seekTotal = Duration.zero,
    this.seekDeltaMs = 0,
  });

  /// 亮度 · [value] 0~1
  factory PlayerIndicator.brightness(double value) =>
      PlayerIndicator._(PlayerIndicatorKind.brightness, value: value);

  /// 音量 · [value] 0~1
  factory PlayerIndicator.volume(double value) =>
      PlayerIndicator._(PlayerIndicatorKind.volume, value: value);

  /// 长按倍速 · [rate] 当前速率
  factory PlayerIndicator.speed(double rate) =>
      PlayerIndicator._(PlayerIndicatorKind.speed, rate: rate);

  /// 水平拖动 seek 预览
  factory PlayerIndicator.seek({
    required Duration target,
    required Duration total,
    required int deltaMs,
  }) => PlayerIndicator._(
    PlayerIndicatorKind.seek,
    seekTarget: target,
    seekTotal: total,
    seekDeltaMs: deltaMs,
  );

  final PlayerIndicatorKind _kind;
  final double value;
  final double rate;
  final Duration seekTarget;
  final Duration seekTotal;
  final int seekDeltaMs;

  PlayerIndicatorKind get kind => _kind;

  /// 固定在画面上部显示的指示器 (倍速提示 / seek 预览)，其余保持居中。
  bool get showAtTop =>
      _kind == PlayerIndicatorKind.speed || _kind == PlayerIndicatorKind.seek;
}

/// 播放器指示器层 · 纯展示, 不拦手势。
///
/// 倍速提示与拖动 seek 预览固定在画面上部，避免遮挡影片中央内容；
/// 其他调节提示仍保持在中央，便于用户快速确认当前值。
class PlayerOverlayIndicators extends StatelessWidget {
  const PlayerOverlayIndicators({super.key, this.indicator});

  final PlayerIndicator? indicator;

  @override
  Widget build(BuildContext context) {
    final ind = indicator;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ind?.showAtTop == true)
            Positioned(
              top: 56,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topCenter,
                child: _animatedCard(context, ind),
              ),
            )
          else
            Center(child: _animatedCard(context, ind)),
        ],
      ),
    );
  }

  Widget _animatedCard(BuildContext context, PlayerIndicator? ind) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: ind == null
          ? const SizedBox.shrink()
          : KeyedSubtree(
              key: const ValueKey('indicator-card'),
              child: _card(context, ind),
            ),
    );
  }

  Widget _card(BuildContext context, PlayerIndicator ind) {
    switch (ind._kind) {
      case PlayerIndicatorKind.brightness:
        return _BarCard(icon: Icons.brightness_6, value: ind.value);
      case PlayerIndicatorKind.volume:
        return _BarCard(
          icon: ind.value <= 0 ? Icons.volume_off : Icons.volume_up,
          value: ind.value,
        );
      case PlayerIndicatorKind.speed:
        return _PillCard(
          icon: Icons.fast_forward,
          label: '${ind.rate.toStringAsFixed(1)}x 倍速播放中',
        );
      case PlayerIndicatorKind.seek:
        final total = ind.seekTotal;
        final deltaSec = (ind.seekDeltaMs / 1000).round();
        final sign = deltaSec >= 0 ? '+' : '';
        return _SeekCard(
          target: formatDuration(ind.seekTarget),
          total: total > Duration.zero ? formatDuration(total) : '--:--',
          delta: '$sign${deltaSec}s',
        );
    }
  }
}

/// 亮度 / 音量 · 图标 + 横向进度条 + 百分比
class _BarCard extends StatelessWidget {
  const _BarCard({required this.icon, required this.value});

  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    return _Shell(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 38,
            child: Text(
              '$pct%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 倍速 · 图标 + 文案
class _PillCard extends StatelessWidget {
  const _PillCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 拖动 seek 预览 · 目标时间 / 总时长 + 累计偏移
class _SeekCard extends StatelessWidget {
  const _SeekCard({
    required this.target,
    required this.total,
    required this.delta,
  });

  final String target;
  final String total;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                target,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' / $total',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            delta,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 指示器卡片外壳 · 半透明黑底圆角
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
