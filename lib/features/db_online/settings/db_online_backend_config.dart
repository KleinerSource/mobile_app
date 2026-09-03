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
    return ref.read(requiredApiClientProvider).dbOnline.getBackendConfig();
  }

  Future<void> save(Map<String, dynamic> partial) async {
    final saved = await ref
        .read(requiredApiClientProvider)
        .dbOnline
        .updateBackendConfig(partial);
    state = AsyncData(saved);
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

enum DboBackendConfigFieldType { toggle, text, password, number, select }

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
  });

  final String Function(AppL10n l) title;
  final String basePath;
  final List<DboBackendConfigField> fields;
  final String? testName;
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
      label: (l) => l.dbOnlineFieldCategoryId,
      type: DboBackendConfigFieldType.text,
      hint: (l) => l.dbOnlineFieldCategoryIdHint,
    ),
    DboBackendConfigField(
      path: 'reserve_quota',
      label: (l) => l.dbOnlineFieldReserveQuotaGb,
      type: DboBackendConfigFieldType.number,
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
      label: (l) => l.dbOnlineFieldDeviceId,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'parent_folder_id',
      label: (l) => l.dbOnlineFieldParentFolderId,
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: (l) => l.dbOnlineFieldTimeoutSeconds,
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

final _playerSection = DboBackendConfigSection(
  title: (l) => l.dbOnlineSectionPlayer,
  basePath: 'mediaserver.player',
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
  ],
);

final dboBackendConfigGroups = <DboBackendConfigGroup>[
  DboBackendConfigGroup((l) => l.dbOnlineGroupSystem, <DboBackendConfigSection>[
    _javdbApiSection,
    _subscriptionSection,
    _proxySection,
  ]),
  DboBackendConfigGroup(
    (l) => l.dbOnlineGroupDownloader,
    <DboBackendConfigSection>[
      _aria2Section,
      _qbittorrentSection,
      _pan115Section,
      _thunderSection,
    ],
  ),
  DboBackendConfigGroup(
    (l) => l.dbOnlineGroupMediaLibrary,
    <DboBackendConfigSection>[_playerSection],
  ),
];
