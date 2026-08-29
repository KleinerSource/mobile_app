// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/player_gesture_layer_test.dart
//   - test/features/player_device_stats_test.dart
//   - test/features/player_resume_test.dart
//   - test/features/player_subtitle_track_resolver_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:omm/core/models/watch_record.dart';
import 'package:omm/features/player/player_device_stats.dart';
import 'package:omm/features/player/player_gesture_layer.dart';
import 'package:omm/features/player/player_resume.dart';
import 'package:omm/features/player/player_status_overlay.dart';
import 'package:omm/features/player/player_subtitle_track_resolver.dart';

// ==================== 原 test/features/player_gesture_layer_test.dart ====================
void _main_0() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> hapticCalls;

  setUp(() {
    hapticCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('单击播放器切换控件显隐不触发震动', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: PlayerGestureLayer(
              positionGetter: () => Duration.zero,
              durationGetter: () => const Duration(minutes: 2),
              onTap: () => tapCount++,
              doubleTapCenterEnabled: true,
              doubleTapEdgesEnabled: true,
              onDoubleTapCenter: () {},
              onDoubleTapSeek: (_) {},
              hapticLongPress: true,
              hapticSeek: true,
              hapticRate: true,
              onRateBoost: (_) {},
              onRateBoostEnd: () {},
              onSeekPreview: (_, __) {},
              onSeekCommit: (_) {},
              onBrightnessDelta: (_) {},
              onVolumeDelta: (_) {},
              onAxisDragEnd: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PlayerGestureLayer));
    await tester.pump(const Duration(seconds: 1));

    expect(tapCount, 1);
    expect(hapticCalls, isEmpty);
  });
}

// ==================== 原 test/features/player_device_stats_test.dart ====================
void _main_1() {
  test('设备状态可以从原生通道数据解析', () {
    final stats = PlayerDeviceStats.fromMap(const <Object?, Object?>{
      'cpu_percent': 42.5,
      'battery_percent': 87,
      'download_bps': 1536,
      'upload_bps': 512,
      'network_type': '5g',
    });

    expect(stats.cpuPercent, 42.5);
    expect(stats.batteryPercent, 87);
    expect(stats.downloadBytesPerSecond, 1536);
    expect(stats.uploadBytesPerSecond, 512);
    expect(stats.networkType, PlayerNetworkType.cellular5G);
  });

  test('网络类型可以区分 Wi-Fi、4G 和流量兜底状态', () {
    expect(PlayerNetworkType.fromValue('wifi'), PlayerNetworkType.wifi);
    expect(PlayerNetworkType.fromValue('lte'), PlayerNetworkType.cellular4G);
    expect(PlayerNetworkType.fromValue('mobile'), PlayerNetworkType.mobile);
    expect(
      PlayerNetworkType.fromValue('unsupported'),
      PlayerNetworkType.unknown,
    );
  });

  test('网速格式化按可读单位输出', () {
    expect(formatPlayerNetworkRate(null), '--');
    expect(formatPlayerNetworkRate(512), '512 B/s');
    expect(formatPlayerNetworkRate(2048), '2 KB/s');
    expect(formatPlayerNetworkRate(2 * 1024 * 1024), '2.0 MB/s');
  });

  testWidgets('网络和 CPU OSD 使用图标并保留数值', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerStatusOverlay(
            title: '测试影片',
            stats: PlayerDeviceStats(
              cpuPercent: 42.5,
              downloadBytesPerSecond: 2048,
              networkType: PlayerNetworkType.wifi,
            ),
            showSystemTime: false,
            showNetworkSpeed: true,
            showCpuUsage: true,
            showBattery: false,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.memory), findsOneWidget);
    expect(find.text('2 KB/s'), findsOneWidget);
    expect(find.text('43%'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsNothing);
    expect(find.text('CPU'), findsNothing);
  });
}

// ==================== 原 test/features/player_resume_test.dart ====================
void _main_2() {
  const record = WatchRecord(
    lastPositionSec: 123.4,
    durationSec: 600,
    completed: false,
  );

  test('自动续播使用服务端最后位置', () {
    expect(
      resolveResumePosition(
        enabled: true,
        explicitPositionSec: 0,
        record: record,
      ),
      123,
    );
  });

  test('显式位置优先于服务端记录', () {
    expect(
      resolveResumePosition(
        enabled: true,
        explicitPositionSec: 45,
        record: record,
      ),
      45,
    );
  });

  test('关闭续播或已完成影片从头开始', () {
    expect(
      resolveResumePosition(
        enabled: false,
        explicitPositionSec: 0,
        record: record,
      ),
      0,
    );
    expect(
      const WatchRecord(
        lastPositionSec: 580,
        durationSec: 600,
        completed: true,
      ).resumePositionSec,
      0,
    );
  });
}

// ==================== 原 test/features/player_subtitle_track_resolver_test.dart ====================
void _main_3() {
  test('优先使用 media_kit 的内嵌字幕轨道 ID', () {
    const tracks = [
      SubtitleTrack('auto', null, null),
      SubtitleTrack('no', null, null),
      SubtitleTrack('7', '中文', 'zh'),
    ];

    expect(resolveSubtitleTrack(tracks, '7', fallbackIndex: 0), tracks.last);
  });

  test('轨道 ID 不一致时按内嵌字幕顺序回退', () {
    const tracks = [
      SubtitleTrack('auto', null, null),
      SubtitleTrack('no', null, null),
      SubtitleTrack('3', '英文', 'en'),
      SubtitleTrack('4', '中文', 'zh'),
    ];

    expect(resolveSubtitleTrack(tracks, '99', fallbackIndex: 1), tracks[3]);
    expect(resolveSubtitleTrack(tracks, '99', fallbackIndex: 2), isNull);
  });
}

void main() {
  group('player_gesture_layer', _main_0);
  group('player_device_stats', _main_1);
  group('player_resume', _main_2);
  group('player_subtitle_track_resolver', _main_3);
}
