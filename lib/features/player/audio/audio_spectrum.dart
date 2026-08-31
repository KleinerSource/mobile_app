import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

final class AudioNowPlayingGeometry {
  const AudioNowPlayingGeometry({
    required this.recordSize,
    required this.deckSize,
    required this.lyricsWidth,
    required this.stageWidth,
    required this.stageHeight,
  });

  static const double lyricsSlotHeight = 128;
  static const double lyricsTopInset = 38;
  static const double stageTopInset = 98;
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
