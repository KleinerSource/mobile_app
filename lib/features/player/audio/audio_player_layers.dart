import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

import 'audio_spectrum.dart';

class AudioPlayerVisualLayers extends StatelessWidget {
  const AudioPlayerVisualLayers({
    super.key,
    required this.surface,
    required this.spectrum,
    required this.child,
    this.effectsSuspended = false,
  });

  final Widget surface;
  final ValueListenable<AudioSpectrumFrame> spectrum;
  final Widget child;
  final bool effectsSuspended;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey<String>('audio-player-visual-layers'),
      fit: StackFit.expand,
      children: [
        surface,
        if (!effectsSuspended)
          SafeArea(
            key: const ValueKey<String>('audio-spectrum-layer'),
            child: AudioSpectrumBackdrop(spectrum: spectrum),
          ),
        SafeArea(
          key: const ValueKey<String>('audio-player-foreground-layer'),
          child: child,
        ),
      ],
    );
  }
}
