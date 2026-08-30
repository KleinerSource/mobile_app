import 'package:flutter/material.dart';

import '../common/playback_engine.dart';
import '../common/playback_control_parts.dart';
import '../common/player_session_controller.dart';

/// 音频播放器控制层。音频布局独立于视频控制层，不包含画质、字幕或画面预览。
class AudioPlayerControls extends StatelessWidget {
  const AudioPlayerControls({
    super.key,
    required this.controller,
    required this.hapticProgressBar,
    required this.showPlayPauseButton,
    this.isLoading = false,
    required this.showSeekButtons,
    required this.showSpeedButton,
    required this.showMediaSwitchButton,
    required this.showShuffleButton,
    required this.shuffleEnabled,
    required this.shuffleOnTooltip,
    required this.shuffleOffTooltip,
    required this.onShuffleToggle,
    required this.showRepeatButton,
    required this.repeatMode,
    required this.repeatOffTooltip,
    required this.repeatOneTooltip,
    required this.repeatAllTooltip,
    required this.onRepeatToggle,
    required this.playbackRate,
    required this.onPreviousMedia,
    required this.onNextMedia,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onRateChanged,
    required this.onSeek,
    required this.onInteraction,
    required this.onExit,
  });

  final PlayerSessionController controller;
  final bool hapticProgressBar;
  final bool showPlayPauseButton;
  final bool isLoading;
  final bool showSeekButtons;
  final bool showSpeedButton;
  final bool showMediaSwitchButton;
  final bool showShuffleButton;
  final bool shuffleEnabled;
  final String shuffleOnTooltip;
  final String shuffleOffTooltip;
  final VoidCallback? onShuffleToggle;
  final bool showRepeatButton;
  final PlaybackRepeatMode repeatMode;
  final String repeatOffTooltip;
  final String repeatOneTooltip;
  final String repeatAllTooltip;
  final VoidCallback? onRepeatToggle;
  final double playbackRate;
  final VoidCallback? onPreviousMedia;
  final VoidCallback? onNextMedia;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final ValueChanged<double> onRateChanged;
  final Future<void> Function(Duration) onSeek;
  final VoidCallback onInteraction;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 20,
          child: IconButton(
            tooltip: '退出播放',
            enableFeedback: false,
            icon: const Icon(Icons.close),
            onPressed: onExit,
          ),
        ),
        Positioned(
          right: 24,
          bottom: 18,
          left: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title(context),
              const SizedBox(height: 20),
              _progress(),
              const SizedBox(height: 28),
              _primaryControls(),
              const SizedBox(height: 20),
              _secondaryControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _title(BuildContext context) {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: controller,
      builder: (context, state, _) => Text(
        state.currentTitle?.trim().isNotEmpty == true
            ? state.currentTitle!.trim()
            : '音乐播放',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _progress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaybackProgressSlider(
          controller: controller,
          hapticProgressBar: hapticProgressBar,
          onSeek: onSeek,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PlaybackTimeLabel(controller: controller),
            PlaybackTimeLabel(controller: controller, duration: true),
          ],
        ),
      ],
    );
  }

  Widget _primaryControls() {
    final actions = <Widget>[
      if (showSeekButtons)
        PlaybackActionButton(
          icon: Icons.replay_10,
          tooltip: '快退 10 秒',
          onPressed: onSeekBackward,
          onInteraction: onInteraction,
        ),
      if (showMediaSwitchButton)
        PlaybackActionButton(
          icon: Icons.skip_previous,
          tooltip: '上一曲',
          onPressed: onPreviousMedia,
          onInteraction: onInteraction,
        ),
      if (showPlayPauseButton)
        PlaybackPlayPauseButton(
          controller: controller,
          size: 48,
          loading: isLoading,
          onPressed: () {
            onTogglePlay();
            onInteraction();
          },
        ),
      if (showMediaSwitchButton)
        PlaybackActionButton(
          icon: Icons.skip_next,
          tooltip: '下一曲',
          onPressed: onNextMedia,
          onInteraction: onInteraction,
        ),
      if (showSeekButtons)
        PlaybackActionButton(
          icon: Icons.forward_10,
          tooltip: '快进 10 秒',
          onPressed: onSeekForward,
          onInteraction: onInteraction,
        ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions,
    );
  }

  Widget _secondaryControls() {
    final actions = <Widget>[
      if (showSpeedButton)
        PlaybackSpeedButton(
          playbackRate: playbackRate,
          onRateChanged: onRateChanged,
          onInteraction: onInteraction,
        ),
      if (showShuffleButton)
        PlaybackActionButton(
          icon: Icons.shuffle,
          tooltip: shuffleEnabled ? shuffleOffTooltip : shuffleOnTooltip,
          onPressed: onShuffleToggle,
          active: shuffleEnabled,
          onInteraction: onInteraction,
        ),
      if (showRepeatButton)
        PlaybackActionButton(
          icon: repeatMode == PlaybackRepeatMode.one
              ? Icons.repeat_one
              : Icons.repeat,
          tooltip: switch (repeatMode) {
            PlaybackRepeatMode.off => repeatOffTooltip,
            PlaybackRepeatMode.one => repeatOneTooltip,
            PlaybackRepeatMode.all => repeatAllTooltip,
          },
          onPressed: onRepeatToggle,
          active: repeatMode != PlaybackRepeatMode.off,
          onInteraction: onInteraction,
        ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions,
    );
  }
}
