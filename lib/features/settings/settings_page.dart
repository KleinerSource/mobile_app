import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../configs/dbo_settings_page.dart';
import '../configs/video_extensions_page.dart';
import '../i18n/locale_providers.dart';
import '../libraries/libraries_page.dart';
import '../mappings/mapping_rules_page.dart';
import '../mappings/mappings_repository.dart';
import '../privacy/privacy_providers.dart';
import '../resources/resource_list_page.dart';
import '../resources/resources_repository.dart';
import '../translation/translation_settings_page.dart';
import 'server_setup_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    final c = appColors(context);
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.settingsTitle.toUpperCase(), style: AppText.eyebrow(context)),
                          const SizedBox(height: 3),
                          Text(l.settingsPreferences, style: AppText.pageTitle(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _SettingsGroup(
                title: l.settingsGroupServer,
                items: [
                  _SettingsTile(
                    title: l.settingsServerUrl,
                    subtitle: cfg?.baseUrl ?? l.settingsServerNotConfigured,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ServerSetupPage()),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: l.settingsGroupLibrary,
                items: [
                  _SettingsTile(
                    title: l.settingsLibraries,
                    subtitle: l.settingsLibrariesSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LibrariesPage()),
                    ),
                  ),
                  _SettingsTile(
                    title: l.settingsGenres,
                    subtitle: 'Genres',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResourceListPage(
                          kind: ResourceKind.genre,
                        ),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: l.settingsTags,
                    subtitle: 'Tags',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResourceListPage(
                          kind: ResourceKind.tag,
                        ),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: l.settingsSeries,
                    subtitle: 'Series',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResourceListPage(
                          kind: ResourceKind.series,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: l.settingsGroupPrivacy,
                items: [
                  _PrivacyShieldTile(),
                  const _LanguageTile(),
                ],
              ),
              _SettingsGroup(
                title: l.settingsGroupSystem,
                items: [
                  _SettingsTile(
                    title: l.settingsTranslation,
                    subtitle: l.settingsTranslationSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TranslationSettingsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: l.settingsGroupMappings,
                items: [
                  _SettingsTile(
                    title: l.settingsMappingTags,
                    subtitle: l.settingsMappingSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.tag),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: l.settingsMappingGenres,
                    subtitle: l.settingsMappingSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.genre),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: l.settingsMappingSeries,
                    subtitle: l.settingsMappingSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.series),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: l.settingsMappingActors,
                    subtitle: l.settingsMappingSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.actor),
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: l.settingsGroupTools,
                items: [
                  _SettingsTile(
                    title: l.settingsDbo,
                    subtitle: l.settingsDboSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DboSettingsPage(),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: l.settingsExtensions,
                    subtitle: l.settingsExtensionsSub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VideoExtensionsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: l.settingsGroupAbout,
                items: [
                  _SettingsTile(
                    title: l.settingsVersion,
                    subtitle: '0.1.0',
                  ),
                  _SettingsTile(
                    title: l.settingsLogout,
                    destructive: true,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认退出登录'),
                          content: const Text(
                              '退出后将断开与当前服务器的连接,下次启动需要重新配置服务器地址。'),
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
                      await ref.read(serverConfigProvider.notifier).clear();
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 10),
            child: Text(title.toUpperCase(), style: AppText.eyebrow(context)),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.cardBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: c.divider),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive ? c.danger : c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.meta(context)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null && !destructive)
              Icon(Icons.chevron_right, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// 隐私遮罩开关 · 监听并写入 SharedPreferences
class _PrivacyShieldTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final enabled = ref.watch(privacyShieldProvider);
    return _SettingsTile(
      title: l.settingsPrivacyShield,
      subtitle: l.settingsPrivacyShieldSub,
      trailing: Switch(
        value: enabled,
        onChanged: (v) =>
            ref.read(privacyShieldProvider.notifier).setEnabled(v),
      ),
    );
  }
}

/// 语言选择条目 · 底部 sheet 选 system/zh/en
class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final current = ref.watch(localeProvider);
    return _SettingsTile(
      title: l.settingsLanguage,
      subtitle: _labelOf(current, l),
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
      backgroundColor: c.bg,
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
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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
    if (picked != null) {
      await ref.read(localeProvider.notifier).set(picked);
    }
  }
}
