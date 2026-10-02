import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// DBO 后台配置的状态：读取完整配置，保存时只提交当前编辑的顶层分区。
final dbOnlineBackendConfigProvider =
    AsyncNotifierProvider<
      DbOnlineBackendConfigController,
      Map<String, dynamic>
    >(DbOnlineBackendConfigController.new);

class DbOnlineBackendConfigController
    extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() {
    return ref.watch(requiredApiClientProvider).dbOnline.getBackendConfig();
  }

  Future<void> save(Map<String, dynamic> partial) async {
    final client = ref.read(requiredApiClientProvider);
    final saved = await client.dbOnline.updateBackendConfig(partial);
    if (ref.mounted && identical(ref.read(requiredApiClientProvider), client)) {
      state = AsyncData(saved);
    }
  }

  Future<Map<String, dynamic>> testConnection(
    String name,
    Map<String, dynamic> section,
  ) {
    return ref
        .read(requiredApiClientProvider)
        .dbOnline
        .testBackendConnection(name, section);
  }
}

enum DboBackendConfigFieldType {
  toggle,
  text,
  password,
  number,
  select,
  directory,
  toolPaths,
  libraries,
  multiSelect,
  lines,
  commaList,
  schedule,
}

class DboBackendConfigOption {
  const DboBackendConfigOption({required this.value, required this.label});

  final String value;
  final String Function(AppL10n l) label;
}

class DboBackendConfigField {
  const DboBackendConfigField({
    required this.path,
    required this.label,
    required this.type,
    this.hint,
    this.options,
    this.visibleWhen,
  });

  final String path;
  final String Function(AppL10n l) label;
  final DboBackendConfigFieldType type;
  final String Function(AppL10n l)? hint;
  final List<DboBackendConfigOption>? options;
  final bool Function(Map<String, dynamic> values)? visibleWhen;
}

class DboBackendConfigSection {
  const DboBackendConfigSection({
    required this.title,
    required this.basePath,
    required this.fields,
    this.testName,
    this.defaults = const {},
  });

  final String Function(AppL10n l) title;
  final String basePath;
  final List<DboBackendConfigField> fields;
  final String? testName;
  final Map<String, dynamic> defaults;
}

class DboBackendConfigGroup {
  const DboBackendConfigGroup(this.title, this.sections);

  final String Function(AppL10n l) title;
  final List<DboBackendConfigSection> sections;
}

final _imageModes = <DboBackendConfigOption>[
  DboBackendConfigOption(
    value: 'replace',
    label: (l) => l.dbOnlineImageModeReplace,
  ),
  DboBackendConfigOption(
    value: 'decrypt',
    label: (l) => l.dbOnlineImageModeDecrypt,
  ),
];

bool _isImageReplace(Map<String, dynamic> values) =>
    values['image_mode'] == 'replace';

bool _isRetryEnabled(Map<String, dynamic> values) =>
    values['enable_retry'] == true;

final _javdbApiSection = DboBackendConfigSection(
  title: (l) => 'JavDB API',
  basePath: 'javdb_api',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'host',
      label: (l) => l.dbOnlineFieldApiUrl,
      type: DboBackendConfigFieldType.text,
      hint: (l) => l.dbOnlineFieldApiUrlHint,
    ),
    DboBackendConfigField(
      path: 'authorization',
      label: (l) => l.dbOnlineFieldAuthorization,
      type: DboBackendConfigFieldType.password,
      hint: (l) => l.dbOnlineFieldOptionalMaskHint,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldRequestTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'image_mode',
      label: (l) => l.dbOnlineFieldImageMode,
      type: DboBackendConfigFieldType.select,
      options: _imageModes,
    ),
    DboBackendConfigField(
      path: 'url_replace_new',
      label: (l) => l.dbOnlineFieldImageUrlReplacePrefix,
      type: DboBackendConfigFieldType.text,
      hint: (l) => l.dbOnlineFieldImageUrlReplacePrefixHint,
      visibleWhen: _isImageReplace,
    ),
  ],
);

