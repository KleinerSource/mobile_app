// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/player/engine_playback_route_test.dart
//   - test/features/player/ks_player_media_hls_test.dart
//   - test/features/player/ks_player_seek_recovery_test.dart
//   - test/features/player/common/playback_engine_contract_test.dart
//   - test/features/db_online/pages/db_online_playback_entry_test.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/playback.dart';
import 'package:omm/core/models/playback.dart' as playback_models;
import 'package:omm/features/player/common/engine_playback_route.dart';
import 'package:omm/features/player/video/ks_player_playback_engine.dart';
import 'package:omm/features/player/video/ks_player_seek_recovery.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/video/video_player_page.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/features/player/video/video_player_session_factory.dart';
import 'fake_playback_engine.dart';

// ==================== 原 test/features/player/engine_playback_route_test.dart ====================
PlaybackDecision _decision({required bool hls}) => PlaybackDecision(
  mode: hls ? 'transcode' : 'direct_play',
  streamUrl: hls
      ? 'https://example.com/stream.m3u8'
      : 'https://example.com/video.mp4',
  directUrl: 'https://example.com/original.mkv',
  mimeType: hls ? 'application/vnd.apple.mpegurl' : 'video/mp4',
  hwAccel: '',
  targetVideo: '',
  targetAudio: '',
  targetHeight: 0,
  targetBitrate: 0,
  reasons: const [],
  audioTracks: const [],
  subtitleTracks: const [],
  startSec: 0,
);

void _main_0() {
  test('自动档先使用 direct_url(与引擎无关)', () {
    final route = playbackRouteForQuality(
      quality: 'auto',
      decision: _decision(hls: true),
    );

    expect(route.useBackendStream, isFalse);
    expect(route.useServerRoute, isFalse);
    expect(route.usesManagedTranscode, isFalse);
  });

  test('原生和固定档采用服务端决策地址(与引擎无关)', () {
    final originalDirect = playbackRouteForQuality(
      quality: 'original',
      decision: _decision(hls: false),
    );
    final originalTranscode = playbackRouteForQuality(
      quality: 'original',
      decision: _decision(hls: true),
    );
    final fixed = playbackRouteForQuality(
      quality: '720p',
      decision: _decision(hls: true),
    );

    expect(originalDirect.useBackendStream, isTrue);
    expect(originalDirect.useServerRoute, isFalse);
    expect(originalDirect.usesManagedTranscode, isFalse);
    for (final route in [originalTranscode, fixed]) {
      expect(route.useBackendStream, isTrue);
      expect(route.useServerRoute, isTrue);
      expect(route.usesManagedTranscode, isTrue);
    }
  });

  test('后端 HLS 使用目标编码选择 KSPlayer 内部播放器', () {
    const decision = PlaybackDecision(
      mode: 'transcode',
      streamUrl: 'https://example.com/stream.m3u8?quality=720p',
      directUrl: 'https://example.com/original.mkv',
      mimeType: 'application/vnd.apple.mpegurl',
      container: 'matroska,webm',
      videoCodec: 'hevc',
      bitRate: 20 * 1000 * 1000,
      hwAccel: 'videotoolbox',
      targetVideo: 'h264',
      targetAudio: 'aac',
      targetHeight: 720,
      targetBitrate: 4 * 1000 * 1000,
      reasons: [],
      audioTracks: [],
      subtitleTracks: [],
      startSec: 0,
    );

    final directInfo = playbackMediaInfoForDecision(decision);
    final hlsInfo = playbackMediaInfoForDecision(
      decision,
      preferTargetVideo: true,
    );

    expect(directInfo?.videoCodec, 'hevc');
    expect(hlsInfo?.videoCodec, 'h264');
    expect(hlsInfo?.videoBitrate, 4 * 1000 * 1000);
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        decision.directUrl,
        decision.container,
        videoCodec: directInfo?.videoCodec,
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        decision.streamUrl,
        null,
        videoCodec: hlsInfo?.videoCodec,
      ),
      'AVPlayer',
      reason: 'OMM 转码 HLS 交给 AVPlayer 串流',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        decision.streamUrl,
        null,
        preferFfmpegForHls: true,
      ),
      'KSMEPlayer',
      reason: '文件源显式要求 FFmpeg 时 HLS 才走 KSMEPlayer',
    );
  });

  test('服务器回退优先复用 HLS，否则要求强制视频转码重决策', () {
    final reuse = serverFallbackPlanFor(
      quality: 'auto',
      alreadyAttempted: false,
      usingHls: false,
      decision: _decision(hls: true),
    );
    final refresh = serverFallbackPlanFor(
      quality: 'original',
      alreadyAttempted: false,
      usingHls: false,
      decision: _decision(hls: false),
    );

    expect(reuse?.reuseDecision, isTrue);
    expect(reuse?.forceVideoTranscode, isFalse);
    expect(refresh?.reuseDecision, isFalse);
    expect(refresh?.forceVideoTranscode, isTrue);
  });

  test('固定档、已在 HLS 或已回退时不再自动回退', () {
    final decision = _decision(hls: true);
    expect(
      serverFallbackPlanFor(
        quality: '720p',
        alreadyAttempted: false,
        usingHls: false,
        decision: decision,
      ),
      isNull,
    );
    expect(
      serverFallbackPlanFor(
        quality: 'auto',
        alreadyAttempted: false,
        usingHls: true,
        decision: decision,
      ),
      isNull,
    );
    expect(
      serverFallbackPlanFor(
        quality: 'auto',
        alreadyAttempted: true,
        usingHls: false,
        decision: decision,
      ),
      isNull,
    );
  });

  test('KSPlayer PGS 与 burn_in 字幕要求后端重决策', () {
    const pgs = SubtitleTrack(
      id: 'pgs-1',
      index: 1,
      source: 'embedded',
      language: 'zh',
      title: 'PGS',
      codec: 'hdmv_pgs_subtitle',
      url: '',
      isDefault: false,
    );
    const burnIn = SubtitleTrack(
      id: 'dvd-2',
      index: 2,
      source: 'embedded',
      language: 'zh',
      title: 'VobSub',
      codec: 'dvd_subtitle',
      url: '',
      isDefault: false,
      renderMode: 'burn_in',
    );

    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.libmpv, pgs),
      isFalse,
    );
    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.ksPlayer, pgs),
      isTrue,
    );
    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.ksPlayer, burnIn),
      isTrue,
    );
  });
}

