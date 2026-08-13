import 'dart:async';
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

  void _selectTab(int index) {
    if (index == _index) return;
    AppHaptics.selection();
    setState(() => _index = index);
  }

  Future<void> _showYouQuickMenu() async {
    AppHaptics.medium();
    final anchorContext = _youTabKey.currentContext;
    final anchorRenderObject = anchorContext?.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayRenderObject = overlay.context.findRenderObject();
    if (anchorRenderObject is! RenderBox ||
        overlayRenderObject is! RenderBox) {
      return;
    }
    final anchorBox = anchorRenderObject;
    final overlayBox = overlayRenderObject;

    final anchorOffset = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorRect = anchorOffset & anchorBox.size;
    final overlayRect = Offset.zero & overlayBox.size;
    final l = AppL10n.of(context);
    final action = await showMenu<_YouQuickAction>(
      context: context,
      position: RelativeRect.fromRect(anchorRect, overlayRect),
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      items: [
        _YouQuickMenuEntry(
          items: [
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
          ],
        ),
      ],
    );
    if (!mounted || action == null) return;

    AppHaptics.selection();
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
        onLongPress: (index) {
          if (index == 3) unawaited(_showYouQuickMenu());
        },
      ),
    );
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
    this.onLongPress,
  });

  final List<_TabSpec> tabs;
  final int active;
  final ValueChanged<int> onTap;
  final GlobalKey youTabKey;
  final ValueChanged<int>? onLongPress;

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
                      onLongPress: i == 3 && onLongPress != null
                          ? () => onLongPress!(i)
                          : null,
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
    required this.spec,
    required this.active,
    required this.onTap,
    this.onLongPress,
  });
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
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

class _YouQuickMenuEntry extends PopupMenuEntry<_YouQuickAction> {
  const _YouQuickMenuEntry({required this.items});

  static const menuWidth = 224.0;
  static const verticalPadding = 6.0;
  static const headerHeight = 42.0;
  static const rowHeight = 46.0;

  final List<_YouQuickMenuAction> items;

  @override
  double get height =>
      verticalPadding * 2 + headerHeight + 1 + items.length * rowHeight;

  @override
  bool represents(_YouQuickAction? value) => false;

  @override
  State<_YouQuickMenuEntry> createState() => _YouQuickMenuEntryState();
}

class _YouQuickMenuEntryState extends State<_YouQuickMenuEntry> {
  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: _YouQuickMenuEntry.menuWidth,
      height: widget.height,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: _YouQuickMenuEntry.verticalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: _YouQuickMenuEntry.headerHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: c.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '快捷管理',
                            style: AppText.cardTitle(context).copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 1,
                    child: ColoredBox(color: c.divider),
                  ),
                  for (final item in widget.items)
                    SizedBox(
                      height: _YouQuickMenuEntry.rowHeight,
                      child: _YouQuickMenuItem(item: item),
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
  const _YouQuickMenuItem({required this.item});

  final _YouQuickMenuAction item;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).pop(item.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(item.icon, color: c.text, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: c.muted, size: 20),
            ],
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