final _subscriptionSection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionSubscription,
  basePath: 'subscription',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnableSubscription,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'check_interval',
      label: (l) => l.dbOnlineFieldCheckIntervalMinutes,
      type: DboBackendConfigFieldType.number,
      hint: (l) => l.dbOnlineFieldCheckIntervalHint,
    ),
    DboBackendConfigField(
      path: 'concurrency',
      label: (l) => l.dbOnlineFieldConcurrency,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'request_timeout',
      label: (l) => l.dbOnlineFieldRequestTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'interval_range',
      label: (l) => l.dbOnlineFieldIntervalRangeSeconds,
      type: DboBackendConfigFieldType.text,
      hint: (l) => l.dbOnlineFieldIntervalRangeHint,
    ),
    DboBackendConfigField(
      path: 'enable_retry',
      label: (l) => l.dbOnlineFieldEnableRetry,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'retry_count',
      label: (l) => l.dbOnlineFieldRetryCount,
      type: DboBackendConfigFieldType.number,
      visibleWhen: _isRetryEnabled,
    ),
    DboBackendConfigField(
      path: 'retry_interval',
      label: (l) => l.dbOnlineFieldRetryIntervalSeconds,
      type: DboBackendConfigFieldType.number,
      visibleWhen: _isRetryEnabled,
    ),
  ],
);

final _proxySection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionProxy,
  basePath: 'proxy.main',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnableProxy,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'protocol',
      label: (l) => l.dbOnlineFieldProtocol,
      type: DboBackendConfigFieldType.select,
      options: <DboBackendConfigOption>[
        DboBackendConfigOption(value: 'http', label: (l) => 'HTTP'),
        DboBackendConfigOption(value: 'https', label: (l) => 'HTTPS'),
        DboBackendConfigOption(value: 'socks5', label: (l) => 'SOCKS5'),
      ],
    ),
    DboBackendConfigField(
      path: 'host',
      label: (l) => l.dbOnlineFieldHost,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: (l) => l.dbOnlineFieldPort,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'username',
      label: (l) => l.dbOnlineFieldUsernameOptional,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'password',
      label: (l) => l.dbOnlineFieldPasswordOptional,
      type: DboBackendConfigFieldType.password,
      hint: (l) => l.dbOnlineFieldMaskHint,
    ),
  ],
);

