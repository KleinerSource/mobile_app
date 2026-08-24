import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/core/models/playback.dart' as playback_models;
import 'package:md_center/features/player/playback_engine.dart';
import 'package:md_center/features/player/player_session_controller.dart';
import 'package:md_center/features/player/player_session_factory.dart';

import 'fake_playback_engine.dart';

void main() {
  test('两个内核执行相同命令序列产生一致统一状态', () async {
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

  test('AVPlayer 打开失败只回退一次并恢复位置、暂停状态和倍速', () async {
    final av = FakePlaybackEngine(
      PlaybackEngineKind.avPlayer,
      failOnOpen: true,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.avPlayer,
        position: Duration(seconds: 31),
        rate: 1.75,
        playing: false,
      ),
    );
    final fallback = FakePlaybackEngine(PlaybackEngineKind.libmpv);
    var fallbackCount = 0;
    final session = PlayerSessionController(
      engine: av,
      libmpvFallbackFactory: () {
        fallbackCount++;
        return fallback;
      },
    );

    await session.open('https://example.com/video.mp4');

    expect(fallbackCount, 1);
    expect(session.kind, PlaybackEngineKind.libmpv);
    expect(
      (session.position - const Duration(seconds: 31)).abs(),
      lessThanOrEqualTo(const Duration(seconds: 1)),
    );
    expect(session.playing, isFalse);
    expect(session.value.rate, 1.75);
    expect(fallback.openCount, 1);
    await session.dispose();
  });

  test('AVPlayer 播放决策失败时切换内核供重新决策且只允许一次', () async {
    final av = FakePlaybackEngine(PlaybackEngineKind.avPlayer);
    final fallback = FakePlaybackEngine(PlaybackEngineKind.libmpv);
    var fallbackCount = 0;
    final session = PlayerSessionController(
      engine: av,
      libmpvFallbackFactory: () {
        fallbackCount++;
        return fallback;
      },
    );

    expect(await session.fallbackToLibmpvForReload('decision failed'), isTrue);
    expect(session.kind, PlaybackEngineKind.libmpv);
    expect(fallback.openCount, 0);
    expect(av.commands, contains('dispose'));
    expect(await session.fallbackToLibmpvForReload('second failure'), isFalse);
    expect(fallbackCount, 1);
    await session.dispose();
  });

  test('统一会话按语言和标题映射 AVPlayer 原生音轨', () async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.avPlayer,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.avPlayer,
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

  test('未知 iOS 内核偏好安全回退 libmpv', () {
    expect(PlayerEnginePreference.fromValue(null), PlaybackEngineKind.libmpv);
    expect(
      PlayerEnginePreference.fromValue('future-engine'),
      PlaybackEngineKind.libmpv,
    );
    expect(
      PlayerEnginePreference.fromValue('avplayer'),
      PlaybackEngineKind.avPlayer,
    );
  });

  test('仅 iOS 采纳内核偏好和会话覆盖，其他平台固定 libmpv', () {
    expect(
      resolvePlaybackEngineKind(
        iosEnginePreference: PlaybackEngineKind.avPlayer,
        targetPlatform: TargetPlatform.iOS,
        isWeb: false,
      ),
      PlaybackEngineKind.avPlayer,
    );
    expect(
      resolvePlaybackEngineKind(
        engineKind: PlaybackEngineKind.avPlayer,
        targetPlatform: TargetPlatform.android,
        isWeb: false,
      ),
      PlaybackEngineKind.libmpv,
    );
    expect(
      resolvePlaybackEngineKind(
        engineKind: PlaybackEngineKind.avPlayer,
        targetPlatform: TargetPlatform.iOS,
        isWeb: true,
      ),
      PlaybackEngineKind.libmpv,
    );
  });
}
