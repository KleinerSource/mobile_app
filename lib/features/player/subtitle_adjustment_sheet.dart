import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import 'subtitle_settings.dart';

/// 在播放器中央显示紧凑的字幕调节浮层。
///
/// 浮层不复制字幕预览，所有按钮操作都会通过 [onChanged] 直接作用于
/// 播放器当前的字幕层，影片画面和真实字幕始终保持可见。
Future<void> showSubtitleAdjustmentDialog({
  required BuildContext context,
  required SubtitleAdjustments initial,
  required ValueChanged<SubtitleAdjustments> onChanged,
  SubtitleVerticalOffsetBounds verticalOffsetBounds =
      const SubtitleVerticalOffsetBounds(),
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '字幕设置',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final tint = isDark
          ? const Color(0xD91B1A24)
          : const Color(0xD9FAFAFA);
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassPanel(
                tint: tint,
                sigma: 30,
                borderRadius: BorderRadius.circular(26),
                child: SubtitleAdjustmentSheet(
                  initial: initial,
                  onChanged: onChanged,
                  verticalOffsetBounds: verticalOffsetBounds,
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

/// 播放器内字幕调节控件。
class SubtitleAdjustmentSheet extends StatefulWidget {
  const SubtitleAdjustmentSheet({
    super.key,
    required this.initial,
    required this.onChanged,
    this.verticalOffsetBounds = const SubtitleVerticalOffsetBounds(),
  });

  final SubtitleAdjustments initial;
  final ValueChanged<SubtitleAdjustments> onChanged;
  final SubtitleVerticalOffsetBounds verticalOffsetBounds;

  @override
  State<SubtitleAdjustmentSheet> createState() =>
      _SubtitleAdjustmentSheetState();
}

class _SubtitleAdjustmentSheetState extends State<SubtitleAdjustmentSheet> {
  late SubtitleAdjustments _adjustments = widget.initial.copyWith(
    verticalOffset: widget.verticalOffsetBounds.clamp(
      widget.initial.verticalOffset,
    ),
  );

  void _update(SubtitleAdjustments next) {
    final bounded = widget.verticalOffsetBounds.clampAdjustments(next);
    setState(() => _adjustments = bounded);
    widget.onChanged(bounded);
  }

  void _reset() {
    AppHaptics.medium();
    _update(const SubtitleAdjustments());
  }

  void _changeDelay(int delta) {
    final next = (_adjustments.delayMs + delta).clamp(-5000, 5000).toInt();
    _update(_adjustments.copyWith(delayMs: next));
  }

  void _changeVertical(double delta) {
    final next = widget.verticalOffsetBounds.clamp(
      _adjustments.verticalOffset + delta,
    );
    _update(_adjustments.copyWith(verticalOffset: next));
  }

  void _changeSize(double delta) {
    final next = _stepDouble(
      _adjustments.sizeScale,
      delta,
      min: 0.5,
      max: 2.0,
    );
    _update(_adjustments.copyWith(sizeScale: next));
  }

  void _changeOpacity(double delta) {
    final next = _stepDouble(
      _adjustments.opacity,
      delta,
      min: 0.1,
      max: 1.0,
    );
    _update(_adjustments.copyWith(opacity: next));
  }

  double _stepDouble(
    double value,
    double delta, {
    required double min,
    required double max,
  }) {
    final stepped = ((value + delta) * 100).round() / 100;
    return stepped.clamp(min, max).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: c.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('字幕设置', style: AppText.sectionTitle(context)),
              ),
              IconButton(
                tooltip: '恢复本次播放默认',
                onPressed: _reset,
                icon: Icon(Icons.restore, color: c.muted, size: 20),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: c.muted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AdjustmentRow(
            title: '延迟偏移',
            value: '${(_adjustments.delayMs / 1000).toStringAsFixed(1)} s',
            onDecrease: _adjustments.delayMs <= -5000
                ? null
                : () => _changeDelay(-100),
            onIncrease: _adjustments.delayMs >= 5000
                ? null
                : () => _changeDelay(100),
          ),
          _AdjustmentRow(
            title: '垂直偏移',
            value: _adjustments.verticalOffset.round().toString(),
            onDecrease: _adjustments.verticalOffset <=
                    widget.verticalOffsetBounds.min
                ? null
                : () => _changeVertical(-5),
            onIncrease: _adjustments.verticalOffset >=
                    widget.verticalOffsetBounds.max
                ? null
                : () => _changeVertical(5),
          ),
          _AdjustmentRow(
            title: '大小缩放',
            value: '${(_adjustments.sizeScale * 100).round()}%',
            onDecrease: _adjustments.sizeScale <= 0.5
                ? null
                : () => _changeSize(-0.05),
            onIncrease: _adjustments.sizeScale >= 2.0
                ? null
                : () => _changeSize(0.05),
          ),
          _AdjustmentRow(
            title: '不透明度',
            value: '${(_adjustments.opacity * 100).round()}%',
            onDecrease: _adjustments.opacity <= 0.1
                ? null
                : () => _changeOpacity(-0.05),
            onIncrease: _adjustments.opacity >= 1.0
                ? null
                : () => _changeOpacity(0.05),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.title,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Stepper(
            onDecrease: onDecrease,
            onIncrease: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.onDecrease, required this.onIncrease});

  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            tooltip: '减少',
            onPressed: onDecrease,
          ),
          Container(width: 1, height: 22, color: c.divider),
          _StepperButton(
            icon: Icons.add,
            tooltip: '增加',
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  static const _repeatInterval = Duration(milliseconds: 120);

  Timer? _repeatTimer;

  void _invoke() {
    final action = widget.onPressed;
    if (action == null) return;
    AppHaptics.selection();
    action();
  }

  void _startRepeating(LongPressStartDetails _) {
    if (widget.onPressed == null) return;
    _invoke();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(_repeatInterval, (_) {
      if (!mounted || widget.onPressed == null) {
        _stopRepeating();
        return;
      }
      _invoke();
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        child: SizedBox(
          width: 45,
          height: 40,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _invoke : null,
            onLongPressStart: enabled ? _startRepeating : null,
            onLongPressEnd: enabled ? (_) => _stopRepeating() : null,
            onLongPressCancel: enabled ? _stopRepeating : null,
            child: Center(
              child: Icon(
                widget.icon,
                color: enabled ? c.text : c.muted2,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
