import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/models/playback.dart' as playback_models;
import 'frame_preview_controller.dart';
import 'playback_engine.dart';
import 'player_decode_status.dart';
import 'player_haptics.dart';
import 'player_overlay_indicators.dart' show formatDuration;
import 'player_session_controller.dart';

enum _SubtitleMenuAction { openSettings }

/// 播放器控制层 · 顶部页面操作 + 底部媒体信息、进度和主播放控制。
///
/// 控制层只覆盖顶部和底部，中央区域始终留给手势层。
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.controller,
    this.previewSourceUri,
    this.previewSourceHeaders,
    required this.quality,
    this.showQualityButton = true,
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

  final PlayerSessionController controller;
  final String? previewSourceUri;
  final Map<String, String>? previewSourceHeaders;
  final String quality;
  final bool showQualityButton;
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
  late FramePreviewController _framePreviewController;

  @override
  void initState() {
    super.initState();
    _createFramePreviewController();
  }

  void _createFramePreviewController() {
    _framePreviewController = FramePreviewController(widget.controller)
      ..configureSource(widget.previewSourceUri, widget.previewSourceHeaders)
      ..addListener(_onFramePreviewChanged);
  }

  void _onFramePreviewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _framePreviewController
        ..removeListener(_onFramePreviewChanged)
        ..dispose();
      _createFramePreviewController();
      _dragValue = null;
    } else if (oldWidget.previewSourceUri != widget.previewSourceUri ||
        oldWidget.previewSourceHeaders != widget.previewSourceHeaders) {
      _framePreviewController.configureSource(
        widget.previewSourceUri,
        widget.previewSourceHeaders,
      );
      _dragValue = null;
    }
  }

  @override
  void dispose() {
    _framePreviewController
      ..removeListener(_onFramePreviewChanged)
      ..dispose();
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
        Positioned(top: 36, left: 0, right: 0, child: _topBar()),
        Positioned(right: 0, bottom: 0, left: 0, child: _bottomBar()),
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
              if (widget.showQualityButton) _qualityButton(),
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
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final playing = state.playing;
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
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: widget.controller,
      builder: (_, state, __) => _timeLabel(formatDuration(state.position)),
    );
  }

  Widget _durationText() {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: widget.controller,
      builder: (_, state, __) => _timeLabel(formatDuration(state.duration)),
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
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final dur = state.duration.inMilliseconds;
        final pos = state.position.inMilliseconds;
        final buffer = state.buffered.inMilliseconds;
        final max = dur > 0 ? dur.toDouble() : 1.0;
        final live = pos.clamp(0, max.toInt()).toDouble();
        final buffered = buffer.clamp(0, max.toInt()).toDouble();
        final value = _dragValue ?? live;
        final previewPosition = _framePreviewController.position;
        return LayoutBuilder(
          builder: (context, constraints) {
            final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
            final maxLeft = (constraints.maxWidth - _framePreviewWidth)
                .clamp(0.0, double.infinity)
                .toDouble();
            final previewLeft =
                (constraints.maxWidth * fraction - _framePreviewWidth / 2)
                    .clamp(0.0, maxLeft)
                    .toDouble();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Colors.white,
                    secondaryActiveTrackColor: Colors.white60,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    min: 0,
                    max: max,
                    value: value.clamp(0, max),
                    secondaryTrackValue: buffered,
                    semanticFormatterCallback: (sliderValue) {
                      final current = Duration(
                        milliseconds: sliderValue.round(),
                      );
                      final cached = Duration(milliseconds: buffered.round());
                      return '当前播放 ${formatDuration(current)}，'
                          '已缓冲 ${formatDuration(cached)}';
                    },
                    onChangeStart: dur <= 0 ? null : (v) => _beginSliderDrag(v),
                    onChanged: dur <= 0 ? null : (v) => _updateSliderDrag(v),
                    onChangeEnd: dur <= 0 ? null : (v) => _endSliderDrag(v),
                  ),
                ),
                if (_sliderDragging &&
                    previewPosition != null &&
                    _framePreviewController.frame != null)
                  Positioned(
                    left: previewLeft,
                    bottom: 38,
                    child: IgnorePointer(
                      child: _SliderFramePreview(
                        frame: _framePreviewController.frame,
                        position: previewPosition,
                        unavailable: _framePreviewController.unavailable,
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
    _sliderDragging = true;
    _lastSliderHapticBucket = (value / _sliderHapticStepMs).floor();
    if (widget.hapticProgressBar) PlayerHaptics.selection();
    setState(() {
      _dragValue = value;
    });
    _framePreviewController.request(position);
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
    });
    _framePreviewController.request(position);
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

  void _cancelFramePreview() {
    _sliderDragging = false;
    _framePreviewController.cancel();
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
          icon != null ? Icon(icon, size: 18) : const SizedBox(width: 18),
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
    return '$label · ${track.typeLabel} · ${track.sourceLabel}';
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
            child: Text(
              track.title.isNotEmpty
                  ? track.title
                  : (track.language.isNotEmpty ? track.language : track.codec),
            ),
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
                  Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
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
