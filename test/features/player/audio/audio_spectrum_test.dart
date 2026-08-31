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

  test('环形频谱使用青蓝青绿暖黄，歌词频谱只使用单色前景', () {
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
      Color(0xFF20B8E8),
      Color(0xFF35D6A3),
      Color(0xFFF4C84B),
    ]);
    expect(lyrics.color, Colors.black);
  });

  testWidgets('全屏玻璃覆盖安全区并位于背景频谱和前景之间', (tester) async {
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
    expect(layers.children[2], isA<AudioPlayerGlassVeil>());
    expect(layers.children[3], isA<SafeArea>());

    final glass = find.byKey(const ValueKey<String>('audio-player-glass-veil'));
    expect(tester.getTopLeft(glass), Offset.zero);
    expect(
      tester.getSize(glass),
      tester.getSize(find.byKey(const ValueKey<String>('surface'))),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('foreground'))).dy,
      32,
    );
  });
}
