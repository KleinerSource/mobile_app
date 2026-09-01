import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

import '../../../core/platform/app_haptics.dart';
import '../../../core/platform/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'audio_lyrics_view.dart';
import 'audio_spectrum.dart';
import 'lrc_parser.dart';
import '../common/playback_engine.dart';
import '../common/player_session_controller.dart';

const _vinylRecordAsset = 'assets/audio_player/vinyl_record_matte.png';
const _turntableTonearmAsset = 'assets/audio_player/turntable_tonearm.png';

class AudioNowPlayingView extends StatefulWidget {
  const AudioNowPlayingView({
    super.key,
    required this.controller,
    required this.artworkPath,
    required this.lyrics,
    required this.spectrum,
    this.scratchEnabled = true,
    this.onLyricsPanelVisibilityChanged,
  });

  final PlayerSessionController controller;
  final String? artworkPath;
  final LrcDocument? lyrics;
  final ValueListenable<AudioSpectrumFrame> spectrum;

  /// 是否允许在唱片上搓碟（DJ 台）。远程直链音源没有本地 PCM，
  /// 原生搓碟引擎无法工作，此时应关闭；点按播放/暂停不受影响。
  final bool scratchEnabled;
  final ValueChanged<bool>? onLyricsPanelVisibilityChanged;

  @override
  State<AudioNowPlayingView> createState() => _AudioNowPlayingViewState();
}

