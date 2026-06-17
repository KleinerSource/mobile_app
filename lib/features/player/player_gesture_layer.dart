import 'package:flutter/material.dart';

/// 播放器手势层 · 单个 GestureDetector 区分四类手势
///
/// - 单击: 显隐控制条
/// - 长按: 2x 加速; 长按中上滑提速 / 下滑减速 (0.5x~4x), 松手恢复 1x
/// - 水平拖动: 快进/快退 (拖动预览, 松手 seek)
/// - 左半屏垂直拖动: 亮度 / 右半屏垂直拖动: 音量
///
/// 靠 Flutter gesture arena 天然区分手势, 无需手动算角度:
/// 按住不动到长按阈值 → 进入调速 (后续移动走 onLongPressMoveUpdate);
/// 直接滑动 → 调亮度/音量。
/// position/duration 用 getter 回调拉取 (drag 开始时快照), 避免父级每秒
/// 更新进度时重建本层。
class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({
    super.key,
    required this.positionGetter,
    required this.durationGetter,
    required this.onTap,
    required this.onRateBoost,
    required this.onRateBoostEnd,
    required this.onSeekPreview,
    required this.onSeekCommit,
    required this.onBrightnessDelta,
    required this.onVolumeDelta,
    required this.onAxisDragEnd,
  });

  final Duration Function() positionGetter;
  final Duration Function() durationGetter;

  final VoidCallback onTap;

  /// 长按加速 · [rate] 当前倍速 (起始 2.0, 长按中上/下滑变化)
  final void Function(double rate) onRateBoost;

  /// 长按结束 · 恢复 1x
  final VoidCallback onRateBoostEnd;

  /// 水平拖动中 · [target] 目标位置, [deltaMs] 相对起点的真实偏移
  final void Function(Duration target, int deltaMs) onSeekPreview;

  /// 水平拖动松手 · 提交 seek
  final void Function(Duration target) onSeekCommit;

  /// 垂直拖动 · 归一化增量 (上滑为正)
  final void Function(double delta) onBrightnessDelta;
  final void Function(double delta) onVolumeDelta;

  /// 垂直拖动结束 · 用于延迟隐藏指示器
  final VoidCallback onAxisDragEnd;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  /// 全屏宽度滑动对应的 seek 秒数 (手感系数)
  static const double _fullWidthSeekSeconds = 90;

  /// 长按调速 · 每多少逻辑像素跨一档 (8px×档配 0.1x 刻度 → 上滑 160px 到 4x, 手感不变)
  static const double _rateStepPx = 8;
  static const double _baseRate = 2.0;
  static const double _minRate = 0.5;
  static const double _maxRate = 4.0;

  int _baseMs = 0;
  int _accumMs = 0;
  int _totalMs = 0;
  bool _isLeft = true;
  double _boostRate = _baseRate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final msPerPx = (_fullWidthSeekSeconds * 1000) / width;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPressStart: (_) {
            _boostRate = _baseRate;
            widget.onRateBoost(_boostRate);
          },
          onLongPressMoveUpdate: (d) {
            // 上滑 (dy<0) 提速, 下滑降速; 以长按起点为基准每档 0.1x。
            // 用整数十分位计算, 避免 0.1 浮点累加误差。
            final steps = (-d.localOffsetFromOrigin.dy / _rateStepPx).round();
            final tenths = (_baseRate * 10 + steps).clamp(_minRate * 10, _maxRate * 10);
            final rate = tenths / 10;
            if (rate != _boostRate) {
              _boostRate = rate;
              widget.onRateBoost(rate);
            }
          },
          onLongPressEnd: (_) => widget.onRateBoostEnd(),
          onHorizontalDragStart: (_) {
            _baseMs = widget.positionGetter().inMilliseconds;
            _totalMs = widget.durationGetter().inMilliseconds;
            _accumMs = 0;
          },
          onHorizontalDragUpdate: (d) {
            _accumMs += (d.delta.dx * msPerPx).round();
            final target = _clampTarget();
            widget.onSeekPreview(target, target.inMilliseconds - _baseMs);
          },
          onHorizontalDragEnd: (_) => widget.onSeekCommit(_clampTarget()),
          onVerticalDragStart: (d) => _isLeft = d.localPosition.dx < width / 2,
          onVerticalDragUpdate: (d) {
            final delta = -d.delta.dy / height;
            if (_isLeft) {
              widget.onBrightnessDelta(delta);
            } else {
              widget.onVolumeDelta(delta);
            }
          },
          onVerticalDragEnd: (_) => widget.onAxisDragEnd(),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Duration _clampTarget() {
    var ms = _baseMs + _accumMs;
    if (ms < 0) ms = 0;
    if (_totalMs > 0 && ms > _totalMs) ms = _totalMs;
    return Duration(milliseconds: ms);
  }
}
