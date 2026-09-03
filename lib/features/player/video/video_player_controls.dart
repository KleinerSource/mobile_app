import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/models/playback.dart' as playback_models;
import '../../../l10n/generated/app_localizations.dart';
import 'frame_preview_controller.dart';
import '../common/playback_engine.dart';
import 'player_decode_status.dart';
import '../common/player_haptics.dart';
import '../common/player_overlay_indicators.dart' show formatDuration;
import '../common/player_session_controller.dart';

enum _SubtitleMenuAction { openSettings }

/// 视频播放器控制层 · 顶部页面操作 + 底部媒体信息、进度和主播放控制。
///
/// 控制层只覆盖顶部和底部，中央区域始终留给手势层。
class VideoPlayerControls extends StatefulWidget {
  const VideoPlayerControls({
    super.key,
    required this.controller,
    this.previewSourceUri,
    this.previewSourceHeaders,
    required this.quality,
    required this.qualityOptions,
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
  final List<playback_models.QualityOption> qualityOptions;
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
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
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

  /// 是否已收到按下定位之后的移动：首次 onChanged 是“跳到按下点”，
  /// 点按跳转与拖动起点无法区分，不作为跨档刻度反馈。
  bool _sliderDragMoved = false;
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
  void didUpdateWidget(covariant VideoPlayerControls oldWidget) {
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

  Color _foreground(BuildContext context) {
    return Colors.white;
  }

  Color _mutedForeground(BuildContext context) {
    return _foreground(context).withValues(alpha: 0.3);
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          _topActionButton(
            icon: Icons.close,
            tooltip: AppL10n.of(context).playerExitPlayback,
            onPressed: widget.onExit,
          ),
          const Spacer(),
          if (widget.showPipButton)
            _topActionButton(
              icon: Icons.picture_in_picture_alt,
              tooltip: AppL10n.of(context).playerPictureInPicture,
              onPressed: () {
                widget.onPictureInPicture();
                widget.onInteraction();
              },
            ),
          if (widget.showOrientationButton)
            _topActionButton(
              icon: Icons.screen_rotation,
              tooltip: widget.isLandscape
                  ? AppL10n.of(context).playerSwitchToPortrait
                  : AppL10n.of(context).playerSwitchToLandscape,
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
      icon: Icon(icon, color: _foreground(context), size: 25),
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
          child: widget.decodeStatuses.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  children: [
                    for (final status in widget.decodeStatuses)
                      PlayerDecodeStatusBadge(status: status),
                  ],
                ),
        ),
        if (widget.showQualityButton) _qualityButton(),
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
          tooltip: AppL10n.of(context).playerPreviousMedia,
          onPressed: widget.onPreviousMedia,
        ),
      if (widget.showSeekButtons)
        _actionButton(
          icon: Icons.replay_10,
          tooltip: AppL10n.of(context).playerSeekBack10Seconds,
          onPressed: widget.onSeekBackward,
        ),
      if (widget.showPlayPauseButton) _playPauseButton(),
      if (widget.showSeekButtons)
        _actionButton(
          icon: Icons.forward_10,
          tooltip: AppL10n.of(context).playerSeekForward10Seconds,
          onPressed: widget.onSeekForward,
        ),
      if (widget.showMediaSwitchButton)
        _actionButton(
          icon: Icons.skip_next,
          tooltip: AppL10n.of(context).playerNextMedia,
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
    bool active = false,
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
        color: action == null
            ? _mutedForeground(context)
            : active
            ? const Color(0xFF8ED8FF)
            : _foreground(context),
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
      tooltip: AppL10n.of(
        context,
      ).playerPlaybackSpeed('${widget.playbackRate.toStringAsFixed(1)}x'),
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
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Icon(Icons.speed, color: _foreground(context), size: 25),
        ),
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
            color: _foreground(context),
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
      style: TextStyle(
        color: _foreground(context),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _progressSlider() {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final capabilities = widget.controller.capabilities;
        final dur = state.duration.inMilliseconds;
        final pos = state.position.inMilliseconds;
        final buffer = state.buffered.inMilliseconds;
        final max = dur > 0 ? dur.toDouble() : 1.0;
        final live = pos.clamp(0, max.toInt()).toDouble();
        final buffered = buffer.toDouble().clamp(live, max).toDouble();
        final value = _dragValue ?? live;
        final previewPosition = capabilities.framePreview
            ? _framePreviewController.position
            : null;
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
                    activeTrackColor: _foreground(context),
                    secondaryActiveTrackColor: Colors.white60,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: _foreground(context),
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    min: 0,
                    max: max,
                    value: value.clamp(0, max),
                    secondaryTrackValue: capabilities.customBuffering
                        ? buffered
                        : null,
                    semanticFormatterCallback: (sliderValue) {
                      final l = AppL10n.of(context);
                      final current = Duration(
                        milliseconds: sliderValue.round(),
                      );
                      if (!capabilities.customBuffering) {
                        return l.playerSliderPosition(formatDuration(current));
                      }
                      final cached = Duration(milliseconds: buffered.round());
                      return l.playerSliderPositionBuffered(
                        formatDuration(current),
                        formatDuration(cached),
                      );
                    },
                    onChangeStart: dur <= 0 ? null : (v) => _beginSliderDrag(v),
                    onChanged: dur <= 0 ? null : (v) => _updateSliderDrag(v),
                    onChangeEnd: dur <= 0 ? null : (v) => _endSliderDrag(v),
                  ),
                ),
                if (capabilities.framePreview &&
                    _sliderDragging &&
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
    _sliderDragMoved = false;
    // 按下确认一次；松手不震，拖动由跨档刻度反馈。
    if (widget.hapticProgressBar) PlayerHaptics.selection();
    setState(() {
      _dragValue = value;
    });
    if (widget.controller.capabilities.framePreview) {
      _framePreviewController.request(position);
    }
    widget.onInteraction();
  }

  void _updateSliderDrag(double value) {
    final bucket = (value / _sliderHapticStepMs).floor();
    if (!_sliderDragMoved) {
      _lastSliderHapticBucket = bucket;
      _sliderDragMoved = true;
    } else if (widget.hapticProgressBar && bucket != _lastSliderHapticBucket) {
      _lastSliderHapticBucket = bucket;
      PlayerHaptics.selection();
    }
    final position = Duration(milliseconds: value.round());
    setState(() {
      _dragValue = value;
    });
    if (widget.controller.capabilities.framePreview) {
      _framePreviewController.request(position);
    }
    widget.onInteraction();
  }

  void _endSliderDrag(double value) {
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
    final l = AppL10n.of(context);
    return PopupMenuButton<String>(
      tooltip: l.playerSelectQuality,
      enableFeedback: false,
      initialValue: widget.quality,
      padding: EdgeInsets.zero,
      onSelected: (quality) {
        if (quality != widget.quality) PlayerHaptics.selection();
        widget.onQualityChanged(quality);
        widget.onInteraction();
      },
      itemBuilder: (context) => [
        for (final option in widget.qualityOptions)
          PopupMenuItem(
            value: option.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.kind == 'auto' ? l.playerQualityAuto : option.label,
                  ),
                ),
                const SizedBox(width: 16),
                option.id == widget.quality
                    ? const Icon(Icons.check, size: 18)
                    : const SizedBox(width: 18),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: _roundIcon(Icons.high_quality_outlined, active: true),
        ),
      ),
    );
  }

