part of 'file_browser_page.dart';

class _BatchRenameSheet extends StatefulWidget {
  const _BatchRenameSheet({required this.entries});

  final List<FileEntry> entries;

  @override
  State<_BatchRenameSheet> createState() => _BatchRenameSheetState();
}

class _BatchRenameSheetState extends State<_BatchRenameSheet> {
  final _searchController = TextEditingController();
  final _replacementController = TextEditingController();
  final _addController = TextEditingController();
  var _mode = _BatchRenameMode.replace;
  var _addBefore = true;

  @override
  void dispose() {
    _searchController.dispose();
    _replacementController.dispose();
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final draft = _BatchRenameDraft(
      mode: _mode,
      search: _searchController.text,
      replacement: _replacementController.text,
      addText: _addController.text,
      addBefore: _addBefore,
    );
    final previews = widget.entries
        .map(
          (entry) => (
            original: entry.name,
            renamed: _applyBatchRenameName(entry.name, draft),
          ),
        )
        .toList(growable: false);
    final canSubmit = _mode == _BatchRenameMode.replace
        ? _searchController.text.isNotEmpty
        : _addController.text.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              icon: Icons.drive_file_rename_outline,
              title: l.fileBatchRenameTitle,
              subtitle: l.fileBatchRenameSubtitle,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: DropdownButtonFormField<_BatchRenameMode>(
                initialValue: _mode,
                decoration: sheetInputDecoration(
                  context,
                  labelText: l.fileRenameMode,
                ),
                items: [
                  DropdownMenuItem(
                    value: _BatchRenameMode.replace,
                    child: Text(l.fileRenameModeReplace),
                  ),
                  DropdownMenuItem(
                    value: _BatchRenameMode.add,
                    child: Text(l.fileRenameModeAdd),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _mode = value);
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_mode == _BatchRenameMode.replace) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  controller: _searchController,
                  decoration: sheetInputDecoration(
                    context,
                    labelText: l.fileRenameSearchLabel,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  controller: _replacementController,
                  decoration: sheetInputDecoration(
                    context,
                    labelText: l.fileRenameReplaceLabel,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  controller: _addController,
                  decoration: sheetInputDecoration(
                    context,
                    labelText: l.fileRenameAddTextLabel,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: DropdownButtonFormField<bool>(
                  initialValue: _addBefore,
                  decoration: sheetInputDecoration(
                    context,
                    labelText: l.fileRenameAddPosition,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Text(l.fileRenameAddBefore),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text(l.fileRenameAddAfter),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _addBefore = value);
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Text(
                l.filePreviewSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                itemCount: previews.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final preview = previews[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      preview.renamed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: preview.original == preview.renamed
                        ? null
                        : Text(
                            preview.original,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  );
                },
              ),
            ),
            SheetActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: sheetSecondaryButtonStyle(context),
                      child: Text(AppL10n.of(context).cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSubmit
                          ? () => Navigator.of(context).pop(draft)
                          : null,
                      style: sheetPrimaryButtonStyle(context),
                      child: Text(AppL10n.of(context).fileApply),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _applyBatchRenameName(String name, _BatchRenameDraft draft) {
  return switch (draft.mode) {
    _BatchRenameMode.replace =>
      draft.search.isEmpty
          ? name
          : name.replaceAllMapped(
              RegExp(RegExp.escape(draft.search), caseSensitive: false),
              (_) => draft.replacement,
            ),
    _BatchRenameMode.add =>
      draft.addBefore ? '${draft.addText}$name' : '$name${draft.addText}',
  };
}
