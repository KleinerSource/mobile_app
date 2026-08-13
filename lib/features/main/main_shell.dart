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

  void _selectTab(int index) {
    if (index == _index) return;
    AppHaptics.selection();
    setState(() => _index = index);
  }

  Future<void> _showYouQuickMenu() async {
    AppHaptics.medium();
    final action = await showModalBottomSheet<_YouQuickAction>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (sheetContext) {
        final c = appColors(sheetContext);
        final l = AppL10n.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: c.bg,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: c.accent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '快捷管理',
                          style: AppText.cardTitle(sheetContext).copyWith(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: c.divider),
                  _YouQuickMenuItem(
                    icon: Icons.video_library_outlined,
                    label: l.settingsLibraries,
                    onTap: () => Navigator.of(sheetContext)
                        .pop(_YouQuickAction.libraries),
                  ),
                  _YouQuickMenuItem(
                    icon: Icons.label_outline,
                    label: l.settingsTags,
                    onTap: () => Navigator.of(sheetContext)
                        .pop(_YouQuickAction.tags),
                  ),
                  _YouQuickMenuItem(
                    icon: Icons.category_outlined,
                    label: l.settingsGenres,
                    onTap: () => Navigator.of(sheetContext)
                        .pop(_YouQuickAction.genres),
                  ),
                  _YouQuickMenuItem(
                    icon: Icons.people_outline,
                    label: l.settingsActors,
                    onTap: () => Navigator.of(sheetContext)
                        .pop(_YouQuickAction.actors),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
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
    this.onLongPress,
  });

  final List<_TabSpec> tabs;
  final int active;
  final ValueChanged<int> onTap;
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

class _YouQuickMenuItem extends StatelessWidget {
  const _YouQuickMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return ListTile(
      leading: Icon(icon, color: c.text),
      title: Text(
        label,
        style: TextStyle(
          color: c.text,
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
      onTap: onTap,
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
