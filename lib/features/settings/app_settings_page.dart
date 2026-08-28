import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/sheet_controls.dart';
import '../i18n/locale_providers.dart';
import '../i18n/theme_provider.dart';
import '../privacy/privacy_providers.dart';
import '../security/security_settings_page.dart';
import '../files/file_image_preview_settings.dart';
import 'badge_position_page.dart';
import 'cache_management_page.dart';
import 'haptic_settings.dart';
import 'player_settings_page.dart';
import 'poster_badge_display_page.dart';
import 'settings_common.dart';
import 'subtitle_settings_page.dart';

/// 应用设置子页 · 仅本地客户端偏好
class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsTitle,
              title: l.settingsAppSettings,
            ),
            body: ListView(
              primary: true,
              children: [
                SettingsGroup(
                  title: l.settingsGroupPrivacy,
                  items: [
                    const _PrivacyShieldTile(),
                    const _ShakePrivacyTile(),
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
                      title: l.settingsBadgePositions,
                      subtitle: l.settingsBadgePositionsSub,
                      leadingIcon: Icons.grid_view_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BadgePositionPage(),
                        ),
                      ),
                    ),
                    SettingsTile(
                      title: '海报角标显示',
                      subtitle: '编码 / HDR / STRM / 字幕 / 破解 / HD',
                      leadingIcon: Icons.local_offer_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PosterBadgeDisplayPage(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SettingsGroup(
                  title: '文件管理器',
                  items: [_FileImagePreviewTile()],
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

class _ShakePrivacyTile extends ConsumerWidget {
  const _ShakePrivacyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final enabled = ref.watch(privacyShakeProvider);
    return SettingsTile(
      title: l.settingsShakePrivacy,
      subtitle: l.settingsShakePrivacySub,
      leadingIcon: Icons.vibration,
      trailing: SettingsSwitch(
        value: enabled,
        onChanged: (v) => ref.read(privacyShakeProvider.notifier).setEnabled(v),
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
    final picked = await showGlassSheet<AppLocale>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.language_outlined,
                title: l.settingsLanguage,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              ),
              for (final loc in AppLocale.values)
                ListTile(
                  title: Text(
                    _labelOf(loc, l),
                    style: AppText.body(
                      ctx,
                    ).copyWith(color: c.text, fontWeight: FontWeight.w700),
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
    final picked = await showGlassSheet<AppThemeMode>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.tune_rounded,
                title: l.settingsTheme,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              ),
              for (final m in AppThemeMode.values)
                ListTile(
                  leading: Icon(_iconOf(m), color: c.muted, size: 20),
                  title: Text(
                    _labelOf(m, l),
                    style: AppText.body(
                      ctx,
                    ).copyWith(color: c.text, fontWeight: FontWeight.w700),
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
      subtitle: '当前：${current.label}',
      leadingIcon: Icons.vibration,
      trailing: SizedBox(
        width: 178,
        child: _HapticIntensitySlider(
          value: current,
          onChanged: (value) {
            final intensity = HapticIntensity.values[value.round()];
            unawaited(
              ref.read(hapticIntensityProvider.notifier).set(intensity),
            );
          },
        ),
      ),
    );
  }
}

class _FileImagePreviewTile extends ConsumerWidget {
  const _FileImagePreviewTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(fileImagePreviewProvider);
    return SettingsTile(
      title: '图片预览',
      subtitle: '在文件列表中显示图片缩略图',
      leadingIcon: Icons.image_outlined,
      trailing: SettingsSwitch(
        value: enabled,
        onChanged: (value) =>
            ref.read(fileImagePreviewProvider.notifier).setEnabled(value),
      ),
    );
  }
}

class _HapticIntensitySlider extends StatelessWidget {
  const _HapticIntensitySlider({required this.value, required this.onChanged});

  final HapticIntensity value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final intensities = HapticIntensity.values;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HapticSlider(
          value: value.index.toDouble(),
          min: 0,
          max: (intensities.length - 1).toDouble(),
          divisions: intensities.length - 1,
          label: value.label,
          onChanged: onChanged,
        ),
        Row(
          children: [
            for (var i = 0; i < intensities.length; i++)
              Expanded(
                child: Text(
                  intensities[i].label,
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == intensities.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  style: AppText.meta(context).copyWith(
                    color: intensities[i] == value ? c.accent : c.muted,
                    fontWeight: intensities[i] == value
                        ? FontWeight.w800
                        : FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
