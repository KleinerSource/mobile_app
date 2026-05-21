import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config_provider.dart';
import 'api_client.dart';

/// 仅在已配置服务器地址时返回 ApiClient；未配置时返回 null。
final apiClientProvider = Provider<ApiClient?>((ref) {
  final cfg = ref.watch(serverConfigProvider);
  if (cfg == null) return null;
  return ApiClient.fromConfig(cfg);
});

/// 强制要求已配置；未配置时抛错。
final requiredApiClientProvider = Provider<ApiClient>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    throw StateError('ApiClient 未就绪：服务器地址未配置');
  }
  return client;
});