class _AudioNowPlayingViewState extends State<AudioNowPlayingView>
    with TickerProviderStateMixin {
  // 唱片一整圈对应固定的音轨时间；自然旋转、Scratch 和释放惯性必须
  // 使用同一个基准，否则视觉速度和实际音频速度会彼此漂移。
  static const _rotationPeriodSeconds = 1.8;
  static final _rotationPeriod = Duration(
    microseconds: (_rotationPeriodSeconds * Duration.microsecondsPerSecond)
        .round(),
  );
  static const _gestureThreshold = 10.0;
  static const _innerGestureRadiusFactor = 0.16;
  static const _maxScratchMomentum = 6.0;
  static const _scratchMotorTick = Duration(milliseconds: 16);
  static const _scratchMotorStrength = 6.0;
  static const _scratchMotorRateTolerance = 0.005;
  late final AnimationController _rotationController =
      AnimationController.unbounded(vsync: this, value: 0);
  late final Ticker _rotationTicker = createTicker(_advanceRotation);
  late final AnimationController _tonearmController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 0,
  );
  Duration? _lastTick;
  double? _tonearmTarget;
  bool _disableAnimations = false;
  bool _lyricsPanelOpen = false;
  Offset? _scratchStartPoint;
  Offset? _scratchCenter;
  Offset? _lastScratchLocalPosition;
  Offset? _previousScratchSamplePoint;
  Duration? _previousScratchSampleTime;
  Duration? _lastScratchSampleTime;
  double? _lastScratchAngle;
  Duration? _scratchPosition;
  Future<void>? _scratchSeekFuture;
  Timer? _scratchSeekTimer;
  Timer? _scratchRateStopTimer;
  Duration? _pendingScratchSeek;
  bool _scratchActive = false;
  bool _scratchFinishing = false;
  bool? _scratchWasPlaying;
  int _scratchGeneration = 0;
  bool _nativeScratchRequested = false;
  bool _nativeScratchActive = false;
  bool _scratchStartCancelled = false;
  double _scratchAudioRate = 0;
  final ValueNotifier<({bool scratching, double rate})> _turntableRate =
      ValueNotifier((scratching: false, rate: 0));
  Future<void>? _scratchAudioStartFuture;

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
    if (_lyricsPanelOpen) {
      _stopRotationTicker();
      _tonearmController.stop();
      return;
    }
    final progress = _trackProgress(widget.controller.value);
    if (_disableAnimations) {
      _stopRotationTicker();
      _syncTonearm(
        _scratchActive || _scratchFinishing ? _scratchProgress : progress,
        immediate: true,
      );
      return;
    }

    if (_scratchActive) {
      _stopRotationTicker();
      _syncTonearm(_scratchProgress, immediate: true);
      return;
    }
    if (_scratchFinishing && _nativeScratchActive) {
      _syncTonearm(_scratchProgress, immediate: true);
      _startRotationTicker();
      return;
    }
    if (_scratchFinishing) {
      _stopRotationTicker();
      _syncTonearm(_scratchProgress, immediate: true);
      return;
    }

    final playing = _isPlaybackActive;
    _syncTonearm(progress);
    if (playing) {
      _startRotationTicker();
    } else {
      _stopRotationTicker();
    }
  }

  void _setLyricsPanelVisibility(bool visible) {
    if (_lyricsPanelOpen == visible) return;
    _lyricsPanelOpen = visible;
    if (!visible) _tonearmTarget = null;
    _syncRotation();
    widget.onLyricsPanelVisibilityChanged?.call(visible);
  }

  void _syncTonearm(double progress, {bool immediate = false}) {
    final target = progress.clamp(0.0, 1.0).toDouble();
    if (_tonearmTarget == target &&
        (!immediate || !_tonearmController.isAnimating)) {
      return;
    }
    _tonearmTarget = target;
    if (_disableAnimations || immediate) {
      _tonearmController.stop();
      _tonearmController.value = target;
      return;
    }
    unawaited(
      _tonearmController.animateTo(
        target,
        duration: Duration(
          milliseconds: target == 0 || target == 1 ? 320 : 180,
        ),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  double _trackProgress(PlaybackViewState state) {
    return _progressFor(state.position, state.duration);
  }

  double get _scratchProgress {
    return _progressFor(
      _scratchPosition ?? widget.controller.position,
      widget.controller.duration,
    );
  }

  double _progressFor(Duration position, Duration duration) {
    if (duration <= Duration.zero) return 0;
    return (position.inMicroseconds / duration.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void _startRotationTicker() {
    if (_rotationTicker.isActive) return;
    _lastTick = null;
    _rotationTicker.start();
  }

  void _stopRotationTicker() {
    if (_rotationTicker.isActive) _rotationTicker.stop();
    _lastTick = null;
  }

  bool get _isPlaybackActive {
    final state = widget.controller.value;
    return state.playing &&
        state.lifecycle == PlaybackLifecycle.ready &&
        !state.buffering;
  }

  void _advanceRotation(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    if (_scratchFinishing && _nativeScratchActive) {
      final elapsedSeconds =
          (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
      _rotationController.value +=
          elapsedSeconds / _rotationPeriodSeconds * _scratchAudioRate;
      return;
    }
    if (!_isPlaybackActive) return;
    final elapsedFraction =
        (elapsed - previous).inMicroseconds / _rotationPeriod.inMicroseconds;
    final rate = widget.controller.value.rate;
    final playbackRate = rate.isFinite && rate > 0 ? rate : 1.0;
    _rotationController.value += elapsedFraction * playbackRate;
  }

  @override
  void dispose() {
    _scratchGeneration++;
    _scratchSeekTimer?.cancel();
    _scratchRateStopTimer?.cancel();
    widget.controller.removeListener(_syncRotation);
    _stopRotationTicker();
    _rotationTicker.dispose();
    _tonearmController.dispose();
    _rotationController.dispose();
    _turntableRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = AudioNowPlayingGeometry.fromConstraints(constraints);
        final hasLyrics = widget.lyrics != null && !widget.lyrics!.isEmpty;

        return Padding(
          padding: const EdgeInsets.only(
            top: AudioNowPlayingGeometry.stageTopInset,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            // stageHeight 恒定，歌词的出现/消失不会改变唱盘的定位基准。
            child: SizedBox(
              key: const ValueKey<String>('audio-now-playing-stage'),
              width: geometry.stageWidth,
              height: geometry.stageHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ValueListenableBuilder<PlaybackViewState>(
                      valueListenable: widget.controller,
                      builder: (context, state, _) => _djDeck(
                        context,
                        recordSize: geometry.recordSize,
                        state: state,
                      ),
                    ),
                  ),
                  Positioned(
                    top:
                        geometry.deckSize +
                        AudioNowPlayingGeometry.lyricsTopInset,
                    left: 0,
                    right: 0,
                    height:
                        AudioNowPlayingGeometry.lyricsSlotHeight -
                        AudioNowPlayingGeometry.lyricsTopInset,
                    child: AnimatedSwitcher(
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
                          ? SizedBox(
                              key: const ValueKey('lyrics'),
                              width: geometry.lyricsWidth,
                              height:
                                  AudioNowPlayingGeometry.lyricsSlotHeight -
                                  AudioNowPlayingGeometry.lyricsTopInset,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: AudioLyricsView(
                                  controller: widget.controller,
                                  lyrics: widget.lyrics,
                                  spectrum: widget.spectrum,
                                  onPanelVisibilityChanged:
                                      _setLyricsPanelVisibility,
                                ),
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('no-lyrics'),
                              width: geometry.lyricsWidth,
                              height:
                                  AudioNowPlayingGeometry.lyricsSlotHeight -
                                  AudioNowPlayingGeometry.lyricsTopInset,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: LyricsAudioSpectrum(
                                  spectrum: widget.spectrum,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
      },
    );
  }

  Widget _djDeck(
    BuildContext context, {
    required double recordSize,
    required PlaybackViewState state,
  }) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final l10n = AppL10n.of(context);
    final deckSize = recordSize + 28;
    return SizedBox(
      key: const ValueKey<String>('audio-dj-deck'),
      width: deckSize,
      height: deckSize,
      child: Stack(
        key: const ValueKey<String>('audio-dj-deck-layers'),
        clipBehavior: Clip.none,
        children: [
          Center(
            key: const ValueKey<String>('audio-vinyl-layer'),
            child: _artwork(recordSize, state),
          ),
          Center(
            key: const ValueKey<String>('audio-vinyl-light-layer'),
            child: SizedBox.square(
              dimension: recordSize,
              child: const _VinylLightOverlay(),
            ),
          ),
          Positioned.fill(
            key: const ValueKey<String>('audio-tonearm-layer'),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _tonearmController,
                builder: (_, __) =>
                    _TurntableTonearm(progress: _tonearmController.value),
              ),
            ),
          ),
          Positioned(
            bottom: deckSize * 0.06,
            right: deckSize * 0.10,
            child: IgnorePointer(
              child: ValueListenableBuilder<({bool scratching, double rate})>(
                valueListenable: _turntableRate,
                builder: (_, turntableRate, __) {
                  final rate = turntableRate.scratching
                      ? turntableRate.rate
                      : _playbackTurntableRate(state);
                  return _DjBadge(
                    key: const ValueKey<String>('audio-dj-speed'),
                    label: '${l10n.playerDjPitch} ${rate.toStringAsFixed(2)}x',
                    color: foreground.withValues(alpha: 0.62),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _artwork(double size, PlaybackViewState state) {
    final l10n = AppL10n.of(context);
    final enabled = _recordInteractionEnabled(state);
    // 搓碟依赖本地 PCM；远程直链音源关闭搓碟手势，点按播放/暂停保留。
    final scratchEnabled = widget.scratchEnabled && enabled;
    return SizedBox(
      key: _recordGestureKey,
      width: size,
      height: size,
      child: Semantics(
        key: const ValueKey<String>('audio-dj-record-semantics'),
        container: true,
        button: true,
        enabled: enabled,
        label: l10n.playerDjDeck,
        hint: scratchEnabled ? l10n.playerDjGestureHint : null,
        onTap: enabled ? _toggleFromRecord : null,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: scratchEnabled
              ? (event) => _onScratchPointerDown(event, size)
              : null,
          onPointerMove: scratchEnabled
              ? (event) => _onScratchPointerMove(event, size)
              : null,
          onPointerUp: scratchEnabled ? (_) => _clearScratchCandidate() : null,
          onPointerCancel: scratchEnabled
              ? (_) => _clearScratchCandidate()
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _toggleFromRecord : null,
            onPanStart: scratchEnabled
                ? (details) => _onScratchStart(details, size)
                : null,
            onPanUpdate: scratchEnabled
                ? (details) => _onScratchUpdate(details, size)
                : null,
            onPanEnd: scratchEnabled
                ? (details) => _finishScratch(details)
                : null,
            onPanCancel: scratchEnabled ? _finishScratch : null,
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
        ),
      ),
    );
  }

  bool _recordInteractionEnabled(PlaybackViewState state) {
    return state.lifecycle != PlaybackLifecycle.idle &&
        state.lifecycle != PlaybackLifecycle.opening &&
        state.duration > Duration.zero;
  }

  void _toggleFromRecord() {
    if (!_recordInteractionEnabled(widget.controller.value) ||
        _scratchActive ||
        _scratchFinishing) {
      return;
    }
    AppHaptics.selection();
    unawaited(widget.controller.playOrPause());
  }

  void _onScratchPointerDown(PointerDownEvent event, double size) {
    if (_scratchActive ||
        _scratchFinishing ||
        _scratchSeekFuture != null ||
        !_recordInteractionEnabled(widget.controller.value)) {
      return;
    }
    _prepareScratchCandidate(event.position, event.localPosition, size);
    _lastScratchSampleTime = event.timeStamp;
  }

  void _onScratchPointerMove(PointerMoveEvent event, double size) {
    if (_scratchStartPoint == null) return;
    final localPosition = _recordLocalPosition(
      event.position,
      event.localPosition,
    );
    _previousScratchSamplePoint = _lastScratchLocalPosition;
    _previousScratchSampleTime = _lastScratchSampleTime;
    _lastScratchLocalPosition = localPosition;
    _lastScratchSampleTime = event.timeStamp;
    if (_scratchActive) _scheduleScratchRateStop();
  }

  void _prepareScratchCandidate(
    Offset globalPosition,
    Offset fallbackLocalPosition,
    double size,
  ) {
    final center = Offset(size / 2, size / 2);
    final localPosition = _recordLocalPosition(
      globalPosition,
      fallbackLocalPosition,
    );
    final vector = localPosition - center;
    _scratchStartPoint = localPosition;
    _scratchCenter = center;
    _lastScratchLocalPosition = localPosition;
    _previousScratchSamplePoint = null;
    _previousScratchSampleTime = null;
    _lastScratchSampleTime = null;
    _lastScratchAngle = vector.distance >= size * _innerGestureRadiusFactor
        ? math.atan2(vector.dy, vector.dx)
        : null;
    _scratchPosition = null;
  }

  void _onScratchStart(DragStartDetails details, double size) {
    if (_scratchStartPoint == null) {
      _prepareScratchCandidate(
        details.globalPosition,
        details.localPosition,
        size,
      );
    }
    _applyScratchPosition(details.globalPosition, details.localPosition, size);
  }

  void _onScratchUpdate(DragUpdateDetails details, double size) {
    _applyScratchPosition(details.globalPosition, details.localPosition, size);
  }

  void _applyScratchPosition(
    Offset globalPosition,
    Offset fallbackLocalPosition,
    double size,
  ) {
    final start = _scratchStartPoint;
    final center = _scratchCenter;
    if (start == null || center == null) return;
    final localPosition = _recordLocalPosition(
      globalPosition,
      fallbackLocalPosition,
    );
    _lastScratchLocalPosition = localPosition;
    if (!_scratchActive &&
        (localPosition - start).distance < _gestureThreshold) {
      return;
    }

    final vector = localPosition - center;
    if (vector.distance < size * _innerGestureRadiusFactor) {
      _lastScratchAngle = null;
      return;
    }
    final angle = math.atan2(vector.dy, vector.dx);
    final previous = _lastScratchAngle;
    _lastScratchAngle = angle;
    if (previous == null) return;

    var angleDelta = angle - previous;
    if (angleDelta > math.pi) angleDelta -= math.pi * 2;
    if (angleDelta < -math.pi) angleDelta += math.pi * 2;
    if (angleDelta.abs() < 0.0001 ||
        widget.controller.duration <= Duration.zero) {
      return;
    }

    if (!_scratchActive) _beginScratch();
    final turns = angleDelta / (math.pi * 2);
    _rotationController.value += turns;

    final current = _scratchPosition ?? widget.controller.position;
    final deltaMicros = (turns * _rotationPeriod.inMicroseconds).round();
    final target = _clampPosition(
      current + Duration(microseconds: deltaMicros),
    );
    _scratchPosition = target;
    _syncTonearm(_scratchProgress, immediate: true);
    final elapsedSeconds = _scratchSampleElapsedSeconds();
    final scratchRate = elapsedSeconds > 0
        ? (turns * _rotationPeriodSeconds / elapsedSeconds).clamp(-8.0, 8.0)
        : 0.0;
    _setScratchAudioRate(scratchRate);
    if (_nativeScratchRequested) {
      unawaited(widget.controller.setScratchRate(scratchRate));
    } else {
      _enqueueScratchSeek(target);
    }
    _scheduleScratchRateStop();
  }

  void _scheduleScratchRateStop() {
    _scratchRateStopTimer?.cancel();
    _scratchRateStopTimer = Timer(
      const Duration(milliseconds: 50),
      _stopScratchRateAfterIdle,
    );
  }

  void _stopScratchRateAfterIdle() {
    _scratchRateStopTimer = null;
    if (!_scratchActive || _scratchFinishing || _scratchAudioRate == 0) {
      return;
    }
    _setScratchAudioRate(0);
    if (_nativeScratchRequested) {
      unawaited(widget.controller.setScratchRate(0));
    }
  }

  double _scratchSampleElapsedSeconds() {
    final previous = _previousScratchSampleTime;
    final current = _lastScratchSampleTime;
    if (previous == null || current == null || current <= previous) return 0;
    return (current - previous).inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _clearScratchCandidate() {
    if (_scratchActive || _scratchFinishing) return;
    _scratchStartPoint = null;
    _scratchCenter = null;
    _lastScratchLocalPosition = null;
    _previousScratchSamplePoint = null;
    _previousScratchSampleTime = null;
    _lastScratchSampleTime = null;
    _lastScratchAngle = null;
    _scratchPosition = null;
  }

  void _beginScratch() {
    _scratchActive = true;
    _scratchWasPlaying = widget.controller.playbackIntent;
    _scratchPosition = _clampPosition(widget.controller.position);
    _pendingScratchSeek = null;
    _scratchGeneration++;
    _nativeScratchRequested = widget.controller.supportsScratch;
    _nativeScratchActive = false;
    _scratchStartCancelled = false;
    _setScratchAudioRate(0);
    _stopRotationTicker();
    _syncTonearm(_scratchProgress, immediate: true);
    AppHaptics.light();
    if (_nativeScratchRequested) {
      final future = _startNativeScratch(_scratchGeneration, _scratchPosition!);
      _scratchAudioStartFuture = future;
      unawaited(future);
    } else if (_scratchWasPlaying != true) {
      unawaited(_startScratchAudioPreview());
    }
  }

  void _enqueueScratchSeek(Duration target) {
    _pendingScratchSeek = target;
    if (_scratchSeekFuture != null || _scratchSeekTimer != null) return;

    _scratchSeekTimer = Timer(
      const Duration(milliseconds: 16),
      _startScratchSeekDrain,
    );
  }

  void _startScratchSeekDrain() {
    _scratchSeekTimer = null;
    if (_scratchSeekFuture != null || _pendingScratchSeek == null) return;

    final generation = _scratchGeneration;
    final future = _drainScratchSeeks(generation);
    _scratchSeekFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_scratchSeekFuture, future)) {
          _scratchSeekFuture = null;
        }
      }),
    );
  }

  Future<void> _drainScratchSeeks(int generation) async {
    while (mounted && generation == _scratchGeneration) {
      final target = _pendingScratchSeek;
      _pendingScratchSeek = null;
      if (target == null) return;
      await widget.controller.seek(target, waitForPlaybackResume: false);
    }
  }

  void _finishScratch([DragEndDetails? details]) {
    final momentumVelocity = _scratchReleaseVelocity(details);
    final releaseAudioRate = _scratchReleaseAudioRate(momentumVelocity);
    _scratchStartPoint = null;
    _scratchCenter = null;
    _lastScratchLocalPosition = null;
    _previousScratchSamplePoint = null;
    _previousScratchSampleTime = null;
    _lastScratchSampleTime = null;
    _lastScratchAngle = null;
    if (!_scratchActive) return;

    _scratchSeekTimer?.cancel();
    _scratchSeekTimer = null;
    _scratchRateStopTimer?.cancel();
    _scratchRateStopTimer = null;
    final wasPlaying = _scratchWasPlaying == true;
    final cancelNativeStart = _nativeScratchRequested && !_nativeScratchActive;
    Future<void>? seekFuture;
    if (cancelNativeStart) {
      // 原生 PCM 可能仍在下载/解码。释放手势时取消这次切入，不能让收尾
      // 等待它完成，否则主播放器会在手指离开后长时间保持静音。
      _scratchStartCancelled = true;
      seekFuture = _cancelNativeScratchStartAt(_scratchPosition);
    } else {
      _startScratchSeekDrain();
      seekFuture = _scratchSeekFuture;
    }
    final generation = _scratchGeneration;
    _scratchActive = false;
    _scratchFinishing = true;
    _syncTurntableRate();
    unawaited(
      _completeScratch(
        wasPlaying,
        generation,
        seekFuture,
        momentumVelocity,
        releaseAudioRate,
      ),
    );
  }

  double _scratchReleaseAudioRate(double momentumVelocity) {
    final sampledRate = _scratchAudioRate.isFinite ? _scratchAudioRate : 0.0;
    if (momentumVelocity.isFinite && momentumVelocity.abs() >= 0.01) {
      return (momentumVelocity * _rotationPeriodSeconds)
          .clamp(-8.0, 8.0)
          .toDouble();
    }
    return sampledRate.clamp(-8.0, 8.0).toDouble();
  }

  double _scratchReleaseVelocity(DragEndDetails? details) {
    final center = _scratchCenter;
    final point = _lastScratchLocalPosition;
    if (center == null || point == null) return 0;

    final radius = point - center;
    final radiusSquared = radius.distanceSquared;
    if (radiusSquared < 1) return 0;

    final pixelsPerSecond = details?.velocity.pixelsPerSecond;
    if (pixelsPerSecond != null &&
        pixelsPerSecond.dx.isFinite &&
        pixelsPerSecond.dy.isFinite) {
      final angularVelocity =
          (radius.dx * pixelsPerSecond.dy - radius.dy * pixelsPerSecond.dx) /
          radiusSquared;
      if (angularVelocity.isFinite && angularVelocity.abs() >= 0.0001) {
        return (angularVelocity / (math.pi * 2)).clamp(
          -_maxScratchMomentum,
          _maxScratchMomentum,
        );
      }
    }

    final previousPoint = _previousScratchSamplePoint;
    final previousTime = _previousScratchSampleTime;
    final currentTime = _lastScratchSampleTime;
    if (previousPoint == null ||
        previousTime == null ||
        currentTime == null ||
        currentTime <= previousTime) {
      return 0;
    }
    final previousVector = previousPoint - center;
    final currentVector = point - center;
    if (previousVector.distanceSquared < 1 ||
        currentVector.distanceSquared < 1) {
      return 0;
    }
    var angleDelta =
        math.atan2(currentVector.dy, currentVector.dx) -
        math.atan2(previousVector.dy, previousVector.dx);
    if (angleDelta > math.pi) angleDelta -= math.pi * 2;
    if (angleDelta < -math.pi) angleDelta += math.pi * 2;
    final elapsedSeconds =
        (currentTime - previousTime).inMicroseconds / 1000000;
    final velocity = angleDelta / (math.pi * 2) / elapsedSeconds;
    return velocity.isFinite
        ? velocity.clamp(-_maxScratchMomentum, _maxScratchMomentum)
        : 0;
  }

  Future<void> _completeScratch(
    bool wasPlaying,
    int generation,
    Future<void>? seekFuture,
    double momentumVelocity,
    double releaseAudioRate,
  ) async {
    try {
      if (seekFuture != null) await seekFuture;
      final startWasCancelled = _scratchStartCancelled;
      if (!startWasCancelled) {
        final startFuture = _scratchAudioStartFuture;
        if (startFuture != null) await startFuture;
      }
      final usedNativeScratch = _nativeScratchActive;
      if (usedNativeScratch) {
        await _releaseNativeScratch(
          releaseAudioRate,
          resumePlayback: wasPlaying,
        );
      } else if (!startWasCancelled) {
        await _playScratchBackspin(momentumVelocity: momentumVelocity);
      }
      if (!mounted || generation != _scratchGeneration) return;
      if (!usedNativeScratch && wasPlaying && !startWasCancelled) {
        _requestScratchPlaybackResume(generation);
      } else if (!usedNativeScratch && !startWasCancelled) {
        await widget.controller.pause();
      }
    } catch (_) {
      // Seek/播放失败时仍需释放刮碟状态，页面的统一播放错误链路负责提示。
    } finally {
      if (mounted && generation == _scratchGeneration) {
        _scratchFinishing = false;
        _scratchWasPlaying = null;
        _scratchPosition = null;
        _scratchAudioStartFuture = null;
        _nativeScratchRequested = false;
        _nativeScratchActive = false;
        _scratchStartCancelled = false;
        _syncTurntableRate();
        _syncRotation();
      }
    }
  }

  void _requestScratchPlaybackResume(int generation) {
    unawaited(_resumePlaybackAfterScratch(generation));
  }

  Future<void> _cancelNativeScratchStartAt(Duration? position) async {
    await widget.controller.cancelScratchStart();
    if (position != null) {
      await widget.controller.seek(position, waitForPlaybackResume: false);
    }
  }

  Future<void> _startScratchAudioPreview() async {
    try {
      await widget.controller.play();
    } catch (_) {
      // 预览播放失败时仍保留原本的暂停意图。
    }
  }

  Future<void> _startNativeScratch(int generation, Duration position) async {
    try {
      final started = await widget.controller.startScratch(
        position,
        resumePlayback: _scratchWasPlaying == true,
      );
      if (!started) {
        _nativeScratchRequested = false;
        if (_scratchStartCancelled) return;
        if (mounted && generation == _scratchGeneration) {
          final target = _scratchPosition;
          if (target != null && _scratchActive) {
            _enqueueScratchSeek(target);
          } else if (target != null && _scratchFinishing) {
            await widget.controller.seek(target, waitForPlaybackResume: false);
          }
          if (_scratchWasPlaying != true && _scratchActive) {
            unawaited(_startScratchAudioPreview());
          }
        }
        return;
      }
      if (_scratchStartCancelled ||
          !mounted ||
          generation != _scratchGeneration) {
        await widget.controller.finishScratch(
          resumePlayback: _scratchWasPlaying == true,
        );
        return;
      }
      _nativeScratchActive = true;
      await widget.controller.setScratchRate(_scratchAudioRate);
      _syncRotation();
    } catch (_) {
      _nativeScratchRequested = false;
    }
  }

  Future<void> _releaseNativeScratch(
    double releaseRate, {
    required bool resumePlayback,
  }) async {
    // 释放不是固定时长的 UI 动画，而是把唱盘当前角速度交给电机模型：
    // 反向甩碟先自然减速到 0，再向正常播放速率加速。
    final targetRate = resumePlayback ? _normalPlaybackRate() : 0.0;
    var currentRate = releaseRate.isFinite
        ? releaseRate.clamp(-8.0, 8.0).toDouble()
        : 0.0;
    _setScratchAudioRate(currentRate);
    _syncRotation();
    await widget.controller.setScratchRate(currentRate);

    final tickSeconds =
        _scratchMotorTick.inMicroseconds / Duration.microsecondsPerSecond;
    final response = 1 - math.exp(-_scratchMotorStrength * tickSeconds);
    while ((currentRate - targetRate).abs() > _scratchMotorRateTolerance) {
      await Future<void>.delayed(_scratchMotorTick);
      if (!mounted) return;
      currentRate += (targetRate - currentRate) * response;
      if ((currentRate - targetRate).abs() <= _scratchMotorRateTolerance) {
        currentRate = targetRate;
      }
      _setScratchAudioRate(currentRate);
      await widget.controller.setScratchRate(currentRate);
    }

    await widget.controller.finishScratch(resumePlayback: resumePlayback);
    _nativeScratchActive = false;
  }

  double _normalPlaybackRate() {
    final rate = widget.controller.value.rate;
    return rate.isFinite && rate > 0 ? rate : 1.0;
  }

  double _playbackTurntableRate(PlaybackViewState state) {
    if (!state.playing ||
        state.lifecycle != PlaybackLifecycle.ready ||
        state.buffering) {
      return 0;
    }
    final rate = state.rate;
    return rate.isFinite && rate > 0 ? rate : 1.0;
  }

  void _setScratchAudioRate(double rate) {
    _scratchAudioRate = rate;
    _syncTurntableRate();
  }

  void _syncTurntableRate() {
    final next = (
      scratching: _scratchActive || _scratchFinishing,
      rate: _scratchAudioRate,
    );
    if (_turntableRate.value != next) _turntableRate.value = next;
  }

  Future<void> _playScratchBackspin({required double momentumVelocity}) async {
    // 只有明显甩动才进入 Backspin；普通释放应立即交还播放状态，避免
    // 一次轻微的拖动结束也改变主音轨的最终位置。
    if (!momentumVelocity.isFinite || momentumVelocity.abs() < 4.0) return;
    final start = _scratchPosition;
    if (start == null || !mounted) return;

    final reverseDirection = momentumVelocity >= 0 ? -1 : 1;
    final turns = momentumVelocity.abs().clamp(1.0, _maxScratchMomentum);
    final offsetMicros = (reverseDirection * turns * 180000).round();
    final target = _clampPosition(start + Duration(microseconds: offsetMicros));
    try {
      // 单通道 Backspin 使用一次反向回定位，随后由当前播放意图继续播放，
      // 避免用额外延迟任务制造第二条音频时钟。
      await widget.controller.seek(target, waitForPlaybackResume: false);
    } catch (_) {
      // Backspin 是增强反馈，失败时仍需恢复主播放器状态。
    }
  }

  Future<void> _resumePlaybackAfterScratch(int generation) async {
    try {
      // 音频服务的 play() Future 可能直到当前曲目结束才完成；这里只发起
      // 播放请求，不能让唱片的状态收尾等待整个曲目播放完毕。
      await widget.controller.play();
    } catch (_) {
      // 播放失败时清除待恢复标记，避免唱片在暂停状态继续旋转。
    } finally {
      if (mounted && generation == _scratchGeneration) {
        _syncRotation();
      }
    }
  }

  Duration _clampPosition(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    final duration = widget.controller.duration;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
  }

  final GlobalKey _recordGestureKey = GlobalKey();

  Offset _recordLocalPosition(Offset globalPosition, Offset fallback) {
    final renderObject = _recordGestureKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(globalPosition);
    }
    return fallback;
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
              Positioned.fill(
                child: Image.asset(
                  _vinylRecordAsset,
                  key: const ValueKey<String>('audio-vinyl-image'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
              const Positioned.fill(
                child: ColoredBox(
                  key: ValueKey<String>('audio-vinyl-material-shade'),
                  color: Color(0xB3000000),
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

class _DjBadge extends StatelessWidget {
  const _DjBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(label, style: AppText.mono(context, size: 9, color: color)),
      ),
    );
  }
}

class _VinylLightOverlay extends StatelessWidget {
  const _VinylLightOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ClipOval(
        key: ValueKey<String>('audio-vinyl-light-overlay'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.0, -0.55),
                  end: Alignment(1.0, 0.55),
                  colors: [
                    Colors.transparent,
                    Color(0x08FFFFFF),
                    Color(0x1FFFFFFF),
                    Color(0x06FFFFFF),
                    Colors.transparent,
                  ],
                  stops: [0.12, 0.35, 0.49, 0.62, 0.84],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.48, -0.58),
                  radius: 0.92,
                  colors: [Color(0x14FFFFFF), Colors.transparent],
                  stops: [0.0, 0.66],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurntableTonearm extends StatelessWidget {
  const _TurntableTonearm({required this.progress});

  // 资源中的机械轴心约位于 (78%, 24%)，磁头约位于 (7.5%, 92%)。
  // 放大到唱盘直径的一半以上后，磁头在末端才能落到唱片内圈。
  static const _tonearmSizeFactor = 0.54;
  static const _startAngleDegrees = -45.0;
  // 末端停在唱片内圈，给中心封面留出安全间距。
  static const _endAngleDegrees = -22.0;
  static const _pivotAlignment = Alignment(0.56, -0.52);

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    // 唱臂保持固定尺寸，只围绕图片中的机械轴心转动。
    final angleDegrees =
        _startAngleDegrees +
        (_endAngleDegrees - _startAngleDegrees) * clampedProgress;
    return LayoutBuilder(
      builder: (context, constraints) {
        final deckSize = math.min(constraints.maxWidth, constraints.maxHeight);
        final tonearmSize = deckSize * _tonearmSizeFactor;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              width: tonearmSize,
              height: tonearmSize,
              top: 0,
              right: 0,
              child: Transform.rotate(
                key: const ValueKey<String>('audio-dj-tonearm'),
                angle: angleDegrees * math.pi / 180,
                alignment: _pivotAlignment,
                child: Image.asset(
                  _turntableTonearmAsset,
                  key: const ValueKey<String>('audio-dj-tonearm-image'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
        );
      },
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
