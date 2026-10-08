import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../cache/disk_cache.dart';
import '../cache/music_cache.dart';
import 'settings_common.dart';

class CacheManagementPage extends ConsumerStatefulWidget {
  const CacheManagementPage({super.key});

  @override
  ConsumerState<CacheManagementPage> createState() =>
      _CacheManagementPageState();
}

class _CacheManagementPageState extends ConsumerState<CacheManagementPage> {
  bool _clearing = false;

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(cacheUsageProvider);
    final musicUsage = ref.watch(musicCacheUsageProvider);
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsAppSettings,
              title: l.settingsCacheManagement,
            ),
            body: ListView(
              primary: true,
              children: [
                SettingsGroup(
                  title: l.settingsCurrentCache,
                  items: [
                    _CacheSectionLabel(title: l.settingsCacheCategories),
                    _CacheTile(
                      category: CacheCategory.image,
                      usage: usage,
                      onClear: _clearing
                          ? null
                          : () => _clear(category: CacheCategory.image),
                    ),
                    _CacheTile(
                      category: CacheCategory.other,
                      usage: usage,
                      onClear: _clearing
                          ? null
                          : () => _clear(category: CacheCategory.other),
                    ),
                    _MusicCacheTile(
                      usage: musicUsage,
                      onClear: _clearing ? null : () => _clear(music: true),
                    ),
                    _CacheSectionLabel(title: l.settingsCacheTotal),
                    SettingsTile(
                      title: l.settingsCacheTotalSize,
                      subtitle: _totalCacheText(usage, musicUsage, l),
                      leadingIcon: Icons.storage_outlined,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _clearing ? null : () => _clear(),
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                          ),
                          label: Text(l.settingsCacheCleanAll),
                          style: FilledButton.styleFrom(
                            backgroundColor: appColors(context).danger,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clear({CacheCategory? category, bool music = false}) async {
    if (_clearing) return;
    setState(() => _clearing = true);
    final l = AppL10n.of(context);
    final label = category?.label(l);
    try {
      final confirmed = await _confirmCacheClear(
        context,
        title: label != null
            ? l.settingsCacheClearCategoryTitle(label)
            : music
            ? l.settingsCacheClearMusicTitle
            : l.settingsCacheClearAllTitle,
        message: label != null
            ? l.settingsCacheClearCategoryBody(label)
            : music
            ? l.settingsCacheClearMusicBody
            : l.settingsCacheClearAllBody,
        actionLabel: category != null || music
            ? l.settingsCacheClear
            : l.settingsCacheCleanAll,
      );
      if (!confirmed || !mounted) return;
      AppHaptics.medium();
      Object? failure;
      try {
        if (category != null) {
          await ref.read(diskCacheServiceProvider).clear(category);
        } else if (music) {
          await ref.read(musicCacheServiceProvider).clear();
        } else {
          await Future.wait([
            ref.read(diskCacheServiceProvider).clearAll(),
            ref.read(musicCacheServiceProvider).clear(),
          ]);
        }
      } catch (error) {
        failure = error;
      }
      if (!mounted) return;
      // 部分清理成功后另一项可能失败，两种情况都重新统计。
      ref.invalidate(cacheUsageProvider);
      ref.invalidate(musicCacheUsageProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure != null
                ? l.settingsCacheClearFailed(failure.toString())
                : label != null
                ? l.settingsCacheCategoryCleared(label)
                : music
                ? l.settingsCacheMusicCleared
                : l.settingsCacheCleared,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}

class _CacheSectionLabel extends StatelessWidget {
  const _CacheSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: AppText.eyebrow(context)),
      ),
    );
  }
}

Future<bool> _confirmCacheClear(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
}) async {
  final l = AppL10n.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final c = appColors(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

class _CacheTile extends StatelessWidget {
  const _CacheTile({
    required this.category,
    required this.usage,
    required this.onClear,
  });

  final CacheCategory category;
  final AsyncValue<CacheUsage> usage;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final size = usage.when(
      data: (value) => formatCacheBytes(value.bytesFor(category)),
      loading: () => l.commonLoading,
      error: (_, __) => l.commonReadFailed,
    );
    return SettingsTile(
      title: category.label(l),
      subtitle: size,
      leadingIcon: switch (category) {
        CacheCategory.image => Icons.image_outlined,
        CacheCategory.other => Icons.folder_open_outlined,
      },
      trailing: TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.delete_outline, size: 16),
        label: Text(l.settingsCacheClear),
      ),
    );
  }
}

class _MusicCacheTile extends StatelessWidget {
  const _MusicCacheTile({required this.usage, required this.onClear});

  final AsyncValue<int> usage;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SettingsTile(
      title: l.cacheCategoryMusic,
      subtitle: usage.when(
        data: formatCacheBytes,
        loading: () => l.commonLoading,
        error: (_, __) => l.commonReadFailed,
      ),
      leadingIcon: Icons.music_note_outlined,
      trailing: TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.delete_outline, size: 16),
        label: Text(l.settingsCacheClear),
      ),
    );
  }
}

String _totalCacheText(
  AsyncValue<CacheUsage> usage,
  AsyncValue<int> musicUsage,
  AppL10n l,
) {
  return usage.when(
    data: (base) => musicUsage.when(
      data: (music) => formatCacheBytes(base.totalBytes + music),
      loading: () => l.commonLoading,
      error: (_, __) => l.commonReadFailed,
    ),
    loading: () => l.commonLoading,
    error: (_, __) => l.commonReadFailed,
  );
}
