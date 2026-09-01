import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import 'sheet_controls.dart';

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
    this.showBorder = true,
    this.showHighlight = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final Color? tint;
  final bool showBorder;
  final bool showHighlight;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 统一使用半透明 surface，让背景经过模糊后仍保留层次。
    final solidBg = tint ?? c.sheetBackground;
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
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        // blur 让边缘外的光晕透入面板边沿, 仍有玻璃感
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: solidBg,
            borderRadius: borderRadius,
            border: showBorder
                ? Border.all(color: c.sheetBorder, width: 1)
                : null,
          ),
          child: showHighlight
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: highlight,
                    borderRadius: borderRadius,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                )
              : Material(type: MaterialType.transparency, child: child),
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
    barrierColor: appColors(context).sheetBarrier,
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

/// 显示统一的毛玻璃 BottomSheet。
///
/// 所有业务 sheet 都应通过这里进入，统一处理材质、圆角、遮罩、SafeArea
/// 和拖拽把手；业务 builder 只负责内容和高度。
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    // 面板拖拽由公共 SheetDragCoordinator 处理，避免与内部滚动控件
    // 争夺手势竞技场；enableDrag 仍保留为公共入口的开关。
    enableDrag: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: appColors(context).sheetBarrier,
    elevation: 0,
    builder: (ctx) {
      final sheet = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GlassSheetHandle(),
          Flexible(child: builder(ctx)),
        ],
      );
      final safeSheet = useSafeArea
          ? SafeArea(top: true, bottom: true, child: sheet)
          : sheet;
      final keyboardInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return AnimatedPadding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: SheetDragCoordinator(
          enabled: enableDrag,
          child: GlassPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: sheetMaxHeight(ctx)),
              child: safeSheet,
            ),
          ),
        ),
      );
    },
  );
}

/// 统一的 BottomSheet 拖拽把手，避免各业务面板自行定义尺寸和颜色。
class GlassSheetHandle extends StatelessWidget {
  const GlassSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appColors(context).sheetHandle,
          borderRadius: BorderRadius.circular(100),
        ),
        child: const SizedBox(width: 36, height: 4),
      ),
    );
  }
}
