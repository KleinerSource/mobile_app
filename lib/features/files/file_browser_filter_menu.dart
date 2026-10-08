part of 'file_browser_page.dart';

/// 子项直接更新偏好，避免普通 PopupMenuItem 点击后关闭整个菜单。
class _FileTypeFilterMenu extends PopupMenuEntry<_BrowserMenuAction> {
  const _FileTypeFilterMenu({required this.serverId, required this.onChanged});

  final String serverId;
  final VoidCallback onChanged;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(_BrowserMenuAction? value) => false;

  @override
  State<_FileTypeFilterMenu> createState() => _FileTypeFilterMenuState();
}

class _FileTypeFilterMenuState extends State<_FileTypeFilterMenu> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final provider = fileBrowserPreferencesProvider(widget.serverId);
        final preferences = ref.watch(provider);
        final notifier = ref.read(provider.notifier);
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
                        const Icon(Icons.filter_list, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l.fileTypeFilter)),
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
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
                    widget.onChanged();
                    notifier.toggleType(type);
                  },
                ),
              CheckboxListTile(
                contentPadding: const EdgeInsets.only(left: 24, right: 16),
                title: Text(l.fileShowHidden),
                value: preferences.showHiddenFiles,
                onChanged: (_) {
                  widget.onChanged();
                  notifier.toggleHiddenFiles();
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
