import 'package:flutter/material.dart';

class AudioPlayerVisualLayers extends StatelessWidget {
  const AudioPlayerVisualLayers({
    super.key,
    required this.surface,
    required this.child,
  });

  final Widget surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey<String>('audio-player-visual-layers'),
      fit: StackFit.expand,
      children: [
        surface,
        SafeArea(
          key: const ValueKey<String>('audio-player-foreground-layer'),
          child: child,
        ),
      ],
    );
  }
}
