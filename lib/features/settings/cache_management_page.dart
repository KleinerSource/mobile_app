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
                title: '缓存分类',
                items: [
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
                ],
              ),
              SettingsGroup(
                title: '总缓存大小',
                items: [
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
