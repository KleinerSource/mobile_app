import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/library.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'libraries_providers.dart';

/// 媒体库编辑器
/// - 名称 + 启用开关
/// - 目录列表 (add/remove 行 · 行内输入路径)
/// - 保存时逐目录 validate 路径
class LibraryEditorPage extends ConsumerStatefulWidget {
  const LibraryEditorPage({super.key, this.library});

  /// 为 null 时新建; 非空时编辑
  final LibraryItem? library;

  @override
  ConsumerState<LibraryEditorPage> createState() => _LibraryEditorPageState();
}

class _LibraryEditorPageState extends ConsumerState<LibraryEditorPage> {
  late final TextEditingController _nameController;
  bool _enabled = true;
  final List<_DirRow> _dirs = [];
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.library != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.library?.name ?? '');
    _enabled = widget.library?.enabled ?? true;
    final existing = widget.library?.directories ?? const [];
    if (existing.isEmpty) {
      _dirs.add(_DirRow());
    } else {
      for (final d in existing) {
        _dirs.add(_DirRow(id: d.id, path: d.path, enabled: d.enabled));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final d in _dirs) {
      d.controller.dispose();
    }
    super.dispose();
  }

  void _addDir() => setState(() => _dirs.add(_DirRow()));

  void _removeDir(int i) {
    final removed = _dirs.removeAt(i);
    removed.controller.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.libraryErrNameRequired);
      return;
    }
    final dirs = _dirs
        .where((d) => d.controller.text.trim().isNotEmpty)
        .toList();
    if (dirs.isEmpty) {
      setState(() => _error = l.libraryErrDirRequired);
      return;
    }
    // 重复检查
    final seen = <String>{};
    for (final d in dirs) {
      final p = d.controller.text.trim();
      if (!seen.add(p)) {
        setState(() => _error = l.libraryErrDirDuplicate(p));
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(librariesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 路径验证
      for (final d in dirs) {
        final path = d.controller.text.trim();
        final result = await repo.validatePath(path, directoryId: d.id);
        if (result['exists'] != true) {
          setState(() => _error = l.libraryErrPathNotFound(path));
          return;
        }
        if (result['is_directory'] != true) {
          setState(() => _error = l.libraryErrNotDirectory(path));
          return;
        }
        if (result['is_duplicate'] == true) {
          setState(() => _error = l.libraryErrPathUsed(path));
          return;
        }
      }

      // 保存 library
      final LibraryItem savedLib = _isEdit
          ? await repo.update(widget.library!.id, name: name, enabled: _enabled)
          : await repo.create(name: name, enabled: _enabled);
      final libId = savedLib.id;

      // 同步目录
      if (_isEdit) {
        final existing = widget.library!.directories;
        final keepIds = dirs
            .where((d) => d.id != null)
            .map((d) => d.id!)
            .toSet();
        // 删除原 list 中不在 form 的目录
        for (final old in existing) {
          if (!keepIds.contains(old.id)) {
            await repo.deleteDirectory(libId, old.id);
          }
        }
      }
      // create / update 每个 form 目录
      for (var i = 0; i < dirs.length; i++) {
        final d = dirs[i];
        final path = d.controller.text.trim();
        if (d.id == null) {
          await repo.createDirectory(
            libId,
            path: path,
            name: l.libraryDefaultDirName(i + 1),
            enabled: d.enabled,
          );
        } else {
          await repo.updateDirectory(
            libId,
            d.id!,
            path: path,
            enabled: d.enabled,
          );
        }
      }

      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? l.configSavedToast : l.libraryCreatedToast),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      ref.refresh(librariesAllProvider);
      if (mounted) await Navigator.of(context).maybePop();
    } catch (e) {
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsGroupLibrary,
              title: _isEdit
                  ? l.libraryEditorTitleEdit
                  : l.libraryEditorTitleNew,
              trailing: TextButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _isEdit ? l.save : l.listCreate,
                  style: TextStyle(
                    color: c.accent,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
            body: ListView(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              children: [
                // 名称
                Text(l.libraryEditorName, style: AppText.eyebrow(context)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _nameController,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: l.libraryEditorNameHint,
                      prefixIcon: const Icon(Icons.drive_file_rename_outline),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // 启用开关
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.libraryEnable,
                              style: TextStyle(
                                color: c.text,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.libraryEditorEnableHint,
                              style: AppText.meta(context),
                            ),
                          ],
                        ),
                      ),
                      SettingsSwitch(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // 目录
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.libraryEditorDirectories,
                        style: AppText.eyebrow(context),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addDir,
                      icon: Icon(Icons.add, size: 16, color: c.accent),
                      label: Text(
                        l.libraryEditorAddDir,
                        style: TextStyle(
                          color: c.accent,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _dirs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DirEditor(
                      row: _dirs[i],
                      index: i,
                      canRemove: _dirs.length > 1,
                      onRemove: () => _removeDir(i),
                      onChanged: () => setState(() {}),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.1),
                      border: Border.all(
                        color: c.danger.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: c.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: c.danger,
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_saving) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirRow {
  _DirRow({this.id, String? path, this.enabled = true})
    : controller = TextEditingController(text: path ?? '');

  final int? id;
  bool enabled;
  final TextEditingController controller;
}

class _DirEditor extends StatelessWidget {
  const _DirEditor({
    required this.row,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _DirRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: row.controller,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    hintText: '/path/to/media',
                    prefixIcon: Icon(Icons.folder_outlined),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: c.muted),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