// ==================== 原 test/features/player/ks_player_media_hls_test.dart ====================
void _main_1() {
  test('按地址扩展名与容器提示识别 HLS', () {
    expect(
      KsPlayerPlaybackEngine.mediaIsHls(
        'http://10.0.0.50:9090/api/video/x/online-play/playlist.m3u8?target=a',
        null,
      ),
      isTrue,
      reason: '带查询参数的 m3u8 地址',
    );
    expect(
      KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/hls', 'mpegurl'),
      isTrue,
    );
    for (final hint in ['m3u8', 'hls', 'M3U8', ' HLS ']) {
      expect(
        KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/play', hint),
        isTrue,
        reason: 'hint=$hint',
      );
    }
  });

  test('普通媒体与回环代理文件不误判为 HLS', () {
    expect(
      KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/movie.mp4', null),
      isFalse,
    );
    expect(
      KsPlayerPlaybackEngine.mediaIsHls(
        'http://127.0.0.1:12345/token.mkv',
        null,
      ),
      isFalse,
    );
    expect(
      KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/movie.mp4', 'mp4'),
      isFalse,
    );
  });

  test('回环代理上的 m3u8 文件仍按 HLS 处理', () {
    expect(
      KsPlayerPlaybackEngine.mediaIsHls(
        'http://127.0.0.1:12345/tok.m3u8',
        null,
      ),
      isTrue,
    );
  });
}

