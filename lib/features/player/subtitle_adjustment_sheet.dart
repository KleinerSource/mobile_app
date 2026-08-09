import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import 'subtitle_rendering.dart';
import 'subtitle_settings.dart';

/// 播放器内字幕调节浮层。
///
/// 所有滑块都在拖动过程中回调，父级可以立即更新视频上的字幕层；预览
/// 使用同一套文字样式，避免调节面板和实际字幕的视觉结果不一致。
class SubtitleAdjustmentSheet extends StatefulWidget {
  const SubtitleAdjustmentSheet({
    super.key,
    required this.style,
    required this.initial,
    required this.onChanged,
  });

  final SubtitleSettings style;
  final SubtitleAdjustments initial;
  final ValueChanged<SubtitleAdjustments> onChanged;

  @override
  State<SubtitleAdjustmentSheet> createState() =>
      _SubtitleAdjustmentSheetState();
}

class _SubtitleAdjustmentSheetState extends State<SubtitleAdjustmentSheet> {
  late SubtitleAdjustments _adjustments = widget.initial;

  void _update(SubtitleAdjustments next) {
    setState(() => _adjustments = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('字幕设置', style: AppText.sectionTitle(context)),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: c.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Preview(style: widget.style, adjustments: _adjustments),
        const SizedBox(height: 18),
        _AdjustmentSlider(
          title: '延迟偏移',
          valueLabel: _formatDelay(_adjustments.delayMs),
          icon: Icons.sync_alt,
          value: _adjustments.delayMs.toDouble(),
          min: -5000,
          max: 5000,
          divisions: 40,
          onChanged: (value) => _update(
            _adjustments.copyWith(delayMs: value.round()),
          ),
          onChangeEnd: (_) => AppHaptics.selection(),
        ),
        _AdjustmentSlider(
          title: '垂直偏移',
          valueLabel: _formatOffset(_adjustments.verticalOffset),
          icon: Icons.height,
          value: _adjustments.verticalOffset,
          min: -150,
          max: 150,
          divisions: 30,
          onChanged: (value) => _update(
            _adjustments.copyWith(verticalOffset: value),
          ),
          onChangeEnd: (_) => AppHaptics.selection(),
        ),
        _AdjustmentSlider(
          title: '大小缩放',
          valueLabel: '${(_adjustments.sizeScale * 100).round()}%',
          icon: Icons.format_size,
          value: _adjustments.sizeScale,
          min: 0.5,
          max: 2,
          divisions: 30,
          onChanged: (value) => _update(
            _adjustments.copyWith(sizeScale: value),
          ),
          onChangeEnd: (_) => AppHaptics.selection(),
        ),
        _AdjustmentSlider(
          title: '不透明度',
          valueLabel: '${(_adjustments.opacity * 100).round()}%',
          icon: Icons.opacity,
          value: _adjustments.opacity,
          min: 0.1,
          max: 1,
          divisions: 18,
          onChanged: (value) => _update(
            _adjustments.copyWith(opacity: value),
          ),
          onChangeEnd: (_) => AppHaptics.selection(),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            AppHaptics.medium();
            _update(const SubtitleAdjustments());
          },
          child: const Text('恢复本次播放默认'),
        ),
      ],
    );
  }

  String _formatDelay(int milliseconds) {
    if (milliseconds == 0) return '0 ms';
    final seconds = milliseconds / 1000;
    return '${seconds > 0 ? '+' : ''}${seconds.toStringAsFixed(1)} s';
  }

  String _formatOffset(double value) {
    if (value == 0) return '默认';
    return '${value > 0 ? '+' : ''}${value.round()} px';
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.style, required this.adjustments});

  final SubtitleSettings style;
  final SubtitleAdjustments adjustments;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Colors.black,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, -adjustments.verticalOffset),
              child: Opacity(
                opacity: adjustments.opacity.clamp(0.1, 1.0).toDouble(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Text(
                    '字幕预览\nSubtitle preview',
                    textAlign: TextAlign.center,
                    style: subtitleTextStyle(
                      style,
                      adjustments,
                      baseFontSize: 18,
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

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.title,
    required this.valueLabel,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String title;
  final String valueLabel;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: c.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(valueLabel, style: AppText.meta(context)),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}
