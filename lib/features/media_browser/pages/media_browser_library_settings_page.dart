import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/features/settings/settings_common.dart';

/// Emby / Jellyfin 管理端媒体库配置页。
///
/// 媒体库配置始终从服务器读取；本页只管理服务器虚拟媒体库，不复用
/// OMM 的本地媒体库 Repository。
class MediaBrowserLibrarySettingsPage extends ConsumerStatefulWidget {
  const MediaBrowserLibrarySettingsPage({super.key});

  @override
  ConsumerState<MediaBrowserLibrarySettingsPage> createState() =>
      _MediaBrowserLibrarySettingsPageState();
}

class _MediaBrowserLibrarySettingsPageState
    extends ConsumerState<MediaBrowserLibrarySettingsPage> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(mediaBrowserConfigProvider);
    final colors = appColors(context);
    if (config == null) {
      return _standaloneMessage(
        context,
        title: '无法访问媒体库',
        message: '当前服务器不是 Emby 或 Jellyfin。',
      );
    }

    final user = ref.watch(mediaBrowserCurrentUserProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: config.brandLabel,
              title: '媒体库管理',
              subtitle: '管理服务器上的虚拟媒体库与媒体路径。',
              trailing: user.value?.isAdmin == true ? _headerActions() : null,
            ),
            body: user.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _errorState(
                context,
                message: _errorMessage(error),
                onRetry: () => ref.invalidate(mediaBrowserCurrentUserProvider),
              ),
              data: (currentUser) {
                if (!currentUser.isAdmin) return const _AdminRequiredState();
                return _libraryList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '刷新',
          onPressed: _refreshing ? null : _refresh,
          icon: _refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
        SettingsAddButton(onPressed: _openEditor),
      ],
    );
  }

  Widget _libraryList() {
    final async = ref.watch(mediaBrowserVirtualFoldersProvider);
    return RefreshIndicator(
      color: appColors(context).accent,
      onRefresh: () => ref.refresh(mediaBrowserVirtualFoldersProvider.future),
      child: async.when(
        loading: () =>
            _scrollableMessage(context, const CircularProgressIndicator()),
        error: (error, _) => _errorState(
          context,
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(mediaBrowserVirtualFoldersProvider),
        ),
        data: (libraries) {
          if (libraries.isEmpty) return const _EmptyLibraryState();
          return ListView.separated(
            primary: true,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
            itemCount: libraries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final library = libraries[index];
              return _LibraryCard(
                library: library,
                onTap: () => _openEditor(library),
                onDelete: () => _confirmDelete(library),
              );
            },
          );
        },
      ),
    );
  }

  Widget _scrollableMessage(BuildContext context, Widget child) {
    return ListView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.48,
          child: Center(child: child),
        ),
      ],
    );
  }

  Widget _errorState(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    return _scrollableMessage(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败', style: AppText.sectionTitle(context)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _standaloneMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: SafeArea(
        child: Column(
          children: [
            const SettingsSubPageHeader(eyebrow: '媒体库', title: '媒体库管理'),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppText.sectionTitle(context)),
                    const SizedBox(height: 8),
                    Text(message),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      // ignore: unused_result
      await ref.refresh(mediaBrowserVirtualFoldersProvider.future);
    } catch (error) {
      if (mounted) {
        _showError(_errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openEditor([MediaBrowserLibrary? library]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MediaBrowserLibraryEditorPage(library: library),
      ),
    );
    if (!mounted || saved != true) return;
    _showMessage(library == null ? '媒体库已创建' : '媒体库设置已保存');
  }

  Future<void> _confirmDelete(MediaBrowserLibrary library) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除媒体库'),
        content: Text(
          '确定删除「${library.name}」吗？\n服务器上的媒体文件不会被删除，但库配置和相关索引可能会移除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(context).danger,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      final repository = ref.read(mediaBrowserMediaRepositoryProvider);
      await repository.removeVirtualFolder(library.name);
      await repository.refreshLibrary();
      _invalidateMediaBrowserCaches();
      _showMessage('媒体库已删除');
    } catch (error) {
      _showError('删除失败：${_errorMessage(error)}');
    }
  }

  void _invalidateMediaBrowserCaches() {
    ref.invalidate(mediaBrowserVirtualFoldersProvider);
    ref.invalidate(mediaBrowserViewsProvider);
    ref.invalidate(mediaBrowserLibraryStatsProvider);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AppHaptics.medium();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _errorMessage(Object error) =>
    error is SourceException ? error.message : toApiException(error).message;

class _AdminRequiredState extends StatelessWidget {
  const _AdminRequiredState();

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 42,
              color: colors.muted,
            ),
            const SizedBox(height: 14),
            Text('需要管理员账号', style: AppText.sectionTitle(context)),
            const SizedBox(height: 6),
            Text(
              '当前账号没有管理媒体库的权限，请使用服务器管理员账号登录。',
              textAlign: TextAlign.center,
              style: AppText.meta(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return ListView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.48,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 44,
                  color: colors.muted,
                ),
                const SizedBox(height: 14),
                Text('还没有媒体库', style: AppText.sectionTitle(context)),
                const SizedBox(height: 6),
                Text('点击右上角“添加”创建第一个媒体库', style: AppText.meta(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.onTap,
    required this.onDelete,
  });

  final MediaBrowserLibrary library;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Container(
      decoration: settingsCardDecoration(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.video_library_outlined, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            library.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: library.enabled
                                  ? colors.text
                                  : colors.muted,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(enabled: library.enabled),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _libraryTypeLabel(library.collectionType),
                      style: AppText.meta(context),
                    ),
                    const SizedBox(height: 8),
                    if (library.paths.isEmpty)
                      Text('未配置媒体路径', style: AppText.meta(context))
                    else
                      for (final path in library.paths.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.muted, fontSize: 12),
                          ),
                        ),
                    if (library.paths.length > 3)
                      Text(
                        '+${library.paths.length - 3} 个路径',
                        style: AppText.meta(context),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: '编辑',
                    onPressed: onTap,
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: onDelete,
                    color: colors.danger,
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final color = enabled ? colors.accent : colors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        enabled ? '已启用' : '已停用',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MediaBrowserLibraryEditorPage extends ConsumerStatefulWidget {
  const MediaBrowserLibraryEditorPage({super.key, this.library});

  final MediaBrowserLibrary? library;

  @override
  ConsumerState<MediaBrowserLibraryEditorPage> createState() =>
      _MediaBrowserLibraryEditorPageState();
}

class _MediaBrowserLibraryEditorPageState
    extends ConsumerState<MediaBrowserLibraryEditorPage> {
  late final TextEditingController _nameController;
  final _pathControllers = <TextEditingController>[];
  late String _collectionType;
  late bool _enabled;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.library != null;

  @override
  void initState() {
    super.initState();
    final library = widget.library;
    _nameController = TextEditingController(text: library?.name ?? '');
    _collectionType = library?.collectionType ?? 'movies';
    _enabled = library?.enabled ?? true;
    final paths = library?.paths ?? const <String>[];
    for (final path in paths) {
      _pathControllers.add(TextEditingController(text: path));
    }
    if (_pathControllers.isEmpty) _pathControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _pathControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(mediaBrowserConfigProvider);
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: config?.brandLabel ?? '媒体库',
              title: _editing ? '编辑媒体库' : '新建媒体库',
              subtitle: _editing ? '内容类型创建后不可修改。' : '填写名称、内容类型和一个或多个媒体路径。',
            ),
            body: ListView(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              children: [
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: settingsInputDecoration(
                    context,
                    labelText: '媒体库名称',
                    hintText: '例如：电影、电视剧、音乐',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                _collectionTypeField(colors),
                const SizedBox(height: 22),
                _sectionLabel('媒体路径'),
                _pathsField(colors),
                if (_editing) ...[
                  const SizedBox(height: 22),
                  _enabledField(colors),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _errorBox(colors, _error!),
                ],
                const SizedBox(height: 28),
                SettingsSaveButton(onPressed: _save, saving: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _collectionTypeField(AppColors colors) {
    if (_editing) {
      return InputDecorator(
        decoration: settingsInputDecoration(
          context,
          labelText: '内容类型（只读）',
          prefixIcon: const Icon(Icons.category_outlined),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _libraryTypeLabel(_collectionType),
                style: TextStyle(
                  color: colors.muted,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.lock_outline_rounded, size: 17, color: colors.muted),
          ],
        ),
      );
    }
    return InputDecorator(
      decoration: settingsInputDecoration(
        context,
        labelText: '内容类型',
        prefixIcon: const Icon(Icons.category_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _collectionType,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: colors.text,
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final option in _libraryTypeOptions)
              DropdownMenuItem(value: option.value, child: Text(option.label)),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value == null) return;
                  AppHaptics.selection();
                  setState(() => _collectionType = value);
                },
        ),
      ),
    );
  }

  Widget _pathsField(AppColors colors) {
    return Column(
      children: [
        for (var index = 0; index < _pathControllers.length; index++) ...[
          TextField(
            controller: _pathControllers[index],
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: settingsInputDecoration(
              context,
              labelText: '路径 ${index + 1}',
              hintText: '/media/movies 或 D:\\Media\\Movies',
              prefixIcon: const Icon(Icons.folder_open_outlined),
              suffixIcon: IconButton(
                tooltip: '移除路径',
                onPressed: _saving ? null : () => _removePath(index),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
          ),
          if (index < _pathControllers.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _addPath,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('添加路径'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.text,
              side: BorderSide(color: colors.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _enabledField(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: settingsCardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '启用媒体库',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _enabled ? '服务器会继续扫描并展示此媒体库' : '媒体库停用后不会出现在正常浏览入口',
                  style: AppText.meta(context),
                ),
              ],
            ),
          ),
          SettingsSwitch(
            value: _enabled,
            onChanged: _saving
                ? null
                : (value) => setState(() => _enabled = value),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(), style: AppText.eyebrow(context)),
  );

  Widget _errorBox(AppColors colors, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        border: Border.all(color: colors.danger.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: colors.danger)),
    );
  }

  void _addPath() {
    setState(() => _pathControllers.add(TextEditingController()));
  }

  void _removePath(int index) {
    final controller = _pathControllers.removeAt(index);
    controller.dispose();
    if (_pathControllers.isEmpty) _pathControllers.add(TextEditingController());
    setState(() {});
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final paths = _normalizedPaths(
      _pathControllers.map((controller) => controller.text),
    );
    if (name.isEmpty) {
      setState(() => _error = '媒体库名称不能为空');
      return;
    }
    if (_collectionType.trim().isEmpty) {
      setState(() => _error = '请选择媒体库内容类型');
      return;
    }
    if (paths.isEmpty) {
      setState(() => _error = '至少需要填写一个媒体路径');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(mediaBrowserMediaRepositoryProvider);
      final library = widget.library;
      if (library == null) {
        await repository.addVirtualFolder(
          name: name,
          collectionType: _collectionType,
          paths: paths,
        );
        await repository.refreshLibrary();
      } else {
        await _updateLibrary(repository, library, name, paths);
      }
      _invalidateMediaBrowserCaches();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '保存失败：${_errorMessage(error)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateLibrary(
    MediaBrowserMediaRepository repository,
    MediaBrowserLibrary library,
    String name,
    List<String> paths,
  ) async {
    final oldName = library.name.trim();
    final oldPaths = _normalizedPaths(library.paths);
    final oldPathSet = oldPaths.toSet();
    final newPathSet = paths.toSet();
    final changed =
        oldName != name ||
        oldPathSet.length != newPathSet.length ||
        !oldPathSet.containsAll(newPathSet) ||
        _enabled != library.enabled;
    if (!changed) return;

    // 名称先更新，后续路径接口使用最新名称。
    if (oldName != name) {
      await repository.renameVirtualFolder(name: oldName, newName: name);
    }
    for (final path in oldPaths) {
      if (!newPathSet.contains(path)) {
        await repository.removeMediaPath(libraryName: name, path: path);
      }
    }
    for (final path in paths) {
      if (!oldPathSet.contains(path)) {
        await repository.addMediaPath(libraryName: name, path: path);
      }
    }
    if (_enabled != library.enabled) {
      await repository.updateVirtualFolderOptions(
        id: library.id,
        enabled: _enabled,
        options: library.libraryOptions,
      );
    }
    await repository.refreshLibrary();
  }

  void _invalidateMediaBrowserCaches() {
    ref.invalidate(mediaBrowserVirtualFoldersProvider);
    ref.invalidate(mediaBrowserViewsProvider);
    ref.invalidate(mediaBrowserLibraryStatsProvider);
  }
}

class _LibraryTypeOption {
  const _LibraryTypeOption(this.value, this.label);

  final String value;
  final String label;
}

const _libraryTypeOptions = <_LibraryTypeOption>[
  _LibraryTypeOption('movies', '电影'),
  _LibraryTypeOption('tvshows', '剧集'),
  _LibraryTypeOption('music', '音乐'),
  _LibraryTypeOption('mixed', '混合内容'),
  _LibraryTypeOption('musicvideos', '音乐视频'),
  _LibraryTypeOption('homevideos', '家庭视频'),
  _LibraryTypeOption('books', '图书'),
  _LibraryTypeOption('photos', '图片'),
];

String _libraryTypeLabel(String? type) {
  final value = type?.trim() ?? '';
  for (final option in _libraryTypeOptions) {
    if (option.value == value) return option.label;
  }
  return value.isEmpty ? '未知类型' : '未知类型（$value）';
}

List<String> _normalizedPaths(Iterable<String> paths) {
  final result = <String>[];
  final seen = <String>{};
  for (final path in paths) {
    final normalized = path.trim();
    if (normalized.isEmpty || !seen.add(normalized)) continue;
    result.add(normalized);
  }
  return result;
}
