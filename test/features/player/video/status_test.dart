// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/player_decode_status_test.dart
//   - test/features/player_error_disposition_test.dart
//   - test/features/player_settings_test.dart
//   - test/features/player/video/player_debug_overlay_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/video/player_debug_overlay.dart';
import 'package:omm/features/player/video/player_decode_status.dart';
import 'package:omm/features/player/video/player_error_disposition.dart';
import 'package:omm/features/player/common/player_settings.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/features/player_decode_status_test.dart ====================
void _main_0() {
  test('本地和服务端状态使用不同标签、图标和颜色', () {
    const localHardware = PlayerDecodeStatus.local(hardware: true);
    const localSoftware = PlayerDecodeStatus.local(hardware: false);
    final serverHardware = PlayerDecodeStatus.server(engine: 'videotoolbox');
    final serverSoftware = PlayerDecodeStatus.server(engine: 'software');
    final l = lookupAppL10n(const Locale('zh'));

    expect(localHardware.shortLabel(l), '本地硬解');
    expect(localSoftware.shortLabel(l), '本地软解');
    expect(serverHardware.fullLabel(l), '服务端硬解 · VideoToolbox');
    expect(serverSoftware.shortLabel(l), '服务端软解');
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
    expect(status.shortLabel(lookupAppL10n(const Locale('zh'))), '服务端软解回退');
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

  test('服务端软解转码时只显示服务端软解', () {
    final server = PlayerDecodeStatus.server(engine: 'software');
    final statuses = PlayerDecodeStatus.primary(
      usingHls: true,
      localHardware: true,
      serverStatus: server,
    );

    expect(statuses, hasLength(1));
    expect(statuses.single.location, PlayerDecodeLocation.server);
    expect(
      statuses.single.shortLabel(lookupAppL10n(const Locale('zh'))),
      '服务端软解',
    );
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
    expect(
      statuses.single.shortLabel(lookupAppL10n(const Locale('zh'))),
      '本地硬解',
    );
  });
}

// ==================== 原 test/features/player_error_disposition_test.dart ====================
void _main_1() {
  final now = DateTime(2026, 1, 1, 12);

  test('字幕加载窗口内且主媒体已装载时降级为字幕提示', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: now.add(const Duration(seconds: 5)),
      now: now,
      mainMediaLoaded: true,
    );
    expect(disposition, PlayerErrorDisposition.subtitleWarning);
  });

  test('字幕窗口已过期时保持致命错误', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: now.subtract(const Duration(seconds: 1)),
      now: now,
      mainMediaLoaded: true,
    );
    expect(disposition, PlayerErrorDisposition.fatal);
  });

  test('从未发起字幕加载时保持致命错误', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: null,
      now: now,
      mainMediaLoaded: true,
    );
    expect(disposition, PlayerErrorDisposition.fatal);
  });

  test('主媒体未装载时报错仍然致命（字幕窗口内也可能是主媒体打开失败）', () {
    final disposition = classifyPlayerError(
      subtitleGuardUntil: now.add(const Duration(seconds: 5)),
      now: now,
      mainMediaLoaded: false,
    );
    expect(disposition, PlayerErrorDisposition.fatal);
  });

  test('窗口边界：恰好到期不再降级', () {
    final until = now.add(const Duration(seconds: 15));
    expect(
      classifyPlayerError(
        subtitleGuardUntil: until,
        now: until.subtract(const Duration(milliseconds: 1)),
        mainMediaLoaded: true,
      ),
      PlayerErrorDisposition.subtitleWarning,
    );
    expect(
      classifyPlayerError(
        subtitleGuardUntil: until,
        now: until,
        mainMediaLoaded: true,
      ),
      PlayerErrorDisposition.fatal,
    );
  });
}

