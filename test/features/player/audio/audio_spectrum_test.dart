import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/audio/audio_player_layers.dart';
import 'package:omm/features/player/audio/audio_player_theme.dart';
import 'package:omm/features/player/audio/audio_spectrum.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

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

  test('环形频谱按音频强度选择七彩色，歌词频谱只使用单色前景', () {
    final frame = AudioSpectrumFrame(
      rms: 0.3,
      peak: 0.7,
      bands: List<double>.filled(48, 0.5),
      ready: true,
      sourceId: 'track-a',
    );
    final circular = CircularAudioSpectrumPainter(
      frame: frame,
      recordRadius: 120,
      palette: AudioPlayerTheme.spectrumPalette,
    );
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

    expect(circular.palette, const <Color>[
      Color(0xFF8A63FF),
      Color(0xFF3D8BFF),
      Color(0xFF30D5C8),
      Color(0xFF4DDC78),
      Color(0xFFFFD43B),
      Color(0xFFFF8A3D),
      Color(0xFFFF4B4B),
    ]);
    for (var index = 0; index < circular.palette.length; index++) {
      final intensity = (index + 0.1) / circular.palette.length;
      expect(
        CircularAudioSpectrumPainter.colorForIntensity(
          circular.palette,
          intensity,
        ),
        circular.palette[index],
      );
    }
    expect(
      CircularAudioSpectrumPainter.colorForIntensity(circular.palette, 1),
      circular.palette.last,
    );
    final layerColors = List<Color>.generate(
      CircularAudioSpectrumPainter.layerCount,
      (layer) => CircularAudioSpectrumPainter.colorForLayer(
        circular.palette,
        1,
        layer,
      ),
    );
    expect(layerColors.toSet().length, CircularAudioSpectrumPainter.layerCount);
    expect(
      CircularAudioSpectrumPainter.colorForLayer(circular.palette, 0.9, 3),
      isNot(
        CircularAudioSpectrumPainter.colorForLayer(circular.palette, 0.2, 3),
      ),
    );
    expect(lyrics.color, Colors.black);
    expect(CircularAudioSpectrumPainter.minimumOpacity, greaterThan(0.5));
    expect(AudioSpectrumBackdrop.spectrumOuterPadding, greaterThan(104));
    expect(CircularAudioSpectrumPainter.minimumLength, 0);
    expect(CircularAudioSpectrumPainter.silenceThreshold, greaterThan(0));
    expect(
      CircularAudioSpectrumPainter.amplitudeFor(energy: 0, rms: 0, peak: 0),
      0,
    );
    expect(
      CircularAudioSpectrumPainter.amplitudeFor(energy: 1, rms: 1, peak: 1),
      closeTo(1, 1e-12),
    );
    expect(
      CircularAudioSpectrumPainter.amplitudeFor(
        energy: 0,
        rms: CircularAudioSpectrumPainter.silenceThreshold * 0.5,
        peak: CircularAudioSpectrumPainter.silenceThreshold * 0.5,
      ),
      0,
    );
    expect(
      CircularAudioSpectrumPainter.haloStrokeWidth,
      greaterThan(CircularAudioSpectrumPainter.glowStrokeWidth),
    );
    expect(CircularAudioSpectrumPainter.haloBlurSigma, greaterThan(0));
    expect(CircularAudioSpectrumPainter.glowBlurSigma, greaterThan(0));
    expect(CircularAudioSpectrumPainter.layerCount, greaterThan(1));
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

  testWidgets('环形频谱画布中心与唱片中心重合', (tester) async {
    final spectrum = ValueNotifier<AudioSpectrumFrame>(
      AudioSpectrumFrame(
        rms: 0.6,
        peak: 0.9,
        bands: List<double>.filled(48, 0.8),
        ready: true,
        sourceId: 'track-a',
      ),
    );
    addTearDown(spectrum.dispose);
    const viewport = Size(430, 839);
    final geometry = AudioNowPlayingGeometry.fromConstraints(
      BoxConstraints.tightFor(width: viewport.width, height: viewport.height),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: AudioSpectrumBackdrop(spectrum: spectrum),
          ),
        ),
      ),
    );

    final spectrumBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('audio-circular-spectrum')),
    );
    final spectrumCenter = spectrumBox.localToGlobal(
      Offset(spectrumBox.size.width / 2, spectrumBox.size.height / 2),
    );
    expect(
      spectrumBox.size,
      Size.square(
        geometry.recordSize + AudioSpectrumBackdrop.spectrumOuterPadding,
      ),
    );
    final expectedCenter = Offset(
      viewport.width / 2,
      AudioNowPlayingGeometry.stageTopInset + geometry.deckSize / 2,
    );
    expect(spectrumCenter, expectedCenter);
  });

  testWidgets('背景频谱直接位于纯色基底与前景之间且不存在毛玻璃层', (tester) async {
    final spectrum = ValueNotifier<AudioSpectrumFrame>(
      AudioSpectrumFrame.silence(),
    );
    addTearDown(spectrum.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.fromLTRB(0, 32, 0, 24),
          ),
          child: AudioPlayerTheme(
            child: Scaffold(
              body: AudioPlayerVisualLayers(
                surface: const ColoredBox(
                  key: ValueKey<String>('surface'),
                  color: Colors.white,
                ),
                spectrum: spectrum,
                child: const ColoredBox(
                  key: ValueKey<String>('foreground'),
                  color: Colors.transparent,
                ),
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
    expect(layers.children[1], isA<SafeArea>());
    expect(layers.children[2], isA<SafeArea>());
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('audio-player-glass-veil')),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('foreground'))).dy,
      32,
    );
  });

  testWidgets('暂停视觉效果后恢复时重新挂载频谱层', (tester) async {
    final spectrum = ValueNotifier<AudioSpectrumFrame>(
      AudioSpectrumFrame.silence(),
    );
    addTearDown(spectrum.dispose);
    var suspended = true;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return AudioPlayerVisualLayers(
              surface: const ColoredBox(color: Colors.black),
              spectrum: spectrum,
              effectsSuspended: suspended,
              child: const SizedBox(key: ValueKey<String>('foreground')),
            );
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('audio-spectrum-layer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('audio-player-foreground-layer')),
      findsOneWidget,
    );

    update(() => suspended = false);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('audio-spectrum-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('audio-player-foreground-layer')),
      findsOneWidget,
    );
  });
}
