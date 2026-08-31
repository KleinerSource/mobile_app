import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/platform/app_haptics.dart';
import '../../../core/platform/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    with TickerProviderStateMixin {
  // 唱片一整圈对应固定的音轨时间；自然旋转、Scratch 和释放惯性必须
  // 使用同一个基准，否则视觉速度和实际音频速度会彼此漂移。
  static const _rotationPeriodSeconds = 1.8;
  static final _rotationPeriod = Duration(
    microseconds: (_rotationPeriodSeconds * Duration.microsecondsPerSecond)
        .round(),
  );
  // 歌词只在自己的槽位内变化，不能通过改变父级高度推动唱盘。
  static const double _lyricsSlotHeight = 108;
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
    if (_disableAnimations) {
      _stopRotationTicker();
      _syncTonearm(_scratchActive || _scratchFinishing);
      return;
    }

    if (_scratchActive) {
      _stopRotationTicker();
      _syncTonearm(true);
      return;
    }
    if (_scratchFinishing && _nativeScratchActive) {
      _syncTonearm(true);
      _startRotationTicker();
      return;
    }
    if (_scratchFinishing) {
      _stopRotationTicker();
      _syncTonearm(true);
      return;
    }

    final playing = _isPlaybackActive;
    _syncTonearm(playing);
    if (playing) {
      _startRotationTicker();
    } else {
      _stopRotationTicker();
    }
  }

  void _syncTonearm(bool engaged) {
    final target = engaged ? 1.0 : 0.0;
    if (_tonearmTarget == target) return;
    _tonearmTarget = target;
    if (_disableAnimations) {
      _tonearmController.stop();
      _tonearmController.value = target;
      return;
    }
    unawaited(
      _tonearmController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(0.0, constraints.maxWidth - 48);
        final maxHeight = math.max(0.0, constraints.maxHeight * 0.52);
        final cardSize = math.min(math.min(maxWidth, maxHeight), 380.0);
        final deckSize = cardSize + 28;
        final lyricsWidth = math.min(maxWidth, 420.0);
        final stageWidth = math.max(deckSize, lyricsWidth);
        final stageHeight = deckSize + _lyricsSlotHeight;
        final hasLyrics = widget.lyrics != null && !widget.lyrics!.isEmpty;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: IgnorePointer(child: _djBackdrop(context))),
            Align(
              alignment: const Alignment(0, -0.18),
              // stageHeight 恒定，歌词的出现/消失不会改变唱盘的定位基准。
              child: SizedBox(
                width: stageWidth,
                height: stageHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ValueListenableBuilder<PlaybackViewState>(
                        valueListenable: widget.controller,
                        builder: (context, state, _) => _djDeck(
                          context,
                          recordSize: cardSize,
                          state: state,
                        ),
                      ),
                    ),
                    Positioned(
                      top: deckSize + 18,
                      left: 0,
                      right: 0,
                      height: _lyricsSlotHeight - 18,
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
                                width: lyricsWidth,
                                height: _lyricsSlotHeight - 18,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: AudioLyricsView(
                                    controller: widget.controller,
                                    lyrics: widget.lyrics,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('no-lyrics')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _djBackdrop(BuildContext context) {
    final colors = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.12, -0.28),
                radius: 1.05,
                colors: [
                  colors.glow1.withValues(alpha: isDark ? 0.18 : 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, 0.85),
                radius: 0.9,
                colors: [
                  colors.glow2.withValues(alpha: isDark ? 0.14 : 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _djDeck(
    BuildContext context, {
    required double recordSize,
    required PlaybackViewState state,
  }) {
    final colors = appColors(context);
    final l10n = AppL10n.of(context);
    final deckSize = recordSize + 28;
    final durationMs = state.duration.inMilliseconds;
    final progress = durationMs <= 0
        ? 0.0
        : (state.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
    final rate = state.rate.isFinite ? state.rate : 1.0;

    return SizedBox(
      key: const ValueKey<String>('audio-dj-deck'),
      width: deckSize,
      height: deckSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey<String>('audio-dj-progress-ring'),
                painter: _DjProgressRingPainter(
                  progress: progress,
                  trackColor: colors.text.withValues(alpha: 0.12),
                  progressColor: colors.accent,
                ),
              ),
            ),
          ),
          Center(child: _artwork(recordSize, state)),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _tonearmController,
                builder: (_, __) => CustomPaint(
                  key: const ValueKey<String>('audio-dj-tonearm'),
                  painter: _DjTonearmPainter(
                    progress: _tonearmController.value,
                    color: colors.text.withValues(alpha: 0.78),
                    accent: colors.accent,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: deckSize * 0.06,
            left: deckSize * 0.10,
            child: IgnorePointer(
              child: _DjBadge(label: l10n.playerDjDeckA, color: colors.text),
            ),
          ),
          Positioned(
            top: deckSize * 0.06,
            right: deckSize * 0.10,
            child: IgnorePointer(
              child: _DjStatusBadge(
                label: state.playing
                    ? l10n.playerDjPlaying
                    : l10n.playerDjPaused,
                active: state.playing,
                color: colors.text,
                activeColor: colors.accent,
              ),
            ),
          ),
          Positioned(
            bottom: deckSize * 0.06,
            right: deckSize * 0.10,
            child: IgnorePointer(
              child: _DjBadge(
                label: '${l10n.playerDjPitch} ${rate.toStringAsFixed(2)}x',
                color: colors.muted,
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
        hint: l10n.playerDjGestureHint,
        onTap: enabled ? _toggleFromRecord : null,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: enabled
              ? (event) => _onScratchPointerDown(event, size)
              : null,
          onPointerMove: enabled
              ? (event) => _onScratchPointerMove(event, size)
              : null,
          onPointerUp: enabled ? (_) => _clearScratchCandidate() : null,
          onPointerCancel: enabled ? (_) => _clearScratchCandidate() : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _toggleFromRecord : null,
            onPanStart: enabled
                ? (details) => _onScratchStart(details, size)
                : null,
            onPanUpdate: enabled
                ? (details) => _onScratchUpdate(details, size)
                : null,
            onPanEnd: enabled ? (details) => _finishScratch(details) : null,
            onPanCancel: enabled ? _finishScratch : null,
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
    final elapsedSeconds = _scratchSampleElapsedSeconds();
    final scratchRate = elapsedSeconds > 0
        ? (turns * _rotationPeriodSeconds / elapsedSeconds).clamp(-8.0, 8.0)
        : 0.0;
    _scratchAudioRate = scratchRate;
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
    _scratchAudioRate = 0;
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
    _scratchAudioRate = 0;
    _stopRotationTicker();
    _syncTonearm(true);
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
    final cancelNativeStart = _nativeScratchRequested && !_nativeScratchActive;
    if (cancelNativeStart) {
      // 原生 PCM 可能仍在下载/解码。释放手势时取消这次切入，不能让收尾
      // 等待它完成，否则主播放器会在手指离开后长时间保持静音。
      _scratchStartCancelled = true;
      unawaited(widget.controller.cancelScratchStart());
    } else {
      _startScratchSeekDrain();
    }
    final wasPlaying = _scratchWasPlaying == true;
    final generation = _scratchGeneration;
    final seekFuture = _scratchSeekFuture;
    _scratchActive = false;
    _scratchFinishing = true;
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
      } else {
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
        _syncRotation();
      }
    }
  }

  void _requestScratchPlaybackResume(int generation) {
    unawaited(_resumePlaybackAfterScratch(generation));
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
    _scratchAudioRate = currentRate;
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
      _scratchAudioRate = currentRate;
      await widget.controller.setScratchRate(currentRate);
    }

    await widget.controller.finishScratch(resumePlayback: resumePlayback);
    _nativeScratchActive = false;
  }

  double _normalPlaybackRate() {
    final rate = widget.controller.value.rate;
    return rate.isFinite && rate > 0 ? rate : 1.0;
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

class _DjBadge extends StatelessWidget {
  const _DjBadge({required this.label, required this.color});

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

class _DjStatusBadge extends StatelessWidget {
  const _DjStatusBadge({
    required this.label,
    required this.active,
    required this.color,
    required this.activeColor,
  });

  final String label;
  final bool active;
  final Color color;
  final Color activeColor;

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? activeColor : color.withValues(alpha: 0.42),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(label, style: AppText.mono(context, size: 9, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DjProgressRingPainter extends CustomPainter {
  const _DjProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
    final endpoint = Offset(
      center.dx + radius * math.cos(-math.pi / 2 + math.pi * 2 * progress),
      center.dy + radius * math.sin(-math.pi / 2 + math.pi * 2 * progress),
    );
    canvas.drawCircle(endpoint, 3.5, Paint()..color = progressColor);
  }

  @override
  bool shouldRepaint(covariant _DjProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _DjTonearmPainter extends CustomPainter {
  const _DjTonearmPainter({
    required this.progress,
    required this.color,
    required this.accent,
  });

  final double progress;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.80, size.height * 0.12);
    final parkedElbow = Offset(size.width * 0.76, size.height * 0.14);
    final engagedElbow = Offset(size.width * 0.46, size.height * 0.42);
    final parkedNeedle = Offset(size.width * 0.68, size.height * 0.20);
    final engagedNeedle = Offset(size.width * 0.38, size.height * 0.59);
    final elbow = Offset.lerp(parkedElbow, engagedElbow, progress)!;
    final needle = Offset.lerp(parkedNeedle, engagedNeedle, progress)!;
    final armPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(3.0, size.width * 0.012);
    canvas.drawLine(pivot, elbow, armPaint);
    canvas.drawLine(elbow, needle, armPaint);
    canvas.drawCircle(
      pivot,
      math.max(5.0, size.width * 0.022),
      armPaint..style = PaintingStyle.fill,
    );

    final cartridge = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(needle, math.max(3.0, size.width * 0.014), cartridge);
  }

  @override
  bool shouldRepaint(covariant _DjTonearmPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.accent != accent;
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
