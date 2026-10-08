part of 'file_browser_page.dart';

/// 文件菜单内就地展开；子项自行决定是否关闭菜单。
class _FileBrowserExpandableMenu extends PopupMenuEntry<_BrowserMenuAction> {
  const _FileBrowserExpandableMenu({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(_BrowserMenuAction? value) => false;

  @override
  State<_FileBrowserExpandableMenu> createState() =>
      _FileBrowserExpandableMenuState();
}

class _FileBrowserExpandableMenuState
    extends State<_FileBrowserExpandableMenu> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          expanded: _expanded,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(widget.title)),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) widget.child,
      ],
    );
  }
}

/// 子项直接更新偏好，避免普通 PopupMenuItem 点击后关闭整个菜单。
class _FileTypeFilterOptions extends ConsumerWidget {
  const _FileTypeFilterOptions({
    required this.serverId,
    required this.onChanged,
  });

  final String serverId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final provider = fileBrowserPreferencesProvider(serverId);
    final preferences = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in FileFilterType.values)
          CheckboxListTile(
            contentPadding: const EdgeInsets.only(left: 24, right: 16),
            title: Text(switch (type) {
              FileFilterType.video => l.fileFilterVideo,
              FileFilterType.music => l.fileFilterMusic,
              FileFilterType.image => l.fileFilterImage,
              FileFilterType.subtitle => l.fileFilterSubtitle,
              FileFilterType.other => l.fileFilterOther,
            }),
            value: preferences.selectedTypes.contains(type),
            onChanged: (_) {
              onChanged();
              notifier.toggleType(type);
            },
          ),
        CheckboxListTile(
          contentPadding: const EdgeInsets.only(left: 24, right: 16),
          title: Text(l.fileShowHidden),
          value: preferences.showHiddenFiles,
          onChanged: (_) {
            onChanged();
            notifier.toggleHiddenFiles();
          },
        ),
      ],
    );
  }
}
