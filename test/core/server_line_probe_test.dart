import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_line_probe.dart';

void main() {
  const current = ServerLine(
    id: 'current',
    name: '当前线路',
    baseUrl: 'https://current.example',
  );
  const backup = ServerLine(
    id: 'backup',
    name: '备用线路',
    baseUrl: 'https://backup.example',
  );

  test('当前线路在优先窗口内可用时不启动备用线路', () async {
    var backupProbeCount = 0;
    final coordinator = ServerLineProbeCoordinator(
      fallbackDelay: const Duration(seconds: 1),
      probe: (line) async {
        if (line.id == backup.id) backupProbeCount++;
        return ServerLineProbeResult.success(line, 20);
      },
    );

    final selection = await coordinator.selectPreferred(
      current: current,
      alternatives: const [backup],
    );

    expect(selection.selected?.line, current);
    expect(backupProbeCount, 0);
  });

  test('当前线路失败后立即启用备用线路', () async {
    final coordinator = ServerLineProbeCoordinator(
      fallbackDelay: const Duration(seconds: 1),
      probe: (line) async {
        if (line.id == current.id) {
          return ServerLineProbeResult.failure(line, '连接失败');
        }
        return ServerLineProbeResult.success(line, 35);
      },
    );

    final selection = await coordinator.selectPreferred(
      current: current,
      alternatives: const [backup],
    );

    expect(selection.selected?.line, backup);
    expect(selection.selected?.latencyMs, 35);
  });

  test('并发测速在首条线路成功时立即返回，不等待慢线路', () async {
    final slowResult = Completer<ServerLineProbeResult>();
    final coordinator = ServerLineProbeCoordinator(
      probe: (line) {
        if (line.id == current.id) return slowResult.future;
        return Future.value(ServerLineProbeResult.success(line, 30));
      },
    );

    final batch = coordinator.probeAll(const [current, backup]);
    final selected = await batch.firstAvailable;

    expect(selected?.line, backup);
    var completed = false;
    unawaited(batch.completed.then((_) => completed = true));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    slowResult.complete(const ServerLineProbeResult.failure(current, '连接超时'));
    final results = await batch.completed;
    expect(results, hasLength(2));
  });
}
