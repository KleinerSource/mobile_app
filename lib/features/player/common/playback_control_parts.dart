import 'dart:async';

import 'package:flutter/material.dart';

import 'playback_engine.dart';
import 'player_haptics.dart';
import 'player_overlay_indicators.dart' show formatDuration;
import 'player_session_controller.dart';

/// 播放器公共时间文本。
class PlaybackTimeLabel extends StatelessWidget {
  const PlaybackTimeLabel({
    super.key,
    required this.controller,
    this.duration = false,
  });

  final PlayerSessionController controller;
  final bool duration;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: controller,
      builder: (_, state, __) => Text(
        formatDuration(duration ? state.duration : state.position),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 不带视频帧预览的公共进度条，供音频页面使用。
class PlaybackProgressSlider extends StatefulWidget {
  const PlaybackProgressSlider({
    super.key,
    required this.controller,
    required this.hapticProgressBar,
    required this.onSeek,
  });

  final PlayerSessionController controller;
  final bool hapticProgressBar;
  final Future<void> Function(Duration) onSeek;

  @override
  State<PlaybackProgressSlider> createState() => _PlaybackProgressSliderState();
}

class _PlaybackProgressSliderState extends State<PlaybackProgressSlider> {
  static const _hapticStepMs = 5000;
  double? _dragValue;
  int? _lastHapticBucket;
  bool _dragMoved = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final durationMs = state.duration.inMilliseconds;
        final max = durationMs > 0 ? durationMs.toDouble() : 1.0;
        final current = state.position.inMilliseconds
            .clamp(0, max.toInt())
            .toDouble();
        final value = (_dragValue ?? current).clamp(0, max).toDouble();
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Theme.of(context).colorScheme.onSurface,
            secondaryActiveTrackColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.28),
            inactiveTrackColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.2),
            thumbColor: Theme.of(context).colorScheme.onSurface,
            overlayColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          child: Slider(
            min: 0,
            max: max,
            value: value,
            secondaryTrackValue: widget.controller.capabilities.customBuffering
                ? state.buffered.inMilliseconds
                      .toDouble()
                      .clamp(value, max)
                      .toDouble()
                : null,
            semanticFormatterCallback: (sliderValue) =>
                '当前播放 ${formatDuration(Duration(milliseconds: sliderValue.round()))}',
            onChangeStart: durationMs <= 0 ? null : _beginDrag,
            onChanged: durationMs <= 0 ? null : _updateDrag,
            onChangeEnd: durationMs <= 0 ? null : _endDrag,
          ),
        );
      },
    );
  }

  void _beginDrag(double value) {
    _dragMoved = false;
    _lastHapticBucket = (value / _hapticStepMs).floor();
    if (widget.hapticProgressBar) PlayerHaptics.selection();
    setState(() => _dragValue = value);
  }

  void _updateDrag(double value) {
    final bucket = (value / _hapticStepMs).floor();
    if (!_dragMoved) {
      _dragMoved = true;
      _lastHapticBucket = bucket;
    } else if (widget.hapticProgressBar && bucket != _lastHapticBucket) {
      _lastHapticBucket = bucket;
      PlayerHaptics.selection();
    }
    setState(() => _dragValue = value);
  }

  void _endDrag(double value) {
    _lastHapticBucket = null;
    setState(() => _dragValue = null);
    unawaited(
      widget.onSeek(Duration(milliseconds: value.round())).catchError((_) {}),
    );
  }
}

class PlaybackPlayPauseButton extends StatelessWidget {
  const PlaybackPlayPauseButton({
    super.key,
    required this.controller,
    required this.onPressed,
    this.size = 48,
    this.loading = false,
  });

  final PlayerSessionController controller;
  final VoidCallback onPressed;
  final double size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final scheme = Theme.of(context).colorScheme;
        return IconButton(
          enableFeedback: false,
          iconSize: size,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: loading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: size * 0.5,
                    height: size * 0.5,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    state.playing ? Icons.pause : Icons.play_arrow,
                    key: ValueKey(state.playing ? 'pause' : 'play'),
                  ),
          ),
          onPressed: loading
              ? null
              : () {
                  PlayerHaptics.light();
                  onPressed();
                },
        );
      },
    );
  }
}

class PlaybackSpeedButton extends StatelessWidget {
  const PlaybackSpeedButton({
    super.key,
    required this.playbackRate,
    required this.onRateChanged,
    required this.onInteraction,
  });

  final double playbackRate;
  final ValueChanged<double> onRateChanged;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    const rates = <double>[0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4];
    return PopupMenuButton<double>(
      tooltip: '播放速度 ${playbackRate.toStringAsFixed(1)}x',
      enableFeedback: false,
      initialValue: playbackRate,
      onSelected: (rate) {
        PlayerHaptics.selection();
        onRateChanged(rate);
        onInteraction();
      },
      itemBuilder: (_) => [
        for (final rate in rates)
          PopupMenuItem<double>(
            value: rate,
            child: Text('${rate.toStringAsFixed(rate % 1 == 0 ? 1 : 2)}x'),
          ),
      ],
      child: const SizedBox(
        width: 46,
        height: 46,
        child: Center(child: Icon(Icons.speed, size: 25)),
      ),
    );
  }
}

class PlaybackActionButton extends StatelessWidget {
  const PlaybackActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.onInteraction,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final VoidCallback onInteraction;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final action = onPressed;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      enableFeedback: false,
      icon: Icon(
        icon,
        color: action == null
            ? scheme.onSurface.withValues(alpha: 0.42)
            : active
            ? scheme.primary
            : scheme.onSurface,
        size: 27,
      ),
      onPressed: action == null
          ? null
          : () {
              PlayerHaptics.light();
              action();
              onInteraction();
            },
    );
  }
}
