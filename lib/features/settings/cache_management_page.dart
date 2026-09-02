import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../cache/disk_cache.dart';
import '../cache/music_cache.dart';
import 'settings_common.dart';

String _cacheCategoryLabel(CacheCategory category, AppL10n l) =>
    switch (category) {
      CacheCategory.image => l.cacheCategoryImage,
      CacheCategory.other => l.cacheCategoryOther,
    };

class CacheManagementPage extends ConsumerWidget {
  const CacheManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(cacheUsageProvider);
    final musicUsage = ref.watch(musicCacheUsageProvider);
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
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
                      ref: ref,
                    ),
                    _CacheTile(
                      category: CacheCategory.other,
                      usage: usage,
                      ref: ref,
                    ),
                    _MusicCacheTile(usage: musicUsage, ref: ref),
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
                          onPressed: () => _clearAll(context, ref),
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

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final l = AppL10n.of(context);
    final confirmed = await _confirmCacheClear(
      context,
      title: l.settingsCacheClearAllTitle,
      message: l.settingsCacheClearAllBody,
      actionLabel: l.settingsCacheCleanAll,
    );
    if (!confirmed || !context.mounted) return;

    AppHaptics.medium();
    try {
      await Future.wait([
        ref.read(diskCacheServiceProvider).clearAll(),
        ref.read(musicCacheServiceProvider).clear(),
      ]);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).settingsCacheClearFailed(error.toString()))),
        );
      }
      return;
    }
    ref.invalidate(cacheUsageProvider);
    ref.invalidate(musicCacheUsageProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppL10n.of(context).settingsCacheCleared)));
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
    required this.ref,
  });

  final CacheCategory category;
  final AsyncValue<CacheUsage> usage;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final size = usage.when(
      data: (value) => formatCacheBytes(value.bytesFor(category)),
      loading: () => l.commonLoading,
      error: (_, __) => l.commonReadFailed,
    );
    return SettingsTile(
      title: _cacheCategoryLabel(category, l),
      subtitle: size,
      leadingIcon: switch (category) {
        CacheCategory.image => Icons.image_outlined,
        CacheCategory.other => Icons.folder_open_outlined,
      },
      trailing: TextButton.icon(
        onPressed: () => _clear(context),
        icon: const Icon(Icons.delete_outline, size: 16),
        label: Text(l.settingsCacheClear),
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final l = AppL10n.of(context);
    final categoryLabel = _cacheCategoryLabel(category, l);
    final confirmed = await _confirmCacheClear(
      context,
      title: l.settingsCacheClearCategoryTitle(categoryLabel),
      message: l.settingsCacheClearCategoryBody(categoryLabel),
      actionLabel: l.settingsCacheClear,
    );
    if (!confirmed || !context.mounted) return;

    AppHaptics.medium();
    try {
      await ref.read(diskCacheServiceProvider).clear(category);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).settingsCacheClearFailed(error.toString()),
            ),
          ),
        );
      }
      return;
    }
    ref.invalidate(cacheUsageProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(context).settingsCacheCategoryCleared(categoryLabel),
          ),
        ),
      );
    }
  }
}

class _MusicCacheTile extends StatelessWidget {
  const _MusicCacheTile({required this.usage, required this.ref});

  final AsyncValue<int> usage;
  final WidgetRef ref;

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
        onPressed: () => _clear(context),
        icon: const Icon(Icons.delete_outline, size: 16),
        label: Text(l.settingsCacheClear),
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final l = AppL10n.of(context);
    final confirmed = await _confirmCacheClear(
      context,
      title: l.settingsCacheClearMusicTitle,
      message: l.settingsCacheClearMusicBody,
      actionLabel: l.settingsCacheClear,
    );
    if (!confirmed || !context.mounted) return;

    AppHaptics.medium();
    try {
      await ref.read(musicCacheServiceProvider).clear();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).settingsCacheClearFailed(error.toString()),
            ),
          ),
        );
      }
      return;
    }
    ref.invalidate(musicCacheUsageProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppL10n.of(context).settingsCacheMusicCleared)));
    }
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
