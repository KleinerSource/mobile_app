import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

/// 通用任务/扫描状态胶囊: 状态码 → (标签, 主题色) 的统一映射。
///
/// 覆盖任务中心、扫描进度、音频转译共用的状态词汇;
/// 未识别的状态码原样展示并退化为 [AppColors.muted]。
(String, Color) statusPillStyle(AppL10n l, AppColors colors, String status) {
  return switch (status) {
    'idle' => (l.statusIdle, colors.muted),
    'pending' || 'queued' => (l.statusPending, colors.warning),
    'running' => (l.statusRunning, colors.accent),
    'paused' => (l.statusPaused, colors.warning),
    'completed' => (l.statusCompleted, AppHues.top(AppHues.mint)),
    'skipped' => (l.statusSkipped, colors.muted),
    'cancelled' || 'canceled' => (l.statusCanceled, colors.muted),
    'failed' || 'error' => (l.statusFailed, colors.danger),
    _ => (status.isEmpty ? l.statusUnknown : status, colors.muted),
  };
}

/// 圆角状态胶囊。传入现成的 label/color(如音频页的动态转译阶段),或只传
/// status 由 [statusPillStyle] 统一映射。
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    this.status,
    this.label,
    this.color,
    this.showDot = false,
    this.pulsing = false,
    this.horizontalPadding = 8,
    this.fontSize = 10.5,
  }) : assert(
         (status == null) != (label == null && color == null),
         'status 与 label/color 二选一',
       );

  /// 状态码,经 [statusPillStyle] 映射为标签与颜色
  final String? status;

  /// 直接指定标签(与 [color] 成对使用)
  final String? label;

  /// 直接指定颜色(与 [label] 成对使用)
  final Color? color;

  /// 是否在文字前显示状态圆点
  final bool showDot;

  /// 圆点是否以呼吸动画呈现(进行中的提取/转译)
  final bool pulsing;

  final double horizontalPadding;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final (resolvedLabel, resolvedColor) = status != null
        ? statusPillStyle(AppL10n.of(context), colors, status!)
        : (label!, color!);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _StatusDot(color: resolvedColor, pulsing: pulsing),
            const SizedBox(width: 5),
          ],
          Text(
            resolvedLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: resolvedColor,
              fontFamily: 'Inter',
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    if (!pulsing) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
    }
    return _PulsingDot(color: color, size: 6);
  }
}

/// 提取/转译进行中的呼吸圆点。
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}
