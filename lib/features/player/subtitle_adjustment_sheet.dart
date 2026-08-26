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
      final tint = isDark ? const Color(0xD91B1A24) : const Color(0xD9FAFAFA);
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
    _update(_adjustments.copyWith(delayMs: _adjustments.delayMs + delta));
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
      min: subtitleSizeScaleMin,
      max: subtitleSizeScaleMax,
    );
    _update(_adjustments.copyWith(sizeScale: next));
  }

  void _changeOpacity(double delta) {
    final next = _stepDouble(
      _adjustments.opacity,
      delta,
      min: subtitleOpacityMin,
      max: subtitleOpacityMax,
    );
    _update(_adjustments.copyWith(opacity: next));
  }

  Future<void> _editDelay() async {
    final value = await _showNumericInput(
      title: '延迟偏移',
      initialValue: (_adjustments.delayMs / 1000).toStringAsFixed(1),
      unit: '秒',
    );
    if (!mounted || value == null) return;
    // 无上下限，但需饱和到 int 表示范围，避免极端输入溢出。
    final ms = (value * 1000).clamp(-9.0e18, 9.0e18);
    _update(_adjustments.copyWith(delayMs: ms.round()));
  }

  Future<void> _editVerticalOffset() async {
    final value = await _showNumericInput(
      title: '垂直偏移',
      initialValue: _adjustments.verticalOffset.round().toString(),
      unit: '像素',
      min: widget.verticalOffsetBounds.min,
      max: widget.verticalOffsetBounds.max,
    );
    if (!mounted || value == null) return;
    _update(_adjustments.copyWith(verticalOffset: value.roundToDouble()));
  }

  Future<void> _editSize() async {
    final value = await _showNumericInput(
      title: '大小缩放',
      initialValue: (_adjustments.sizeScale * 100).round().toString(),
      unit: '%',
      min: subtitleSizeScaleMin * 100,
      max: subtitleSizeScaleMax * 100,
    );
    if (!mounted || value == null) return;
    _update(_adjustments.copyWith(sizeScale: value / 100));
  }

  Future<void> _editOpacity() async {
    final value = await _showNumericInput(
      title: '不透明度',
      initialValue: (_adjustments.opacity * 100).round().toString(),
      unit: '%',
      min: subtitleOpacityMin * 100,
      max: subtitleOpacityMax * 100,
    );
    if (!mounted || value == null) return;
    _update(_adjustments.copyWith(opacity: value / 100));
  }

  Future<double?> _showNumericInput({
    required String title,
    required String initialValue,
    required String unit,
    double? min,
    double? max,
  }) {
    return showDialog<double>(
      context: context,
      builder: (_) => _SubtitleNumericInputDialog(
        title: title,
        initialValue: initialValue,
        unit: unit,
        min: min,
        max: max,
      ),
    );
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
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Padding(
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
                  child: Text(
                    '字幕设置',
                    style: AppText.sectionTitle(
                      context,
                    ).copyWith(decoration: TextDecoration.none),
                  ),
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
              onValueTap: _editDelay,
              onDecrease: () => _changeDelay(-100),
              onIncrease: () => _changeDelay(100),
            ),
            _AdjustmentRow(
              title: '垂直偏移',
              value: _adjustments.verticalOffset.round().toString(),
              onValueTap: _editVerticalOffset,
              onDecrease:
                  _adjustments.verticalOffset <= widget.verticalOffsetBounds.min
                  ? null
                  : () => _changeVertical(-5),
              onIncrease:
                  _adjustments.verticalOffset >= widget.verticalOffsetBounds.max
                  ? null
                  : () => _changeVertical(5),
            ),
            _AdjustmentRow(
              title: '大小缩放',
              value: '${(_adjustments.sizeScale * 100).round()}%',
              onValueTap: _editSize,
              onDecrease: _adjustments.sizeScale <= subtitleSizeScaleMin
                  ? null
                  : () => _changeSize(-0.05),
              onIncrease: _adjustments.sizeScale >= subtitleSizeScaleMax
                  ? null
                  : () => _changeSize(0.05),
            ),
            _AdjustmentRow(
              title: '不透明度',
              value: '${(_adjustments.opacity * 100).round()}%',
              onValueTap: _editOpacity,
              onDecrease: _adjustments.opacity <= subtitleOpacityMin
                  ? null
                  : () => _changeOpacity(-0.05),
              onIncrease: _adjustments.opacity >= subtitleOpacityMax
                  ? null
                  : () => _changeOpacity(0.05),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.title,
    required this.value,
    required this.onValueTap,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final String value;
  final VoidCallback onValueTap;
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
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Tooltip(
            message: '编辑$title',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onValueTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: SizedBox(
                  width: 70,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 15,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Stepper(onDecrease: onDecrease, onIncrease: onIncrease),
        ],
      ),
    );
  }
}

