import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 毛玻璃容器 · 用于 dialog / sheet / popup 等浮层。
///
/// 实现:
/// - ClipRRect 切角
/// - BackdropFilter blur 28
/// - 半透明 surface 染色 (60-70%) 让 blur 内容仍透出
/// - 1px cardBorder 描边
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.sigma = 28,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 底色: 完全不透明保底 (解决 scaffold 透明导致的穿透问题)
    final solidBg =
        tint ?? (isDark ? const Color(0xFF1B1A24) : const Color(0xFFFAFAFA));
    // 玻璃高光: 左上更亮的细微渐变叠在底色上 (模拟玻璃表面反光)
    final highlight = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
          );
    final borderColor = isDark
        ? const Color(0x33FFFFFF)
        : const Color(0x1F000000);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        // blur 让边缘外的光晕透入面板边沿, 仍有玻璃感
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: solidBg,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: highlight,
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 显示毛玻璃 AlertDialog
/// content / actions API 兼容 AlertDialog
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  required List<Widget> actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim1, anim2) {
      final c = appColors(ctx);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DefaultTextStyle(
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                      child: title,
                    ),
                    const SizedBox(height: 12),
                    DefaultTextStyle(
                      style: TextStyle(
                        color: c.text2,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      child: content,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (final a in actions) ...[
                          a,
                          if (a != actions.last) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.96,
            end: 1,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

/// 显示毛玻璃 BottomSheet
/// builder 返回的 child 会被包进 GlassPanel + SafeArea
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    elevation: 0,
    builder: (ctx) {
      final c = appColors(ctx);
      return GlassPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragHandle)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.muted2.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            Flexible(child: builder(ctx)),
          ],
        ),
      );
    },
  );
}
