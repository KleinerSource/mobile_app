import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';

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
  final String label;
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
  final String label;
  final DboBackendConfigFieldType type;
  final String? hint;
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

  final String title;
  final String basePath;
  final List<DboBackendConfigField> fields;
  final String? testName;
}

class DboBackendConfigGroup {
  const DboBackendConfigGroup(this.title, this.sections);

  final String title;
  final List<DboBackendConfigSection> sections;
}

const _imageModes = <DboBackendConfigOption>[
  DboBackendConfigOption(value: 'replace', label: '替换图片地址'),
  DboBackendConfigOption(value: 'decrypt', label: '解密图片'),
];

bool _isImageReplace(Map<String, dynamic> values) =>
    values['image_mode'] == 'replace';

bool _isRetryEnabled(Map<String, dynamic> values) =>
    values['enable_retry'] == true;

const _javdbApiSection = DboBackendConfigSection(
  title: 'JavDB API',
  basePath: 'javdb_api',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'host',
      label: 'API 地址',
      type: DboBackendConfigFieldType.text,
      hint: '完整的 JavDB API 地址',
    ),
    DboBackendConfigField(
      path: 'authorization',
      label: 'Authorization',
      type: DboBackendConfigFieldType.password,
      hint: '可选，留空或保持掩码表示不修改',
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: '请求超时（秒）',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'image_mode',
      label: '图片处理',
      type: DboBackendConfigFieldType.select,
      options: _imageModes,
    ),
    DboBackendConfigField(
      path: 'url_replace_new',
      label: '图片 URL 替换前缀',
      type: DboBackendConfigFieldType.text,
      hint: '图片模式为“替换图片地址”时必填',
      visibleWhen: _isImageReplace,
    ),
  ],
);

const _subscriptionSection = DboBackendConfigSection(
  title: '订阅',
  basePath: 'subscription',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: '启用订阅',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'check_interval',
      label: '检查间隔（分钟）',
      type: DboBackendConfigFieldType.number,
      hint: '建议不小于 120 分钟',
    ),
    DboBackendConfigField(
      path: 'concurrency',
      label: '并发数',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'request_timeout',
      label: '请求超时（秒）',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'interval_range',
      label: '间隔范围（秒）',
      type: DboBackendConfigFieldType.text,
      hint: '例如 3-10',
    ),
    DboBackendConfigField(
      path: 'enable_retry',
      label: '失败重试',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'retry_count',
      label: '重试次数',
      type: DboBackendConfigFieldType.number,
      visibleWhen: _isRetryEnabled,
    ),
    DboBackendConfigField(
      path: 'retry_interval',
      label: '重试间隔（秒）',
      type: DboBackendConfigFieldType.number,
      visibleWhen: _isRetryEnabled,
    ),
  ],
);

const _proxySection = DboBackendConfigSection(
  title: '代理',
  basePath: 'proxy.main',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: '启用代理',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'protocol',
      label: '协议',
      type: DboBackendConfigFieldType.select,
      options: <DboBackendConfigOption>[
        DboBackendConfigOption(value: 'http', label: 'HTTP'),
        DboBackendConfigOption(value: 'https', label: 'HTTPS'),
        DboBackendConfigOption(value: 'socks5', label: 'SOCKS5'),
      ],
    ),
    DboBackendConfigField(
      path: 'host',
      label: '主机',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: '端口',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'username',
      label: '用户名（可选）',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'password',
      label: '密码（可选）',
      type: DboBackendConfigFieldType.password,
      hint: '留空或保持掩码表示不修改',
    ),
  ],
);

const _aria2Section = DboBackendConfigSection(
  title: 'Aria2',
  basePath: 'downloader.aria2',
  testName: 'aria2',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: '启用',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: '主机',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: '端口',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'use_https',
      label: '使用 HTTPS',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'secret',
      label: 'RPC Secret',
      type: DboBackendConfigFieldType.password,
      hint: '留空或保持掩码表示不修改',
    ),
    DboBackendConfigField(
      path: 'save_path',
      label: '保存路径',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: '超时（秒）',
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

const _qbittorrentSection = DboBackendConfigSection(
  title: 'qBittorrent',
  basePath: 'downloader.qbittorrent',
  testName: 'qbittorrent',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: '启用',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: '主机',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: '端口',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'use_https',
      label: '使用 HTTPS',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'username',
      label: '用户名',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'password',
      label: '密码',
      type: DboBackendConfigFieldType.password,
      hint: '留空或保持掩码表示不修改',
    ),
    DboBackendConfigField(
      path: 'category',
      label: '分类（可选）',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'save_path',
      label: '保存路径',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: '超时（秒）',
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

const _pan115Section = DboBackendConfigSection(
  title: '115 网盘',
  basePath: 'downloader.pan115',
  testName: 'pan115',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: '启用',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'cookie',
      label: 'Cookie',
      type: DboBackendConfigFieldType.password,
      hint: '留空或保持掩码表示不修改',
    ),
    DboBackendConfigField(
      path: 'cid',
      label: '目录 ID',
      type: DboBackendConfigFieldType.text,
      hint: '0 表示根目录',
    ),
    DboBackendConfigField(
      path: 'reserve_quota',
      label: '保留配额（GB）',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: '超时（秒）',
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

const _thunderSection = DboBackendConfigSection(
  title: '迅雷',
  basePath: 'downloader.thunder',
  testName: 'thunder',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: '启用',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'host',
      label: '主机',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'port',
      label: '端口',
      type: DboBackendConfigFieldType.number,
    ),
    DboBackendConfigField(
      path: 'use_https',
      label: '使用 HTTPS',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'device_target',
      label: '设备标识',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'parent_folder_id',
      label: '父文件夹 ID',
      type: DboBackendConfigFieldType.text,
    ),
    DboBackendConfigField(
      path: 'timeout',
      label: '超时（秒）',
      type: DboBackendConfigFieldType.number,
    ),
  ],
);

const _playerSection = DboBackendConfigSection(
  title: '播放器',
  basePath: 'mediaserver.player',
  fields: <DboBackendConfigField>[
    DboBackendConfigField(
      path: 'enabled',
      label: '启用播放器',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'autoplay',
      label: '自动播放',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'captions',
      label: '字幕',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'pip',
      label: '画中画',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'fullscreen',
      label: '全屏',
      type: DboBackendConfigFieldType.toggle,
    ),
    DboBackendConfigField(
      path: 'keyboard',
      label: '键盘控制',
      type: DboBackendConfigFieldType.toggle,
    ),
  ],
);

const dboBackendConfigGroups = <DboBackendConfigGroup>[
  DboBackendConfigGroup('系统', <DboBackendConfigSection>[
    _javdbApiSection,
    _subscriptionSection,
    _proxySection,
  ]),
  DboBackendConfigGroup('下载器', <DboBackendConfigSection>[
    _aria2Section,
    _qbittorrentSection,
    _pan115Section,
    _thunderSection,
  ]),
  DboBackendConfigGroup('媒体库', <DboBackendConfigSection>[_playerSection]),
];
