import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import 'glass_menu.dart';

/// 悬浮底部导航的视觉高度，不包含外围上下留白。
const floatingTabBarHeight = 60.0;

/// 为滚动内容预留的底部空间，确保最后一项不会被悬浮导航覆盖。
double floatingTabBarContentBottomInset(BuildContext context) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;
  return floatingTabBarHeight + 4 + 16 + safeBottom * 0.4 + 12;
}

/// 悬浮胶囊导航项。
///
/// [quickMenuEntries] 仅供需要在某个 Tab 上挂载快捷菜单的场景使用；普通
/// 导航项只需要提供标题和图标即可。
class FloatingTabSpec<T> {
  const FloatingTabSpec({
    required this.label,
    required this.icon,
    this.quickMenuEntries,
    this.onQuickMenuSelected,
  });

  final String label;
  final IconData icon;
  final List<GlassMenuEntry<T>>? quickMenuEntries;
  final ValueChanged<T>? onQuickMenuSelected;
}

/// 统一的悬浮毛玻璃底部导航。
///
/// 媒体管理器和文件管理器共用同一套材质、激活态和布局，业务层只负责
/// 提供 Tab 数据以及点击回调。
class FloatingTabBar<T> extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  final List<FloatingTabSpec<T>> tabs;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassTint = c.tabBg.withValues(alpha: isDark ? 0.56 : 0.68);
    final glassBorder = Colors.white.withValues(alpha: isDark ? 0.18 : 0.52);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.paddingOf(context).bottom * 0.4,
        top: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: floatingTabBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: glassTint,
              border: Border.all(color: glassBorder, width: 1),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _FloatingTabItem<T>(
                      spec: tabs[i],
                      active: i == active,
                      onTap: () => onTap(i),
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

class _FloatingTabItem<T> extends StatelessWidget {
  const _FloatingTabItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  final FloatingTabSpec<T> spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final tabContent = Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.tabActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              spec.icon,
              size: 20,
              color: active ? c.tabActiveText : c.muted,
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                spec.label,
                style: TextStyle(
                  color: c.tabActiveText,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  letterSpacing: -0.12,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final entries = spec.quickMenuEntries;
    final onQuickMenuSelected = spec.onQuickMenuSelected;
    if (entries == null || onQuickMenuSelected == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tabContent,
      );
    }
    return GlassMenuAnchor<T>(
      width: 224,
      entries: entries,
      onSelected: onQuickMenuSelected,
      placement: GlassMenuPlacement.above,
      alignment: GlassMenuAlignment.center,
      offset: const Offset(0, 10),
      onAnchorTap: onTap,
      child: tabContent,
    );
  }
}