final _aria2Section = DboBackendConfigSection(
  title: (l) => 'Aria2',
  basePath: 'downloader.aria2',
  testName: 'aria2',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnabled,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: (l) => l.dbOnlineFieldHost,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: (l) => l.dbOnlineFieldPort,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'use_https',
      label: (l) => l.dbOnlineFieldUseHttps,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'secret',
      label: (l) => l.dbOnlineFieldRpcSecret,
      type: DboBackendConfigFieldType.password,
      hint: (l) => l.dbOnlineFieldMaskHint,
    ),
    DboBackendConfigField(
      path: 'save_path',
      label: (l) => l.dbOnlineFieldSavePath,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

final _qbittorrentSection = DboBackendConfigSection(
  title: (l) => 'qBittorrent',
  basePath: 'downloader.qbittorrent',
  testName: 'qbittorrent',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnabled,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: (l) => l.dbOnlineFieldHost,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: (l) => l.dbOnlineFieldPort,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'use_https',
      label: (l) => l.dbOnlineFieldUseHttps,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'username',
      label: (l) => l.dbOnlineFieldUsername,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'password',
      label: (l) => l.dbOnlineFieldPassword,
      type: DboBackendConfigFieldType.password,
      hint: (l) => l.dbOnlineFieldMaskHint,
    ),
    DboBackendConfigField(
      path: 'category',
      label: (l) => l.dbOnlineFieldCategoryOptional,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'save_path',
      label: (l) => l.dbOnlineFieldSavePath,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

final _pan115Section = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionPan115,
  basePath: 'downloader.pan115',
  testName: 'pan115',
  defaults: const {'cid': '0', 'timeout': 30, 'reserve_quota': 0},
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnabled,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'cookie',
      label: (l) => l.dbOnlineFieldCookie,
      type: DboBackendConfigFieldType.password,
      hint: (l) => l.dbOnlineFieldMaskHint,
    ),
    DboBackendConfigField(
      path: 'cid',
      label: (l) => l.dbOnlineDownloaderDirectory,
      type: DboBackendConfigFieldType.directory,
    ),
    DboBackendConfigField(
      path: 'reserve_quota',
      label: (l) => l.dbOnlineFieldReserveQuota,
      type: DboBackendConfigFieldType.number,
      hint: (l) => l.dbOnlineReserveQuotaHint,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

final _thunderSection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionThunder,
  basePath: 'downloader.thunder',
  testName: 'thunder',
  defaults: const {'port': 6984, 'timeout': 30},
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnabled,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: (l) => l.dbOnlineFieldHost,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: (l) => l.dbOnlineFieldPort,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'use_https',
      label: (l) => l.dbOnlineFieldUseHttps,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'device_target',
      label: (l) => l.dbOnlineThunderDeviceDirectory,
      type: DboBackendConfigFieldType.directory,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

final _openListSection = DboBackendConfigSection(
  title: (l) => 'OpenList',
  basePath: 'downloader.openlist',
  testName: 'openlist',
  defaults: const {
    'port': 5244,
    'timeout': 30,
    'delete_policy': 'delete_on_upload_succeed',
    'tool_path_suffixes': <String, String>{},
  },
  fields: [
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnabled,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: (l) => l.dbOnlineFieldHost,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: (l) => l.dbOnlineFieldPort,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'use_https',
      label: (l) => l.dbOnlineFieldUseHttps,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'token',
      label: (l) => l.dbOnlineFieldToken,
      type: DboBackendConfigFieldType.password,
      hint: (l) => l.dbOnlineFieldMaskHint,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'delete_policy',
      label: (l) => l.dbOnlineDeletePolicy,
      type: DboBackendConfigFieldType.select,
      options: [
        DboBackendConfigOption(
          value: 'delete_on_upload_succeed',
          label: (l) => l.dbOnlineDeleteOnSuccess,
        ),
        DboBackendConfigOption(
          value: 'delete_on_upload_failed',
          label: (l) => l.dbOnlineDeleteOnFailure,
        ),
        DboBackendConfigOption(
          value: 'delete_never',
          label: (l) => l.dbOnlineDeleteNever,
        ),
        DboBackendConfigOption(
          value: 'delete_always',
          label: (l) => l.dbOnlineDeleteAlways,
        ),
      ],
    ),
    DboBackendConfigField(
      path: 'tool_path_suffixes',
      label: (l) => l.dbOnlineOpenListToolPaths,
      type: DboBackendConfigFieldType.toolPaths,
    ),
  ],
);

final _cloudDrive2Section = DboBackendConfigSection(
  title: (l) => 'CloudDrive2',
  basePath: 'downloader.clouddrive2',
  testName: 'clouddrive2',
  defaults: const {'port': 19798, 'timeout': 30, 'ed2k_enabled': false},
  fields: [
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnabled,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: (l) => l.dbOnlineFieldHost,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: (l) => l.dbOnlineFieldPort,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'ed2k_enabled',
      label: (l) => l.dbOnlineCloudDriveEd2k,
      hint: (l) => l.dbOnlineCloudDriveEd2kHint,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'token',
      label: (l) => l.dbOnlineFieldToken,
      type: DboBackendConfigFieldType.password,
      hint: (l) => l.dbOnlineFieldMaskHint,
    ),
    DboBackendConfigField(
      path: 'save_path',
      label: (l) => l.dbOnlineFieldSavePath,
      hint: (l) =>
          '${l.dbOnlineDownloaderPathVariables}\n{release_date} · {publish_date} · {actor_name} · {sub_name}',
      type: DboBackendConfigFieldType.text,
    ),
  ],
);

final _experimentalSection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionExperimental,
  basePath: 'experimental',
  fields: [
    DboBackendConfigField(
      path: 'auto_sync_watched_online',
      label: (l) => l.dbOnlineExperimentalWatched,
      hint: (l) => l.dbOnlineExperimentalWatchedHint,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'auto_sync_want_watch_online',
      label: (l) => l.dbOnlineExperimentalWantWatch,
      hint: (l) => l.dbOnlineExperimentalWantWatchHint,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'auto_sync_cancel_want_watch_online',
      label: (l) => l.dbOnlineExperimentalCancelWantWatch,
      hint: (l) => l.dbOnlineExperimentalCancelWantWatchHint,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'webhook_cancel_subscription_on_delete',
      label: (l) => l.dbOnlineExperimentalCancelSubscription,
      hint: (l) => l.dbOnlineExperimentalCancelSubscriptionHint,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'webhook_auto_blacklist_on_delete',
      label: (l) => l.dbOnlineExperimentalBlacklist,
      hint: (l) => l.dbOnlineExperimentalBlacklistHint,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'builtin_magnets_in_subscription',
      label: (l) => l.dbOnlineExperimentalBuiltinMagnets,
      hint: (l) => l.dbOnlineExperimentalBuiltinMagnetsHint,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'fetch_video_overview',
      label: (l) => l.dbOnlineExperimentalOverview,
      hint: (l) => l.dbOnlineExperimentalOverviewHint,
      type: DboBackendConfigFieldType.toggle,
    ),
  ],
);

