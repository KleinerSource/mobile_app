import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import 'glass_menu.dart';

/// Header 圆形按钮的两种外观。
enum HeaderActionStyle {
  /// 页头常规操作：36 实色圆底 + 描边。
  solid(HeaderActionIcon.size),

  /// 叠在封面等画面上的操作：30 半透明圆底，不描边。
  overlay(30);

  const HeaderActionStyle(this.diameter);

  final double diameter;

  BoxDecoration decoration(BuildContext context) {
    final colors = appColors(context);
    return switch (this) {
      solid => BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(color: colors.cardBorder),
      ),
      overlay => BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface.withValues(alpha: 0.6),
      ),
    };
  }
}

/// Header 圆形按钮的点击区域与波纹。
///
/// [child] 是直径为 [diameter] 的可见圆，圆底须用 [Ink] 绘制（参见
/// [HeaderActionIcon]），波纹才会画在圆底之上；波纹与高亮裁剪在可见圆内，
/// 不会出现方形或超出圆形的高亮，点击区域保持 [tapTargetSize]。
class HeaderCircleInk extends StatelessWidget {
  const HeaderCircleInk({
    super.key,
    required this.onTap,
    required this.child,
    this.diameter = HeaderActionIcon.size,
    this.tapTargetSize = HeaderActionButton.tapTargetSize,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double diameter;
  final double tapTargetSize;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: tapTargetSize,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: _InsetCircleBorder((tapTargetSize - diameter) / 2),
        child: Center(child: child),
      ),
    ),
  );
}

/// Header 的圆形操作：点击区域 44，长按显示 [tooltip]。
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
    this.color,
    this.style = HeaderActionStyle.solid,
  });

  static const double tapTargetSize = 44;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final HeaderActionStyle style;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      child: HeaderCircleInk(
        onTap: loading ? null : onPressed,
        diameter: style.diameter,
        child: HeaderActionIcon(
          icon: icon,
          loading: loading,
          color: color,
          enabled: onPressed != null,
          style: style,
        ),
      ),
    ),
  );
}

/// Header 的圆形菜单入口：点击打开菜单，长按沿用 [GlassMenuAnchor] 的
/// 滑动选择，[tooltip] 用于悬停提示与无障碍标签。
class HeaderMenuButton<T> extends StatelessWidget {
  const HeaderMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    required this.menuWidth,
    this.enabled = true,
    this.initialSelection,
    this.offset = const Offset(0, 8),
    this.style = HeaderActionStyle.solid,
  });

  final IconData icon;
  final String tooltip;
  final List<GlassMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final double menuWidth;
  final bool enabled;
  final T? initialSelection;
  final Offset offset;
  final HeaderActionStyle style;

  @override
  Widget build(BuildContext context) => GlassMenuAnchor<T>(
    width: menuWidth,
    entries: entries,
    onSelected: onSelected,
    enabled: enabled,
    initialSelection: initialSelection,
    tooltip: tooltip,
    offset: offset,
    builder: (context, open) => Semantics(
      button: true,
      label: tooltip,
      enabled: open != null,
      child: HeaderCircleInk(
        onTap: open,
        diameter: style.diameter,
        child: HeaderActionIcon(
          icon: icon,
          enabled: open != null,
          style: style,
        ),
      ),
    ),
  );
}

/// 圆形按钮的可见圆：[Ink] 绘制圆底，居中 18px 图标或加载指示。
class HeaderActionIcon extends StatelessWidget {
  const HeaderActionIcon({
    super.key,
    required this.icon,
    this.loading = false,
    this.color,
    this.enabled = true,
    this.style = HeaderActionStyle.solid,
  });

  static const double size = 36;

  final IconData icon;
  final bool loading;
  final Color? color;
  final bool enabled;
  final HeaderActionStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Ink(
      width: style.diameter,
      height: style.diameter,
      decoration: style.decoration(context),
      child: Center(
        child: loading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                ),
              )
            : Icon(
                icon,
                size: 18,
                color: enabled ? color ?? colors.text : colors.muted,
              ),
      ),
    );
  }
}

/// 在方形点击区域内居中的圆形裁剪，供波纹与高亮使用。
class _InsetCircleBorder extends ShapeBorder {
  const _InsetCircleBorder(this.inset);

  final double inset;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final circle = Rect.fromCircle(
      center: rect.center,
      radius: (rect.shortestSide / 2 - inset).clamp(0, double.infinity),
    );
    return Path()..addOval(circle);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _InsetCircleBorder(inset * t);

  @override
  bool operator ==(Object other) =>
      other is _InsetCircleBorder && other.inset == inset;

  @override
  int get hashCode => inset.hashCode;
}
