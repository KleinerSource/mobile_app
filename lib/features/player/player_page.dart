import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/providers.dart';
import '../../core/api/url_resolver.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/playback.dart' as playback_models;
import '../../core/platform/app_theme.dart';
import '../movies/movies_providers.dart';
import 'player_controller_host.dart';
import 'player_controls.dart';
import 'player_device_stats.dart';
import 'player_gesture_layer.dart';
import 'player_overlay_indicators.dart';
import 'player_platform.dart';
import 'player_queue.dart';
import 'player_settings.dart';
import 'player_status_overlay.dart';

/// 全屏视频播放页。播放源由后端协商，页面只负责编排回退、进度和用户控制。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.movieId,
    required this.title,
    this.startPositionSec = 0,
    this.queue = const <PlayerQueueItem>[],
    this.queueIndex = 0,
  });

  final int movieId;
  final String title;
  final int startPositionSec;
  final List<PlayerQueueItem> queue;
  final int queueIndex;

  static Future<void> open(
    BuildContext context, {
    required int movieId,
    required String title,
    int startPositionSec = 0,
    List<PlayerQueueItem> queue = const <PlayerQueueItem>[],
    int queueIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          movieId: movieId,
          title: title,
          startPositionSec: startPositionSec,
          queue: queue,
          queueIndex: queueIndex,
        ),
      ),
    );
  }

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver {
  static const List<DeviceOrientation> _portraitOrientations = [
    DeviceOrientation.portraitUp,
  ];

  final PlayerControllerHost _host = PlayerControllerHost();
  final PlayerDeviceStatsReader _deviceStatsReader =
      PlayerDeviceStatsReader();

  bool _loading = true;
  String? _error;
  String _quality = 'original';
  playback_models.PlaybackDecision? _decision;
  bool _usingHls = false;
  bool _clientHardwareAcceleration = true;
  bool _transcodeSessionActive = false;
  String? _serverHardwareLabel;
  int _loadGeneration = 0;

  int _lastPositionSec = 0;
  int _lastDurationSec = 0;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<playback_models.TranscodeStatus>? _eventsSub;
  Timer? _transcodePollTimer;
  Timer? _deviceStatsTimer;
  PlayerDeviceStats _deviceStats = const PlayerDeviceStats();

  bool _controlsVisible = true;
  Timer? _hideTimer;
  PlayerIndicator? _indicator;
  Timer? _indicatorTimer;
  double _brightness = 0.5;
  double _volume = 0.5;
  double? _restoreBrightness;
  bool _wasPlayingBeforePause = false;
  Duration _backgroundPosition = Duration.zero;
  bool _handlingPlaybackError = false;
  bool _isLandscape = true;
  bool _isRateBoosting = false;
  double _playbackRate = 1.0;
  bool _pictureInPictureRequesting = false;
  bool _isLeaving = false;
  Future<void>? _stopPlayerFuture;
  bool _orientationInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_applyEntryOrientation(ref.read(playerSettingsProvider)));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    FlutterVolumeController.updateShowSystemUI(false);
    // ignore: discarded_futures
    WakelockPlus.enable();
    _initLevels();
    _startDeviceStatsPolling();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orientationInitialized) return;
    final settings = ref.read(playerSettingsProvider);
    _isLandscape = switch (settings.entryOrientation) {
      PlayerEntryOrientation.forceLandscape => true,
      PlayerEntryOrientation.forcePortrait => false,
      PlayerEntryOrientation.unchanged =>
        MediaQuery.of(context).orientation == Orientation.landscape,
    };
    _orientationInitialized = true;
  }

  Future<void> _applyEntryOrientation(PlayerSettings settings) async {
    final orientations = switch (settings.entryOrientation) {
      PlayerEntryOrientation.unchanged => null,
      PlayerEntryOrientation.forceLandscape => [
          _landscapeOrientation(settings.landscapeSide),
        ],
      PlayerEntryOrientation.forcePortrait => _portraitOrientations,
    };
    if (orientations == null) return;
    await SystemChrome.setPreferredOrientations(orientations);
  }

  DeviceOrientation _landscapeOrientation(PlayerLandscapeSide side) {
    return side == PlayerLandscapeSide.cameraLeft
        ? DeviceOrientation.landscapeLeft
        : DeviceOrientation.landscapeRight;
  }

  Future<void> _initLevels() async {
    try {
      _restoreBrightness = await ScreenBrightness.instance.application;
      _brightness = _restoreBrightness ?? 0.5;
    } catch (_) {}
    try {
      _volume = await FlutterVolumeController.getVolume() ?? 0.5;
    } catch (_) {}
  }

  void _startDeviceStatsPolling() {
    unawaited(_refreshDeviceStats());
    _deviceStatsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshDeviceStats()),
    );
  }

  Future<void> _refreshDeviceStats() async {
    if (_isLeaving) return;
    final settings = ref.read(playerSettingsProvider);
    if (!settings.showNetworkSpeed &&
        !settings.showCpuUsage &&
        !settings.showBattery) {
      return;
    }
    final stats = await _deviceStatsReader.read();
    if (!mounted || _isLeaving) return;
    setState(() => _deviceStats = stats);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isLeaving) return;
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        !_pictureInPictureRequesting) {
      _onRateBoostEnd();
      _wasPlayingBeforePause = _host.player.state.playing;
      _backgroundPosition = _host.position;
      // ignore: discarded_futures
      _host.player.pause();
      if (_transcodeSessionActive) {
        // ignore: discarded_futures
        _stopTranscodeSession();
      }
    } else if (state == AppLifecycleState.resumed && _wasPlayingBeforePause) {
      if (_usingHls) {
        // HLS 会话在后台已停止，恢复时以当前位置重新协商并起播。
        // ignore: discarded_futures
        _load(resume: _backgroundPosition);
      } else {
        // ignore: discarded_futures
        _host.player.play();
      }
    }
  }

  @override
  void dispose() {
    _isLeaving = true;
    _loadGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    _durSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _eventsSub?.cancel();
    _transcodePollTimer?.cancel();
    _deviceStatsTimer?.cancel();
    _hideTimer?.cancel();
    _onRateBoostEnd();
    _indicatorTimer?.cancel();
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    FlutterVolumeController.updateShowSystemUI(true);
    if (_restoreBrightness != null) {
      // ignore: discarded_futures
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    }
    _reportProgress();
    if (_transcodeSessionActive) {
      _transcodeSessionActive = false;
      try {
        final stopFuture = ref
            .read(requiredApiClientProvider)
            .playback
            .stop(widget.movieId);
        unawaited(stopFuture);
      } catch (_) {}
    }
    // ignore: discarded_futures
    WakelockPlus.disable();
    unawaited(_disposePlayer());
    super.dispose();
  }

  void _reportProgress() {
    if (_lastDurationSec <= 0 || _lastPositionSec <= 0) return;
    // ignore: discarded_futures
    ref.read(moviesRepositoryProvider).upsertWatchRecord(
          widget.movieId,
          positionSec: _lastPositionSec,
          durationSec: _lastDurationSec,
          completed: _lastPositionSec >= (_lastDurationSec * 0.95),
        );
  }

  Future<void> _load({
    String? quality,
    Duration? resume,
    bool forceHls = false,
    bool forceSoftware = false,
  }) async {
    if (_isLeaving) return;
    final generation = ++_loadGeneration;
    final selectedQuality = quality ?? _quality;
    _onRateBoostEnd();
    await _stopTranscodeSession();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _quality = selectedQuality;
      _decision = null;
      _serverHardwareLabel = null;
    });

    try {
      final cfg = ref.read(serverConfigProvider);
      if (cfg == null) throw StateError('未配置服务器');
      final client = ref.read(requiredApiClientProvider);
      final token = await ref.read(authSessionRepositoryProvider).accessToken();

      if (forceSoftware) {
        if (_clientHardwareAcceleration) {
          await _host.recreate(enableHardwareAcceleration: false);
        }
        _clientHardwareAcceleration = false;
      } else if (!_clientHardwareAcceleration) {
        await _host.recreate(enableHardwareAcceleration: true);
        _clientHardwareAcceleration = true;
      }

      final decision = await client.playback.decision(
        widget.movieId,
        _clientCaps(selectedQuality),
      );
      if (!mounted || generation != _loadGeneration) return;
      _decision = decision;
      if (decision.hwAccel.isNotEmpty) {
        _serverHardwareLabel = '硬解 ${decision.hwAccel}';
      }

      final resumeFromLastPosition =
          ref.read(playerSettingsProvider).resumeFromLastPosition;
      final startAt = resume ??
          (resumeFromLastPosition && widget.startPositionSec > 0
              ? Duration(seconds: widget.startPositionSec)
              : null);
      final direct = !forceHls &&
          !decision.isTranscode &&
          !decision.mimeType.contains('mpegurl');
      if (direct) {
        final directUrl = resolveServerUrl(cfg, decision.streamUrl);
        try {
          await _host.open(
            directUrl,
            startAt: startAt,
            headers: _authorizationHeaders(token),
          );
          _usingHls = false;
        } catch (_) {
          // 直传失败时切换到服务端 HLS，再考虑关闭客户端硬解。
          final hlsUrl = _fallbackHlsUrl(cfg, token, selectedQuality);
          await _openHlsWithClientFallback(hlsUrl, startAt);
        }
      } else {
        final hlsUrl = decision.isTranscode
            ? _protectedUrl(cfg, decision.streamUrl, token)
            : _fallbackHlsUrl(cfg, token, selectedQuality);
        await _openHlsWithClientFallback(hlsUrl, startAt);
      }
      if (_playbackRate != 1.0) {
        await _host.setRate(_playbackRate);
      }

      if (!mounted || generation != _loadGeneration) return;
      _bindProgress();
      await _applyDefaultTracks(cfg, token, decision);
      if (decision.isTranscode || _usingHls) {
        _transcodeSessionActive = true;
        _startTranscodeMonitoring(selectedQuality == 'original' ? 'auto' : selectedQuality);
      }
      setState(() => _loading = false);
      _restartHideTimer();
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = toApiException(error).message;
        _loading = false;
      });
    }
  }

  Future<void> _openHlsWithClientFallback(String url, Duration? startAt) async {
    try {
      await _host.open(url, startAt: startAt);
    } catch (_) {
      if (!_clientHardwareAcceleration) rethrow;
      await _host.recreate(enableHardwareAcceleration: false);
      _clientHardwareAcceleration = false;
      await _host.open(url, startAt: startAt);
    }
    _usingHls = true;
  }

  Future<void> _applyDefaultTracks(
    ServerConfig cfg,
    String? token,
    playback_models.PlaybackDecision decision,
  ) async {
    playback_models.SubtitleTrack? defaultSubtitle;
    for (final track in decision.subtitleTracks) {
      if (track.isDefault) {
        defaultSubtitle = track;
        break;
      }
    }
    if (defaultSubtitle != null) {
      await _selectSubtitle(cfg, token, defaultSubtitle);
    }
    playback_models.AudioTrack? defaultAudio;
    for (final track in decision.audioTracks) {
      if (track.isDefault) {
        defaultAudio = track;
        break;
      }
    }
    if (defaultAudio != null) {
      await _host.setAudioTrackById(defaultAudio.index.toString());
    }
  }

  void _bindProgress() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _posSub = _host.positionStream.listen((position) {
      _lastPositionSec = position.inSeconds;
    });
    _durSub = _host.durationStream.listen((duration) {
      _lastDurationSec = duration.inSeconds;
    });
    _completedSub = _host.completedStream.listen((completed) {
      if (!_isLeaving && completed && _lastDurationSec > 0) {
        _lastPositionSec = _lastDurationSec;
        _reportProgress();
        // ignore: discarded_futures
        _stopTranscodeSession();
      }
    });
    _errorSub = _host.errorStream.listen(_onPlayerError);
  }

  void _onPlayerError(String message) {
    if (!mounted || _isLeaving || _loading || _handlingPlaybackError) return;
    _handlingPlaybackError = true;
    final resume = _host.position;
    unawaited(_recoverFromPlayerError(message, resume));
  }

  Future<void> _recoverFromPlayerError(String message, Duration resume) async {
    try {
      if (_usingHls && _clientHardwareAcceleration) {
        await _load(
          resume: resume,
          forceHls: true,
          forceSoftware: true,
        );
      } else if (!_usingHls) {
        await _load(resume: resume, forceHls: true);
      } else if (mounted) {
        setState(() {
          _error = toApiException(message).message;
          _loading = false;
        });
      }
    } finally {
      _handlingPlaybackError = false;
    }
  }

  Future<void> _onQualityChanged(String quality) async {
    final position = _host.position;
    await _load(quality: quality, resume: position);
  }

  void _togglePlay() {
    if (_isLeaving) return;
    if (_host.player.state.playing) {
      _backgroundPosition = _host.position;
      // HLS 会话不能在暂停期间继续占用服务端转码资源。
      // ignore: discarded_futures
      _host.player.pause();
      if (_transcodeSessionActive) {
        // ignore: discarded_futures
        _stopTranscodeSession();
      }
      return;
    }
    if (_usingHls) {
      // ignore: discarded_futures
      _load(
        resume: _backgroundPosition == Duration.zero
            ? _host.position
            : _backgroundPosition,
      );
      return;
    }
    // ignore: discarded_futures
    _host.player.play();
  }

  Future<void> _selectSubtitle(
    ServerConfig cfg,
    String? token,
    playback_models.SubtitleTrack? track,
  ) async {
    if (track == null) {
      await _host.clearSubtitle();
      return;
    }
    if (track.source == 'embedded') {
      await _host.setSubtitleTrackById(track.index.toString());
      return;
    }
    if (track.url.isEmpty) return;
    await _host.setSubtitleUrl(_protectedUrl(cfg, track.url, token));
  }

  Future<void> _openExternalPlayer() async {
    try {
      final cfg = ref.read(serverConfigProvider);
      if (cfg == null) throw StateError('未配置服务器');
      final client = ref.read(requiredApiClientProvider);
      final token = await ref.read(authSessionRepositoryProvider).accessToken();
      final raw = await client.playback.streamUrl(widget.movieId);
      final url = _protectedUrl(cfg, raw, token);
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showError('系统没有可用的外部播放器');
      }
    } catch (error) {
      if (mounted) _showError(toApiException(error).message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _stopTranscodeSession() async {
    await _eventsSub?.cancel();
    _eventsSub = null;
    _transcodePollTimer?.cancel();
    _transcodePollTimer = null;
    if (!_transcodeSessionActive) return;
    _transcodeSessionActive = false;
    try {
      await ref.read(requiredApiClientProvider).playback.stop(widget.movieId);
    } catch (_) {}
  }

  void _startTranscodeMonitoring(String quality) {
    _eventsSub?.cancel();
    _transcodePollTimer?.cancel();
    final api = ref.read(requiredApiClientProvider).playback;
    _eventsSub = api.events(widget.movieId, quality: quality).listen(
      _applyTranscodeStatus,
      onError: (_) => _startTranscodePolling(quality),
      onDone: () => _startTranscodePolling(quality),
    );
    _transcodePollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollTranscodeStatus(quality),
    );
  }

  void _startTranscodePolling(String quality) {
    if (_transcodePollTimer != null) return;
    _transcodePollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollTranscodeStatus(quality),
    );
  }

  Future<void> _pollTranscodeStatus(String quality) async {
    if (!mounted || _isLeaving || !_transcodeSessionActive) return;
    try {
      final status = await ref
          .read(requiredApiClientProvider)
          .playback
          .status(widget.movieId, quality: quality);
      _applyTranscodeStatus(status);
    } catch (_) {}
  }

  void _applyTranscodeStatus(playback_models.TranscodeStatus status) {
    if (!mounted || _isLeaving) return;
    setState(() {
      _serverHardwareLabel = !status.active || status.hwAccel.isEmpty
          ? null
          : status.hwDecodeOk
              ? '硬解 ${status.hwAccel}'
              : '软解回退';
    });
  }

  Map<String, String>? _authorizationHeaders(String? token) {
    final value = token?.trim() ?? '';
    if (value.isEmpty) return null;
    return {'Authorization': 'Bearer $value'};
  }

  String _fallbackHlsUrl(
    ServerConfig cfg,
    String? token,
    String quality,
  ) {
    final selected = quality == 'original' ? 'auto' : quality;
    final path =
        '/api/movies/id/${widget.movieId}/stream.m3u8?quality=$selected';
    return appendQueryToken(resolveServerUrl(cfg, path), token);
  }

  String _protectedUrl(ServerConfig cfg, String raw, String? token) {
    return resolveProtectedUrl(cfg, raw, token);
  }

  playback_models.PlaybackClientCaps _clientCaps(String quality) {
    final os = kIsWeb ? 'flutter-web' : Platform.operatingSystem;
    return playback_models.PlaybackClientCaps(
      containers: const [
        'mp4',
        'mov',
        'm4v',
        'matroska',
        'mkv',
        'webm',
        'mpegts',
      ],
      videoCodecs: const {
        'h264': playback_models.VideoCodecCapability(
          pixFormats: ['yuv420p', 'yuvj420p'],
        ),
        'avc1': playback_models.VideoCodecCapability(
          pixFormats: ['yuv420p', 'yuvj420p'],
        ),
        'hevc': playback_models.VideoCodecCapability(
          pixFormats: ['yuv420p', 'yuv420p10le'],
        ),
        'h265': playback_models.VideoCodecCapability(
          pixFormats: ['yuv420p', 'yuv420p10le'],
        ),
        'vp9': playback_models.VideoCodecCapability(
          pixFormats: ['yuv420p', 'yuv420p10le'],
        ),
        'av1': playback_models.VideoCodecCapability(
          pixFormats: ['yuv420p', 'yuv420p10le'],
        ),
      },
      audioCodecs: const {
        'aac': playback_models.AudioCodecCapability(maxChannels: 8),
        'ac3': playback_models.AudioCodecCapability(maxChannels: 8),
        'eac3': playback_models.AudioCodecCapability(maxChannels: 8),
        'mp3': playback_models.AudioCodecCapability(maxChannels: 2),
        'opus': playback_models.AudioCodecCapability(maxChannels: 8),
        'vorbis': playback_models.AudioCodecCapability(maxChannels: 8),
        'flac': playback_models.AudioCodecCapability(maxChannels: 8),
      },
      qualityPreset: quality,
      userAgent: 'md_center/$os',
    );
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      setState(() => _controlsVisible = true);
      _restartHideTimer();
    }
  }

  void _onRateBoost(double rate) {
    if (_isLeaving) return;
    _isRateBoosting = true;
    unawaited(_host.setRate(rate));
    _showIndicator(PlayerIndicator.speed(rate), autoHide: false);
  }

  void _onRateBoostEnd() {
    if (!_isRateBoosting) return;
    _isRateBoosting = false;
    unawaited(_host.setRate(_playbackRate));
    _hideIndicator();
  }

  void _onRateChanged(double rate) {
    if (_isLeaving) return;
    _playbackRate = rate;
    unawaited(_host.setRate(rate));
    _showIndicator(PlayerIndicator.speed(rate));
  }

  void _onDoubleTapCenter() {
    if (_isLeaving) return;
    _togglePlay();
  }

  void _onDoubleTapSeek(int deltaSeconds) {
    if (_isLeaving) return;
    final base = _host.position;
    final total = _host.duration;
    var targetMs = base.inMilliseconds + deltaSeconds * 1000;
    if (targetMs < 0) targetMs = 0;
    if (total > Duration.zero && targetMs > total.inMilliseconds) {
      targetMs = total.inMilliseconds;
    }
    final target = Duration(milliseconds: targetMs);
    unawaited(_host.seek(target));
    _showIndicator(
      PlayerIndicator.seek(
        target: target,
        total: total,
        deltaMs: target.inMilliseconds - base.inMilliseconds,
      ),
    );
  }

  Future<void> _enterPictureInPicture() async {
    if (_isLeaving) return;
    _pictureInPictureRequesting = true;
    try {
      final entered =
          await PlayerPlatformCapabilities.enterPictureInPicture();
      if (!entered && mounted) {
        await _openExternalPlayer();
      }
    } finally {
      _pictureInPictureRequesting = false;
    }
  }

  Future<void> _switchMedia(int index) async {
    if (_isLeaving || index < 0 || index >= widget.queue.length) return;
    final item = widget.queue[index];
    _isLeaving = true;
    _loadGeneration++;
    _hideTimer?.cancel();
    _onRateBoostEnd();
    _reportProgress();
    try {
      await _stopPlayer();
      await _stopTranscodeSession();
    } finally {
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => PlayerPage(
            movieId: item.movieId,
            title: item.title,
            startPositionSec: item.startPositionSec,
            queue: widget.queue,
            queueIndex: index,
          ),
        ),
      );
    }
  }

  Future<void> _toggleOrientation() async {
    final nextIsLandscape = !_isLandscape;
    setState(() => _isLandscape = nextIsLandscape);
    try {
      final side = ref.read(playerSettingsProvider).landscapeSide;
      await SystemChrome.setPreferredOrientations(
        nextIsLandscape
            ? [_landscapeOrientation(side)]
            : _portraitOrientations,
      );
    } catch (_) {
      if (mounted) setState(() => _isLandscape = !nextIsLandscape);
    }
  }

  void _onSeekPreview(Duration target, int deltaMs) {
    if (_isLeaving) return;
    _showIndicator(
      PlayerIndicator.seek(
        target: target,
        total: _host.duration,
        deltaMs: deltaMs,
      ),
      autoHide: false,
    );
  }

  void _onSeekCommit(Duration target) {
    if (_isLeaving) return;
    // ignore: discarded_futures
    _host.seek(target);
    _hideIndicator();
  }

  void _onBrightnessDelta(double delta) {
    _brightness = (_brightness + delta).clamp(0.0, 1.0);
    // ignore: discarded_futures
    ScreenBrightness.instance.setApplicationScreenBrightness(_brightness);
    _showIndicator(PlayerIndicator.brightness(_brightness), autoHide: false);
  }

  void _onVolumeDelta(double delta) {
    _volume = (_volume + delta).clamp(0.0, 1.0);
    // ignore: discarded_futures
    FlutterVolumeController.setVolume(_volume);
    _showIndicator(PlayerIndicator.volume(_volume), autoHide: false);
  }

  void _showIndicator(PlayerIndicator indicator, {bool autoHide = true}) {
    _indicatorTimer?.cancel();
    setState(() => _indicator = indicator);
    if (autoHide) {
      _indicatorTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _indicator = null);
      });
    }
  }

  void _hideIndicator() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _indicator = null);
    });
  }

  Future<void> _stopPlayer() {
    return _stopPlayerFuture ??= _stopPlayerInternal();
  }

  Future<void> _stopPlayerInternal() async {
    try {
      await _host.stop();
    } catch (_) {}
  }

  Future<void> _disposePlayer() async {
    await _stopPlayer();
    try {
      await _host.dispose();
    } catch (_) {}
  }

  Future<void> _exitPlayer() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _loadGeneration++;
    _hideTimer?.cancel();
    _onRateBoostEnd();
    _reportProgress();
    try {
      await _stopPlayer();
      await _stopTranscodeSession();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exitPlayer());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _body()),
              Positioned(
                top: 6,
                left: 6,
                child: IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _isLeaving
                      ? null
                      : () => unawaited(_exitPlayer()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final settings = ref.watch(playerSettingsProvider);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final decision = _decision;
    if (decision == null) {
      return _ErrorView(message: '播放决策为空', onRetry: _load);
    }
    final hardwareLabel = _serverHardwareLabel ??
        (_clientHardwareAcceleration ? '硬解开启' : '客户端软解');
    return Stack(
      children: [
        Positioned.fill(
          child: Video(
            controller: _host.controller,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),
        Positioned.fill(
          child: PlayerGestureLayer(
            positionGetter: () => _host.position,
            durationGetter: () => _host.duration,
            onTap: _toggleControls,
            doubleTapCenterEnabled: settings.doubleTapCenter,
            doubleTapEdgesEnabled: settings.doubleTapEdges,
            onDoubleTapCenter: _onDoubleTapCenter,
            onDoubleTapSeek: _onDoubleTapSeek,
            hapticLongPress: settings.hapticLongPress,
            hapticSeek: settings.hapticSeek,
            hapticRate: settings.hapticRate,
            onRateBoost: _onRateBoost,
            onRateBoostEnd: _onRateBoostEnd,
            onSeekPreview: _onSeekPreview,
            onSeekCommit: _onSeekCommit,
            onBrightnessDelta: _onBrightnessDelta,
            onVolumeDelta: _onVolumeDelta,
            onAxisDragEnd: _hideIndicator,
          ),
        ),
        Positioned.fill(child: PlayerOverlayIndicators(indicator: _indicator)),
        Positioned(
          top: 58,
          left: 16,
          right: 16,
          child: PlayerStatusOverlay(
            stats: _deviceStats,
            showSystemTime: settings.showSystemTime,
            showNetworkSpeed: settings.showNetworkSpeed,
            showCpuUsage: settings.showCpuUsage,
            showBattery: settings.showBattery,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: PlayerControls(
                player: _host.player,
                title: widget.title,
                quality: _quality,
                onQualityChanged: _onQualityChanged,
                subtitleTracks: decision.subtitleTracks,
                onSubtitleChanged: (track) {
                  final cfg = ref.read(serverConfigProvider);
                  if (cfg == null) return;
                  ref
                      .read(authSessionRepositoryProvider)
                      .accessToken()
                      .then((token) => _selectSubtitle(cfg, token, track));
                },
                audioTracks: decision.audioTracks,
                onAudioChanged: (track) {
                  // 后端 track index 与 media_kit 的轨道 ID 一致时直接切换。
                  _host.setAudioTrackById(track.index.toString());
                },
                hardwareLabel: hardwareLabel,
                hapticProgressBar: settings.hapticProgressBar,
                showPlayPauseButton: settings.showPlayPauseButton,
                showSeekButtons: settings.showSeekButtons,
                showSpeedButton: settings.showSpeedButton,
                showPipButton: settings.showPipButton,
                showOrientationButton: settings.showOrientationButton,
                showMediaSwitchButton: settings.showMediaSwitchButton,
                playbackRate: _playbackRate,
                onExternalPlayer: _openExternalPlayer,
                onPictureInPicture: () =>
                    unawaited(_enterPictureInPicture()),
                onPreviousMedia: widget.queueIndex > 0
                    ? () => unawaited(_switchMedia(widget.queueIndex - 1))
                    : null,
                onNextMedia: widget.queueIndex < widget.queue.length - 1
                    ? () => unawaited(_switchMedia(widget.queueIndex + 1))
                    : null,
                isLandscape: _isLandscape,
                onOrientationToggle: () => unawaited(_toggleOrientation()),
                onTogglePlay: _togglePlay,
                onSeekBackward: () => _onDoubleTapSeek(-10),
                onSeekForward: () => _onDoubleTapSeek(10),
                onRateChanged: _onRateChanged,
                onSeek: _host.seek,
                onInteraction: _restartHideTimer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.danger, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