class _SubtitleNumericInputDialog extends StatefulWidget {
  const _SubtitleNumericInputDialog({
    required this.title,
    required this.initialValue,
    required this.unit,
    this.min,
    this.max,
  });

  final String title;
  final String initialValue;
  final String unit;
  final double? min;
  final double? max;

  @override
  State<_SubtitleNumericInputDialog> createState() =>
      _SubtitleNumericInputDialogState();
}

class _SubtitleNumericInputDialogState
    extends State<_SubtitleNumericInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || !value.isFinite) {
      setState(() => _errorText = '请输入有效数字');
      return;
    }
    final min = widget.min;
    final max = widget.max;
    if (min != null && value < min) {
      setState(() => _errorText = '不能低于 ${_formatNumber(min)}');
      return;
    }
    if (max != null && value > max) {
      setState(() => _errorText = '不能高于 ${_formatNumber(max)}');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surfaceAlt.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.cardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              // border 为 none 时 InputDecorator 默认顶对齐,prefixIcon 的 48px
              // 最小高度会把输入行撑高,文字会被钉在顶部,需显式垂直居中。
              textAlignVertical: TextAlignVertical.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.tune),
                suffixText: widget.unit,
                errorText: _errorText,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '范围：${_rangeHint(widget.min, widget.max)}',
            style: TextStyle(
              color: c.muted,
              fontFamily: 'Inter',
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}

String _rangeHint(double? min, double? max) {
  if (min == null && max == null) return '无限制';
  if (min == null) return '~ ${_formatNumber(max!)}';
  if (max == null) return '${_formatNumber(min)} ~ 无限制';
  return '${_formatNumber(min)} ~ ${_formatNumber(max)}';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.onDecrease, required this.onIncrease});

  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 深色下 surfaceAlt/cardBorder 的白色透明度太低,叠在玻璃面板上轮廓
    // 几乎不可见,需用更高的白色叠层保证胶囊和分隔线可辨识。
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : c.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.18) : c.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            tooltip: '减少',
            onPressed: onDecrease,
          ),
          Container(
            width: 1,
            height: 22,
            color: isDark ? Colors.white.withValues(alpha: 0.14) : c.divider,
          ),
          _StepperButton(icon: Icons.add, tooltip: '增加', onPressed: onIncrease),
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
  // 基础连发节奏；按住 3 秒后提速一倍，5 秒后再提一倍，
  // 让长按可以更快到达目标值。按住时长用已排定的连发间隔累加
  // 度量，避免依赖真实时钟。
  static const _repeatInterval = Duration(milliseconds: 120);
  static const _speedUp1After = Duration(seconds: 3);
  static const _speedUp2After = Duration(seconds: 5);

  Timer? _repeatTimer;
  Duration _heldFor = Duration.zero;

  void _invoke() {
    final action = widget.onPressed;
    if (action == null) return;
    AppHaptics.selection();
    action();
  }

  void _scheduleNextTick() {
    _repeatTimer?.cancel();
    final interval = _currentInterval(_heldFor);
    _heldFor += interval;
    _repeatTimer = Timer(interval, () {
      if (!mounted || widget.onPressed == null) {
        _stopRepeating();
        return;
      }
      _invoke();
      _scheduleNextTick();
    });
  }

  static Duration _currentInterval(Duration heldFor) {
    if (heldFor >= _speedUp2After) return _repeatInterval ~/ 3;
    if (heldFor >= _speedUp1After) return _repeatInterval ~/ 2;
    return _repeatInterval;
  }

  void _startRepeating(LongPressStartDetails _) {
    if (widget.onPressed == null) return;
    _invoke();
    _heldFor = Duration.zero;
    _scheduleNextTick();
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _heldFor = Duration.zero;
  }

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: enabled ? c.text : (isDark ? c.muted : c.muted2),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
