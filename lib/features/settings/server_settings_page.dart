import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../actor_associations/actor_associations_page.dart';
import '../configs/avdb_settings_page.dart';
import '../configs/dbo_settings_page.dart';
import '../configs/ffmpeg_settings_page.dart';
import '../configs/video_extensions_page.dart';
import '../libraries/libraries_page.dart';
import '../mappings/mapping_rules_page.dart';
import '../mappings/mappings_repository.dart';
import '../resources/resource_list_page.dart';
import '../resources/resources_repository.dart';
import '../translation/translation_settings_page.dart';
import 'server_setup_page.dart';
import 'settings_common.dart';

/// 服务器设置子页 · 凡是依赖服务端 API 的配置都放这里
class ServerSettingsPage extends ConsumerWidget {
  const ServerSettingsPage({super.key});

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
              SettingsSubPageHeader(
                eyebrow: l.settingsTitle,
                title: l.settingsServerSettings,
              ),
              SettingsGroup(
                title: l.settingsGroupServer,
                items: [
                  SettingsTile(
                    title: l.settingsServerUrl,
                    subtitle:
                        cfg?.baseUrl ?? l.settingsServerNotConfigured,
                    leadingIcon: Icons.dns_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ServerSetupPage()),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: l.settingsGroupLibrary,
                items: [
                  SettingsTile(
                    title: l.settingsLibraries,
                    subtitle: l.settingsLibrariesSub,
                    leadingIcon: Icons.video_library_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LibrariesPage()),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsGenres,
                    subtitle: 'Genres',
                    leadingIcon: Icons.category_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResourceListPage(
                          kind: ResourceKind.genre,
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsTags,
                    subtitle: 'Tags',
                    leadingIcon: Icons.label_outline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResourceListPage(
                          kind: ResourceKind.tag,
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsSeries,
                    subtitle: 'Series',
                    leadingIcon: Icons.collections_bookmark_outlined,
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
              SettingsGroup(
                title: l.settingsGroupSystem,
                items: [
                  SettingsTile(
                    title: l.settingsTranslation,
                    subtitle: l.settingsTranslationSub,
                    leadingIcon: Icons.translate_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TranslationSettingsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: l.settingsGroupMappings,
                items: [
                  SettingsTile(
                    title: l.settingsMappingTags,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.tag),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsMappingGenres,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.genre),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsMappingSeries,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.series),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsMappingActors,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MappingRulesPage(type: MappingType.actor),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsActorAssociations,
                    subtitle: l.settingsActorAssociationsSub,
                    leadingIcon: Icons.account_tree_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ActorAssociationsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: l.settingsGroupTools,
                items: [
                  SettingsTile(
                    title: 'DB Online 数据源',
                    subtitle: '影片信息、资源和演员关联',
                    leadingIcon: Icons.api_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DboSettingsPage(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: 'AVDB 数据源',
                    subtitle: '演员关联同步',
                    leadingIcon: Icons.cloud_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AvdbSettingsPage(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: 'FFmpeg 与硬解',
                    subtitle: '硬件解码、后端选择和失败回退',
                    leadingIcon: Icons.memory_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FfmpegSettingsPage(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsExtensions,
                    subtitle: l.settingsExtensionsSub,
                    leadingIcon: Icons.movie_filter_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VideoExtensionsPage(),
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
