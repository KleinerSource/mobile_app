import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/core/models/playback.dart' as playback_models;
import 'package:md_center/features/player/playback_engine.dart';
import 'package:md_center/features/player/ks_player_playback_engine.dart';
import 'package:md_center/features/player/player_session_controller.dart';
import 'package:md_center/features/player/player_session_factory.dart';

import 'fake_playback_engine.dart';

void main() {
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

  test('KSPlayer 首帧前错误仍然保留，播放后的迟到错误被忽略', () {
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

    expect(shouldIgnoreKsPlayerError(opening), isFalse);
    expect(shouldIgnoreKsPlayerError(playing), isTrue);
    expect(shouldIgnoreKsPlayerError(pausedAtFirstFrame), isFalse);
  });
}
