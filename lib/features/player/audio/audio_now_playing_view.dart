import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'audio_lyrics_view.dart';
import 'lrc_parser.dart';
import '../common/playback_engine.dart';
import '../common/player_session_controller.dart';

class AudioNowPlayingView extends StatefulWidget {
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
  State<AudioNowPlayingView> createState() => _AudioNowPlayingViewState();
}

class _AudioNowPlayingViewState extends State<AudioNowPlayingView>
    with SingleTickerProviderStateMixin {
  static const _rotationPeriod = Duration(seconds: 8);

  late final AnimationController _rotationController = AnimationController(
    vsync: this,
    duration: _rotationPeriod,
  );
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncRotation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant AudioNowPlayingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncRotation);
      widget.controller.addListener(_syncRotation);
    }
    _syncRotation();
  }

  void _syncRotation() {
    final shouldRotate = !_disableAnimations && widget.controller.playing;
    if (!shouldRotate) {
      if (_rotationController.isAnimating) {
        _rotationController.stop(canceled: false);
      }
      return;
    }
    if (!_rotationController.isAnimating) {
      _rotationController.repeat(period: _rotationPeriod);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncRotation);
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(0.0, constraints.maxWidth - 48);
        final maxHeight = math.max(0.0, constraints.maxHeight * 0.52);
        final cardSize = math.min(math.min(maxWidth, maxHeight), 420.0);
        final hasLyrics = widget.lyrics != null && !widget.lyrics!.isEmpty;

        return Align(
          alignment: const Alignment(0, -0.18),
          // 歌词出现/消失时整体高度平滑变化，封面随之连续移动而非跳变。
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(child: _artwork(cardSize)),
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
                                controller: widget.controller,
                                lyrics: widget.lyrics,
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

  Widget _artwork(double size) {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: widget.controller,
      builder: (context, state, _) => AnimatedScale(
        scale: state.playing ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: RotationTransition(
          key: const ValueKey<String>('audio-vinyl-rotation'),
          turns: _rotationController,
          child: _VinylRecord(
            artworkPath: widget.artworkPath,
            size: size,
            labelTransitionDuration: _disableAnimations
                ? const Duration(milliseconds: 90)
                : const Duration(milliseconds: 240),
            labelTransitionReverseDuration: _disableAnimations
                ? const Duration(milliseconds: 60)
                : const Duration(milliseconds: 160),
          ),
        ),
      ),
    );
  }
}

class _VinylRecord extends StatelessWidget {
  const _VinylRecord({
    required this.artworkPath,
    required this.size,
    required this.labelTransitionDuration,
    required this.labelTransitionReverseDuration,
  });

  final String? artworkPath;
  final double size;
  final Duration labelTransitionDuration;
  final Duration labelTransitionReverseDuration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imagePath = artworkPath?.trim();
    final labelSize = size * 0.34;

    return SizedBox(
      key: const ValueKey<String>('audio-vinyl-record'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          key: const ValueKey<String>('audio-vinyl-surface'),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(
                  key: ValueKey<String>('audio-vinyl-painter'),
                  painter: _VinylRecordPainter(),
                ),
              ),
              SizedBox(
                width: labelSize,
                height: labelSize,
                child: AnimatedSwitcher(
                  duration: labelTransitionDuration,
                  reverseDuration: labelTransitionReverseDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.94,
                          end: 1,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: _ArtworkLabel(
                    key: ValueKey<String>(imagePath ?? 'empty'),
                    path: imagePath,
                    size: labelSize,
                    background: Color.alphaBlend(
                      (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.12,
                      ),
                      scheme.surface,
                    ),
                    iconColor: scheme.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ),
              IgnorePointer(
                child: SizedBox(
                  width: size * 0.035,
                  height: size * 0.035,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.26),
                        width: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkLabel extends StatelessWidget {
  const _ArtworkLabel({
    super.key,
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
    return ClipOval(
      key: const ValueKey<String>('audio-vinyl-label'),
      child: ColoredBox(
        color: background,
        child: path == null || path!.isEmpty
            ? Center(
                child: Icon(
                  Icons.music_note_rounded,
                  color: iconColor,
                  size: size * 0.34,
                ),
              )
            : Image.file(
                File(path!),
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
    );
  }
}

class _VinylRecordPainter extends CustomPainter {
  const _VinylRecordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xff101010));

    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, radius * 0.006);
    for (var index = 0; index < 14; index++) {
      canvas.drawCircle(center, radius * (0.25 + index * 0.047), groovePaint);
    }

    final sheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, radius * 0.014);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -math.pi * 0.82,
      math.pi * 0.52,
      false,
      sheenPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VinylRecordPainter oldDelegate) => false;
}