DboBackendConfigSection _mediaServerSection(String name) =>
    DboBackendConfigSection(
      title: (l) => name == 'fnmedia'
          ? l.dbOnlineSectionFnMedia
          : (name == 'emby' ? 'Emby' : 'Jellyfin'),
      basePath: 'mediaserver.$name',
      testName: name,
      defaults: {
        'enabled': false,
        'port': name == 'fnmedia' ? 5666 : 8096,
        'use_https': false,
        'timeout': 30,
        'library_ids': <String>[],
      },
      fields: [
        DboBackendConfigField(
          path: 'enabled',
          label: (l) => l.dbOnlineFieldEnabled,
          type: DboBackendConfigFieldType.toggle,
        ),
        DboBackendConfigField(
          path: 'host',
          label: (l) => l.dbOnlineFieldHost,
          type: DboBackendConfigFieldType.text,
        ),
        DboBackendConfigField(
          path: 'port',
          label: (l) => l.dbOnlineFieldPort,
          type: DboBackendConfigFieldType.number,
        ),
        DboBackendConfigField(
          path: 'timeout',
          label: (l) => l.dbOnlineFieldTimeoutSeconds,
          type: DboBackendConfigFieldType.number,
        ),
        DboBackendConfigField(
          path: 'use_https',
          label: (l) => l.dbOnlineFieldUseHttps,
          type: DboBackendConfigFieldType.toggle,
        ),
        if (name == 'fnmedia') ...[
          DboBackendConfigField(
            path: 'username',
            label: (l) => l.dbOnlineFieldUsername,
            type: DboBackendConfigFieldType.text,
          ),
          DboBackendConfigField(
            path: 'password',
            label: (l) => l.dbOnlineFieldPassword,
            type: DboBackendConfigFieldType.password,
          ),
        ] else
          DboBackendConfigField(
            path: 'api_key',
            label: (l) => 'API Key',
            type: DboBackendConfigFieldType.password,
          ),
        DboBackendConfigField(
          path: 'library_ids',
          label: (l) => l.dbOnlineMediaLibraries,
          hint: (l) => l.dbOnlineMediaLibrariesHint,
          type: DboBackendConfigFieldType.libraries,
        ),
      ],
    );

final _libraryCacheSection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionLibraryCache,
  basePath: 'mediaserver',
  defaults: const {'library_cache_schedule': '30 0 * * *'},
  fields: [
    DboBackendConfigField(
      path: 'library_cache_schedule',
      label: (l) => l.dbOnlineCacheSchedule,
      hint: (l) => l.dbOnlineCacheScheduleHint,
      type: DboBackendConfigFieldType.schedule,
      options: [
        DboBackendConfigOption(
          value: '30 0 * * *',
          label: (l) => l.dbOnlineCronDaily0030,
        ),
        DboBackendConfigOption(
          value: '20 1 * * *',
          label: (l) => l.dbOnlineCronDaily0120,
        ),
        DboBackendConfigOption(
          value: '0 2 * * 0',
          label: (l) => l.dbOnlineCronWeekly,
        ),
        DboBackendConfigOption(
          value: '0 23 2 * *',
          label: (l) => l.dbOnlineCronMonthly,
        ),
        DboBackendConfigOption(
          value: '0 */6 * * *',
          label: (l) => l.dbOnlineCronEvery6Hours,
        ),
        DboBackendConfigOption(
          value: '0 */12 * * *',
          label: (l) => l.dbOnlineCronEvery12Hours,
        ),
      ],
    ),
  ],
);

final _subtitleSection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionSubtitleSettings,
  basePath: 'subtitle',
  defaults: const {
    'enabled': false,
    'directories': <String>[],
    'extensions': ['.srt', '.ass', '.ssa', '.sub', '.idx', '.vtt'],
    'scan_interval': 0,
  },
  fields: [
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnabled,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'directories',
      label: (l) => l.dbOnlineSubtitleDirectories,
      hint: (l) => l.dbOnlineSubtitleDirectoriesHint,
      type: DboBackendConfigFieldType.lines,
    ),
    DboBackendConfigField(
      path: 'scan_interval',
      label: (l) => l.dbOnlineSubtitleScanInterval,
      hint: (l) => l.dbOnlineSubtitleScanIntervalHint,
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'extensions',
      label: (l) => l.dbOnlineSubtitleExtensions,
      hint: (l) => l.dbOnlineSubtitleExtensionsHint,
      type: DboBackendConfigFieldType.commaList,
    ),
  ],
);

