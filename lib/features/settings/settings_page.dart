import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../core/platform/app_version.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import 'app_settings_page.dart';
import 'app_update_settings_page.dart';
import 'server_settings_page.dart';
import 'settings_common.dart';

/// 设置主入口 · 仅 2 个分类入口 + 关于
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final packageInfo = ref.watch(appPackageInfoProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              SettingsSubPageHeader(
                eyebrow: l.settingsTitle,
                title: l.settingsPreferences,
              ),
              SettingsGroup(
                title: l.settingsPreferences,
                items: [
                  SettingsTile(
                    title: l.settingsServerSettings,
                    subtitle: l.settingsServerSettingsSub,
                    leadingIcon: Icons.dns_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ServerSettingsPage()),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsAppSettings,
                    subtitle: l.settingsAppSettingsSub,
                    leadingIcon: Icons.tune_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AppSettingsPage()),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: l.settingsGroupAbout,
                items: [
                  _VersionSettingsTile(
                    subtitle: packageInfo.when(
                      data: (info) =>
                          formatAppVersion(info.version, info.buildNumber),
                      loading: () => '读取中…',
                      error: (_, __) => '未知',
                    ),
                    title: l.settingsVersion,
                  ),
                  SettingsTile(
                    title: l.settingsLogout,
                    destructive: true,
                    leadingIcon: Icons.logout,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认退出登录'),
                          content: const Text(
                              '退出后将清理当前会话,下次启动需要重新登录;服务器地址会保留。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.danger,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('退出登录'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      if (!context.mounted) return;
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
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
}

class _VersionSettingsTile extends StatefulWidget {
  const _VersionSettingsTile({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<_VersionSettingsTile> createState() => _VersionSettingsTileState();
}

class _VersionSettingsTileState extends State<_VersionSettingsTile> {
  static const _requiredTaps = 5;
  static const _tapWindow = Duration(seconds: 2);

  int _tapCount = 0;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: widget.title,
      subtitle: widget.subtitle,
      leadingIcon: Icons.info_outline,
      showChevron: false,
      onTap: _handleTap,
    );
  }

  void _handleTap() {
    _resetTimer?.cancel();
    _tapCount++;

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AppUpdateSettingsPage(),
          ),
        ),
      );
      return;
    }

    _resetTimer = Timer(_tapWindow, () {
      _tapCount = 0;
    });
  }
}
