import 'dart:math' as math;
import 'dart:ui' as ui;

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
  static const double stageTopInset = 78;
  static const double maxRecordSize = 300;

  final double recordSize;
  final double deckSize;
  final double lyricsWidth;
  final double stageWidth;
  final double stageHeight;

  factory AudioNowPlayingGeometry.fromConstraints(BoxConstraints constraints) {
    final maxWidth = math.max(0.0, constraints.maxWidth - 48);
    final layoutHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : 932.0;
    final maxHeight = math.max(0.0, layoutHeight * 0.52);
    final recordSize = math.min(math.min(maxWidth, maxHeight), maxRecordSize);
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

  static const double spectrumOuterPadding = 136;

  final ValueListenable<AudioSpectrumFrame> spectrum;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = AudioNowPlayingGeometry.fromConstraints(constraints);
        final spectrumSize = geometry.recordSize + spectrumOuterPadding;
        final spectrumOffsetY = (geometry.deckSize - spectrumSize) / 2;
        return Padding(
          padding: const EdgeInsets.only(
            top: AudioNowPlayingGeometry.stageTopInset,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: const ValueKey<String>('audio-spectrum-stage'),
              width: geometry.stageWidth,
              height: geometry.stageHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minWidth: spectrumSize,
                  maxWidth: spectrumSize,
                  minHeight: spectrumSize,
                  maxHeight: spectrumSize,
                  child: Transform.translate(
                    offset: Offset(0, spectrumOffsetY),
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

  static const double strokeWidth = 5;
  static const double glowStrokeWidth = 18;
  static const double haloStrokeWidth = 32;
  static const double haloBlurSigma = 12;
  static const double glowBlurSigma = 5;
  static const double minimumLength = 14;
  static const double minimumOpacity = 0.82;

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
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowStrokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        glowBlurSigma,
      );
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = haloStrokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        haloBlurSigma,
      );
    for (var index = 0; index < frame.bands.length; index++) {
      final fraction = index / frame.bands.length;
      final energy = frame.bands[index].clamp(0.0, 1.0);
      final angle = -math.pi / 2 + math.pi * 2 * fraction;
      final volume = (frame.rms * 0.7 + frame.peak * 0.3).clamp(0.0, 1.0);
      final response = (energy * 0.72 + volume * 0.18 + frame.peak * 0.10)
          .clamp(0.0, 1.0);
      final length = minimumLength + maxLength * response;
      final opacity =
          (minimumOpacity + math.max(energy, frame.rms) * (1 - minimumOpacity))
              .clamp(0.0, 1.0);
      final color = colorForIntensity(palette, energy);
      haloPaint.color = color.withValues(alpha: opacity * 0.30);
      glowPaint.color = color.withValues(alpha: opacity * 0.52);
      paint.color = color.withValues(alpha: opacity);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * baseRadius;
      final end = center + direction * (baseRadius + length);
      canvas.drawLine(start, end, haloPaint);
      canvas.drawLine(start, end, glowPaint);
      canvas.drawLine(start, end, paint);
    }
  }

  static Color colorForIntensity(List<Color> palette, double intensity) {
    if (palette.isEmpty) return Colors.transparent;
    if (palette.length == 1) return palette.first;
    final normalized = intensity.clamp(0.0, 1.0).toDouble();
    final index = (normalized * palette.length).floor().clamp(
      0,
      palette.length - 1,
    );
    return palette[index];
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
