import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/audio/audio_player_layers.dart';
import 'package:omm/features/player/audio/audio_spectrum.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  test('频谱帧会归一化异常数值并补齐固定频段', () {
    final frame = AudioSpectrumFrame.fromObject({
      'rms': 1.4,
      'peak': -0.2,
      'bands': <Object?>[0.25, double.nan, 2, -1],
      'ready': true,
      'sourceId': 'track-a',
    }, bandCount: 8);

    expect(frame.rms, 1);
    expect(frame.peak, 0);
    expect(frame.bands, <double>[0.25, 0, 1, 0, 0, 0, 0, 0]);
    expect(frame.ready, isTrue);
    expect(frame.sourceId, 'track-a');
    expect(frame.isSilent, isFalse);
  });

  test('直线频谱使用单色前景', () {
    const lyrics = LyricsAudioSpectrumPainter(
      frame: AudioSpectrumFrame(
        rms: 0.3,
        peak: 0.7,
        bands: <double>[0.5],
        ready: true,
        sourceId: 'track-a',
      ),
      color: Colors.black,
    );

    expect(lyrics.color, Colors.black);
    expect(lyrics.shouldRepaint(lyrics), isFalse);
  });

  test('唱机舞台下移并为歌词和底部进度条保留间距', () {
    const height = 839.0;
    const progressTopFromBottom = 208.0;
    final geometry = AudioNowPlayingGeometry.fromConstraints(
      const BoxConstraints.tightFor(width: 430, height: height),
    );
    final stageBottom =
        AudioNowPlayingGeometry.stageTopInset + geometry.stageHeight;
    final progressTop = height - progressTopFromBottom;

    expect(AudioNowPlayingGeometry.stageTopInset, 98);
    expect(AudioNowPlayingGeometry.lyricsTopInset, 38);
    expect(AudioNowPlayingGeometry.lyricsSlotHeight, 128);
    expect(AudioNowPlayingGeometry.maxRecordSize, 300);
    expect(geometry.recordSize, AudioNowPlayingGeometry.maxRecordSize);
    expect(stageBottom, lessThanOrEqualTo(progressTop - 16));
  });

  testWidgets('播放器视觉图层不挂载圆形频谱', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.fromLTRB(0, 32, 0, 24),
          ),
          child: Scaffold(
            body: AudioPlayerVisualLayers(
              surface: ColoredBox(
                key: ValueKey<String>('surface'),
                color: Colors.white,
              ),
              child: ColoredBox(
                key: ValueKey<String>('foreground'),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );

    final layers = tester.widget<Stack>(
      find.byKey(const ValueKey<String>('audio-player-visual-layers')),
    );
    expect(layers.children[0].key, const ValueKey<String>('surface'));
    expect(layers.children.length, 2);
    expect(layers.children[1], isA<SafeArea>());
    expect(
      find.byKey(const ValueKey<String>('audio-player-glass-veil')),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('foreground'))).dy,
      32,
    );
    expect(
      find.byKey(const ValueKey<String>('audio-player-foreground-layer')),
      findsOneWidget,
    );
  });
}
