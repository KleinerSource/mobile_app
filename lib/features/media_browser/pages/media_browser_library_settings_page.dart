import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/swipe_actions.dart';
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
  String? _busyLibraryId;
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);

  @override
  void dispose() {
    _openSwipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(mediaBrowserConfigProvider);
    final colors = appColors(context);
    final l = AppL10n.of(context);
    if (config == null) {
      return _standaloneMessage(
        context,
        title: l.mediaBrowserLibrariesUnavailable,
        message: l.mediaBrowserNotMediaServer,
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
              title: l.mediaBrowserLibraryManageTitle,
              subtitle: l.mediaBrowserLibraryManageSubtitle,
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
    final l = AppL10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l.mediaBrowserRefresh,
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
      child: NotificationListener<ScrollUpdateNotification>(
        // 与 OMM 媒体库页一致：列表开始滚动时收起已展开的左滑操作。
        onNotification: (_) {
          if (_openSwipe.value != null) _openSwipe.value = null;
          return false;
        },
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
            return ListView(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
              children: [
                Container(
                  decoration: settingsCardDecoration(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        for (var i = 0; i < libraries.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: appColors(context).divider,
                            ),
                          SwipeActionCell(
                            group: _openSwipe,
                            cellKey: libraries[i].id,
                            actions: _librarySwipeActions(libraries[i]),
                            enabled: _busyLibraryId != libraries[i].id,
                            child: _LibraryCard(
                              library: libraries[i],
                              busy: _busyLibraryId == libraries[i].id,
                              onTap: () => _openEditor(libraries[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 与 OMM 媒体库页一致：点击行编辑，左滑提供刷新、启停和删除。
  List<SwipeActionData> _librarySwipeActions(MediaBrowserLibrary library) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return [
      SwipeActionData(
        icon: Icons.refresh_rounded,
        label: l.mediaBrowserRefresh,
        color: AppHues.top(AppHues.mint),
        onPressed: () => _refreshLibrary(library),
      ),
      SwipeActionData(
        icon: library.enabled
            ? Icons.toggle_off_outlined
            : Icons.toggle_on_outlined,
        label: library.enabled
            ? l.mediaBrowserDisableAction
            : l.mediaBrowserEnableAction,
        color: colors.warning,
        onPressed: () => _toggleLibrary(library),
      ),
      SwipeActionData(
        icon: Icons.delete_outline_rounded,
        label: l.delete,
        color: colors.danger,
        onPressed: () => _confirmDelete(library),
      ),
    ];
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
            Text(
              AppL10n.of(context).loadFailed,
              style: AppText.sectionTitle(context),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(AppL10n.of(context).mediaBrowserRetry),
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
            SettingsSubPageHeader(
              eyebrow: AppL10n.of(context).mediaBrowserLibrariesTitle,
              title: AppL10n.of(context).mediaBrowserLibraryManageTitle,
            ),
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

  Future<void> _refreshLibrary(MediaBrowserLibrary library) async {
    if (_busyLibraryId != null) return;
    final l = AppL10n.of(context);
    setState(() => _busyLibraryId = library.id);
    try {
      await ref.read(mediaBrowserMediaRepositoryProvider).refreshLibrary();
      _invalidateMediaBrowserCaches();
      _showMessage(l.mediaBrowserLibraryRefreshStarted(library.name));
    } catch (error) {
      _showError(l.mediaBrowserRefreshFailed(_errorMessage(error)));
    } finally {
      if (mounted) setState(() => _busyLibraryId = null);
    }
  }

  Future<void> _toggleLibrary(MediaBrowserLibrary library) async {
    if (_busyLibraryId != null) return;
    final l = AppL10n.of(context);
    final enabled = !library.enabled;
    setState(() => _busyLibraryId = library.id);
    try {
      final repository = ref.read(mediaBrowserMediaRepositoryProvider);
      await repository.updateVirtualFolderOptions(
        id: library.id,
        enabled: enabled,
        // 保留服务器返回的高级 LibraryOptions，避免启停操作覆盖配置。
        options: library.libraryOptions,
      );
      await repository.refreshLibrary();
      _invalidateMediaBrowserCaches();
      _showMessage(
        enabled
            ? l.mediaBrowserLibraryEnabled
            : l.mediaBrowserLibraryDisabled,
      );
    } catch (error) {
      _showError(l.mediaBrowserActionFailed(_errorMessage(error)));
    } finally {
      if (mounted) setState(() => _busyLibraryId = null);
    }
  }

  Future<void> _openEditor([MediaBrowserLibrary? library]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MediaBrowserLibraryEditorPage(library: library),
      ),
    );
    if (!mounted || saved != true) return;
    _showMessage(
      library == null
          ? AppL10n.of(context).mediaBrowserLibraryCreated
          : AppL10n.of(context).mediaBrowserLibrarySettingsSaved,
    );
  }

  Future<void> _confirmDelete(MediaBrowserLibrary library) async {
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.of(dialogContext).mediaBrowserDeleteLibraryTitle),
        content: Text(
          AppL10n.of(
            dialogContext,
          ).mediaBrowserDeleteLibraryBody(library.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppL10n.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(context).danger,
            ),
            child: Text(AppL10n.of(dialogContext).delete),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busyLibraryId = library.id);
    try {
      final repository = ref.read(mediaBrowserMediaRepositoryProvider);
      await repository.removeVirtualFolder(library.name);
      await repository.refreshLibrary();
      _invalidateMediaBrowserCaches();
      _showMessage(l.mediaBrowserLibraryDeleted);
    } catch (error) {
      _showError(l.mediaBrowserDeleteFailed(_errorMessage(error)));
    } finally {
      if (mounted) setState(() => _busyLibraryId = null);
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
            Text(
              AppL10n.of(context).mediaBrowserAdminRequired,
              style: AppText.sectionTitle(context),
            ),
            const SizedBox(height: 6),
            Text(
              AppL10n.of(context).mediaBrowserAdminRequiredHint,
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
                Text(
                  AppL10n.of(context).mediaBrowserNoLibrariesYet,
                  style: AppText.sectionTitle(context),
                ),
                const SizedBox(height: 6),
                Text(
                  AppL10n.of(context).mediaBrowserNoLibrariesHint,
                  style: AppText.meta(context),
                ),
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
    required this.busy,
    required this.onTap,
  });

  final MediaBrowserLibrary library;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.video_library_outlined,
                color: colors.accent,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          library.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: library.enabled ? colors.text : colors.muted,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(enabled: library.enabled),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _libraryTypeLabel(
                          AppL10n.of(context),
                          library.collectionType,
                        ),
                        style: AppText.meta(context),
                      ),
                      if (busy) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: colors.accent,
                          ),
                        ),
                      ],
                    ],
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
        enabled
            ? AppL10n.of(context).mediaBrowserStatusEnabled
            : AppL10n.of(context).mediaBrowserStatusDisabled,
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
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: config?.brandLabel ?? l.mediaBrowserLibrariesTitle,
              title: _editing
                  ? l.mediaBrowserEditLibraryTitle
                  : l.mediaBrowserNewLibraryTitle,
              subtitle: _editing
                  ? l.mediaBrowserEditLibrarySubtitle
                  : l.mediaBrowserNewLibrarySubtitle,
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
                    labelText: l.mediaBrowserLibraryNameLabel,
                    hintText: l.mediaBrowserLibraryNameHint,
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                _collectionTypeField(colors),
                const SizedBox(height: 22),
                _sectionLabel(l.mediaBrowserMediaPathsLabel),
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
    final l = AppL10n.of(context);
    if (_editing) {
      return InputDecorator(
        decoration: settingsInputDecoration(
          context,
          labelText: l.mediaBrowserContentTypeReadonly,
          prefixIcon: const Icon(Icons.category_outlined),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _libraryTypeLabel(l, _collectionType),
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
        labelText: l.mediaBrowserContentType,
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
              DropdownMenuItem(
                value: option.value,
                child: Text(option.label(l)),
              ),
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
    final l = AppL10n.of(context);
    return Column(
      children: [
        for (var index = 0; index < _pathControllers.length; index++) ...[
          TextField(
            controller: _pathControllers[index],
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: settingsInputDecoration(
              context,
              labelText: l.mediaBrowserPathNumber(index + 1),
              hintText: l.mediaBrowserPathHint,
              prefixIcon: const Icon(Icons.folder_open_outlined),
              suffixIcon: IconButton(
                tooltip: l.mediaBrowserRemovePath,
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
            label: Text(l.mediaBrowserAddPath),
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
                  AppL10n.of(context).mediaBrowserEnableLibraryLabel,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _enabled
                      ? AppL10n.of(context).mediaBrowserEnableLibraryHint
                      : AppL10n.of(context).mediaBrowserDisableLibraryHint,
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
      setState(
        () => _error = AppL10n.of(context).mediaBrowserLibraryNameRequired,
      );
      return;
    }
    if (_collectionType.trim().isEmpty) {
      setState(() => _error = AppL10n.of(context).mediaBrowserContentTypeRequired);
      return;
    }
    if (paths.isEmpty) {
      setState(() => _error = AppL10n.of(context).mediaBrowserPathRequired);
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
        setState(() {
          _error = AppL10n.of(
            context,
          ).mediaBrowserSaveFailed(_errorMessage(error));
        });
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
  final String Function(AppL10n l) label;
}

final _libraryTypeOptions = <_LibraryTypeOption>[
  _LibraryTypeOption('movies', (l) => l.mediaBrowserTypeMovies),
  _LibraryTypeOption('tvshows', (l) => l.mediaBrowserTypeTvShows),
  _LibraryTypeOption('music', (l) => l.mediaBrowserTypeMusic),
  _LibraryTypeOption('mixed', (l) => l.mediaBrowserTypeMixed),
  _LibraryTypeOption('musicvideos', (l) => l.mediaBrowserTypeMusicVideos),
  _LibraryTypeOption('homevideos', (l) => l.mediaBrowserTypeHomeVideos),
  _LibraryTypeOption('books', (l) => l.mediaBrowserTypeBooks),
  _LibraryTypeOption('photos', (l) => l.mediaBrowserTypePhotos),
];

String _libraryTypeLabel(AppL10n l, String? type) {
  final value = type?.trim() ?? '';
  for (final option in _libraryTypeOptions) {
    if (option.value == value) return option.label(l);
  }
  return value.isEmpty
      ? l.mediaBrowserTypeUnknown
      : l.mediaBrowserTypeUnknownWithValue(value);
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
