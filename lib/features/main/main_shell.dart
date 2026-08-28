import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass_menu.dart';
import '../../shared/status_bar_scroll_to_top.dart';
import 'package:omm/features/oh_my_media/actors/actor_management_page.dart';
import 'package:omm/features/oh_my_media/audio/audio_management_page.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_page.dart';
import '../home/home_page.dart';
import 'package:omm/features/db_online/pages/db_online_home_page.dart';
import 'package:omm/features/db_online/pages/db_online_search_page.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_page.dart';
import '../files/file_sources_page.dart';
import 'package:omm/features/db_online/pages/db_online_library_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/features/oh_my_media/resources/resource_list_page.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'package:omm/features/oh_my_media/search/search_page.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_page.dart';
import '../settings/server_selection_page.dart';
import '../settings/settings_page.dart';
import '../../shared/edge_swipe_back.dart';

/// omm 主框架 · 设计稿 4 Tab 悬浮胶囊
///
/// Home / Library / Search / You
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  ServerProject? _lastProject;

  // 各 Tab 独立的回顶控制器：无自定义控制器的 Tab 页（首页/搜索）通过
  // PrimaryScrollController 自动挂接，状态栏回顶由 StatusBarScrollToTop
  // 统一接管；持自有控制器的页面（影片库/我的）内部另有 StatusBarScrollToTop，
  // 这里对应的控制器无客户端，自动空操作。
  final List<ScrollController> _tabScrollControllers = List.generate(
    4,
    (_) => ScrollController(),
  );

  @override
  void dispose() {
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _index) return;
    AppHaptics.selection();
    setState(() => _index = index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final project = ref.read(serverConfigProvider)?.activeServer?.project;
    if (_lastProject != null && project != _lastProject && _index != 0) {
      _index = 0;
    }
    _lastProject = project;
  }

  List<GlassMenuEntry<_YouQuickAction>> _quickMenuEntries(
    BuildContext context,
  ) {
    final l = AppL10n.of(context);
    return [
      GlassMenuEntry<_YouQuickAction>.action(
        value: _YouQuickAction.tasks,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.task_alt_outlined,
          label: '任务中心',
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<_YouQuickAction>.action(
        value: _YouQuickAction.libraries,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.video_library_outlined,
          label: l.settingsLibraries,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<_YouQuickAction>.action(
        value: _YouQuickAction.audios,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.graphic_eq_outlined,
          label: '音频管理',
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<_YouQuickAction>.action(
        value: _YouQuickAction.tags,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.label_outline,
          label: l.settingsTags,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<_YouQuickAction>.action(
        value: _YouQuickAction.genres,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.category_outlined,
          label: l.settingsGenres,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<_YouQuickAction>.action(
        value: _YouQuickAction.series,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.collections_bookmark_outlined,
          label: l.settingsSeries,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<_YouQuickAction>.action(
        value: _YouQuickAction.actors,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.people_outline,
          label: l.settingsActors,
          selected: selected,
          onTap: onTap,
        ),
      ),
    ];
  }

  Future<void> _openYouQuickAction(_YouQuickAction action) async {
    if (!mounted) return;
    final page = switch (action) {
      _YouQuickAction.tasks => const TaskCenterPage(),
      _YouQuickAction.libraries => const LibrariesPage(),
      _YouQuickAction.audios => const AudioManagementPage(),
      _YouQuickAction.tags => const ResourceListPage(kind: ResourceKind.tag),
      _YouQuickAction.genres => const ResourceListPage(
        kind: ResourceKind.genre,
      ),
      _YouQuickAction.series => const ResourceListPage(
        kind: ResourceKind.series,
      ),
      _YouQuickAction.actors => const ActorManagementPage(),
    };
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  List<_TabSpec> _tabsFor(
    BuildContext context, {
    required bool dbOnline,
    required bool fileServer,
  }) {
    final l = AppL10n.of(context);
    if (fileServer) {
      return [
        const _TabSpec(label: '文件', icon: _TabIcon.library),
        _TabSpec(label: l.settingsTitle, icon: _TabIcon.you),
      ];
    }
    if (dbOnline) {
      return [
        _TabSpec(label: l.tabHome, icon: _TabIcon.home),
        _TabSpec(label: l.tabLibrary, icon: _TabIcon.library),
        _TabSpec(label: l.tabSearch, icon: _TabIcon.search),
        _TabSpec(label: l.settingsTitle, icon: _TabIcon.you),
      ];
    }
    return [
      _TabSpec(label: l.tabHome, icon: _TabIcon.home),
      _TabSpec(label: l.tabLibrary, icon: _TabIcon.library),
      _TabSpec(label: l.tabSearch, icon: _TabIcon.search),
      _TabSpec(label: l.tabYou, icon: _TabIcon.you),
    ];
  }

  Widget _bodyFor(int i, {required bool dbOnline, required bool fileServer}) {
    if (fileServer) {
      return i == 0 ? const FileSourcesPage() : const SettingsPage();
    }
    switch (i) {
      case 0:
        return dbOnline ? const DbOnlineHomePage() : const HomePage();
      case 1:
        return dbOnline ? const DbOnlineLibraryPage() : const MoviesPage();
      case 2:
        return dbOnline ? const DbOnlineSearchPage() : const SearchPage();
      case 3:
        return dbOnline ? const SettingsPage() : const FavoritesPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final project = ref.watch(serverConfigProvider)?.activeServer?.project;
    final dbOnline = project == ServerProject.dbOnline;
    final fileServer = project?.isFileSource == true;
    if (_lastProject != null && project != _lastProject && _index != 0) {
      _index = 0;
    }
    _lastProject = project;
    final tabs = _tabsFor(context, dbOnline: dbOnline, fileServer: fileServer);
    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: EdgeSwipeBack(
        enabled: _index == 0,
        onTriggered: () =>
            unawaited(ServerSelectionPage.openForReturn(context)),
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < tabs.length; i++)
              ActiveTabScope(
                active: i == _index,
                child: StatusBarScrollToTop(
                  scrollController: _tabScrollControllers[i],
                  child: _bodyFor(
                    i,
                    dbOnline: dbOnline,
                    fileServer: fileServer,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _FloatingTabBar(
        tabs: tabs,
        active: _index,
        onTap: _selectTab,
        quickMenuEnabled: !dbOnline && !fileServer,
        quickMenuEntries: _quickMenuEntries(context),
        onQuickMenuSelected: (action) => unawaited(_openYouQuickAction(action)),
      ),
    );
  }
}

enum _YouQuickAction { tasks, libraries, audios, tags, genres, series, actors }

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
    required this.quickMenuEnabled,
    required this.quickMenuEntries,
    required this.onQuickMenuSelected,
  });

  final List<_TabSpec> tabs;
  final int active;
  final ValueChanged<int> onTap;
  final bool quickMenuEnabled;
  final List<GlassMenuEntry<_YouQuickAction>> quickMenuEntries;
  final ValueChanged<_YouQuickAction> onQuickMenuSelected;

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
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.5
                        : 0.18,
                  ),
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
                      quickMenuEntries: i == 3 && quickMenuEnabled
                          ? quickMenuEntries
                          : null,
                      onQuickMenuSelected: i == 3 && quickMenuEnabled
                          ? onQuickMenuSelected
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
    this.quickMenuEntries,
    this.onQuickMenuSelected,
  });
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;
  final List<GlassMenuEntry<_YouQuickAction>>? quickMenuEntries;
  final ValueChanged<_YouQuickAction>? onQuickMenuSelected;

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
    );
    if (quickMenuEntries == null || onQuickMenuSelected == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tabContent,
      );
    }
    return GlassMenuAnchor<_YouQuickAction>(
      width: 224,
      entries: quickMenuEntries!,
      onSelected: onQuickMenuSelected!,
      placement: GlassMenuPlacement.above,
      alignment: GlassMenuAlignment.center,
      offset: const Offset(0, 10),
      onAnchorTap: onTap,
      child: tabContent,
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
