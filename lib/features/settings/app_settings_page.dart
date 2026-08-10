import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/update/update_repository.dart';
import '../../shared/glow_background.dart';
import '../i18n/locale_providers.dart';
import '../i18n/theme_provider.dart';
import '../privacy/privacy_providers.dart';
import '../security/security_settings_page.dart';
import 'badge_position_page.dart';
import 'cache_management_page.dart';
import 'haptic_settings.dart';
import 'app_update_settings_page.dart';
import 'player_settings_page.dart';
import 'settings_common.dart';
import 'subtitle_settings_page.dart';

/// 应用设置子页 · 仅本地客户端偏好
class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final updateRepository = ref.watch(updateRepositoryUrlProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              SettingsSubPageHeader(
                eyebrow: l.settingsTitle,
                title: l.settingsAppSettings,
              ),
              SettingsGroup(
                title: l.settingsGroupPrivacy,
                items: [
                  const _PrivacyShieldTile(),
                  SettingsTile(
                    title: '安全设置',
                    subtitle: '面容/指纹、进入密码、手势密码',
                    leadingIcon: Icons.lock_outline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SecuritySettingsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '通用',
                items: [
                  const _LanguageTile(),
                  const _ThemeTile(),
                  const _HapticIntensityTile(),
                  SettingsTile(
                    title: '应用更新',
                    subtitle: updateRepository ?? '未配置 GitHub 地址',
                    leadingIcon: Icons.system_update_alt_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppUpdateSettingsPage(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsBadgePositions,
                    subtitle: l.settingsBadgePositionsSub,
                    leadingIcon: Icons.grid_view_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const BadgePositionPage()),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '播放器',
                items: [
                  SettingsTile(
                    title: '播放器设置',
                    subtitle: '播放进度 / 屏幕方向 / OSD / 播放按钮 / 手势反馈',
                    leadingIcon: Icons.play_circle_outline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlayerSettingsPage(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: '字幕设置',
                    subtitle: '记忆选择 / 字体 / 颜色 / 描边 / 阴影',
                    leadingIcon: Icons.subtitles_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubtitleSettingsPage(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: '缓存管理',
                    subtitle: '磁盘缓存额度 / 缓存分类 / 一键清理',
                    leadingIcon: Icons.cleaning_services_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CacheManagementPage(),
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
}

class _PrivacyShieldTile extends ConsumerWidget {
  const _PrivacyShieldTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final enabled = ref.watch(privacyShieldProvider);
    return SettingsTile(
      title: l.settingsPrivacyShield,
      subtitle: l.settingsPrivacyShieldSub,
      leadingIcon: Icons.shield_outlined,
      trailing: SettingsSwitch(
        value: enabled,
        onChanged: (v) =>
            ref.read(privacyShieldProvider.notifier).setEnabled(v),
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final current = ref.watch(localeProvider);
    return SettingsTile(
      title: l.settingsLanguage,
      subtitle: _labelOf(current, l),
      leadingIcon: Icons.language_outlined,
      onTap: () => _showSheet(context, ref, current),
    );
  }

  String _labelOf(AppLocale loc, AppL10n l) {
    switch (loc) {
      case AppLocale.system:
        return l.languageSystem;
      case AppLocale.zh:
        return l.languageZh;
      case AppLocale.en:
        return l.languageEn;
    }
  }

  Future<void> _showSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocale current,
  ) async {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final picked = await showModalBottomSheet<AppLocale>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Row(children: [
                  Text(l.settingsLanguage, style: AppText.sectionTitle(ctx)),
                ]),
              ),
              for (final loc in AppLocale.values)
                ListTile(
                  title: Text(
                    _labelOf(loc, l),
                    style: AppText.body(ctx).copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: loc == current
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, loc),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != current) {
      AppHaptics.selection();
      await ref.read(localeProvider.notifier).set(picked);
    }
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final current = ref.watch(themeModeProvider);
    return SettingsTile(
      title: l.settingsTheme,
      subtitle: _labelOf(current, l),
      leadingIcon: _iconOf(current),
      onTap: () => _showSheet(context, ref, current),
    );
  }

  IconData _iconOf(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }

  String _labelOf(AppThemeMode m, AppL10n l) {
    switch (m) {
      case AppThemeMode.system:
        return l.themeSystem;
      case AppThemeMode.light:
        return l.themeLight;
      case AppThemeMode.dark:
        return l.themeDark;
    }
  }

  Future<void> _showSheet(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) async {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Row(children: [
                  Text(l.settingsTheme, style: AppText.sectionTitle(ctx)),
                ]),
              ),
              for (final m in AppThemeMode.values)
                ListTile(
                  leading: Icon(_iconOf(m), color: c.muted, size: 20),
                  title: Text(
                    _labelOf(m, l),
                    style: AppText.body(ctx).copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: m == current
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, m),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != current) {
      AppHaptics.selection();
      await ref.read(themeModeProvider.notifier).set(picked);
    }
  }
}

class _HapticIntensityTile extends ConsumerWidget {
  const _HapticIntensityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(hapticIntensityProvider);
    return SettingsTile(
      title: '震动反馈强度',
      subtitle: current.label,
      leadingIcon: Icons.vibration,
      onTap: () => _showSheet(context, ref, current),
    );
  }

  Future<void> _showSheet(
    BuildContext context,
    WidgetRef ref,
    HapticIntensity current,
  ) async {
    final c = appColors(context);
    final picked = await showModalBottomSheet<HapticIntensity>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Row(
                  children: [
                    Text('震动反馈强度', style: AppText.sectionTitle(ctx)),
                  ],
                ),
              ),
              for (final intensity in HapticIntensity.values)
                ListTile(
                  leading: Icon(Icons.vibration, color: c.muted, size: 20),
                  title: Text(
                    intensity.label,
                    style: AppText.body(ctx).copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: intensity == current
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, intensity),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != current) {
      await ref.read(hapticIntensityProvider.notifier).set(picked);
      AppHaptics.selection();
    }
  }
}
