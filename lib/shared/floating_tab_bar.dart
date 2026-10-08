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
/// 导航项只需要提供标题和图标即可。五格及以上的奇数格导航无需额外配置：
/// [FloatingTabBar] 会自动把正中间一项渲染为圆形仅图标按钮。
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
///
/// 四格以内使用常规胶囊：激活时横向展开并带出标题。出现第 5 个图标
/// （奇数格 ≥5）时自动切换为紧凑布局：正中间一项渲染为强调色圆形仅
/// 图标按钮（仅激活时高亮），其余项改为图标在上、标题在下，保证每格
/// 都能完整显示三至四字标题而不被截断。
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

  /// 五格及以上的奇数格导航中，正中间一项的序号；其余布局返回 -1。
  int get _centerIndex =>
      tabs.length >= 5 && tabs.length.isOdd ? tabs.length ~/ 2 : -1;

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
                      center: i == _centerIndex,
                      compact: tabs.length >= 5,
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
    required this.center,
    required this.compact,
    required this.onTap,
  });

  final FloatingTabSpec<T> spec;
  final bool active;

  /// 正中间的圆形仅图标主入口，由 [FloatingTabBar] 按格数自动判定。
  final bool center;

  /// 五格及以上布局：其余项改为竖排紧凑胶囊，标题恒定显示。
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final Widget tabContent;
    if (center) {
      tabContent = Center(child: _centerCircle(context, c));
    } else if (compact) {
      tabContent = Center(child: _compactPill(context, c));
    } else {
      tabContent = Center(child: _pill(context, c));
    }

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

  /// 常规导航项：激活时展开为胶囊并带出标题。
  Widget _pill(BuildContext context, AppColors c) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.tabActiveText,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  letterSpacing: -0.12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 紧凑导航项：图标在上、标题在下，标题不随激活状态收起，保证
  /// 「影片库」「收藏夹」等三至四字标题在五格布局中完整可见。
  /// 选中背景铺满整格（左右各留 3dp），避免窄条选中态的局促观感。
  Widget _compactPill(BuildContext context, AppColors c) {
    final contentColor = active ? c.tabActiveText : c.muted;
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: constraints.maxWidth - 6,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: active ? c.tabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, size: 20, color: contentColor),
              const SizedBox(height: 2),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                strutStyle: const StrutStyle(
                  fontSize: 10.5,
                  height: 1.15,
                  forceStrutHeight: true,
                ),
                style: TextStyle(
                  color: contentColor,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 中间主入口：仅激活时使用强调色圆底与光晕，未激活保持中性外观。
  Widget _centerCircle(BuildContext context, AppColors c) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? c.accent : c.chipBg,
        border: active ? null : Border.all(color: c.cardBorder),
        boxShadow: active
            ? [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(spec.icon, size: 23, color: active ? Colors.white : c.text),
      ),
    );
  }
}
