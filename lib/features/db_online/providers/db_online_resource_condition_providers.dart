import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/db_online/settings/db_online_backend_config.dart';

/// 服务端配置 `javdb_api.can_play` 开启后，资源条件才提供 p（可播放），
/// 与网页端「在线播」筛选项同一开关；配置未加载或未开启时隐藏。
final dbOnlineOnlinePlayAvailableProvider = Provider<bool>((ref) {
  final config = ref.watch(dbOnlineBackendConfigProvider);
  return config.when(
    data: (value) {
      final api = value['javdb_api'];
      return api is Map && api['can_play'] == true;
    },
    loading: () => false,
    error: (_, _) => false,
  );
});
