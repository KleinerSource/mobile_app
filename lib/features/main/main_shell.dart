import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../actors/actor_management_page.dart';
import '../favorites/favorites_page.dart';
import '../home/home_page.dart';
import '../libraries/libraries_page.dart';
import '../movies/movies_page.dart';
import '../resources/resource_list_page.dart';
import '../resources/resources_repository.dart';
import '../search/search_page.dart';

/// md_center 主框架 · 设计稿 4 Tab 悬浮胶囊
///
/// Home / Library / Search / You
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _youTabKey = GlobalKey();
  OverlayEntry? _quickMenuEntry;
  ValueNotifier<_YouQuickAction?>? _quickMenuSelection;
  Rect? _quickMenuRect;
  List<_YouQuickMenuAction>? _quickMenuItems;
  bool _quickMenuInteractive = false;

  void _selectTab(int index) {
    if (index == _index) return;
    AppHaptics.selection();
    setState(() => _index = index);
  }

  List<_YouQuickMenuAction> _quickMenuActions(BuildContext context) {
    final l = AppL10n.of(context);
    return [
      _YouQuickMenuAction(
        icon: Icons.video_library_outlined,
        label: l.settingsLibraries,
        value: _YouQuickAction.libraries,
      ),
      _YouQuickMenuAction(
        icon: Icons.label_outline,
        label: l.settingsTags,
        value: _YouQuickAction.tags,
      ),
      _YouQuickMenuAction(
        icon: Icons.category_outlined,
        label: l.settingsGenres,
        value: _YouQuickAction.genres,
      ),
      _YouQuickMenuAction(
        icon: Icons.people_outline,
        label: l.settingsActors,
        value: _YouQuickAction.actors,
      ),
    ];
  }

  Rect? _quickMenuGeometry() {
    final anchorContext = _youTabKey.currentContext;
    final anchorRenderObject = anchorContext?.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayRenderObject = overlay.context.findRenderObject();
    if (anchorRenderObject is! RenderBox ||
        overlayRenderObject is! RenderBox) {
      return null;
    }

    final anchorBox = anchorRenderObject;
    final overlayBox = overlayRenderObject;
    final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);
    final anchorRect = anchorTopLeft & anchorBox.size;
    final overlayTopLeft = overlayBox.localToGlobal(Offset.zero);
    final overlaySize = overlayBox.size;
    final horizontalInset = 12.0;
    final rawLeft = anchorRect.center.dx - _YouQuickMenuPanel.width / 2;
    final minLeft = overlayTopLeft.dx + horizontalInset;
    final maxLeft = math.max(
      minLeft,
      overlayTopLeft.dx + overlaySize.width -
          _YouQuickMenuPanel.width -
          horizontalInset,
    );
    final left = rawLeft.clamp(minLeft, maxLeft).toDouble();

    // 菜单从“我的”按钮上方出现，底部预留间距，避免遮挡底部导航按钮。
    final rawTop = anchorRect.top - 10 - _YouQuickMenuPanel.height;
    final minTop =
        overlayTopLeft.dy + MediaQuery.of(context).padding.top + 12;
    final maxTop = math.max(
      minTop,
      overlayTopLeft.dy + overlaySize.height -
          _YouQuickMenuPanel.height -
          12,
    );
    final top = rawTop.clamp(minTop, maxTop).toDouble();
    return Rect.fromLTWH(
      left,
      top,
      _YouQuickMenuPanel.width,
      _YouQuickMenuPanel.height,
    );
  }

  _YouQuickAction? _quickActionAt(Offset position) {
    final rect = _quickMenuRect;
    final items = _quickMenuItems;
    if (rect == null || items == null || !rect.contains(position)) return null;
    final y = position.dy - rect.top - _YouQuickMenuPanel.verticalPadding;
    if (y < 0 || y >= items.length * _YouQuickMenuPanel.rowHeight) {
      return null;
    }
    final index = y ~/ _YouQuickMenuPanel.rowHeight;
    if (index < 0 || index >= items.length) return null;
    return items[index].value;
  }

  void _startYouQuickMenu(LongPressStartDetails details) {
    _removeYouQuickMenu();
    final rect = _quickMenuGeometry();
    if (rect == null) return;

    AppHaptics.medium();
    final items = _quickMenuActions(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayRenderObject = overlay.context.findRenderObject();
    if (overlayRenderObject is! RenderBox) {
      return;
    }
    final overlayBox = overlayRenderObject;
    final localTopLeft = overlayBox.globalToLocal(rect.topLeft);
    final selection = ValueNotifier<_YouQuickAction?>(null);
    _quickMenuInteractive = false;
    _quickMenuRect = rect;
    _quickMenuItems = items;
    _quickMenuSelection = selection;
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Stack(
          children: [
            if (_quickMenuInteractive)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _removeYouQuickMenu,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              left: localTopLeft.dx,
              top: localTopLeft.dy,
              width: _YouQuickMenuPanel.width,
              height: _YouQuickMenuPanel.height,
              child: ValueListenableBuilder<_YouQuickAction?>(
                valueListenable: selection,
                builder: (context, selected, _) {
                  final panel = _YouQuickMenuPanel(
                    items: items,
                    selected: selected,
                    onSelect: _selectYouQuickAction,
                  );
                  return _quickMenuInteractive
                      ? panel
                      : IgnorePointer(child: panel);
                },
              ),
            ),
        ),
      ),
    );
    _quickMenuEntry = entry;
    overlay.insert(entry);
    _updateYouQuickMenu(details.globalPosition);
  }

  void _updateYouQuickMenu(Offset position) {
    final selection = _quickMenuSelection;
    if (selection == null) return;
    final next = _quickActionAt(position);
    if (next == selection.value) return;
    selection.value = next;
    if (next != null) AppHaptics.selection();
  }

  void _finishYouQuickMenu(LongPressEndDetails details) {
    if (_quickMenuEntry == null) return;
    _updateYouQuickMenu(details.globalPosition);
    _quickMenuInteractive = true;
    _quickMenuEntry?.markNeedsBuild();
  }

  void _selectYouQuickAction(_YouQuickAction action) {
    if (!_quickMenuInteractive) return;
    _removeYouQuickMenu();
    if (!mounted) return;
    AppHaptics.selection();
    unawaited(_openYouQuickAction(action));
  }

  void _removeYouQuickMenu() {
    _quickMenuEntry?.remove();
    _quickMenuEntry = null;
    _quickMenuRect = null;
    _quickMenuItems = null;
    _quickMenuInteractive = false;
    _quickMenuSelection?.dispose();
    _quickMenuSelection = null;
  }

  Future<void> _openYouQuickAction(_YouQuickAction action) async {
    if (!mounted) return;
    final page = switch (action) {
      _YouQuickAction.libraries => const LibrariesPage(),
      _YouQuickAction.tags => const ResourceListPage(kind: ResourceKind.tag),
      _YouQuickAction.genres =>
        const ResourceListPage(kind: ResourceKind.genre),
      _YouQuickAction.actors => const ActorManagementPage(),
    };
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  List<_TabSpec> _tabsFor(BuildContext context) {
    final l = AppL10n.of(context);
    return [
      _TabSpec(label: l.tabHome, icon: _TabIcon.home),
      _TabSpec(label: l.tabLibrary, icon: _TabIcon.library),
      _TabSpec(label: l.tabSearch, icon: _TabIcon.search),
      _TabSpec(label: l.tabYou, icon: _TabIcon.you),
    ];
  }

  Widget _bodyFor(int i) {
    switch (i) {
      case 0:
        return const HomePage();
      case 1:
        return const MoviesPage();
      case 2:
        return const SearchPage();
      case 3:
        return const FavoritesPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final tabs = _tabsFor(context);
    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: IndexedStack(
        index: _index,
        children: List.generate(tabs.length, _bodyFor),
      ),
      bottomNavigationBar: _FloatingTabBar(
        tabs: tabs,
        active: _index,
        onTap: _selectTab,
        youTabKey: _youTabKey,
        onLongPressStart: _startYouQuickMenu,
        onLongPressMoveUpdate: (details) =>
            _updateYouQuickMenu(details.globalPosition),
        onLongPressEnd: _finishYouQuickMenu,
      ),
    );
  }

  @override
  void dispose() {
    _removeYouQuickMenu();
    super.dispose();
  }
}

