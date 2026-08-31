// 回归测试：文件服务器添加后首次登录报
// "Bad state: Cannot call onDispose after a provider was dispose"。
//
// 根因：设置页保存后会 invalidate fileSourceConfigsProvider；登录时 registry
// 首次构建并 watch 到这个脏依赖，Riverpod 在 build 内同步 flush 并立即
// invalidate registry 元素，随后 ref.onDispose 在已卸载元素上调用而抛错
// （该时序仅在 release 下出现，debug 的 assert 预 flush 会掩盖它）。
// 修复：registry 直接从仓库读取配置，不 watch 该 provider。
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _RegistryRebuildCounter extends ProviderObserver {
  int registryUpdates = 0;

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    final provider = context.provider;
    if (provider.name == 'fileSourceRegistryProvider' ||
        provider.runtimeType.toString().contains('FileSourceRegistry')) {
      registryUpdates++;
    }
  }
}

void main() {
  Future<SharedPreferences> prefsFor(String serverId) async {
    SharedPreferences.setMockInitialValues({
      'file_sources.v1': jsonEncode([
        {
          'id': 'fs-1',
          'name': '我的 WebDAV',
          'protocol': 'webdav',
          'host': '127.0.0.1',
          'port': 1,
          'path': '/media',
          'uri': 'https://127.0.0.1:1/media',
          'credential_ref': 'cred-1',
          'server_id': serverId,
          'enabled': true,
          'timeout_ms': 30000,
          'smb_workers': 2,
        },
      ]),
    });
    return SharedPreferences.getInstance();
  }

  ServerConfig configFor(String serverId, String baseUrl) {
    final line = ServerLine(id: 'main', name: '主线路', baseUrl: baseUrl);
    return ServerConfig(
      baseUrl: baseUrl,
      lines: [line],
      servers: [
        ServerProfile(
          id: serverId,
          name: '我的 WebDAV',
          lines: [line],
          activeLineId: line.id,
          projectName: 'webdav',
        ),
      ],
      activeServerId: serverId,
    );
  }

  test('registry 不依赖 fileSourceConfigsProvider，单独失效配置不触发重建', () async {
    const serverId = 'server-1';
    final prefs = await prefsFor(serverId);
    final observer = _RegistryRebuildCounter();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      observers: [observer],
    );
    addTearDown(container.dispose);

    container.read(serverConfigProvider.notifier).state = configFor(
      serverId,
      'https://127.0.0.1:1',
    );

    // 保持 registry 存活（连接 127.0.0.1:1 异步失败与断言无关）。
    final subscription = container.listen(
      fileSourceRegistryProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    // 设置页保存后的失效序列（server_setup_page）。
    container.invalidate(fileSourceConfigsProvider);
    container.invalidate(fileSourceRegistryProvider);
    await Future<void>.delayed(Duration.zero);

    // 登录：在配置仓库仍脏时立即读取 registry，不应出现 onDispose 异常。
    // 只关心同步 flush 阶段是否抛错，连接结果由后续断言检查。
    unawaited(container.read(fileSourceRegistryProvider.future));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(fileSourceRegistryProvider);
    expect(
      state.hasError,
      isTrue,
      reason: '连接失败应以错误态呈现',
    );
    expect(
      state.error.toString(),
      isNot(contains('onDispose')),
      reason: '不应出现 onDispose 相关的 Bad state',
    );

    // 单独失效配置不应再触发 registry 重建（旧实现 watch 了该 provider，
    // 会在设置页保存后引发登录时的重建竞争）。
    observer.registryUpdates = 0;
    container.invalidate(fileSourceConfigsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      observer.registryUpdates,
      0,
      reason: 'registry 不应 watch fileSourceConfigsProvider',
    );
  });
}
