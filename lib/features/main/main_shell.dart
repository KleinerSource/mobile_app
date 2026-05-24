import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorites_page.dart';
import '../home/home_page.dart';
import '../movies/movies_page.dart';
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
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({required this.label, required this.icon});
  final String label;
  final _TabIcon icon;
}

enum _TabIcon { home, library, search, you }

/// 悬浮胶囊 TabBar · 设计稿样式 · 16px margin + blur + active inset pill
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
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
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: c.tabBg,
              border: Border.all(color: c.tabBorder, width: 1),
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
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabItem(
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