  Widget _subtitleButton() {
    final l = AppL10n.of(context);
    return PopupMenuButton<Object>(
      tooltip: l.playerSelectSubtitle,
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
        PopupMenuItem<Object>(
          value: _SubtitleMenuAction.openSettings,
          child: Row(
            children: [
              const Icon(Icons.tune, size: 18),
              const SizedBox(width: 10),
              Text(l.settingsSubtitleSettings),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        _subtitleMenuItem(
          _noSubtitleTrack,
          label: l.playerSubtitleOff,
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

  /// 字幕轨道菜单文案。模型层不再提供本地化标签（内嵌/外挂等），
  /// 这里按轨道字段在 UI 层组装本地化描述。
  String _subtitleLabel(playback_models.SubtitleTrack track) {
    final l = AppL10n.of(context);
    final label = track.title.isNotEmpty
        ? track.title
        : (track.language.isNotEmpty ? track.language : l.playerSubtitleName);
    final codec = track.codec.trim().isEmpty ? l.codecUnknown : track.typeLabel;
    final source = track.isEmbedded
        ? l.subtitleSourceEmbedded
        : track.isExternal
        ? l.subtitleSourceExternal
        : (track.source.trim().isEmpty
              ? l.subtitleSourceUnknown
              : track.source.trim());
    return '$label · $codec · $source';
  }

  Widget _audioButton() {
    return PopupMenuButton<playback_models.AudioTrack>(
      tooltip: AppL10n.of(context).playerSelectAudioTrack,
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
      width: _VideoPlayerControlsState._framePreviewWidth,
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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppL10n.of(context).playerFramePreviewUnavailable,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
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
