import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../cache/disk_cache.dart';
import 'settings_common.dart';

class CacheManagementPage extends ConsumerWidget {
  const CacheManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(diskPrecacheSettingsProvider);
    final usage = ref.watch(cacheUsageProvider);
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              const SettingsSubPageHeader(
                eyebrow: '应用设置',
                title: '缓存管理',
              ),
              SettingsGroup(
                title: '磁盘缓存',
                items: [
                  SettingsTile(
                    title: '缓存大小(Wi-Fi)',
                    subtitle: '播放时最多保留的缓冲数据，不下载完整视频',
                    leadingIcon: Icons.wifi_outlined,
                    trailing: _ValueLabel(text: settings.wifiLimit.label),
                    onTap: () => _selectLimit(
                      context,
                      ref,
                      network: PrecacheNetwork.wifi,
                      current: settings.wifiLimit,
                    ),
                  ),
                  SettingsTile(
                    title: '缓存大小(流量)',
                    subtitle: '播放时最多保留的缓冲数据，不下载完整视频',
                    leadingIcon: Icons.signal_cellular_alt_outlined,
                    trailing: _ValueLabel(text: settings.mobileLimit.label),
                    onTap: () => _selectLimit(
                      context,
                      ref,
                      network: PrecacheNetwork.mobile,
                      current: settings.mobileLimit,
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '当前缓存',
                items: [
                  const _CacheSectionLabel(title: '缓存分类'),
                  _CacheTile(
                    category: CacheCategory.video,
                    usage: usage,
                    ref: ref,
                  ),
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
                  const _CacheSectionLabel(title: '总缓存'),
                  SettingsTile(
                    title: '总缓存大小',
                    subtitle: usage.when(
                      data: (value) => formatCacheBytes(value.totalBytes),
                      loading: () => '读取中…',
                      error: (_, __) => '读取失败',
                    ),
                    leadingIcon: Icons.storage_outlined,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _clearAll(context, ref),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('一键清理'),
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
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmCacheClear(
      context,
      title: '确认清理全部缓存',
      message: '将清理视频、图片和其他缓存，此操作不可撤销。',
      actionLabel: '一键清理',
    );
    if (!confirmed || !context.mounted) return;

    AppHaptics.medium();
    try {
      await ref.read(diskCacheServiceProvider).clearAll();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清理失败: $error')),
        );
      }
      return;
    }
    ref.invalidate(cacheUsageProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清理')),
      );
    }
  }

  Future<void> _selectLimit(
    BuildContext context,
    WidgetRef ref, {
    required PrecacheNetwork network,
    required CacheSizeOption current,
  }) async {
    final selected = await showModalBottomSheet<CacheSizeOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final c = appColors(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '缓存大小(${network.label})',
                    style: AppText.sectionTitle(sheetContext),
                  ),
                ),
              ),
              for (final option in cacheSizeOptions)
                ListTile(
                  leading: Icon(
                    option == CacheSizeOption.disabled
                        ? Icons.block_outlined
                        : Icons.sd_storage_outlined,
                    color: option == current ? c.accent : c.muted,
                  ),
                  title: Text(option.label),
                  trailing: option == current
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == current || !context.mounted) return;
    AppHaptics.selection();
    final notifier = ref.read(diskPrecacheSettingsProvider.notifier);
    final currentSettings = ref.read(diskPrecacheSettingsProvider);
    await notifier.update(
      network == PrecacheNetwork.wifi
          ? currentSettings.copyWith(wifiLimit: selected)
          : currentSettings.copyWith(mobileLimit: selected),
    );
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

class _ValueLabel extends StatelessWidget {
  const _ValueLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Text(
      text,
      style: TextStyle(
        color: c.accent,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 13,
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
            child: const Text('取消'),
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
    final size = usage.when(
      data: (value) => formatCacheBytes(value.bytesFor(category)),
      loading: () => '读取中…',
      error: (_, __) => '读取失败',
    );
    return SettingsTile(
      title: category.label,
      subtitle: size,
      leadingIcon: switch (category) {
        CacheCategory.video => Icons.movie_outlined,
        CacheCategory.image => Icons.image_outlined,
        CacheCategory.other => Icons.folder_open_outlined,
      },
      trailing: TextButton.icon(
        onPressed: () => _clear(context),
        icon: const Icon(Icons.delete_outline, size: 16),
        label: const Text('清理'),
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await _confirmCacheClear(
      context,
      title: '确认清理${category.label}',
      message: '将删除当前${category.label}中的全部文件，此操作不可撤销。',
      actionLabel: '清理',
    );
    if (!confirmed || !context.mounted) return;

    AppHaptics.medium();
    try {
      await ref.read(diskCacheServiceProvider).clear(category);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清理失败: $error')),
        );
      }
      return;
    }
    ref.invalidate(cacheUsageProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${category.label}已清理')),
      );
    }
  }
}