// ==================== 原 test/features/player/ks_player_seek_recovery_test.dart ====================
void _main_2() {
  test('缓冲结束后停止观察', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 1),
        buffering: false,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.stop,
    );
  });

  test('缓冲窗口内每秒补发 play，窗口外只等待', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    for (final elapsed in [1, 3, 7]) {
      expect(
        policy.evaluate(
          elapsed: Duration(seconds: elapsed),
          buffering: true,
          lifecycle: PlaybackLifecycle.ready,
        ),
        KsPlayerSeekRecoveryAction.nudgePlay,
        reason: '第 $elapsed 秒仍缓冲应补发 play',
      );
    }
    for (final elapsed in [8, 15, 19]) {
      expect(
        policy.evaluate(
          elapsed: Duration(seconds: elapsed),
          buffering: true,
          lifecycle: PlaybackLifecycle.ready,
        ),
        KsPlayerSeekRecoveryAction.wait,
        reason: '第 $elapsed 秒已过补发窗口，只等待',
      );
    }
  });

  test('持续缓冲超过上限判定恢复失败', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 20),
        buffering: true,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.reportStalled,
    );
  });

  test('会话失效或已结束时停止观察，重新打开时等待', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    for (final lifecycle in [
      PlaybackLifecycle.idle,
      PlaybackLifecycle.stopped,
      PlaybackLifecycle.failed,
      PlaybackLifecycle.completed,
    ]) {
      expect(
        policy.evaluate(
          elapsed: const Duration(seconds: 2),
          buffering: true,
          lifecycle: lifecycle,
        ),
        KsPlayerSeekRecoveryAction.stop,
        reason: '$lifecycle 会话已结束',
      );
    }
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 2),
        buffering: true,
        lifecycle: PlaybackLifecycle.opening,
      ),
      KsPlayerSeekRecoveryAction.wait,
    );
  });

  test('自定义窗口与上限参与判定', () {
    const policy = KsPlayerSeekRecoveryPolicy(
      nudgeWindow: Duration(seconds: 2),
      stallTimeout: Duration(seconds: 5),
    );
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 2),
        buffering: true,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.wait,
    );
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 5),
        buffering: true,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.reportStalled,
    );
  });
}

