import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/common/source_id.dart';
import '../../core/sources/files/file_entry.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/floating_tab_bar.dart';
import 'file_browser_page.dart';
import 'file_favorites.dart';
import 'file_favorites_page.dart';
import 'file_navigation.dart';
import 'file_sources_page.dart';
import '../settings/server_selection_page.dart';
import '../settings/settings_page.dart';

/// 文件管理器 Shell · 文件管理 / 收藏 / 设置三项悬浮导航。
///
/// SMB、WebDAV、OpenList 以及未来接入的 NFS/FTP 等文件来源统一从这里
/// 进入。目录页面由内部 Navigator 承载，使悬浮导航在所有目录层级保持
/// 可见；收藏为独立列表页，点击收藏项会切回文件 Tab 并定位打开。
class FileManagerShell extends ConsumerStatefulWidget {
  const FileManagerShell({super.key});

  @override
  ConsumerState<FileManagerShell> createState() => _FileManagerShellState();
}

class _FileManagerShellState extends ConsumerState<FileManagerShell> {
  final _fileNavigatorKey = GlobalKey<NavigatorState>();
  final _moveTargetTab = ValueNotifier<int?>(null);
  var _index = 0;

  @override
  void dispose() {
    _moveTargetTab.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _index) return;
    AppHaptics.selection();
    setState(() => _index = index);
  }

  void _returnToServerSelector() {
    ServerSelectionPage.requestReturn(context);
  }

  /// 收藏列表跳转：目录按路径逐级压入目录栈（返回行为与逐级进入一致）；
  /// 文件压入所在目录并在首次加载后自动打开。随后切回文件 Tab。
  void _openFavorite(FileFavorite favorite) {
    final navigator = _fileNavigatorKey.currentState;
    final serverId = ref.read(serverConfigProvider)?.activeServerId;
    if (navigator == null || serverId == null) return;
    final sourceId = SourceId(favorite.sourceId);
    final crumbs = buildBreadcrumbs(
      FilePath(sourceId: sourceId, value: favorite.path),
      webDav: favorite.path.startsWith('/'),
    );
    // 首个面包屑是根目录（由文件 Tab 根页面承载），文件还需去掉自身。
    final chain = <FilePath>[for (var i = 1; i < crumbs.length; i++) crumbs[i]];
    if (!favorite.isDirectory && chain.isNotEmpty) {
      chain.removeLast();
    }
    if (chain.isEmpty) chain.add(FilePath(sourceId: sourceId, value: ''));
    for (var i = 0; i < chain.length; i++) {
      final isTarget = i == chain.length - 1;
      navigator.push<void>(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: fileBrowserRouteName(
              serverId: serverId,
              sourceId: sourceId.value,
              path: chain[i].value,
            ),
          ),
          allowSnapshotting: false,
          builder: (_) => FileBrowserPage(
            serverId: serverId,
            sourceId: sourceId,
            initialPath: chain[i].value,
            autoOpenFile: isTarget && !favorite.isDirectory
                ? favorite.toEntry(sourceId)
                : null,
          ),
        ),
      );
    }
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final fileNavigator = NavigatorPopHandler<void>(
      enabled: _index == 0,
      onPopWithResult: (_) {
        _fileNavigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _fileNavigatorKey,
        initialRoute: fileManagerRootRouteName,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(
            name: settings.name ?? fileManagerRootRouteName,
          ),
          builder: (_) => const FileSourcesPage(),
        ),
      ),
    );

    return FileManagerNavigationScope(
      onRequestServerSelection: _returnToServerSelector,
      moveTargetTab: _moveTargetTab,
      child: Scaffold(
        extendBody: true,
        backgroundColor: c.bg,
        body: IndexedStack(
          index: _index,
          children: [
            fileNavigator,
            FileFavoritesPage(onOpenFavorite: _openFavorite),
            const SettingsPage(forFileManager: true),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<int?>(
          valueListenable: _moveTargetTab,
          builder: (context, moveTab, _) {
            final isMoveTargetPicker = moveTab != null;
            final tabs = isMoveTargetPicker
                ? [
                    FloatingTabSpec<void>(
                      label: l.tabFiles,
                      icon: Icons.folder_rounded,
                    ),
                    FloatingTabSpec<void>(
                      label: l.fileFavoritesSection,
                      icon: Icons.star_rounded,
                    ),
                  ]
                : [
                    FloatingTabSpec<void>(
                      label: l.tabFiles,
                      icon: Icons.folder_rounded,
                    ),
                    FloatingTabSpec<void>(
                      label: l.fileFavoritesSection,
                      icon: Icons.star_rounded,
                    ),
                    FloatingTabSpec<void>(
                      label: l.settingsTitle,
                      icon: Icons.settings_rounded,
                    ),
                  ];
            return FloatingTabBar<void>(
              tabs: tabs,
              active: isMoveTargetPicker ? moveTab : _index,
              onTap: (index) {
                if (!isMoveTargetPicker) {
                  _selectTab(index);
                  return;
                }
                if (index != moveTab) AppHaptics.selection();
                _moveTargetTab.value = index;
              },
            );
          },
        ),
      ),
    );
  }
}
