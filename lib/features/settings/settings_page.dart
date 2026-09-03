import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/platform/app_version.dart';
import '../../core/update/update_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/floating_tab_bar.dart';
import '../../shared/glow_background.dart';
import 'app_settings_page.dart';
import 'app_update_settings_page.dart';
import 'app_update_startup_gate.dart';
import 'server_list_page.dart';
import 'server_settings_page.dart';
import 'server_setup_page.dart';
import 'settings_common.dart';

/// 设置主入口 · 服务器、应用与关于入口
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.forFileManager = false});

  final bool forFileManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final serverConfig = ref.watch(serverConfigProvider);
    final packageInfo = ref.watch(appPackageInfoProvider);
    final updateRepository = ref.watch(updateRepositoryUrlProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsTitle,
              title: l.settingsPreferences,
            ),
            body: ListView(
              primary: true,
              children: [
                SettingsGroup(
                  title: l.settingsPreferences,
                  items: [
                    SettingsTile(
                      title: l.settingsServerList,
                      subtitle: serverConfig == null
                          ? l.settingsServerNotConfigured
                          : l.settingsServerListSub(
                              serverConfig.servers.length,
                            ),
                      leadingIcon: Icons.dns_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => serverConfig == null
                              ? const ServerSetupPage()
                              : const ServerListPage(),
                        ),
                      ),
                    ),
                    if (!forFileManager &&
                        serverConfig?.activeServer?.project?.isFileSource !=
                            true)
                      SettingsTile(
                        title: l.settingsServerSettings,
                        subtitle: l.settingsServerSettingsSub,
                        leadingIcon: Icons.dns_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ServerSettingsPage(),
                          ),
                        ),
                      ),
                    SettingsTile(
                      title: l.settingsAppSettings,
                      subtitle: l.settingsAppSettingsSub,
                      leadingIcon: Icons.tune_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AppSettingsPage(),
                        ),
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
                        loading: () => l.commonLoading,
                        error: (_, __) => l.commonUnknown,
                      ),
                      title: l.settingsVersion,
                      hasUpdateSource: updateRepository != null,
                      onCheckForUpdates: () {
                        if (updateRepository == null) {
                          unawaited(
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AppUpdateSettingsPage(),
                              ),
                            ),
                          );
                          return;
                        }
                        checkConfiguredAppUpdate(
                          context: context,
                          ref: ref,
                          showLatestMessage: true,
                        ).ignore();
                      },
                    ),
                    if (!forFileManager)
                      SettingsTile(
                        title: l.settingsLogout,
                        destructive: true,
                        leadingIcon: Icons.logout,
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l.settingsLogoutConfirmTitle),
                              content: Text(l.settingsLogoutConfirmBody),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: c.danger,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(l.settingsLogout),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          if (!context.mounted) return;
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                      ),
                  ],
                ),
                SizedBox(
                  height: forFileManager
                      ? floatingTabBarContentBottomInset(context)
                      : 80,
                ),
              ],
            ),
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
    required this.hasUpdateSource,
    required this.onCheckForUpdates,
  });

  final String title;
  final String subtitle;
  final bool hasUpdateSource;
  final VoidCallback onCheckForUpdates;

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
    final l = AppL10n.of(context);
    return SettingsTile(
      title: widget.title,
      subtitle: widget.subtitle,
      leadingIcon: Icons.info_outline,
      showChevron: false,
      trailing: widget.hasUpdateSource
          ? TextButton.icon(
              onPressed: () {
                AppHaptics.selection();
                widget.onCheckForUpdates();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l.settingsCheckForUpdates),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            )
          : null,
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
          MaterialPageRoute(builder: (_) => const AppUpdateSettingsPage()),
        ),
      );
      return;
    }

    _resetTimer = Timer(_tapWindow, () {
      _tapCount = 0;
    });
  }
}
