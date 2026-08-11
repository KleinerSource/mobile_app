import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'server_config.dart';
import 'server_config_repository.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('在 main.dart 用 overrideWithValue 注入');
});

final serverConfigRepoProvider = Provider<ServerConfigRepository>((ref) {
  return ServerConfigRepository(ref.watch(sharedPrefsProvider));
});

class ServerConfigNotifier extends Notifier<ServerConfig?> {
  @override
  ServerConfig? build() {
    return ref.watch(serverConfigRepoProvider).load();
  }

  Future<void> save(ServerConfig cfg) async {
    final normalized = cfg.copyWith(
      baseUrl: ServerConfig.normalize(cfg.baseUrl),
      lines: cfg.lines
          .map(
            (line) => line.copyWith(
              baseUrl: ServerConfig.normalize(line.baseUrl),
            ),
          )
          .toList(),
    );
    final repository = ref.read(serverConfigRepoProvider);
    await repository.save(normalized);
    state = repository.load();
  }

  Future<void> clear() async {
    await ref.read(serverConfigRepoProvider).clear();
    state = null;
  }

  /// 进入服务器编辑页，但保留本地配置，供编辑页回填。
  void beginEdit() {
    state = null;
  }
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfig?>(ServerConfigNotifier.new);
