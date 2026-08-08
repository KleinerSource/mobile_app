import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/player/player_decode_status.dart';

void main() {
  test('本地和服务端状态使用不同标签、图标和颜色', () {
    const localHardware = PlayerDecodeStatus.local(hardware: true);
    const localSoftware = PlayerDecodeStatus.local(hardware: false);
    final serverHardware = PlayerDecodeStatus.server(engine: 'videotoolbox');
    final serverSoftware = PlayerDecodeStatus.server(engine: 'software');

    expect(localHardware.shortLabel, '本地硬解');
    expect(localSoftware.shortLabel, '本地软解');
    expect(serverHardware.fullLabel, '服务端硬解 · VideoToolbox');
    expect(serverSoftware.shortLabel, '服务端软解');
    expect(localHardware.icon, isNot(localSoftware.icon));
    expect(localHardware.icon, isNot(serverHardware.icon));
    expect(localHardware.color, isNot(localSoftware.color));
    expect(serverHardware.color, isNot(serverSoftware.color));
  });

  test('服务端硬解失败显示软解回退', () {
    final status = PlayerDecodeStatus.server(
      engine: 'videotoolbox',
      hardwareDecodeOk: false,
    );

    expect(status.mode, PlayerDecodeMode.software);
    expect(status.shortLabel, '服务端软解回退');
    expect(status.isFallback, isTrue);
  });

  test('服务端转码时只显示服务端主状态', () {
    final server = PlayerDecodeStatus.server(engine: 'videotoolbox');
    final statuses = PlayerDecodeStatus.primary(
      usingHls: true,
      localHardware: true,
      serverStatus: server,
    );

    expect(statuses, hasLength(1));
    expect(statuses.single, same(server));
    expect(statuses.single.location, PlayerDecodeLocation.server);
  });

  test('直传时显示本地主状态', () {
    final server = PlayerDecodeStatus.server(engine: 'videotoolbox');
    final statuses = PlayerDecodeStatus.primary(
      usingHls: false,
      localHardware: true,
      serverStatus: server,
    );

    expect(statuses, hasLength(1));
    expect(statuses.single.location, PlayerDecodeLocation.local);
    expect(statuses.single.shortLabel, '本地硬解');
  });
}