// ==================== 原 test/features/player_settings_test.dart ====================
void _main_2() {
  test('播放器内核测试入口文案支持中英文', () {
    final zh = lookupAppL10n(const Locale('zh'));
    final en = lookupAppL10n(const Locale('en'));
    expect(zh.playerEnginePickerTitle, '选择播放器');
    expect(zh.playerEnginePickerSubtitle, '仅用于本次播放，不会修改默认设置');
    expect(en.playerEnginePickerTitle, 'Choose player');
    expect(
      en.playerEnginePickerSubtitle,
      'Applies to this playback only and does not change your default',
    );
  });

  test('播放器设置默认值保持现有播放行为', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = PlayerSettingsRepository(prefs).load();

    expect(settings.resumeFromLastPosition, isTrue);
    expect(settings.landscapeSide, PlayerLandscapeSide.cameraLeft);
    expect(settings.entryOrientation, PlayerEntryOrientation.forceLandscape);
    expect(settings.orientationSensorUnlocked, isTrue);
    expect(settings.preloadSize, PlayerPreloadSize.mb250);
    expect(settings.iosEngine, PlaybackEngineKind.libmpv);
    expect(settings.debugMode, isFalse);
    expect(settings.doubleTapCenter, isTrue);
    expect(settings.doubleTapEdges, isTrue);
    expect(settings.hapticLongPress, isTrue);
    expect(settings.hapticSeek, isTrue);
    expect(settings.hapticRate, isTrue);
    expect(settings.hapticProgressBar, isTrue);
    expect(settings.showSystemTime, isTrue);
    expect(settings.showNetworkSpeed, isTrue);
    expect(settings.showCpuUsage, isTrue);
    expect(settings.showBattery, isTrue);
    expect(settings.showPlayPauseButton, isTrue);
    expect(settings.showSeekButtons, isTrue);
    expect(settings.showSpeedButton, isTrue);
    expect(settings.showPipButton, isTrue);
    expect(settings.showOrientationButton, isTrue);
    expect(settings.showMediaSwitchButton, isTrue);
  });

  test('设备横屏方向未知值回退为摄像头在左侧', () async {
    expect(
      const PlayerSettings().landscapeSide,
      PlayerLandscapeSide.cameraLeft,
    );
    expect(PlayerLandscapeSide.fromValue(null), PlayerLandscapeSide.cameraLeft);
    SharedPreferences.setMockInitialValues({
      'player.landscape_side': 'unsupported',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      PlayerSettingsRepository(prefs).load().landscapeSide,
      PlayerLandscapeSide.cameraLeft,
    );
  });

  test('预载档位提供四个内存选项且未知值回退默认', () {
    expect(PlayerPreloadSize.values, hasLength(4));
    expect(PlayerPreloadSize.mb250.bytes, 250 * 1024 * 1024);
    expect(PlayerPreloadSize.mb500.bytes, 500 * 1024 * 1024);
    expect(PlayerPreloadSize.mb750.bytes, 750 * 1024 * 1024);
    expect(PlayerPreloadSize.gb1.bytes, 1024 * 1024 * 1024);
    expect(
      PlayerPreloadSize.gb1.label(lookupAppL10n(const Locale('zh'))),
      '1GB',
    );
    expect(PlayerPreloadSize.fromValue('500mb'), PlayerPreloadSize.mb500);
    expect(PlayerPreloadSize.fromValue(null), PlayerPreloadSize.mb250);
    expect(PlayerPreloadSize.fromValue('unsupported'), PlayerPreloadSize.mb250);
  });

  test('预载档位可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = PlayerSettingsRepository(prefs);

    await repository.save(
      const PlayerSettings(preloadSize: PlayerPreloadSize.gb1),
    );
    expect(repository.load().preloadSize, PlayerPreloadSize.gb1);

    SharedPreferences.setMockInitialValues({'player.preload_size': '750mb'});
    final restored = await SharedPreferences.getInstance();
    expect(
      PlayerSettingsRepository(restored).load().preloadSize,
      PlayerPreloadSize.mb750,
    );
  });

  test('播放器设置可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = PlayerSettingsRepository(prefs);
    const expected = PlayerSettings(
      resumeFromLastPosition: false,
      landscapeSide: PlayerLandscapeSide.cameraRight,
      entryOrientation: PlayerEntryOrientation.forcePortrait,
      orientationSensorUnlocked: false,
      preloadSize: PlayerPreloadSize.mb500,
      iosEngine: PlaybackEngineKind.ksPlayer,
      debugMode: true,
      doubleTapCenter: false,
      doubleTapEdges: true,
      hapticLongPress: false,
      hapticSeek: false,
      hapticRate: true,
      hapticProgressBar: false,
      showSystemTime: false,
      showNetworkSpeed: false,
      showCpuUsage: true,
      showBattery: false,
      showPlayPauseButton: false,
      showSeekButtons: false,
      showSpeedButton: true,
      showPipButton: false,
      showOrientationButton: false,
      showMediaSwitchButton: true,
    );

    await repository.save(expected);
    final actual = repository.load();

    expect(actual.resumeFromLastPosition, isFalse);
    expect(actual.landscapeSide, PlayerLandscapeSide.cameraRight);
    expect(actual.entryOrientation, PlayerEntryOrientation.forcePortrait);
    expect(actual.orientationSensorUnlocked, isFalse);
    expect(actual.preloadSize, PlayerPreloadSize.mb500);
    expect(actual.iosEngine, PlaybackEngineKind.ksPlayer);
    expect(actual.debugMode, isTrue);
    expect(actual.doubleTapCenter, isFalse);
    expect(actual.doubleTapEdges, isTrue);
    expect(actual.hapticLongPress, isFalse);
    expect(actual.hapticSeek, isFalse);
    expect(actual.hapticRate, isTrue);
    expect(actual.hapticProgressBar, isFalse);
    expect(actual.showSystemTime, isFalse);
    expect(actual.showNetworkSpeed, isFalse);
    expect(actual.showCpuUsage, isTrue);
    expect(actual.showBattery, isFalse);
    expect(actual.showPlayPauseButton, isFalse);
    expect(actual.showSeekButtons, isFalse);
    expect(actual.showSpeedButton, isTrue);
    expect(actual.showPipButton, isFalse);
    expect(actual.showOrientationButton, isFalse);
    expect(actual.showMediaSwitchButton, isTrue);
  });

  test('历史 avplayer 设置值读取后回退到 libmpv', () async {
    SharedPreferences.setMockInitialValues({
      PlayerEnginePreference.storageKey: 'avplayer',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      PlayerSettingsRepository(prefs).load().iosEngine,
      PlaybackEngineKind.libmpv,
    );
  });
}

