import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

import 'audio_player_theme.dart';
import 'audio_spectrum.dart';

class AudioPlayerVisualLayers extends StatelessWidget {
  const AudioPlayerVisualLayers({
    super.key,
    required this.surface,
    required this.spectrum,
    required this.child,
  });

  final Widget surface;
  final ValueListenable<AudioSpectrumFrame> spectrum;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey<String>('audio-player-visual-layers'),
      fit: StackFit.expand,
      children: [
        surface,
        SafeArea(child: AudioSpectrumBackdrop(spectrum: spectrum)),
        const AudioPlayerGlassVeil(),
        SafeArea(child: child),
      ],
    );
  }
}

class AudioPlayerGlassVeil extends StatelessWidget {
  const AudioPlayerGlassVeil({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ClipRect(
      key: const ValueKey<String>('audio-player-glass-veil'),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AudioPlayerTheme.glassBlurSigma,
          sigmaY: AudioPlayerTheme.glassBlurSigma,
        ),
        child: ColoredBox(color: AudioPlayerTheme.glassTintFor(brightness)),
      ),
    );
  }
}
