import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/diagnostics/crash_log_service.dart';

void main() {
  late Directory root;
  late CrashLogService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('md-center-crash-log-test-');
    service = await CrashLogService.create(rootDirectory: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('记录内容会脱敏令牌和密码', () async {
    await service.recordMessage(
      '请求失败 https://example.test/play?token=secret-token&x=1',
      source: 'player',
      stack: StackTrace.fromString('Authorization: Bearer access-secret'),
      context: const {
        'access_token': 'access-secret',
        'refresh_token': 'refresh-secret',
        'movie_id': 8,
      },
    );

    final entries = await service.readEntries();
    expect(entries, hasLength(1));
    expect(entries.single.message, isNot(contains('secret-token')));
    expect(entries.single.stack, contains('[REDACTED]'));
    expect(entries.single.context['access_token'], '[REDACTED]');
    expect(entries.single.context['refresh_token'], '[REDACTED]');
    expect(entries.single.context['movie_id'], 8);
  });

  test('并发写入会串行保存且按倒序读取', () async {
    await Future.wait([
      for (var i = 0; i < 5; i++)
        service.recordMessage('error-$i', source: 'test'),
    ]);

    final entries = await service.readEntries();
    expect(entries, hasLength(5));
    expect(entries.first.message, 'error-4');
    expect(entries.last.message, 'error-0');
  });

  test('可以清空日志文件', () async {
    await service.recordMessage('to-be-cleared');
    await service.clear();

    expect(await service.readEntries(), isEmpty);
    expect(await service.logFile.exists(), isTrue);
  });

  test('fatal 错误可以同步落盘', () async {
    service.recordErrorSync(
      StateError('fatal'),
      StackTrace.fromString('stack'),
      source: 'platform',
    );

    final entries = await service.readEntries();
    expect(entries.single.source, 'platform');
    expect(entries.single.message, contains('fatal'));
  });

  test('可以读取并导出 iOS native 报告', () async {
    await service.nativeLogFile.writeAsString(
      '${jsonEncode({
        'timestamp': '2026-08-12T00:00:00.000Z',
        'source': 'ios-metrickit',
        'message': 'native crash',
        'stack': 'SIGABRT',
        'context': {'kind': 'MXDiagnosticPayload'},
      })}\n',
    );
    final ips = File(
      '${service.logFile.parent.path}${Platform.pathSeparator}ios-1.ips',
    );
    await ips.writeAsString('{"signal":"SIGABRT"}');

    final entries = await service.readEntries();
    expect(entries.single.source, 'ios-metrickit');
    expect(
      (await service.nativeReportFiles()).map((file) => file.path),
      [ips.path],
    );

    await service.clear();
    expect(await service.nativeReportFiles(), isEmpty);
    expect(await service.nativeLogFile.exists(), isFalse);
  });
}
