import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import 'package:omm/features/oh_my_media/actor_associations/actor_associations_page.dart';
import 'package:omm/features/oh_my_media/actors/actor_management_page.dart';
import 'package:omm/features/oh_my_media/audio/audio_management_page.dart';
import 'package:omm/features/oh_my_media/configs/avdb_settings_page.dart';
import 'package:omm/features/oh_my_media/configs/dbo_settings_page.dart';
import 'package:omm/features/oh_my_media/configs/ffmpeg_settings_page.dart';
import 'package:omm/features/oh_my_media/configs/video_extensions_page.dart';
import 'package:omm/features/db_online/settings/db_online_backend_settings_page.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_page.dart';
import 'package:omm/features/oh_my_media/mappings/mapping_rules_page.dart';
import 'package:omm/features/oh_my_media/mappings/mappings_repository.dart';
import 'package:omm/features/oh_my_media/resources/resource_list_page.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'package:omm/features/media_browser/pages/media_browser_library_settings_page.dart';
import '../translation/translation_settings_page.dart';
import '../translation/modal_transcription_settings_page.dart';
import 'access_control_page.dart';
import 'settings_common.dart';

/// 服务器设置子页 · 依赖服务端 API 的配置按业务职责分组。
class ServerSettingsPage extends ConsumerWidget {
  const ServerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    final l = AppL10n.of(context);
    final project = cfg?.activeServer?.project;
    final dbOnline = project == ServerProject.dbOnline;
    // Emby/Jellyfin/飞牛影视的服务端设置（转码、字幕等）在其网页控制台管理，App 内
    // 不重复实现这些入口。
    final externalMediaServer =
        project == ServerProject.emby ||
        project == ServerProject.jellyfin ||
        project == ServerProject.feiniu;
    final managedMediaServer =
        project == ServerProject.emby ||
        project == ServerProject.jellyfin ||
        project == ServerProject.feiniu;

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
                if (managedMediaServer)
                  SettingsGroup(
                    title: l.settingsGroupLibrary,
                    items: [
                      SettingsTile(
                        title: l.settingsLibraries,
                        subtitle: l.settingsLibrariesSub,
                        leadingIcon: Icons.video_library_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const MediaBrowserLibrarySettingsPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (dbOnline) const DboBackendSettingsContent(),
                if (!dbOnline && !externalMediaServer)
                  SettingsGroup(
                    title: l.settingsGroupSystem,
                    items: [
                      SettingsTile(
                        title: l.accessControlTitle,
                        subtitle: l.serverSettingsAccessSub,
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
                      SettingsTile(
                        title: l.serverSettingsModalTranscription,
                        subtitle: l.serverSettingsModalTranscriptionSub,
                        leadingIcon: Icons.cloud_sync_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ModalTranscriptionSettingsPage(),
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: l.serverSettingsTranscoding,
                        subtitle: l.serverSettingsTranscodingSub,
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
                if (!dbOnline && !externalMediaServer)
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
                        title: l.settingsAudioManagement,
                        subtitle: l.serverSettingsAudioSub,
                        leadingIcon: Icons.graphic_eq_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AudioManagementPage(),
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: l.settingsTags,
                        subtitle: l.settingsTags,
                        leadingIcon: Icons.label_outline,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ResourceListPage(kind: ResourceKind.tag),
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: l.settingsGenres,
                        subtitle: l.settingsGenres,
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
                        subtitle: l.settingsSeries,
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
                if (!dbOnline && !externalMediaServer)
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
                            builder: (_) => const MappingRulesPage(
                              type: MappingType.series,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (!dbOnline && !externalMediaServer)
                  SettingsGroup(
                    title: l.settingsGroupTools,
                    items: [
                      SettingsTile(
                        title: l.settingsDbo,
                        subtitle: l.serverSettingsDboSub,
                        leadingIcon: Icons.api_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DboSettingsPage(),
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: l.serverSettingsAvdb,
                        subtitle: l.serverSettingsAvdbSub,
                        leadingIcon: Icons.cloud_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AvdbSettingsPage(),
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