final dboPlayerSpeeds = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];
final _playerControls = <DboBackendConfigOption>[
  DboBackendConfigOption(
    value: 'play-large',
    label: (l) => l.dbOnlinePlayerPlayLarge,
  ),
  DboBackendConfigOption(
    value: 'play',
    label: (l) => l.dbOnlinePlayerPlayPause,
  ),
  DboBackendConfigOption(
    value: 'progress',
    label: (l) => l.dbOnlinePlayerProgress,
  ),
  DboBackendConfigOption(
    value: 'current-time',
    label: (l) => l.dbOnlinePlayerCurrentTime,
  ),
  DboBackendConfigOption(
    value: 'duration',
    label: (l) => l.dbOnlinePlayerDuration,
  ),
  DboBackendConfigOption(value: 'mute', label: (l) => l.dbOnlinePlayerMute),
  DboBackendConfigOption(value: 'volume', label: (l) => l.dbOnlinePlayerVolume),
  DboBackendConfigOption(
    value: 'captions',
    label: (l) => l.dbOnlineFieldCaptions,
  ),
  DboBackendConfigOption(
    value: 'settings',
    label: (l) => l.dbOnlinePlayerSettings,
  ),
  DboBackendConfigOption(value: 'pip', label: (l) => l.dbOnlineFieldPip),
  DboBackendConfigOption(value: 'airplay', label: (l) => 'AirPlay'),
  DboBackendConfigOption(
    value: 'fullscreen',
    label: (l) => l.dbOnlineFieldFullscreen,
  ),
];
final _playerSpeeds = [
  for (final speed in dboPlayerSpeeds)
    DboBackendConfigOption(value: '$speed', label: (l) => '${speed}x'),
];

final _playerSection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionPlayer,
  basePath: 'mediaserver.player',
  defaults: {
    'enabled': true,
    'autoplay': true,
    'captions': true,
    'pip': true,
    'fullscreen': true,
    'keyboard': true,
    'control_mode': 'custom',
    'controls': _playerControls.map((item) => item.value).toList(),
    'default_speed': 1,
    'speed_options': dboPlayerSpeeds,
  },
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: (l) => l.dbOnlineFieldEnablePlayer,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'autoplay',
      label: (l) => l.dbOnlineFieldAutoplay,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'captions',
      label: (l) => l.dbOnlineFieldCaptions,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'pip',
      label: (l) => l.dbOnlineFieldPip,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'fullscreen',
      label: (l) => l.dbOnlineFieldFullscreen,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'keyboard',
      label: (l) => l.dbOnlineFieldKeyboard,
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'control_mode',
      label: (l) => l.dbOnlinePlayerControlMode,
      type: DboBackendConfigFieldType.select,
      options: [
        DboBackendConfigOption(
          value: 'full',
          label: (l) => l.dbOnlinePlayerModeFull,
        ),
        DboBackendConfigOption(
          value: 'compact',
          label: (l) => l.dbOnlinePlayerModeCompact,
        ),
        DboBackendConfigOption(
          value: 'minimal',
          label: (l) => l.dbOnlinePlayerModeMinimal,
        ),
        DboBackendConfigOption(
          value: 'hidden',
          label: (l) => l.dbOnlinePlayerModeHidden,
        ),
        DboBackendConfigOption(
          value: 'custom',
          label: (l) => l.dbOnlinePlayerModeCustom,
        ),
      ],
    ),
    DboBackendConfigField(
      path: 'controls',
      label: (l) => l.dbOnlinePlayerControls,
      type: DboBackendConfigFieldType.multiSelect,
      options: _playerControls,
      visibleWhen: (values) => values['control_mode'] == 'custom',
    ),
    DboBackendConfigField(
      path: 'default_speed',
      label: (l) => l.dbOnlinePlayerDefaultSpeed,
      type: DboBackendConfigFieldType.select,
      options: _playerSpeeds,
    ),
    DboBackendConfigField(
      path: 'speed_options',
      label: (l) => l.dbOnlinePlayerSpeeds,
      type: DboBackendConfigFieldType.multiSelect,
      options: _playerSpeeds,
    ),
  ],
);

