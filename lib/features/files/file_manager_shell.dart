import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/floating_tab_bar.dart';
import 'file_sources_page.dart';
import 'file_navigation.dart';
import '../settings/server_selection_page.dart';
import '../settings/settings_page.dart';

/// 文件管理器 Shell · 文件管理 / 设置两项悬浮导航。
///
/// SMB、WebDAV 以及未来接入的 OpenList/NFS/FTP 等文件来源统一从这里
/// 进入。目录页面由内部 Navigator 承载，使悬浮导航在所有目录层级保持
/// 可见。
class FileManagerShell extends StatefulWidget {
  const FileManagerShell({super.key});

  @override
  State<FileManagerShell> createState() => _FileManagerShellState();
}

class _FileManagerShellState extends State<FileManagerShell> {
  final _fileNavigatorKey = GlobalKey<NavigatorState>();
  var _index = 0;

  void _selectTab(int index) {
    if (index == _index) return;
    AppHaptics.selection();
    setState(() => _index = index);
  }

  void _returnToServerSelector() {
    ServerSelectionPage.requestReturn(context);
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
      child: Scaffold(
        extendBody: true,
        backgroundColor: c.bg,
        body: IndexedStack(
          index: _index,
          children: [fileNavigator, const SettingsPage(forFileManager: true)],
        ),
        bottomNavigationBar: FloatingTabBar<void>(
          tabs: [
            FloatingTabSpec<void>(
              label: l.tabFiles,
              icon: Icons.folder_outlined,
            ),
            FloatingTabSpec<void>(
              label: l.settingsTitle,
              icon: Icons.settings_outlined,
            ),
          ],
          active: _index,
          onTap: _selectTab,
        ),
      ),
    );
  }
}