// ==================== 原 test/features/player/playback_engine_contract_test.dart ====================
void _main_3() {
  test('所有内核执行相同命令序列产生一致统一状态', () async {
    final states = <PlaybackViewState>[];
    for (final kind in PlaybackEngineKind.values) {
      final engine = FakePlaybackEngine(kind);
      final session = PlayerSessionController(engine: engine);
      await session.open(
        'https://example.com/video.mp4',
        startAt: const Duration(seconds: 12),
      );
      await session.pause();
      await session.seek(const Duration(seconds: 42));
      await session.setRate(1.5);
      await session.setAudioTrackById('2');
      await session.setSubtitleTrackById('3');
      states.add(session.value);
      await session.dispose();
    }

    expect(states[0].lifecycle, states[1].lifecycle);
    expect(states[0].playing, states[1].playing);
    expect(states[0].position, states[1].position);
    expect(states[0].duration, states[1].duration);
    expect(states[0].rate, states[1].rate);
    expect(states[0].selectedAudioTrackId, states[1].selectedAudioTrackId);
    expect(
      states[0].selectedSubtitleTrackId,
      states[1].selectedSubtitleTrackId,
    );
  });

  test('播放中定位后恢复播放，暂停时定位保持暂停', () async {
    for (final kind in PlaybackEngineKind.values) {
      final playingEngine = FakePlaybackEngine(kind, pauseOnSeek: true);
      final playingSession = PlayerSessionController(engine: playingEngine);

      await playingSession.open('https://example.com/video.m3u8');
      await playingSession.seek(const Duration(seconds: 42));

      expect(playingEngine.commands, ['open', 'seek', 'play']);
      expect(playingSession.value.playing, isTrue);
      await playingSession.dispose();

      final pausedEngine = FakePlaybackEngine(kind, pauseOnSeek: true);
      final pausedSession = PlayerSessionController(engine: pausedEngine);

      await pausedSession.open('https://example.com/video.m3u8', play: false);
      await pausedSession.seek(const Duration(seconds: 42));

      expect(pausedEngine.commands, ['open', 'seek']);
      expect(pausedSession.value.playing, isFalse);
      await pausedSession.dispose();
    }
  });

  test('定位期间立即同步目标时间并忽略迟到的旧位置', () async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      seekDelay: const Duration(milliseconds: 40),
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        position: Duration(seconds: 2),
        duration: Duration(minutes: 3),
      ),
    );
    final session = PlayerSessionController(engine: engine);

    final seek = session.seek(const Duration(seconds: 12));
    expect(session.position, const Duration(seconds: 12));

    engine.emitPosition(const Duration(seconds: 2));
    expect(session.position, const Duration(seconds: 12));

    await seek;
    engine.emitPosition(const Duration(seconds: 2));
    expect(session.position, const Duration(seconds: 12));

    engine.emitPosition(const Duration(seconds: 13));
    expect(session.position, const Duration(seconds: 13));
    await session.dispose();
  });

  test('连续定位只保留最新目标并只恢复一次播放', () async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      seekDelay: const Duration(milliseconds: 20),
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        position: Duration(seconds: 2),
        duration: Duration(minutes: 3),
      ),
    );
    final session = PlayerSessionController(engine: engine);

    final firstSeek = session.seek(const Duration(seconds: 12));
    final secondSeek = session.seek(const Duration(seconds: 24));
    expect(session.position, const Duration(seconds: 24));

    await Future.wait([firstSeek, secondSeek]);

    expect(session.position, const Duration(seconds: 24));
    expect(engine.commands.where((command) => command == 'play'), hasLength(1));
    await session.dispose();
  });

  test('所有内核停止后可按续播位置和播放意图再次打开', () async {
    const resume = Duration(seconds: 84);
    for (final kind in PlaybackEngineKind.values) {
      for (final shouldPlay in [true, false]) {
        final engine = FakePlaybackEngine(kind);
        final session = PlayerSessionController(engine: engine);

        await session.open('https://example.com/first.mp4');
        await session.stop();
        await session.open(
          'https://example.com/second.m3u8',
          startAt: resume,
          play: shouldPlay,
        );

        expect(engine.commands, [
          'open',
          'stop',
          'open',
        ], reason: '$kind play=$shouldPlay');
        expect(engine.openCount, 2);
        expect(engine.lastOpenRequest?.url, 'https://example.com/second.m3u8');
        expect(engine.lastOpenRequest?.startAt, resume);
        expect(engine.lastOpenRequest?.play, shouldPlay);
        expect(session.value.lifecycle, PlaybackLifecycle.ready);
        expect(session.value.position, resume);
        expect(session.value.playing, shouldPlay);

        await session.dispose();
      }
    }
  });

  test('所有内核连续两次切源后仍可第三次打开', () async {
    const positions = [
      Duration(seconds: 12),
      Duration(seconds: 48),
      Duration(seconds: 84),
    ];
    for (final kind in PlaybackEngineKind.values) {
      final engine = FakePlaybackEngine(kind);
      final session = PlayerSessionController(engine: engine);

      for (var index = 0; index < positions.length; index++) {
        if (index > 0) await session.stop();
        await session.open(
          'https://example.com/quality-$index.m3u8',
          startAt: positions[index],
          play: index.isEven,
        );
      }

      expect(engine.commands, [
        'open',
        'stop',
        'open',
        'stop',
        'open',
      ], reason: '$kind');
      expect(engine.openCount, 3);
      expect(engine.lastOpenRequest?.startAt, positions.last);
      expect(engine.lastOpenRequest?.play, isTrue);
      expect(session.value.lifecycle, PlaybackLifecycle.ready);
      expect(session.value.position, positions.last);
      expect(session.value.playing, isTrue);

      await session.dispose();
    }
  });

  test('容器提示随统一会话传递给 KSPlayer', () async {
    final engine = FakePlaybackEngine(PlaybackEngineKind.ksPlayer);
    final session = PlayerSessionController(engine: engine);

    await session.open(
      'https://example.com/stream',
      formatHint: 'matroska,webm',
    );

    expect(engine.lastOpenRequest?.formatHint, 'matroska,webm');
    await session.dispose();
  });

  test('H.265 编码信息随统一会话传递给 KSPlayer', () async {
    final engine = FakePlaybackEngine(PlaybackEngineKind.ksPlayer);
    final session = PlayerSessionController(engine: engine);

    await session.open(
      'https://example.com/video.mp4',
      formatHint: 'mp4',
      mediaInfo: const PlaybackMediaInfo(videoCodec: 'hevc'),
    );

    expect(engine.lastOpenRequest?.mediaInfo?.videoCodec, 'hevc');
    await session.dispose();
  });

  test('统一会话按语言和标题映射原生音轨', () async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.ksPlayer,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.ksPlayer,
        audioTracks: [
          PlaybackAudioTrackState(
            id: 'native-en',
            title: 'Commentary',
            language: 'en',
            isSelected: false,
          ),
        ],
      ),
    );
    final session = PlayerSessionController(engine: engine);
    const backendTrack = playback_models.AudioTrack(
      index: 4,
      codec: 'aac',
      language: 'en',
      title: 'Commentary',
      channels: 2,
      isDefault: false,
    );

    expect(await session.trySelectAudioTrack(backendTrack, null), isTrue);
    expect(engine.commands, contains('audio:native-en'));
    await session.dispose();
  });

  test('KSPlayer 不直接使用后端音轨 index，而是映射原生音轨 ID', () async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.ksPlayer,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.ksPlayer,
        audioTracks: [
          PlaybackAudioTrackState(
            id: 'native-en',
            title: 'Commentary',
            language: 'en',
            isSelected: false,
          ),
        ],
      ),
    );
    final session = PlayerSessionController(engine: engine);
    const backendTrack = playback_models.AudioTrack(
      index: 4,
      codec: 'aac',
      language: 'en',
      title: 'Commentary',
      channels: 2,
      isDefault: false,
    );

    expect(await session.trySelectAudioTrack(backendTrack, null), isTrue);
    expect(engine.commands, contains('audio:native-en'));
    expect(engine.commands, isNot(contains('audio:4')));
    await session.dispose();
  });

  test('KSPlayer 在语言和标题不匹配时按音轨 ordinal 映射', () async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.ksPlayer,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.ksPlayer,
        audioTracks: [
          PlaybackAudioTrackState(
            id: 'native-1',
            title: 'Track 1',
            language: 'und',
            isSelected: false,
          ),
          PlaybackAudioTrackState(
            id: 'native-2',
            title: 'Track 2',
            language: 'und',
            isSelected: false,
          ),
        ],
      ),
    );
    final session = PlayerSessionController(engine: engine);
    const first = playback_models.AudioTrack(
      index: 2,
      codec: 'aac',
      language: 'de',
      title: 'German',
      channels: 2,
      isDefault: false,
    );
    const second = playback_models.AudioTrack(
      index: 7,
      codec: 'aac',
      language: 'fr',
      title: 'French',
      channels: 2,
      isDefault: false,
    );
    const decision = playback_models.PlaybackDecision(
      mode: 'direct_play',
      streamUrl: 'https://example.com/video.mkv',
      mimeType: 'video/x-matroska',
      hwAccel: '',
      targetVideo: '',
      targetAudio: '',
      targetHeight: 0,
      targetBitrate: 0,
      reasons: [],
      audioTracks: [first, second],
      subtitleTracks: [],
      startSec: 0,
    );

    expect(await session.trySelectAudioTrack(second, decision), isTrue);
    expect(engine.commands, contains('audio:native-2'));
    expect(engine.commands, isNot(contains('audio:7')));
    await session.dispose();
  });

  test('KSPlayer 单音轨不调用原生切换命令', () async {
    final engine = FakePlaybackEngine(PlaybackEngineKind.ksPlayer);
    final session = PlayerSessionController(engine: engine);
    const backendTrack = playback_models.AudioTrack(
      index: 4,
      codec: 'aac',
      language: 'en',
      title: 'English',
      channels: 2,
      isDefault: true,
    );
    const decision = playback_models.PlaybackDecision(
      mode: 'direct_play',
      streamUrl: 'https://example.com/video.mp4',
      mimeType: 'video/mp4',
      hwAccel: '',
      targetVideo: '',
      targetAudio: '',
      targetHeight: 0,
      targetBitrate: 0,
      reasons: [],
      audioTracks: [backendTrack],
      subtitleTracks: [],
      startSec: 0,
    );

    expect(
      await session
          .trySelectAudioTrack(backendTrack, decision)
          .timeout(const Duration(milliseconds: 100)),
      isTrue,
    );
    expect(
      engine.commands.where((command) => command.startsWith('audio:')),
      isEmpty,
    );
    await session.dispose();
  });

  test('libmpv 仍按后端音轨 index 选择', () async {
    final engine = FakePlaybackEngine(PlaybackEngineKind.libmpv);
    final session = PlayerSessionController(engine: engine);
    const backendTrack = playback_models.AudioTrack(
      index: 4,
      codec: 'aac',
      language: 'en',
      title: 'English',
      channels: 2,
      isDefault: false,
    );

    expect(await session.trySelectAudioTrack(backendTrack, null), isTrue);
    expect(engine.commands, contains('audio:4'));
    await session.dispose();
  });

  test('未知 iOS 内核偏好安全回退 libmpv', () {
    expect(PlayerEnginePreference.fromValue(null), PlaybackEngineKind.libmpv);
    expect(
      PlayerEnginePreference.fromValue('future-engine'),
      PlaybackEngineKind.libmpv,
    );
    expect(
      PlayerEnginePreference.fromValue('avplayer'),
      PlaybackEngineKind.libmpv,
    );
    expect(
      PlayerEnginePreference.fromValue('ksplayer'),
      PlaybackEngineKind.ksPlayer,
    );
  });

  test('仅 iOS 采纳内核偏好和会话覆盖，其他平台固定 libmpv', () {
    expect(
      resolvePlaybackEngineKind(
        iosEnginePreference: PlaybackEngineKind.ksPlayer,
        targetPlatform: TargetPlatform.iOS,
        isWeb: false,
      ),
      PlaybackEngineKind.ksPlayer,
    );
    expect(
      resolvePlaybackEngineKind(
        engineKind: PlaybackEngineKind.ksPlayer,
        targetPlatform: TargetPlatform.android,
        isWeb: false,
      ),
      PlaybackEngineKind.libmpv,
    );
    expect(
      resolvePlaybackEngineKind(
        engineKind: PlaybackEngineKind.ksPlayer,
        targetPlatform: TargetPlatform.iOS,
        isWeb: true,
      ),
      PlaybackEngineKind.libmpv,
    );
    expect(
      availablePlaybackEngineKinds(
        targetPlatform: TargetPlatform.iOS,
        isWeb: false,
      ),
      [PlaybackEngineKind.libmpv, PlaybackEngineKind.ksPlayer],
    );
    expect(
      availablePlaybackEngineKinds(
        targetPlatform: TargetPlatform.android,
        isWeb: false,
      ),
      [PlaybackEngineKind.libmpv],
    );
  });

  test('KSPlayer 失败不会自动切换内核', () async {
    final ks = FakePlaybackEngine(PlaybackEngineKind.ksPlayer);
    final session = PlayerSessionController(engine: ks);
    ks.notifier.value = ks.notifier.value.copyWith(
      lifecycle: PlaybackLifecycle.failed,
      error: 'KSPlayer failed',
    );
    expect(session.kind, PlaybackEngineKind.ksPlayer);
    await session.dispose();
  });

  test('KSPlayer 打开期间和播放后的迟到错误被忽略', () {
    const opening = PlaybackViewState(
      engineKind: PlaybackEngineKind.ksPlayer,
      lifecycle: PlaybackLifecycle.opening,
    );
    const playing = PlaybackViewState(
      engineKind: PlaybackEngineKind.ksPlayer,
      lifecycle: PlaybackLifecycle.ready,
      playing: true,
      firstFrameRendered: true,
      position: Duration(seconds: 1),
    );
    const pausedAtFirstFrame = PlaybackViewState(
      engineKind: PlaybackEngineKind.ksPlayer,
      lifecycle: PlaybackLifecycle.ready,
      firstFrameRendered: true,
    );

    expect(shouldIgnoreKsPlayerError(opening), isTrue);
    expect(shouldIgnoreKsPlayerError(playing), isTrue);
    expect(shouldIgnoreKsPlayerError(pausedAtFirstFrame), isFalse);
  });
}

// ==================== 原 test/features/db_online/pages/db_online_playback_entry_test.dart ====================
void _main_4() {
  test('dbonline 直连播放器入口不需要 OMM 整数影片 ID', () {
    const page = VideoPlayerPage.direct(
      title: 'ABC-001 · 第 1 集',
      directUrl: 'https://example.test/api/video/ABC-001/playlist.m3u8',
    );

    expect(page.movieId, isNull);
    expect(page.directUrl, contains('.m3u8'));
    expect(page.title, contains('ABC-001'));
  });
}

void main() {
  group('engine_playback_route', _main_0);
  group('ks_player_media_hls', _main_1);
  group('ks_player_seek_recovery', _main_2);
  group('playback_engine_contract', _main_3);
  group('db_online_playback_entry', _main_4);
}
