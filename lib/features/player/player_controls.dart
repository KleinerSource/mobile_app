import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/models/playback.dart' as playback_models;
import 'player_decode_status.dart';
import 'player_haptics.dart';
import 'player_overlay_indicators.dart' show formatDuration;

enum _SubtitleMenuAction { openSettings }

/// 播放器控制层 · 顶部页面操作 + 底部媒体信息、进度和主播放控制。
///
/// 控制层只覆盖顶部和底部，中央区域始终留给手势层。
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.player,
    required this.quality,
    required this.onQualityChanged,
    required this.subtitleTracks,
    required this.selectedSubtitle,
    required this.onSubtitleChanged,
    required this.onOpenSubtitleSettings,
    required this.audioTracks,
    required this.onAudioChanged,
    required this.decodeStatuses,
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
    required this.onExit,
  });

  final Player player;
  final String quality;
  final ValueChanged<String> onQualityChanged;
  final List<playback_models.SubtitleTrack> subtitleTracks;
  final playback_models.SubtitleTrack? selectedSubtitle;
  final ValueChanged<playback_models.SubtitleTrack?> onSubtitleChanged;
  final VoidCallback onOpenSubtitleSettings;
  final List<playback_models.AudioTrack> audioTracks;
  final ValueChanged<playback_models.AudioTrack> onAudioChanged;
  final List<PlayerDecodeStatus> decodeStatuses;
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
  final Future<void> Function(Duration) onSeek;

  /// 任意控制交互 · 父级据此重置自动隐藏定时器。
  final VoidCallback onInteraction;
  final VoidCallback onExit;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  static const int _sliderHapticStepMs = 5000;
  static const Duration _framePreviewInterval = Duration(milliseconds: 250);
  static const double _framePreviewWidth = 136;
  static const _noSubtitleTrack = playback_models.SubtitleTrack(
    index: -1,
    source: 'none',
    language: '',
    title: '',
    codec: '',
    url: '',
    isDefault: false,
  );

  /// 拖动进度条时的本地预览值 (null = 未拖动)。
  double? _dragValue;
  int? _lastSliderHapticBucket;
  bool _sliderDragging = false;
  Uint8List? _framePreview;
  Duration? _framePreviewPosition;
  Duration? _pendingFramePreviewPosition;
  DateTime? _lastFramePreviewAt;
  int _framePreviewSession = 0;
  bool _framePreviewBusy = false;
  bool _framePreviewUnavailable = false;
  Player? _framePreviewPlayer;
  String? _framePreviewSourceUri;
  Map<String, String>? _framePreviewSourceHeaders;

  @override
  void didUpdateWidget(covariant PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _cancelFramePreview();
      _dragValue = null;
      unawaited(_disposeFramePreviewPlayer());
    }
  }

  @override
  void dispose() {
    _cancelFramePreview();
    unawaited(_disposeFramePreviewPlayer());
    super.dispose();
  }

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
          top: 36,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          _topActionButton(
            icon: Icons.close,
            tooltip: '退出播放',
            onPressed: widget.onExit,
          ),
          const Spacer(),
          if (widget.showPipButton)
            _topActionButton(
              icon: Icons.picture_in_picture_alt,
              tooltip: '画中画',
              onPressed: () {
                widget.onPictureInPicture();
                widget.onInteraction();
              },
            ),
          if (widget.showOrientationButton)
            _topActionButton(
              icon: Icons.screen_rotation,
              tooltip: widget.isLandscape ? '切换竖屏' : '切换横屏',
              onPressed: () {
                widget.onOrientationToggle();
                widget.onInteraction();
              },
            ),
          if (widget.showSpeedButton) _speedButton(),
        ],
      ),
    );
  }

  Widget _topActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      enableFeedback: false,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      constraints: const BoxConstraints.tightFor(width: 46, height: 46),
      icon: Icon(icon, color: Colors.white, size: 25),
      onPressed: () {
        PlayerHaptics.light();
        onPressed();
      },
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _metadataRow(),
          const SizedBox(height: 6),
          _progressRow(),
          const SizedBox(height: 8),
          _actionBar(),
        ],
      ),
    );
  }

  Widget _metadataRow() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _qualityButton(),
              if (widget.decodeStatuses.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      for (final status in widget.decodeStatuses)
                        PlayerDecodeStatusBadge(status: status),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.subtitleTracks.isNotEmpty) _subtitleButton(),
        if (widget.audioTracks.length > 1) _audioButton(),
      ],
    );
  }

  Widget _progressRow() {
    return Row(
      children: [
        _positionText(),
        const SizedBox(width: 8),
        Expanded(child: _progressSlider()),
        const SizedBox(width: 8),
        _durationText(),
      ],
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
    ];
    if (actions.isEmpty) return const SizedBox(height: 56);
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
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
      enableFeedback: false,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(
        icon,
        color: action == null ? Colors.white30 : Colors.white,
        size: 27,
      ),
      onPressed: action == null
          ? null
          : () {
              PlayerHaptics.light();
              action();
              widget.onInteraction();
            },
    );
  }

  Widget _speedButton() {
    const rates = <double>[0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4];
    return PopupMenuButton<double>(
      tooltip: '播放速度 ${widget.playbackRate.toStringAsFixed(1)}x',
      enableFeedback: false,
      initialValue: widget.playbackRate,
      padding: EdgeInsets.zero,
      onSelected: (rate) {
        PlayerHaptics.selection();
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
      child: const SizedBox(
        width: 46,
        height: 46,
        child: Center(child: Icon(Icons.speed, color: Colors.white, size: 25)),
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
          enableFeedback: false,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.standard,
          constraints: const BoxConstraints.tightFor(width: 56, height: 56),
          icon: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () {
            PlayerHaptics.light();
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
        final previewPosition = _framePreviewPosition;
        return LayoutBuilder(
          builder: (context, constraints) {
            final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
            final maxLeft = (constraints.maxWidth - _framePreviewWidth)
                .clamp(0.0, double.infinity)
                .toDouble();
            final previewLeft = (constraints.maxWidth * fraction -
                    _framePreviewWidth / 2)
                .clamp(0.0, maxLeft)
                .toDouble();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
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
                        : (v) => _beginSliderDrag(v),
                    onChanged: dur <= 0
                        ? null
                        : (v) => _updateSliderDrag(v),
                    onChangeEnd: dur <= 0
                        ? null
                        : (v) => _endSliderDrag(v),
                  ),
                ),
                if (_sliderDragging && previewPosition != null)
                  Positioned(
                    left: previewLeft,
                    bottom: 38,
                    child: IgnorePointer(
                      child: _SliderFramePreview(
                        frame: _framePreview,
                        position: previewPosition,
                        unavailable: _framePreviewUnavailable,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _beginSliderDrag(double value) {
    final position = Duration(milliseconds: value.round());
    _framePreviewSession++;
    _sliderDragging = true;
    _lastFramePreviewAt = null;
    _pendingFramePreviewPosition = null;
    _lastSliderHapticBucket = (value / _sliderHapticStepMs).floor();
    if (widget.hapticProgressBar) PlayerHaptics.selection();
    setState(() {
      _dragValue = value;
      _framePreview = null;
      _framePreviewPosition = position;
      _framePreviewUnavailable = false;
    });
    _queueFramePreview(position);
    widget.onInteraction();
  }

  void _updateSliderDrag(double value) {
    final bucket = (value / _sliderHapticStepMs).floor();
    if (widget.hapticProgressBar && bucket != _lastSliderHapticBucket) {
      _lastSliderHapticBucket = bucket;
      PlayerHaptics.selection();
    }
    final position = Duration(milliseconds: value.round());
    setState(() {
      _dragValue = value;
      _framePreviewPosition = position;
    });
    _queueFramePreview(position);
    widget.onInteraction();
  }

  void _endSliderDrag(double value) {
    if (widget.hapticProgressBar) PlayerHaptics.medium();
    final position = Duration(milliseconds: value.round());
    final commitSeek = widget.onSeek;
    _cancelFramePreview();
    setState(() => _dragValue = null);
    _lastSliderHapticBucket = null;
    widget.onInteraction();
    unawaited(_commitSliderSeek(position, commitSeek));
  }

  void _queueFramePreview(Duration position) {
    if (!_sliderDragging || _framePreviewUnavailable) return;
    _pendingFramePreviewPosition = position;
    if (_framePreviewBusy) return;
    _framePreviewBusy = true;
    unawaited(_runFramePreviewLoop(_framePreviewSession));
  }

  Future<void> _commitSliderSeek(
    Duration position,
    Future<void> Function(Duration) commitSeek,
  ) async {
    try {
      await commitSeek(position);
    } catch (_) {
      // 播放器错误流会负责展示定位失败,这里避免产生未处理 Future。
    }
  }

  Future<void> _runFramePreviewLoop(int session) async {
    try {
      while (mounted &&
          _sliderDragging &&
          session == _framePreviewSession) {
        var position = _pendingFramePreviewPosition;
        if (position == null) break;
        _pendingFramePreviewPosition = null;

        final lastCapture = _lastFramePreviewAt;
        if (lastCapture != null) {
          final elapsed = DateTime.now().difference(lastCapture);
          final remaining = _framePreviewInterval - elapsed;
          if (remaining > Duration.zero) await Future<void>.delayed(remaining);
          if (!mounted ||
              !_sliderDragging ||
              session != _framePreviewSession) {
            break;
          }
          position = _pendingFramePreviewPosition ?? position;
          _pendingFramePreviewPosition = null;
        }

        try {
          final previewPlayer = await _ensureFramePreviewPlayer(position);
          if (previewPlayer == null) {
            _markFramePreviewUnavailable(session);
            break;
          }
          final frame = await _captureFrame(previewPlayer, position);
          _lastFramePreviewAt = DateTime.now();
          if (frame != null &&
              mounted &&
              _sliderDragging &&
              session == _framePreviewSession) {
            setState(() {
              _framePreview = frame;
              _framePreviewUnavailable = false;
            });
          } else if (frame == null) {
            _markFramePreviewUnavailable(session);
            break;
          }
        } catch (_) {
          _lastFramePreviewAt = DateTime.now();
          _markFramePreviewUnavailable(session);
          break;
        }
      }
    } finally {
      _framePreviewBusy = false;
      final pending = _pendingFramePreviewPosition;
      if (mounted && _sliderDragging && pending != null) {
        _queueFramePreview(pending);
      }
    }
  }

  Future<Player?> _ensureFramePreviewPlayer(Duration startAt) async {
    final playlist = widget.player.state.playlist;
    if (playlist.index < 0 || playlist.index >= playlist.medias.length) {
      return null;
    }
    final source = playlist.medias[playlist.index];
    final existing = _framePreviewPlayer;
    if (existing != null &&
        _framePreviewSourceUri == source.uri &&
        mapEquals(_framePreviewSourceHeaders, source.httpHeaders)) {
      return existing;
    }

    await _disposeFramePreviewPlayer();
    final player = Player(
      configuration: const PlayerConfiguration(
        muted: true,
        bufferSize: 8 * 1024 * 1024,
      ),
    );
    _framePreviewPlayer = player;
    _framePreviewSourceUri = source.uri;
    _framePreviewSourceHeaders = source.httpHeaders == null
        ? null
        : Map<String, String>.from(source.httpHeaders!);
    try {
      await player.open(
        Media(
          source.uri,
          httpHeaders: source.httpHeaders,
          start: startAt,
        ),
        // screenshot 只有在解码出视频帧后才会返回数据。预览内核保持
        // 静音，只在取帧期间短暂播放，绝不影响主播放器位置。
        play: true,
      ).timeout(const Duration(seconds: 3));
      final width = player.state.width;
      if (width == null || width <= 0) {
        await player.stream.width
            .firstWhere((value) => value != null && value > 0)
            .timeout(const Duration(milliseconds: 2500));
      }
      return player;
    } catch (_) {
      if (identical(_framePreviewPlayer, player)) {
        _framePreviewPlayer = null;
        _framePreviewSourceUri = null;
        _framePreviewSourceHeaders = null;
      }
      try {
        await player.dispose();
      } catch (_) {}
      return null;
    }
  }

  Future<Uint8List?> _captureFrame(
    Player previewPlayer,
    Duration position,
  ) async {
    try {
      await previewPlayer.seek(position).timeout(const Duration(seconds: 2));
      await previewPlayer.play();
      for (var attempt = 0; attempt < 15; attempt++) {
        final frame = await previewPlayer
            .screenshot(format: 'image/jpeg')
            .timeout(
              const Duration(milliseconds: 400),
              onTimeout: () => null,
            );
        if (frame != null && frame.isNotEmpty) return frame;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return null;
    } finally {
      try {
        await previewPlayer.pause();
      } catch (_) {}
    }
  }

  void _markFramePreviewUnavailable(int session) {
    if (!mounted || !_sliderDragging || session != _framePreviewSession) return;
    setState(() {
      _framePreview = null;
      _framePreviewUnavailable = true;
    });
  }

  Future<void> _disposeFramePreviewPlayer() async {
    final player = _framePreviewPlayer;
    _framePreviewPlayer = null;
    _framePreviewSourceUri = null;
    _framePreviewSourceHeaders = null;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {}
  }

  void _cancelFramePreview() {
    _sliderDragging = false;
    _framePreviewSession++;
    _pendingFramePreviewPosition = null;
    _framePreview = null;
    _framePreviewPosition = null;
    _lastFramePreviewAt = null;
    _framePreviewUnavailable = false;
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
      enableFeedback: false,
      initialValue: widget.quality,
      padding: EdgeInsets.zero,
      onSelected: (quality) {
        if (quality != widget.quality) PlayerHaptics.selection();
        widget.onQualityChanged(quality);
        widget.onInteraction();
      },
      itemBuilder: (context) => [
        for (final entry in qualities.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Text(
        (qualities[widget.quality] ?? widget.quality).toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _subtitleButton() {
    return PopupMenuButton<Object>(
      tooltip: '选择字幕',
      enableFeedback: false,
      padding: EdgeInsets.zero,
      initialValue: widget.selectedSubtitle ?? _noSubtitleTrack,
      onSelected: (value) {
        PlayerHaptics.selection();
        if (value == _SubtitleMenuAction.openSettings) {
          widget.onOpenSubtitleSettings();
          widget.onInteraction();
          return;
        }
        final track = value as playback_models.SubtitleTrack;
        widget.onSubtitleChanged(track.index < 0 ? null : track);
        widget.onInteraction();
      },
      itemBuilder: (context) => <PopupMenuEntry<Object>>[
        const PopupMenuItem<Object>(
          value: _SubtitleMenuAction.openSettings,
          child: Row(
            children: [
              Icon(Icons.tune, size: 18),
              SizedBox(width: 10),
              Text('字幕设置'),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        _subtitleMenuItem(
          _noSubtitleTrack,
          label: '关闭字幕',
          selected: widget.selectedSubtitle == null,
          icon: Icons.closed_caption_disabled_outlined,
        ),
        for (final track in widget.subtitleTracks)
          _subtitleMenuItem(
            track,
            label: _subtitleLabel(track),
            selected: identical(widget.selectedSubtitle, track),
            enabled: track.canLoad,
            icon: track.isExternal ? Icons.file_open_outlined : null,
          ),
      ],
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: _roundIcon(
            Icons.subtitles_outlined,
            active: widget.selectedSubtitle != null,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<Object> _subtitleMenuItem(
    playback_models.SubtitleTrack track, {
    required String label,
    required bool selected,
    bool enabled = true,
    IconData? icon,
  }) {
    return PopupMenuItem<Object>(
      value: track,
      enabled: enabled,
      child: Row(
        children: [
          icon != null
              ? Icon(icon, size: 18)
              : const SizedBox(width: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          selected
              ? const Icon(Icons.check, size: 18)
              : const SizedBox(width: 18),
        ],
      ),
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
      enableFeedback: false,
      padding: EdgeInsets.zero,
      onSelected: (track) {
        PlayerHaptics.selection();
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
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(child: _roundIcon(Icons.audiotrack_outlined)),
      ),
    );
  }

  Widget _roundIcon(IconData icon, {bool active = false}) {
    final color = active ? Colors.white : Colors.white70;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _SliderFramePreview extends StatelessWidget {
  const _SliderFramePreview({
    required this.frame,
    required this.position,
    required this.unavailable,
  });

  final Uint8List? frame;
  final Duration position;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _PlayerControlsState._framePreviewWidth,
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xF21A191F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white38),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (frame == null && !unavailable)
            const Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            )
          else if (frame == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      color: Colors.white70, size: 20),
                  SizedBox(height: 4),
                  Text(
                    '当前源无法预览',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            )
          else
            Image.memory(
              frame!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              cacheWidth: 272,
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.black.withValues(alpha: 0.72),
              child: Text(
                formatDuration(position),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
