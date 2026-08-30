import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'audio_lyrics_view.dart';
import 'lrc_parser.dart';
import 'player_session_controller.dart';

class AudioNowPlayingView extends StatelessWidget {
  const AudioNowPlayingView({
    super.key,
    required this.controller,
    required this.artworkPath,
    required this.lyrics,
  });

  final PlayerSessionController controller;
  final String? artworkPath;
  final LrcDocument? lyrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final maxWidth = math.max(0.0, constraints.maxWidth - 48);
        final maxHeight = math.max(0.0, constraints.maxHeight * 0.52);
        final cardSize = math.min(math.min(maxWidth, maxHeight), 420.0);
        final card = _ArtworkCard(
          path: artworkPath,
          size: cardSize,
          background: Color.alphaBlend(
            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            scheme.surface,
          ),
          iconColor: scheme.onSurface.withValues(alpha: 0.08),
        );

        return Align(
          alignment: const Alignment(0, -0.18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IgnorePointer(child: card),
              if (lyrics != null && !lyrics!.isEmpty) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: math.min(maxWidth, 420.0),
                  child: AudioLyricsView(
                    controller: controller,
                    lyrics: lyrics,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({
    required this.path,
    required this.size,
    required this.background,
    required this.iconColor,
  });

  final String? path;
  final double size;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final imagePath = path?.trim();
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.18
                    : 0.1,
              ),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: imagePath == null || imagePath.isEmpty
              ? Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: iconColor,
                    size: size * 0.34,
                  ),
                )
              : Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      color: iconColor,
                      size: size * 0.34,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
