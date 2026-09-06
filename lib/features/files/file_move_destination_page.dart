part of 'file_browser_page.dart';

class FileMoveDestinationPage extends StatefulWidget {
  const FileMoveDestinationPage({
    super.key,
    required this.serverId,
    required this.sourceId,
    required this.initialPath,
  });

  final String serverId;
  final SourceId sourceId;
  final String initialPath;

  @override
  State<FileMoveDestinationPage> createState() =>
      _FileMoveDestinationPageState();
}

class _FileMoveDestinationPageState extends State<FileMoveDestinationPage> {
  final _fileNavigatorKey = GlobalKey<NavigatorState>();
  final _localTab = ValueNotifier<int?>(0);

  @override
  void dispose() {
    _localTab.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _localTab.value) return;
    AppHaptics.selection();
    _localTab.value = index;
  }

  void _cancelPicker() {
    if (mounted) Navigator.of(context).pop();
  }

  void _submitDirectory(FilePath path) {
    if (mounted) Navigator.of(context).pop(path);
  }

  void _openFavorite(FileFavorite favorite) {
    if (favorite.sourceId != widget.sourceId.value) return;
    final navigator = _fileNavigatorKey.currentState;
    if (navigator == null) return;
    final sharedTab = FileManagerNavigationScope.moveTargetTabOf(context);
    if (sharedTab != null) {
      sharedTab.value = 0;
    } else {
      _localTab.value = 0;
    }
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: fileBrowserRouteName(
            serverId: widget.serverId,
            sourceId: widget.sourceId.value,
            path: favorite.path,
          ),
        ),
        allowSnapshotting: false,
        builder: (_) => FileBrowserPage(
          serverId: widget.serverId,
          sourceId: widget.sourceId,
          initialPath: favorite.path,
          directoryPicker: true,
          onDirectorySubmitted: _submitDirectory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final sharedTab = FileManagerNavigationScope.moveTargetTabOf(context);
    final tab = sharedTab ?? _localTab;
    return ValueListenableBuilder<int?>(
      valueListenable: tab,
      builder: (context, selectedTab, _) => _buildPage(
        context,
        l,
        selectedTab ?? 0,
        showBottomNavigation: sharedTab == null,
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    AppL10n l,
    int index, {
    required bool showBottomNavigation,
  }) {
    final fileNavigator = NavigatorPopHandler<void>(
      enabled: index == 0,
      onPopWithResult: (_) {
        _fileNavigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _fileNavigatorKey,
        initialRoute: fileBrowserRouteName(
          serverId: widget.serverId,
          sourceId: widget.sourceId.value,
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(
            name:
                settings.name ??
                fileBrowserRouteName(
                  serverId: widget.serverId,
                  sourceId: widget.sourceId.value,
                ),
          ),
          allowSnapshotting: false,
          builder: (_) => FileBrowserPage(
            serverId: widget.serverId,
            sourceId: widget.sourceId,
            initialPath: widget.initialPath,
            directoryPicker: true,
            onDirectorySubmitted: _submitDirectory,
            onDirectoryPickerCancelled: _cancelPicker,
          ),
        ),
      ),
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: appColors(context).bg,
      body: IndexedStack(
        index: index,
        children: [
          fileNavigator,
          FileFavoritesPage(
            directoriesOnly: true,
            sourceId: widget.sourceId.value,
            onOpenFavorite: _openFavorite,
          ),
        ],
      ),
      bottomNavigationBar: showBottomNavigation
          ? FloatingTabBar<void>(
              tabs: [
                FloatingTabSpec<void>(
                  label: l.tabFiles,
                  icon: Icons.folder_rounded,
                ),
                FloatingTabSpec<void>(
                  label: l.fileFavoritesSection,
                  icon: Icons.star_rounded,
                ),
              ],
              active: index,
              onTap: _selectTab,
            )
          : null,
    );
  }
}