final dboBackendConfigGroups = <DboBackendConfigGroup>[
  DboBackendConfigGroup((l) => l.dbOnlineGroupSystem, <DboBackendConfigSection>[
    _javdbApiSection,
    _subscriptionSection,
    _proxySection,
    _experimentalSection,
  ]),
  DboBackendConfigGroup(
    (l) => l.dbOnlineGroupDownloader,
    <DboBackendConfigSection>[
      _aria2Section,
      _qbittorrentSection,
      _openListSection,
      _cloudDrive2Section,
      _pan115Section,
      _thunderSection,
    ],
  ),
  DboBackendConfigGroup(
    (l) => l.dbOnlineGroupMediaLibrary,
    <DboBackendConfigSection>[
      _mediaServerSection('emby'),
      _mediaServerSection('fnmedia'),
      _mediaServerSection('jellyfin'),
      _playerSection,
      _libraryCacheSection,
      _subtitleSection,
    ],
  ),
];

bool isDboMediaServer(String? name) =>
    const ['emby', 'jellyfin', 'fnmedia'].contains(name);

String? validateDboMediaServer(
  String? name,
  Map<String, dynamic> values,
  AppL10n l,
) {
  if (!isDboMediaServer(name) || values['enabled'] != true) return null;
  final requiredFields = [
    'host',
    if (name == 'fnmedia') ...['username', 'password'] else 'api_key',
  ];
  if (requiredFields.any(
    (key) => values[key]?.toString().trim().isNotEmpty != true,
  )) {
    return l.dbOnlineMediaServerRequired;
  }
  final port = int.tryParse(values['port']?.toString() ?? '');
  final timeout = int.tryParse(values['timeout']?.toString() ?? '');
  if (port == null ||
      port < 1 ||
      port > 65535 ||
      timeout == null ||
      timeout < 1) {
    return l.dbOnlineDownloaderInvalidConnection;
  }
  return null;
}

String? dboExperimentalDisabledReason(
  String path,
  Map<String, dynamic> config,
  AppL10n l,
) {
  if (path.startsWith('auto_sync_')) {
    final api = config['javdb_api'];
    if (api is! Map ||
        api['authorization']?.toString().trim().isNotEmpty != true) {
      return l.dbOnlineExperimentalRequireAuthorization;
    }
  } else if (path.startsWith('webhook_')) {
    final media = config['mediaserver'];
    final webhook = media is Map ? media['webhook'] : null;
    final telegram = config['telegram'];
    if (webhook is! Map ||
        webhook['enabled'] != true ||
        telegram is! Map ||
        telegram['enabled'] != true) {
      return l.dbOnlineExperimentalRequireWebhook;
    }
  } else if (path == 'builtin_magnets_in_subscription') {
    final external = config['external_magnet'];
    final builtin = external is Map ? external['builtin_magnets'] : null;
    if (builtin is! List || !builtin.contains('nyaa')) {
      return l.dbOnlineExperimentalRequireNyaa;
    }
  }
  return null;
}

bool isDboCloudDownloader(String? name) =>
    const ['pan115', 'thunder', 'openlist', 'clouddrive2'].contains(name);

String? validateDboCloudDownloader(
  String? name,
  Map<String, dynamic> values,
  AppL10n l, {
  bool connectionOnly = false,
}) {
  if (!isDboCloudDownloader(name) || values['enabled'] != true) return null;
  final requiredFields = name == 'pan115'
      ? ['cookie']
      : [
          'host',
          if (name == 'openlist' || name == 'clouddrive2') 'token',
          if (name == 'clouddrive2') 'save_path',
        ];
  if (requiredFields.any(
    (key) => values[key]?.toString().trim().isNotEmpty != true,
  )) {
    return l.dbOnlineDownloaderRequiredFields;
  }
  final timeout = int.tryParse(values['timeout']?.toString() ?? '');
  final port = int.tryParse(values['port']?.toString() ?? '');
  if (timeout == null ||
      timeout < 1 ||
      (name != 'pan115' && (port == null || port < 1 || port > 65535))) {
    return l.dbOnlineDownloaderInvalidConnection;
  }
  if (connectionOnly) return null;
  if (name == 'pan115') {
    final reserve = int.tryParse(values['reserve_quota']?.toString() ?? '');
    if (reserve == null || reserve < 0) return l.dbOnlineReserveQuotaInvalid;
    if (!RegExp(r'^\d+$').hasMatch(values['cid']?.toString() ?? '')) {
      return l.dbOnlineDownloaderSelectDirectory;
    }
  } else if (name == 'thunder' &&
      values['parent_folder_id']?.toString().trim().isNotEmpty != true) {
    return l.dbOnlineDownloaderSelectDirectory;
  }
  return null;
}
