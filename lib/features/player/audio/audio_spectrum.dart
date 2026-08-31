import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

import 'audio_player_theme.dart';

final class AudioNowPlayingGeometry {
  const AudioNowPlayingGeometry({
    required this.recordSize,
    required this.deckSize,
    required this.lyricsWidth,
    required this.stageWidth,
    required this.stageHeight,
  });

  static const double lyricsSlotHeight = 108;

  final double recordSize;
  final double deckSize;
  final double lyricsWidth;
  final double stageWidth;
  final double stageHeight;

  factory AudioNowPlayingGeometry.fromConstraints(BoxConstraints constraints) {
    final maxWidth = math.max(0.0, constraints.maxWidth - 48);
    final maxHeight = math.max(0.0, constraints.maxHeight * 0.52);
    final recordSize = math.min(math.min(maxWidth, maxHeight), 380.0);
    final deckSize = recordSize + 28;
    final lyricsWidth = math.min(maxWidth, 420.0);
    return AudioNowPlayingGeometry(
      recordSize: recordSize,
      deckSize: deckSize,
      lyricsWidth: lyricsWidth,
      stageWidth: math.max(deckSize, lyricsWidth),
      stageHeight: deckSize + lyricsSlotHeight,
    );
  }
}

class AudioSpectrumBackdrop extends StatelessWidget {
  const AudioSpectrumBackdrop({super.key, required this.spectrum});

  final ValueListenable<AudioSpectrumFrame> spectrum;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = AudioNowPlayingGeometry.fromConstraints(constraints);
        final spectrumSize = geometry.recordSize + 72;
        return Align(
          alignment: const Alignment(0, -0.18),
          child: SizedBox(
            width: geometry.stageWidth,
            height: geometry.stageHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: SizedBox.square(
                  dimension: spectrumSize,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<AudioSpectrumFrame>(
                      valueListenable: spectrum,
                      builder: (_, frame, _) => RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey<String>(
                            'audio-circular-spectrum',
                          ),
                          painter: CircularAudioSpectrumPainter(
                            frame: frame,
                            recordRadius: geometry.recordSize / 2,
                            palette: AudioPlayerTheme.spectrumPalette,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CircularAudioSpectrumPainter extends CustomPainter {
  const CircularAudioSpectrumPainter({
    required this.frame,
    required this.recordRadius,
    required this.palette,
  });

  final AudioSpectrumFrame frame;
  final double recordRadius;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.isSilent || frame.bands.isEmpty || palette.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = recordRadius + 5;
    final maxLength = math.max(0.0, size.shortestSide / 2 - baseRadius - 2);
    if (maxLength <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < frame.bands.length; index++) {
      final fraction = index / frame.bands.length;
      final energy = frame.bands[index].clamp(0.0, 1.0);
      final angle = -math.pi / 2 + math.pi * 2 * fraction;
      final length = 3 + maxLength * (energy * 0.85 + frame.peak * 0.15);
      final opacity = (0.34 + math.max(energy, frame.rms) * 0.66).clamp(
        0.0,
        1.0,
      );
      paint.color = _paletteColor(palette, fraction).withValues(alpha: opacity);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * baseRadius,
        center + direction * (baseRadius + length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CircularAudioSpectrumPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.recordRadius != recordRadius ||
        !listEquals(oldDelegate.palette, palette);
  }
}

class LyricsAudioSpectrum extends StatelessWidget {
  const LyricsAudioSpectrum({
    super.key,
    required this.spectrum,
    required this.color,
  });

  final ValueListenable<AudioSpectrumFrame> spectrum;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 20,
      child: IgnorePointer(
        child: ValueListenableBuilder<AudioSpectrumFrame>(
          valueListenable: spectrum,
          builder: (_, frame, _) => CustomPaint(
            key: const ValueKey<String>('audio-lyrics-spectrum'),
            painter: LyricsAudioSpectrumPainter(frame: frame, color: color),
          ),
        ),
      ),
    );
  }
}

class LyricsAudioSpectrumPainter extends CustomPainter {
  const LyricsAudioSpectrumPainter({required this.frame, required this.color});

  final AudioSpectrumFrame frame;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.isSilent || frame.bands.isEmpty) return;
    final centerY = size.height / 2;
    final step = size.width / frame.bands.length;
    final paint = Paint()
      ..strokeWidth = math.min(2.2, step * 0.48)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < frame.bands.length; index++) {
      final energy = frame.bands[index].clamp(0.0, 1.0);
      final halfHeight = 1 + (size.height / 2 - 1) * energy;
      paint.color = color.withValues(
        alpha: (0.12 + math.max(energy, frame.rms) * 0.28).clamp(0.0, 0.4),
      );
      final x = step * (index + 0.5);
      canvas.drawLine(
        Offset(x, centerY - halfHeight),
        Offset(x, centerY + halfHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LyricsAudioSpectrumPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.color != color;
  }
}

Color _paletteColor(List<Color> palette, double fraction) {
  if (palette.length == 1) return palette.first;
  final scaled = fraction.clamp(0.0, 1.0) * (palette.length - 1);
  final start = scaled.floor().clamp(0, palette.length - 1);
  final end = math.min(start + 1, palette.length - 1);
  return Color.lerp(palette[start], palette[end], scaled - start) ??
      palette[start];
}
