import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../cache/disk_cache.dart';
import 'cache_management_page.dart';
import 'settings_common.dart';

class DiskPrecachePage extends ConsumerWidget {
  const DiskPrecachePage({super.key});

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
                title: '磁盘预缓存',
              ),
              SettingsGroup(
                title: '缓存大小(Wi-Fi)',
                items: [
                  SettingsTile(
                    title: '缓存大小(Wi-Fi)',
                    subtitle: '连接 Wi-Fi 时允许使用的最大视频缓存空间',
                    leadingIcon: Icons.wifi_outlined,
                    trailing: _ValueLabel(text: settings.wifiLimit.label),
                    onTap: () => _selectLimit(
                      context,
                      ref,
                      network: PrecacheNetwork.wifi,
                      current: settings.wifiLimit,
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '缓存大小(流量)',
                items: [
                  SettingsTile(
                    title: '缓存大小(流量)',
                    subtitle: '使用移动数据时允许的最大视频缓存空间',
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
                  SettingsTile(
                    title: '视频缓存已占用',
                    subtitle: usage.when(
                      data: (value) => formatCacheBytes(value.videoBytes),
                      loading: () => '读取中…',
                      error: (_, __) => '读取失败',
                    ),
                    leadingIcon: Icons.movie_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CacheManagementPage(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: '缓存管理',
                    subtitle: '清理视频、图片和其他缓存',
                    leadingIcon: Icons.cleaning_services_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CacheManagementPage(),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(30, 0, 30, 80),
                child: Text(
                  '预缓存只在影片详情页手动启动。自动模式播放时会优先使用完整的视频缓存；固定画质仍使用服务器转码。',
                  style: TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