// ==================== 原 test/features/player/video/player_debug_overlay_test.dart ====================
void _main_3() {
  test('媒体调试信息可以从 KSPlayer 原生事件解析', () {
    const json =
        '{"internal_player":"KSMEPlayer","video_codec":"hevc",'
        '"video_bitrate":8240000,"video_fps":23.976,'
        '"audio_codec":"aac"}';

    final info = PlaybackMediaInfo.fromJsonString(json);

    expect(info?.internalPlayer, 'KSMEPlayer');
    expect(info?.videoCodec, 'hevc');
    expect(info?.videoBitrate, 8240000);
    expect(info?.videoFps, 23.976);
    expect(info?.audioCodec, 'aac');
  });

  test('播放请求可以从容器提示和地址识别 KSPlayer 内部播放器', () {
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/video.mkv?token=1',
        null,
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/stream',
        'video/mp4',
      ),
      'AVPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/video.mp4',
        'mp4',
        videoCodec: 'hevc',
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'http://127.0.0.1:56386/proxy.mp4',
        null,
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/stream.m3u8',
        'matroska',
      ),
      'AVPlayer',
      reason: '网络 HLS 默认交给 AVPlayer，容器提示不再干预',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/live/index.m3u8?token=1',
        null,
        videoCodec: 'h264',
      ),
      'AVPlayer',
      reason: 'OMM/DBO 的网络 HLS 默认 AVPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/v/play',
        'hls',
      ),
      'AVPlayer',
      reason: 'hls 容器提示按网络 HLS 处理',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'https://example.com/live/index.m3u8?token=1',
        null,
        videoCodec: 'h264',
        preferFfmpegForHls: true,
      ),
      'KSMEPlayer',
      reason: '文件源显式要求 FFmpeg 播放 HLS',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        'http://127.0.0.1:56386/token.m3u8',
        null,
      ),
      'KSMEPlayer',
      reason: '回环代理上的 m3u8 始终是 KSMEPlayer',
    );
  });

  test('码率格式化为用户可读单位', () {
    expect(formatPlaybackBitrate(null), '--');
    expect(formatPlaybackBitrate(512000), '512 kbps');
    expect(formatPlaybackBitrate(8240000), '8.24 Mbps');
  });

  testWidgets('Debug OSD 只展示统一播放状态中的信息', (tester) async {
    final state = ValueNotifier(
      const PlaybackViewState(
        engineKind: PlaybackEngineKind.ksPlayer,
        videoSize: Size(1920, 1080),
        mediaInfo: PlaybackMediaInfo(
          container: 'matroska',
          videoCodec: 'hevc',
          videoBitrate: 8240000,
          videoFps: 23.976,
          internalPlayer: 'KSMEPlayer',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: PlayerDebugOverlay(stateListenable: state)),
      ),
    );

    expect(find.text('播放器内核：KSPlayer'), findsOneWidget);
    expect(find.text('内部播放器：KSMEPlayer'), findsOneWidget);
    expect(find.text('视频编码：hevc'), findsOneWidget);
    expect(find.text('视频码率：8.24 Mbps'), findsOneWidget);
    expect(find.text('帧率：23.98 fps'), findsOneWidget);
    expect(find.text('分辨率：1920×1080'), findsOneWidget);
  });
}

void main() {
  group('player_decode_status', _main_0);
  group('player_error_disposition', _main_1);
  group('player_settings', _main_2);
  group('player_debug_overlay', _main_3);
}
