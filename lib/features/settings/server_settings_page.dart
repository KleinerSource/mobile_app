import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../actor_associations/actor_associations_page.dart';
import '../actors/actor_management_page.dart';
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
import 'access_control_page.dart';
import 'server_list_page.dart';
import 'server_setup_page.dart';
import 'settings_common.dart';

/// 服务器设置子页 · 依赖服务端 API 的配置按业务职责分组。
class ServerSettingsPage extends ConsumerWidget {
  const ServerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
                eyebrow: l.settingsTitle,
                title: l.settingsServerSettings,
              ),
            body: ListView(
              primary: true,
              children: [
              SettingsGroup(
                title: l.settingsGroupServer,
                items: [
                  SettingsTile(
                    title: '服务器列表',
                    subtitle: cfg == null
                        ? l.settingsServerNotConfigured
                        : '${cfg.servers.length} 台服务器 · 可分别配置线路',
                    leadingIcon: Icons.dns_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => cfg == null
                            ? const ServerSetupPage()
                            : const ServerListPage(),
                      ),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: l.settingsGroupSystem,
                items: [
                  SettingsTile(
                    title: '访问控制',
                    subtitle: '登录密码、会话策略与 TOTP',
                    leadingIcon: Icons.shield_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccessControlPage(),
                      ),
                    ),
                  ),
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
                title: l.settingsGroupLibrary,
                items: [
                  SettingsTile(
                    title: l.settingsLibraries,
                    subtitle: l.settingsLibrariesSub,
                    leadingIcon: Icons.video_library_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LibrariesPage(),
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
                  SettingsTile(
                    title: l.settingsActors,
                    subtitle: l.settingsActorsSub,
                    leadingIcon: Icons.people_outline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ActorManagementPage(),
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
                title: l.settingsGroupMappings,
                items: [
                  SettingsTile(
                    title: l.settingsMappingTags,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MappingRulesPage(
                          type: MappingType.tag,
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsMappingGenres,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MappingRulesPage(
                          type: MappingType.genre,
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsMappingSeries,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MappingRulesPage(
                          type: MappingType.series,
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    title: l.settingsMappingActors,
                    subtitle: l.settingsMappingSub,
                    leadingIcon: Icons.swap_horiz,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MappingRulesPage(
                          type: MappingType.actor,
                        ),
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
                    title: '转码',
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
      ),
    );
  }
}
