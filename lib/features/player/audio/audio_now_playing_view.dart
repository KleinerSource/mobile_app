import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'audio_lyrics_view.dart';
import 'lrc_parser.dart';
import '../common/playback_engine.dart';
import '../common/player_session_controller.dart';

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
        final hasLyrics = lyrics != null && !lyrics!.isEmpty;

        return Align(
          alignment: const Alignment(0, -0.18),
          // 歌词出现/消失时整体高度平滑变化，封面随之连续移动而非跳变。
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(child: _artwork(context, cardSize, scheme, isDark)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: hasLyrics
                      ? Column(
                          key: const ValueKey('lyrics'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 18),
                            SizedBox(
                              width: math.min(maxWidth, 420.0),
                              child: AudioLyricsView(
                                controller: controller,
                                lyrics: lyrics,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('no-lyrics')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _artwork(
    BuildContext context,
    double size,
    ColorScheme scheme,
    bool isDark,
  ) {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: controller,
      builder: (context, state, _) => AnimatedScale(
        scale: state.playing ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: _ArtworkCard(
          path: artworkPath,
          size: size,
          playing: state.playing,
          background: Color.alphaBlend(
            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            scheme.surface,
          ),
          iconColor: scheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({
    required this.path,
    required this.size,
    required this.playing,
    required this.background,
    required this.iconColor,
  });

  final String? path;
  final double size;
  final bool playing;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final imagePath = path?.trim();
    final hasImage = imagePath != null && imagePath.isNotEmpty;
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 占位色块只保留音符图标，不展示文件名等文本。
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: hasImage
                    ? Image.file(
                        File(imagePath),
                        key: ValueKey<String>('art:$imagePath'),
                        fit: BoxFit.cover,
                        frameBuilder: (context, child, frame, synced) {
                          if (synced) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child: child,
                          );
                        },
                        errorBuilder: (_, __, ___) => _placeholder(size),
                      )
                    : _placeholder(size),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: playing ? 0 : 1,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(double size) {
    return Center(
      key: const ValueKey('art:placeholder'),
      child: Icon(
        Icons.music_note_rounded,
        color: iconColor,
        size: size * 0.34,
      ),
    );
  }
}
