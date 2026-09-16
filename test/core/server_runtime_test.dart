import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

void main() {
  final config = _config();

  test('冷启动运行槽为空且两条连接均未激活', () {
    final container = ProviderContainer.test(
      overrides: [
        serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
      ],
    );

    expect(container.read(serverRuntimeProvider), const ServerRuntimeState());
    expect(container.read(mediaRuntimeConfigProvider), isNull);
    expect(container.read(fileRuntimeConfigProvider), isNull);
    expect(container.read(mediaServerConnectionProvider).suspended, isTrue);
    expect(container.read(fileServerConnectionProvider).suspended, isTrue);
  });

  test('媒体槽和文件槽拥有独立连接代际', () {
    final container = ProviderContainer.test(
      overrides: [
        serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
      ],
    );
    final runtime = container.read(serverRuntimeProvider.notifier);

    runtime.beginSwitch(ServerRuntimeLane.media, 'media-one');
    final firstMediaLease = container
        .read(mediaServerConnectionProvider.notifier)
        .activate('media-one');
    runtime.commit(ServerRuntimeLane.media, 'media-one');

    runtime.beginSwitch(ServerRuntimeLane.files, 'file-one');
    final fileLease = container
        .read(fileServerConnectionProvider.notifier)
        .activate('file-one');
    runtime.commit(ServerRuntimeLane.files, 'file-one');

    runtime.showLane(ServerRuntimeLane.media);
    expect(firstMediaLease.isActive, isTrue);
    expect(fileLease.isActive, isTrue);

    container.read(mediaServerConnectionProvider.notifier).suspend();
    runtime.beginSwitch(ServerRuntimeLane.media, 'media-two');
    final secondMediaLease = container
        .read(mediaServerConnectionProvider.notifier)
        .activate('media-two');
    runtime.commit(ServerRuntimeLane.media, 'media-two');

    expect(firstMediaLease.isActive, isFalse);
    expect(secondMediaLease.isActive, isTrue);
    expect(fileLease.isActive, isTrue);
    expect(
      container.read(fileServerConnectionProvider).lease,
      same(fileLease),
    );
  });

  test('切换可见槽不会重建任一连接', () {
    final container = ProviderContainer.test(
      overrides: [
        serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
      ],
    );
    final runtime = container.read(serverRuntimeProvider.notifier);
    runtime.beginSwitch(ServerRuntimeLane.media, 'media-one');
    final mediaLease = container
        .read(mediaServerConnectionProvider.notifier)
        .activate('media-one');
    runtime.commit(ServerRuntimeLane.media, 'media-one');
    runtime.beginSwitch(ServerRuntimeLane.files, 'file-one');
    final fileLease = container
        .read(fileServerConnectionProvider.notifier)
        .activate('file-one');
    runtime.commit(ServerRuntimeLane.files, 'file-one');

    runtime.showLane(ServerRuntimeLane.media);
    runtime.showLane(ServerRuntimeLane.files);
    runtime.showLane(ServerRuntimeLane.media);

    expect(
      container.read(mediaServerConnectionProvider).lease,
      same(mediaLease),
    );
    expect(
      container.read(fileServerConnectionProvider).lease,
      same(fileLease),
    );
  });

  test('删除运行实例只清理对应槽', () {
    final notifier = _ServerConfigState(config);
    final container = ProviderContainer.test(
      overrides: [serverConfigProvider.overrideWith(() => notifier)],
    );
    final runtime = container.read(serverRuntimeProvider.notifier);
    runtime.beginSwitch(ServerRuntimeLane.media, 'media-one');
    final mediaLease = container
        .read(mediaServerConnectionProvider.notifier)
        .activate('media-one');
    runtime.commit(ServerRuntimeLane.media, 'media-one');
    runtime.beginSwitch(ServerRuntimeLane.files, 'file-one');
    final fileLease = container
        .read(fileServerConnectionProvider.notifier)
        .activate('file-one');
    runtime.commit(ServerRuntimeLane.files, 'file-one');

    container.read(serverConfigProvider.notifier).state = config.copyWith(
      servers: config.servers.where((server) => server.id != 'media-one').toList(),
      activeServerId: 'file-one',
    );

    expect(container.read(serverRuntimeProvider).media.serverId, isNull);
    expect(container.read(serverRuntimeProvider).files.serverId, 'file-one');
    expect(mediaLease.isActive, isFalse);
    expect(fileLease.isActive, isTrue);
  });
}

ServerConfig _config() {
  const mediaLineOne = ServerLine(
    id: 'media-line-one',
    name: '媒体一',
    baseUrl: 'https://media-one.example',
  );
  const mediaLineTwo = ServerLine(
    id: 'media-line-two',
    name: '媒体二',
    baseUrl: 'https://media-two.example',
  );
  const fileLine = ServerLine(
    id: 'file-line-one',
    name: '文件一',
    baseUrl: 'https://file-one.example',
  );
  return const ServerConfig(
    baseUrl: 'https://media-one.example',
    lines: [mediaLineOne],
    servers: [
      ServerProfile(
        id: 'media-one',
        name: '媒体一',
        lines: [mediaLineOne],
        activeLineId: 'media-line-one',
        projectName: 'emby',
      ),
      ServerProfile(
        id: 'media-two',
        name: '媒体二',
        lines: [mediaLineTwo],
        activeLineId: 'media-line-two',
        projectName: 'emby',
      ),
      ServerProfile(
        id: 'file-one',
        name: '文件一',
        lines: [fileLine],
        activeLineId: 'file-line-one',
        projectName: 'webdav',
      ),
    ],
    activeServerId: 'media-one',
  );
}