enum _YouQuickAction { libraries, tags, genres, actors }

class _TabSpec {
  const _TabSpec({required this.label, required this.icon});
  final String label;
  final _TabIcon icon;
}

enum _TabIcon { home, library, search, you }

/// 悬浮胶囊 TabBar · 毛玻璃材质 · 16px margin + blur + active inset pill
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
    required this.youTabKey,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  final List<_TabSpec> tabs;
  final int active;
  final ValueChanged<int> onTap;
  final GlobalKey youTabKey;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;

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
        bottom: 16 + MediaQuery.of(context).padding.bottom * 0.4,
        top: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: glassTint,
              border: Border.all(color: glassBorder, width: 1),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:
                      Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.18),
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
                    child: _TabItem(
                      key: i == 3 ? youTabKey : null,
                      spec: tabs[i],
                      active: i == active,
                      onTap: () => onTap(i),
                      onLongPressStart:
                          i == 3 ? onLongPressStart : null,
                      onLongPressMoveUpdate:
                          i == 3 ? onLongPressMoveUpdate : null,
                      onLongPressEnd: i == 3 ? onLongPressEnd : null,
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.spec,
    required this.active,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd: onLongPressEnd,
      child: Center(
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
              _TabIconWidget(
                icon: spec.icon,
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
      ),
    );
  }
}

class _YouQuickMenuAction {
  const _YouQuickMenuAction({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final _YouQuickAction value;
}

class _YouQuickMenuPanel extends StatelessWidget {
  const _YouQuickMenuPanel({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  static const width = 224.0;
  static const verticalPadding = 6.0;
  static const rowHeight = 48.0;
  static const height = verticalPadding * 2 + rowHeight * 4;

  final List<_YouQuickMenuAction> items;
  final _YouQuickAction? selected;
  final ValueChanged<_YouQuickAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.bg.withValues(alpha: isDark ? 0.70 : 0.76),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.56),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: verticalPadding),
              child: Column(
                children: [
                  for (final item in items)
                    SizedBox(
                      height: rowHeight,
                      child: _YouQuickMenuItem(
                        item: item,
                        selected: item.value == selected,
                        onTap: () => onSelect(item.value),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YouQuickMenuItem extends StatelessWidget {
  const _YouQuickMenuItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _YouQuickMenuAction item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? c.tabActiveBg.withValues(alpha: 0.86)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? c.tabActiveText : c.text,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? c.tabActiveText : c.text,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
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

class _TabIconWidget extends StatelessWidget {
  const _TabIconWidget({required this.icon, required this.color});
  final _TabIcon icon;
  final Color color;

  IconData get _data {
    switch (icon) {
      case _TabIcon.home:
        return Icons.home_rounded;
      case _TabIcon.library:
        return Icons.video_library_rounded;
      case _TabIcon.search:
        return Icons.search_rounded;
      case _TabIcon.you:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(_data, size: 20, color: color);
  }
}
