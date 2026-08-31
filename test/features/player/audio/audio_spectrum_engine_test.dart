import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/audio/audio_playback_engine.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('播放位置驱动真实频谱轮询，暂停切歌和释放后立即归零', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final requestedPositions = <int>[];
    var preparedSourceId = '';
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          preparedSourceId = _arguments(call)['sourceId']!.toString();
          if (preparedSourceId == 'track-b') {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          return _scratchState(preparedSourceId);
        case 'spectrum':
          requestedPositions.add(
            (_arguments(call)['positionMs'] as num).toInt(),
          );
          return <String, Object>{
            'rms': 0.35,
            'peak': 0.8,
            'bands': List<double>.filled(48, 0.5),
            'ready': true,
            'sourceId': preparedSourceId,
          };
        case 'stop':
          return null;
      }
      return null;
    });

    final handler = _SpectrumAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    final spectrum = engine.spectrum;
    AudioSpectrumFrame lastFrame = spectrum.value;
    var disposed = false;
    void captureFrame() => lastFrame = spectrum.value;
    spectrum.addListener(captureFrame);
    try {
      await Future<void>.delayed(Duration.zero);
      handler.mediaItem.add(
        const audio_service.MediaItem(
          id: 'track-a',
          title: 'A',
          duration: Duration(minutes: 2),
          extras: <String, Object>{'audioUrl': 'file:///track-a.flac'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      handler.playbackState.add(_playingState(const Duration(seconds: 12)));
      await Future<void>.delayed(const Duration(milliseconds: 140));

      expect(spectrum.value.ready, isTrue);
      expect(requestedPositions.length, greaterThanOrEqualTo(2));
      expect(requestedPositions.last, greaterThan(requestedPositions.first));

      final samplesBeforeSuspend = requestedPositions.length;
      engine.setVisualEffectsSuspended(true);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(spectrum.value.isSilent, isTrue);
      expect(requestedPositions.length, samplesBeforeSuspend);

      engine.setVisualEffectsSuspended(false);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(spectrum.value.ready, isTrue);
      expect(requestedPositions.length, greaterThan(samplesBeforeSuspend));

      handler.playbackState.add(
        _playingState(const Duration(seconds: 13), playing: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(spectrum.value.isSilent, isTrue);

      handler.playbackState.add(_playingState(const Duration(seconds: 14)));
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(spectrum.value.ready, isTrue);
      handler.mediaItem.add(
        const audio_service.MediaItem(
          id: 'track-b',
          title: 'B',
          duration: Duration(minutes: 2),
          extras: <String, Object>{'audioUrl': 'file:///track-b.flac'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(spectrum.value.isSilent, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(spectrum.value.ready, isTrue);
      await engine.dispose();
      disposed = true;
      expect(lastFrame.isSilent, isTrue);
    } finally {
      if (!disposed) await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Map<Object?, Object?> _arguments(MethodCall call) =>
    (call.arguments as Map).cast<Object?, Object?>();

Map<String, Object> _scratchState(String sourceId) => <String, Object>{
  'positionMs': 0,
  'durationMs': 120000,
  'rate': 1.0,
  'playing': false,
  'ready': true,
  'outputReady': true,
  'lastWriteResult': 1024,
  'sourceId': sourceId,
};

audio_service.PlaybackState _playingState(
  Duration position, {
  bool playing = true,
}) {
  return audio_service.PlaybackState(
    processingState: audio_service.AudioProcessingState.ready,
    playing: playing,
    updatePosition: position,
    speed: 1,
  );
}

class _SpectrumAudioHandler extends audio_service.BaseAudioHandler {
  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    return null;
  }
}
