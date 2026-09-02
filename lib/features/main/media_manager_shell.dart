import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/floating_tab_bar.dart';
import '../../shared/glass_menu.dart';
import '../../shared/status_bar_scroll_to_top.dart';
import 'package:omm/features/oh_my_media/actors/actor_management_page.dart';
import 'package:omm/features/oh_my_media/audio/audio_management_page.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_page.dart';
import '../home/home_page.dart';
import '../home/server_switch_transition.dart';
import '../home/server_switcher.dart';
import 'package:omm/features/db_online/pages/db_online_home_page.dart';
import 'package:omm/features/db_online/pages/db_online_search_page.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/pages/media_browser_favorites_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_home_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_library_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_search_page.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_page.dart';
import 'package:omm/features/db_online/pages/db_online_library_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/features/oh_my_media/resources/resource_list_page.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'package:omm/features/oh_my_media/search/search_page.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_page.dart';
import '../settings/settings_page.dart';

/// 媒体管理器 Shell · 设计稿 4 Tab 悬浮胶囊。
///
/// OMM、DBO 以及未来接入的 Emby/Jellyfin 等媒体管理器共用这一层。
/// Home / Library / Search / You
class MediaManagerShell extends ConsumerStatefulWidget {
  const MediaManagerShell({super.key});

  @override
  ConsumerState<MediaManagerShell> createState() => _MediaManagerShellState();
}

class _MediaManagerShellState extends ConsumerState<MediaManagerShell> {
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

  void _switchServer(String serverId) {
    if (ref.read(serverSwitchTransitionProvider).isActive) return;
    unawaited(
      ref.read(serverSwitchTransitionProvider.notifier).switchTo(serverId),
    );
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

  List<GlassMenuEntry<Object?>> _quickMenuEntries(BuildContext context) {
    final l = AppL10n.of(context);
    return [
      GlassMenuEntry<Object?>.action(
        value: _YouQuickAction.tasks,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.task_alt_outlined,
          label: '任务中心',
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<Object?>.action(
        value: _YouQuickAction.libraries,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.video_library_outlined,
          label: l.settingsLibraries,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<Object?>.action(
        value: _YouQuickAction.audios,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.graphic_eq_outlined,
          label: '音频管理',
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<Object?>.action(
        value: _YouQuickAction.tags,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.label_outline,
          label: l.settingsTags,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<Object?>.action(
        value: _YouQuickAction.genres,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.category_outlined,
          label: l.settingsGenres,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<Object?>.action(
        value: _YouQuickAction.series,
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.collections_bookmark_outlined,
          label: l.settingsSeries,
          selected: selected,
          onTap: onTap,
        ),
      ),
      GlassMenuEntry<Object?>.action(
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

  List<FloatingTabSpec<Object?>> _tabsFor(
    BuildContext context, {
    required bool dbOnline,
    required bool mediaBrowser,
    required List<ServerProfile> servers,
    required String? activeServerId,
    required String? selectingServerId,
  }) {
    final l = AppL10n.of(context);
    final homeTab = FloatingTabSpec<Object?>(
      label: l.tabHome,
      icon: Icons.home_rounded,
      quickMenuEntries: buildServerQuickSwitchEntries<Object?>(
        context: context,
        servers: servers,
        activeServerId: activeServerId,
        selectingServerId: selectingServerId,
        valueFor: (serverId) => serverId,
      ),
      onQuickMenuSelected: (value) {
        if (value is String) _switchServer(value);
      },
    );
    if (dbOnline) {
      return [
        homeTab,
        FloatingTabSpec<Object?>(
          label: l.tabLibrary,
          icon: Icons.video_library_rounded,
        ),
        FloatingTabSpec<Object?>(
          label: l.tabSearch,
          icon: Icons.search_rounded,
        ),
        FloatingTabSpec<Object?>(
          label: l.settingsTitle,
          icon: Icons.person_outline_rounded,
        ),
      ];
    }
    if (mediaBrowser) {
      // Emby/Jellyfin 与 OMM 一致：第 4 Tab 是收藏夹，设置入口在页头。
      return [
        homeTab,
        FloatingTabSpec<Object?>(
          label: l.tabLibrary,
          icon: Icons.video_library_rounded,
        ),
        FloatingTabSpec<Object?>(
          label: l.tabSearch,
          icon: Icons.search_rounded,
        ),
        FloatingTabSpec<Object?>(
          label: l.favoritesTitle,
          icon: Icons.favorite_outline_rounded,
        ),
      ];
    }
    return [
      homeTab,
      FloatingTabSpec<Object?>(
        label: l.tabLibrary,
        icon: Icons.video_library_rounded,
      ),
      FloatingTabSpec<Object?>(label: l.tabSearch, icon: Icons.search_rounded),
      FloatingTabSpec<Object?>(
        label: l.tabYou,
        icon: Icons.person_outline_rounded,
        quickMenuEntries: _quickMenuEntries(context),
        onQuickMenuSelected: (action) {
          if (action is _YouQuickAction) {
            unawaited(_openYouQuickAction(action));
          }
        },
      ),
    ];
  }

  Widget _bodyFor(int i, {required bool dbOnline, required bool mediaBrowser}) {
    switch (i) {
      case 0:
        if (dbOnline) return const DbOnlineHomePage();
        if (mediaBrowser) return const MediaBrowserHomePage();
        return const HomePage();
      case 1:
        if (dbOnline) return const DbOnlineLibraryPage();
        if (mediaBrowser) return const MediaBrowserLibraryPage();
        return const MoviesPage();
      case 2:
        if (dbOnline) return const DbOnlineSearchPage();
        if (mediaBrowser) return const MediaBrowserSearchPage();
        return const SearchPage();
      case 3:
        if (mediaBrowser) return const MediaBrowserFavoritesPage();
        return dbOnline ? const SettingsPage() : const FavoritesPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final project = config?.activeServer?.project;
    final dbOnline = project == ServerProject.dbOnline;
    final mediaBrowser = MediaBrowserConfig.byProject[project] != null;
    final transition = ref.watch(serverSwitchTransitionProvider);
    if (_lastProject != null && project != _lastProject && _index != 0) {
      _index = 0;
    }
    _lastProject = project;
    final tabs = _tabsFor(
      context,
      dbOnline: dbOnline,
      mediaBrowser: mediaBrowser,
      servers: config?.servers ?? const <ServerProfile>[],
      activeServerId: config?.activeServerId,
      selectingServerId: transition.isActive ? transition.targetServerId : null,
    );
    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: IndexedStack(
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
                  mediaBrowser: mediaBrowser,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: FloatingTabBar<Object?>(
        tabs: tabs,
        active: _index,
        onTap: _selectTab,
      ),
    );
  }
}

enum _YouQuickAction { tasks, libraries, audios, tags, genres, series, actors }
