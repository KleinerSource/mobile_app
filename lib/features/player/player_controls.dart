import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/models/playback.dart' as playback_models;
import 'player_overlay_indicators.dart' show formatDuration;
import 'player_haptics.dart';

/// 播放器控制层 · 顶栏标题 + 底栏 (播放/暂停 · 进度条 · 时间 · 清晰度)
///
/// 时间 / 进度 / 播放图标用 StreamBuilder 局部订阅, 避免整页每秒重建。
/// 渐变背景不参与命中测试, 控制栏中间留给手势层。
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.player,
    required this.title,
    required this.quality,
    required this.onQualityChanged,
    required this.subtitleTracks,
    required this.onSubtitleChanged,
    required this.audioTracks,
    required this.onAudioChanged,
    required this.hardwareLabel,
    required this.hapticProgressBar,
    required this.showPlayPauseButton,
    required this.showSeekButtons,
    required this.showSpeedButton,
    required this.showPipButton,
    required this.showOrientationButton,
    required this.showMediaSwitchButton,
    required this.playbackRate,
    required this.onPictureInPicture,
    required this.onPreviousMedia,
    required this.onNextMedia,
    required this.isLandscape,
    required this.onOrientationToggle,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onRateChanged,
    required this.onSeek,
    required this.onInteraction,
  });

  final Player player;
  final String title;

  final String quality;
  final ValueChanged<String> onQualityChanged;
  final List<playback_models.SubtitleTrack> subtitleTracks;
  final ValueChanged<playback_models.SubtitleTrack?> onSubtitleChanged;
  final List<playback_models.AudioTrack> audioTracks;
  final ValueChanged<playback_models.AudioTrack> onAudioChanged;
  final String? hardwareLabel;
  final bool hapticProgressBar;
  final bool showPlayPauseButton;
  final bool showSeekButtons;
  final bool showSpeedButton;
  final bool showPipButton;
  final bool showOrientationButton;
  final bool showMediaSwitchButton;
  final double playbackRate;
  final VoidCallback onPictureInPicture;
  final VoidCallback? onPreviousMedia;
  final VoidCallback? onNextMedia;
  final bool isLandscape;
  final VoidCallback onOrientationToggle;

  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final ValueChanged<double> onRateChanged;
  final void Function(Duration) onSeek;

  /// 任意控制交互 · 父级据此重置自动隐藏定时器
  final VoidCallback onInteraction;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  static const int _sliderHapticStepMs = 5000;

  /// 拖动进度条时的本地预览值 (null = 未拖动)
  double? _dragValue;
  int? _lastSliderHapticBucket;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black54],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _topBar(),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          left: 0,
          child: _bottomBar(),
        ),
      ],
    );
  }

  Widget _topBar() {
    // 顶栏左侧留出常驻返回键的空间 (父级 Stack 顶层放返回键)
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.hardwareLabel != null)
            Text(
              widget.hardwareLabel!,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          if (widget.showPipButton)
            IconButton(
              tooltip: '画中画',
              icon: const Icon(
                Icons.picture_in_picture_alt,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                widget.onPictureInPicture();
                widget.onInteraction();
              },
            ),
          if (widget.showOrientationButton)
            IconButton(
              tooltip: widget.isLandscape ? '切换竖屏' : '切换横屏',
              icon: Icon(
                widget.isLandscape
                    ? Icons.stay_current_portrait
                    : Icons.stay_current_landscape,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                widget.onOrientationToggle();
                widget.onInteraction();
              },
            ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionBar(),
          const SizedBox(height: 2),
          Row(
            children: [
              _positionText(),
              const SizedBox(width: 8),
              Expanded(child: _progressSlider()),
              const SizedBox(width: 8),
              _durationText(),
              const SizedBox(width: 4),
              _qualityButton(),
              if (widget.subtitleTracks.isNotEmpty) _subtitleButton(),
              if (widget.audioTracks.length > 1) _audioButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    final actions = <Widget>[
      if (widget.showMediaSwitchButton)
        _actionButton(
          icon: Icons.skip_previous,
          tooltip: '上一部',
          onPressed: widget.onPreviousMedia,
        ),
      if (widget.showSeekButtons)
        _actionButton(
          icon: Icons.replay_10,
          tooltip: '快退 10 秒',
          onPressed: widget.onSeekBackward,
        ),
      if (widget.showPlayPauseButton) _playPauseButton(),
      if (widget.showSeekButtons)
        _actionButton(
          icon: Icons.forward_10,
          tooltip: '快进 10 秒',
          onPressed: widget.onSeekForward,
        ),
      if (widget.showMediaSwitchButton)
        _actionButton(
          icon: Icons.skip_next,
          tooltip: '下一部',
          onPressed: widget.onNextMedia,
        ),
      if (widget.showSpeedButton) _speedButton(),
    ];
    if (actions.isEmpty) return const SizedBox(height: 2);
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        children: actions,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final action = onPressed;
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      icon: Icon(
        icon,
        color: action == null ? Colors.white30 : Colors.white,
        size: 22,
      ),
      onPressed: action == null
          ? null
          : () {
              action();
              widget.onInteraction();
            },
    );
  }

  Widget _speedButton() {
    const rates = <double>[0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4];
    return PopupMenuButton<double>(
      tooltip: '播放速度',
      initialValue: widget.playbackRate,
      padding: EdgeInsets.zero,
      onSelected: (rate) {
        widget.onRateChanged(rate);
        widget.onInteraction();
      },
      itemBuilder: (context) => [
        for (final rate in rates)
          PopupMenuItem<double>(
            value: rate,
            child: Text('${rate.toStringAsFixed(rate % 1 == 0 ? 1 : 2)}x'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: Text(
          '${widget.playbackRate.toStringAsFixed(1)}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _playPauseButton() {
    return StreamBuilder<bool>(
      stream: widget.player.stream.playing,
      initialData: widget.player.state.playing,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return IconButton(
          icon: Icon(playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white, size: 30),
          onPressed: () {
            widget.onTogglePlay();
            widget.onInteraction();
          },
        );
      },
    );
  }

  Widget _positionText() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      initialData: widget.player.state.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        return _timeLabel(formatDuration(pos));
      },
    );
  }

  Widget _durationText() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.duration,
      initialData: widget.player.state.duration,
      builder: (context, snap) {
        final dur = snap.data ?? Duration.zero;
        return _timeLabel(formatDuration(dur));
      },
    );
  }

  Widget _timeLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _progressSlider() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      initialData: widget.player.state.position,
      builder: (context, snap) {
        final dur = widget.player.state.duration.inMilliseconds;
        final pos = (snap.data ?? Duration.zero).inMilliseconds;
        final max = dur > 0 ? dur.toDouble() : 1.0;
        final live = pos.clamp(0, max.toInt()).toDouble();
        final value = _dragValue ?? live;
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            min: 0,
            max: max,
            value: value.clamp(0, max),
            onChangeStart: dur <= 0
                ? null
                : (v) {
                    _lastSliderHapticBucket =
                        (v / _sliderHapticStepMs).floor();
                    if (widget.hapticProgressBar) {
                      PlayerHaptics.selection();
                    }
                    widget.onInteraction();
                  },
            onChanged: dur <= 0
                ? null
                : (v) {
                    final bucket = (v / _sliderHapticStepMs).floor();
                    if (widget.hapticProgressBar &&
                        bucket != _lastSliderHapticBucket) {
                      _lastSliderHapticBucket = bucket;
                      PlayerHaptics.selection();
                    }
                    setState(() => _dragValue = v);
                    widget.onInteraction();
                  },
            onChangeEnd: dur <= 0
                ? null
                : (v) {
                    if (widget.hapticProgressBar) PlayerHaptics.medium();
                    widget.onSeek(Duration(milliseconds: v.round()));
                    setState(() => _dragValue = null);
                    _lastSliderHapticBucket = null;
                    widget.onInteraction();
                  },
          ),
        );
      },
    );
  }

  Widget _qualityButton() {
    const qualities = <String, String>{
      'original': '自动',
      '2160p': '2160p',
      '1080p': '1080p',
      '720p': '720p',
      '480p': '480p',
      '360p': '360p',
    };
    return PopupMenuButton<String>(
      tooltip: '选择画质',
      initialValue: widget.quality,
      onSelected: (quality) {
        widget.onQualityChanged(quality);
        widget.onInteraction();
      },
      itemBuilder: (context) => [
        for (final entry in qualities.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Text(
        qualities[widget.quality] ?? widget.quality,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _subtitleButton() {
    return PopupMenuButton<playback_models.SubtitleTrack>(
      tooltip: '选择字幕',
      onSelected: (track) {
        widget.onSubtitleChanged(track.index < 0 ? null : track);
        widget.onInteraction();
      },
      itemBuilder: (context) => [
        const PopupMenuItem<playback_models.SubtitleTrack>(
          value: playback_models.SubtitleTrack(
            index: -1,
            source: 'none',
            language: '',
            title: '',
            codec: '',
            url: '',
            isDefault: false,
          ),
          child: Text('关闭字幕'),
        ),
        for (final track in widget.subtitleTracks)
          PopupMenuItem<playback_models.SubtitleTrack>(
            value: track,
            enabled: track.canLoad,
            child: Text(_subtitleLabel(track)),
          ),
      ],
      child: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 21),
    );
  }

  String _subtitleLabel(playback_models.SubtitleTrack track) {
    final label = track.title.isNotEmpty
        ? track.title
        : (track.language.isNotEmpty ? track.language : '字幕');
    return track.isExternal ? '$label · 外挂' : label;
  }

  Widget _audioButton() {
    return PopupMenuButton<playback_models.AudioTrack>(
      tooltip: '选择音轨',
      onSelected: (track) {
        widget.onAudioChanged(track);
        widget.onInteraction();
      },
      itemBuilder: (context) => [
        for (final track in widget.audioTracks)
          PopupMenuItem(
            value: track,
            child: Text(track.title.isNotEmpty
                ? track.title
                : (track.language.isNotEmpty ? track.language : track.codec)),
          ),
      ],
      child: const Icon(Icons.audiotrack_outlined, color: Colors.white, size: 21),
    );
  }
}
