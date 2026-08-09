import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/providers.dart';
import '../../core/api/url_resolver.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/playback.dart' as playback_models;
import '../../core/models/watch_record.dart';
import '../../core/platform/app_theme.dart';
import '../home/home_providers.dart';
import '../movies/movies_providers.dart';
import 'player_controller_host.dart';
import 'player_controls.dart';
import 'player_decode_status.dart';
import 'player_device_stats.dart';
import 'player_gesture_layer.dart';
import 'player_overlay_indicators.dart';
import 'player_platform.dart';
import 'player_queue.dart';
import 'playback_decision.dart';
import 'player_resume.dart';
import 'player_settings.dart';
import 'player_status_overlay.dart';
import 'subtitle_adjustment_sheet.dart';
import 'subtitle_rendering.dart';
import 'subtitle_settings.dart';

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
  playback_models.SubtitleTrack? _selectedSubtitle;
  SubtitleAdjustments _subtitleAdjustments = const SubtitleAdjustments();
  bool _usingHls = false;
  bool _clientHardwareAcceleration = true;
  bool _transcodeSessionActive = false;
  PlayerDecodeStatus? _serverDecodeStatus;
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
  Timer? _progressReportTimer;
  Future<void> _progressReportChain = Future<void>.value();
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
  String? _pendingPlaybackError;
  Timer? _rateChangeGraceTimer;
  bool _isLandscape = true;
  bool _isRateBoosting = false;
  double _playbackRate = 1.0;
  bool _pictureInPictureRequesting = false;
  bool _isLeaving = false;
  Future<void>? _stopPlayerFuture;
  Future<void> _loadQueue = Future<void>.value();
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
      unawaited(_reportProgress());
      // ignore: discarded_futures
      _host.player.pause();
      if (_transcodeSessionActive) {
        // ignore: discarded_futures
        _stopTranscodeSession();
        if (mounted) setState(() => _serverDecodeStatus = null);
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
    _progressReportTimer?.cancel();
    _hideTimer?.cancel();
    _rateChangeGraceTimer?.cancel();
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
    unawaited(_reportProgress());
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

  Future<void> _reportProgress() {
    final next = _progressReportChain.then<void>((_) async {
      final position = _host.position.inSeconds;
      final duration = _host.duration.inSeconds;
      final positionSec = position > 0 ? position : _lastPositionSec;
      final durationSec = duration > 0 ? duration : _lastDurationSec;
      _lastPositionSec = positionSec;
      _lastDurationSec = durationSec;
      if (durationSec <= 0 || positionSec <= 0) return;

      try {
        await ref.read(moviesRepositoryProvider).upsertWatchRecord(
              widget.movieId,
              positionSec: positionSec,
              durationSec: durationSec,
              completed: positionSec >= (durationSec * 0.95),
            );
      } catch (_) {
        // 播放器退出时网络可能已经断开，不能影响退出流程。
      }
    });
    _progressReportChain = next;
    return next;
  }

  Future<void> _load({
    String? quality,
    Duration? resume,
    bool forceSoftware = false,
  }) {
    final generation = ++_loadGeneration;

    final next = _loadQueue.then<void>(
      (_) => _loadInternal(
        generation: generation,
        quality: quality,
        resume: resume,
        forceSoftware: forceSoftware,
      ),
    );
    _loadQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _loadInternal({
    required int generation,
    String? quality,
    Duration? resume,
    bool forceSoftware = false,
  }) async {
    if (_isLeaving || generation != _loadGeneration) return;
    final selectedQuality = quality ?? _quality;
    final cachedDecision = quality == null ? _decision : null;
    final route = playbackRouteForQuality(selectedQuality);
    _onRateBoostEnd();
    await _stopTranscodeSession();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _loading = true;
      _error = null;
      _quality = selectedQuality;
      _decision = null;
      _selectedSubtitle = null;
      _serverDecodeStatus = null;
    });

    try {
      final cfg = ref.read(serverConfigProvider);
      if (cfg == null) throw StateError('未配置服务器');
      final client = ref.read(requiredApiClientProvider);
      final token = await ref.read(authSessionRepositoryProvider).accessToken();
      if (!mounted || generation != _loadGeneration) return;

      if (forceSoftware) {
        if (_clientHardwareAcceleration) {
          await _host.recreate(enableHardwareAcceleration: false);
        }
        _clientHardwareAcceleration = false;
      } else if (!_clientHardwareAcceleration && quality != null) {
        await _host.recreate(enableHardwareAcceleration: true);
        _clientHardwareAcceleration = true;
      }
      if (!mounted || generation != _loadGeneration) return;

      final decision = cachedDecision ??
          await client.playback.decision(
            widget.movieId,
            _clientCaps(selectedQuality),
          );
      if (!mounted || generation != _loadGeneration) return;
      _decision = decision;
      // 自动画质不采纳后端的服务端转码建议，始终把原始媒体交给
      // media_kit/libmpv；只有用户明确选择固定画质时才使用 HLS。
      final useServerRoute = route == PlaybackRoute.hls;
      _serverDecodeStatus = useServerRoute
          ? PlayerDecodeStatus.server(engine: decision.hwAccel)
          : null;

      final resumeFromLastPosition =
          ref.read(playerSettingsProvider).resumeFromLastPosition;
      WatchRecord? savedRecord;
      if (quality == null &&
          resume == null &&
          resumeFromLastPosition &&
          widget.startPositionSec <= 0) {
        try {
          savedRecord = await ref
              .read(moviesRepositoryProvider)
              .watchRecord(widget.movieId);
        } catch (_) {
          // 观看记录是续播增强能力，读取失败不能阻塞首次播放。
        }
      }
      final resumePositionSec = resolveResumePosition(
        enabled: resumeFromLastPosition,
        explicitPositionSec: widget.startPositionSec,
        record: savedRecord,
      );
      final startAt = resume ??
          (resumePositionSec > 0 ? Duration(seconds: resumePositionSec) : null);
      final direct = !useServerRoute;
      if (direct) {
        final directUrl = _directUrl(cfg);
        await _openDirectWithClientFallback(
          directUrl,
          startAt,
          token,
        );
      } else {
        final hlsUrl = _fallbackHlsUrl(cfg, token, selectedQuality);
        await _openHlsWithClientFallback(hlsUrl, startAt);
      }
      if (!mounted || generation != _loadGeneration) {
        await _host.stop();
        return;
      }
      if (_playbackRate != 1.0) {
        await _host.setRate(_playbackRate);
      }

      if (!mounted || generation != _loadGeneration) return;
      _bindProgress();
      await _applyDefaultTracks(cfg, token, decision);
      if (useServerRoute) {
        _transcodeSessionActive = true;
        _startTranscodeMonitoring(selectedQuality);
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

  Future<void> _openDirectWithClientFallback(
    String url,
    Duration? startAt,
    String? token,
  ) async {
    try {
      await _host.open(
        url,
        startAt: startAt,
        headers: _authorizationHeaders(token),
      );
    } catch (_) {
      if (!_clientHardwareAcceleration) rethrow;
      await _host.recreate(enableHardwareAcceleration: false);
      _clientHardwareAcceleration = false;
      await _host.open(
        url,
        startAt: startAt,
        headers: _authorizationHeaders(token),
      );
    }
    _usingHls = false;
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
    final subtitleSettings = ref.read(subtitleSettingsProvider);
    playback_models.SubtitleTrack? defaultSubtitle;
    final rememberedKey = subtitleSettings.rememberSelectedSubtitle
        ? subtitleSettings.rememberedSubtitleKey
        : null;
    if (rememberedKey != subtitleDisabledSelectionKey) {
      if (rememberedKey != null) {
        for (final track in decision.subtitleTracks) {
          if (subtitleSelectionKey(track) == rememberedKey) {
            defaultSubtitle = track;
            break;
          }
        }
      }
      for (final track in decision.subtitleTracks) {
        if (defaultSubtitle == null && track.isDefault) {
          defaultSubtitle = track;
          break;
        }
      }
    }
    if (defaultSubtitle != null) {
      await _selectSubtitle(
        cfg,
        token,
        defaultSubtitle,
        embeddedOrdinal: _embeddedSubtitleOrdinal(defaultSubtitle),
        showError: false,
      );
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
    _progressReportTimer?.cancel();
    _lastPositionSec = _host.position.inSeconds;
    _lastDurationSec = _host.duration.inSeconds;
    _posSub = _host.positionStream.listen((position) {
      _lastPositionSec = position.inSeconds;
    });
    _durSub = _host.durationStream.listen((duration) {
      _lastDurationSec = duration.inSeconds;
    });
    _completedSub = _host.completedStream.listen((completed) {
      if (!_isLeaving && completed) {
        final duration = _host.duration.inSeconds;
        if (duration > 0) _lastDurationSec = duration;
        if (_lastDurationSec > 0) _lastPositionSec = _lastDurationSec;
        unawaited(_reportProgress());
        // ignore: discarded_futures
        _stopTranscodeSession();
      }
    });
    _errorSub = _host.errorStream.listen(_onPlayerError);
    _progressReportTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!_isLeaving) unawaited(_reportProgress());
      },
    );
  }

  void _onPlayerError(String message) {
    if (!mounted || _isLeaving || _loading || _handlingPlaybackError) return;
    if (_rateChangeGraceTimer != null) {
      _pendingPlaybackError = message;
      return;
    }
    _beginPlaybackErrorRecovery(message);
  }

  void _beginPlaybackErrorRecovery(String message) {
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
          forceSoftware: true,
        );
      } else if (!_usingHls) {
        // 自动画质下只重开当前直传源，不能把播放器错误升级成服务端转码。
        await _load(resume: resume);
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
        if (mounted) setState(() => _serverDecodeStatus = null);
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

  Future<bool> _selectSubtitle(
    ServerConfig cfg,
    String? token,
    playback_models.SubtitleTrack? track, {
    int? embeddedOrdinal,
    bool showError = true,
  }) async {
    try {
      if (track == null) {
        await _host.clearSubtitle();
        _setSelectedSubtitle(null);
        return true;
      }
      if (track.isEmbedded) {
        await _host.setSubtitleTrackById(
          track.index.toString(),
          fallbackIndex: embeddedOrdinal,
        );
        _setSelectedSubtitle(track);
        return true;
      }
      if (!track.canLoad || track.url.trim().isEmpty) {
        throw StateError('字幕地址不可用');
      }
      await _host.setSubtitleUrl(
        _protectedUrl(cfg, track.url, token),
        title: track.title.isEmpty ? null : track.title,
        language: track.language.isEmpty ? null : track.language,
      );
      _setSelectedSubtitle(track);
      return true;
    } catch (error) {
      if (showError && mounted) {
        _showError('字幕加载失败: ${toApiException(error).message}');
      }
      return false;
    }
  }

  Future<void> _onSubtitleChanged(
    playback_models.SubtitleTrack? track,
  ) async {
    final cfg = ref.read(serverConfigProvider);
    if (cfg == null) return;
    try {
      final token = track == null
          ? null
          : await ref.read(authSessionRepositoryProvider).accessToken();
      if (!mounted || _isLeaving) return;
      final loaded = await _selectSubtitle(
        cfg,
        token,
        track,
        embeddedOrdinal:
            track == null ? null : _embeddedSubtitleOrdinal(track),
      );
      if (loaded && ref.read(subtitleSettingsProvider).rememberSelectedSubtitle) {
        final key = track == null
            ? subtitleDisabledSelectionKey
            : subtitleSelectionKey(track);
        unawaited(
          ref
              .read(subtitleSettingsProvider.notifier)
              .rememberSelection(key)
              .catchError((_) {}),
        );
      }
    } catch (error) {
      if (mounted) _showError('字幕加载失败: ${toApiException(error).message}');
    }
  }

  int? _embeddedSubtitleOrdinal(playback_models.SubtitleTrack track) {
    final decision = _decision;
    if (decision == null || !track.isEmbedded) return null;
    var ordinal = 0;
    for (final candidate in decision.subtitleTracks) {
      if (!candidate.isEmbedded) continue;
      if (identical(candidate, track) ||
          (candidate.index == track.index &&
              candidate.source == track.source &&
              candidate.url == track.url)) {
        return ordinal;
      }
      ordinal++;
    }
    return null;
  }

  void _setSelectedSubtitle(playback_models.SubtitleTrack? track) {
    if (!mounted) return;
    setState(() => _selectedSubtitle = track);
  }

  void _updateSubtitleAdjustments(SubtitleAdjustments next) {
    if (!mounted || _isLeaving) return;
    setState(() => _subtitleAdjustments = next);
  }

  Future<void> _showSubtitleSettings() async {
    await showSubtitleAdjustmentDialog(
      context: context,
      initial: _subtitleAdjustments,
      onChanged: _updateSubtitleAdjustments,
    );
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
      _serverDecodeStatus = !status.active
          ? null
          : PlayerDecodeStatus.server(
              engine: status.hwAccel,
              hardwareDecodeOk: status.hwDecodeOk,
              isFallback: status.hasHardwareFallback,
            );
    });
  }

  List<PlayerDecodeStatus> get _decodeStatuses =>
      PlayerDecodeStatus.primary(
        usingHls: _usingHls,
        localHardware: _clientHardwareAcceleration,
        serverStatus: _serverDecodeStatus,
      );

  Map<String, String>? _authorizationHeaders(String? token) {
    final value = token?.trim() ?? '';
    if (value.isEmpty) return null;
    return {'Authorization': 'Bearer $value'};
  }

  String _directUrl(ServerConfig cfg) {
    final path = '/api/movies/id/${widget.movieId}/stream?mode=direct';
    return resolveServerUrl(cfg, path);
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
    return playback_models.PlaybackClientCaps.mobile(
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
    _setPlaybackRate(rate);
    _showIndicator(PlayerIndicator.speed(rate), autoHide: false);
  }

  void _onRateBoostEnd() {
    if (!_isRateBoosting) return;
    _isRateBoosting = false;
    if (_isLeaving) return;
    _setPlaybackRate(_playbackRate);
    _hideIndicator();
  }

  void _onRateChanged(double rate) {
    if (_isLeaving) return;
    _playbackRate = rate;
    _setPlaybackRate(rate);
    _showIndicator(PlayerIndicator.speed(rate));
  }

  void _setPlaybackRate(double rate) {
    _rateChangeGraceTimer?.cancel();
    _rateChangeGraceTimer = Timer(const Duration(milliseconds: 1200), () {
      _rateChangeGraceTimer = null;
      final pending = _pendingPlaybackError;
      _pendingPlaybackError = null;
      if (pending != null) _beginPlaybackErrorRecovery(pending);
    });
    unawaited(_setPlaybackRateInternal(rate));
  }

  Future<void> _setPlaybackRateInternal(double rate) async {
    try {
      await _host.setRate(rate);
    } catch (_) {
      // 播放器内核对倍速命令的短暂失败不应触发播放源切换。
    }
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
        _showError('当前设备或播放内核不支持画中画');
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
    await _reportProgress();
    try {
      await _stopPlayer();
      await _stopTranscodeSession();
    } finally {
      if (mounted) {
        _invalidateHomeMovieLists();
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
    await _reportProgress();
    try {
      await _stopPlayer();
      await _stopTranscodeSession();
    } finally {
      if (mounted) {
        _invalidateHomeMovieLists();
        Navigator.of(context).pop();
      }
    }
  }

  void _invalidateHomeMovieLists() {
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(recentlyAddedProvider);
    ref.invalidate(recommendCarouselProvider);
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final settings = ref.watch(playerSettingsProvider);
    final subtitleSettings = ref.watch(subtitleSettingsProvider);
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
    return Stack(
      children: [
        Positioned.fill(
          child: Video(
            controller: _host.controller,
            controls: NoVideoControls,
            fit: BoxFit.contain,
            subtitleViewConfiguration: const SubtitleViewConfiguration(
              visible: false,
            ),
          ),
        ),
        Positioned.fill(
          child: PlayerSubtitleOverlay(
            player: _host.player,
            selectedTrack: _selectedSubtitle,
            settings: subtitleSettings,
            adjustments: _subtitleAdjustments,
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
          top: 8,
          left: 20,
          right: 20,
          child: PlayerStatusOverlay(
            title: widget.title,
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
                quality: _quality,
                onQualityChanged: _onQualityChanged,
                subtitleTracks: decision.subtitleTracks,
                selectedSubtitle: _selectedSubtitle,
                onSubtitleChanged: (track) =>
                    unawaited(_onSubtitleChanged(track)),
                onOpenSubtitleSettings: () =>
                    unawaited(_showSubtitleSettings()),
                audioTracks: decision.audioTracks,
                onAudioChanged: (track) {
                  // 后端 track index 与 media_kit 的轨道 ID 一致时直接切换。
                  _host.setAudioTrackById(track.index.toString());
                },
                decodeStatuses: _decodeStatuses,
                hapticProgressBar: settings.hapticProgressBar,
                showPlayPauseButton: settings.showPlayPauseButton,
                showSeekButtons: settings.showSeekButtons,
                showSpeedButton: settings.showSpeedButton,
                showPipButton: settings.showPipButton,
                showOrientationButton: settings.showOrientationButton,
                showMediaSwitchButton: settings.showMediaSwitchButton,
                playbackRate: _playbackRate,
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
                onExit: () => unawaited(_exitPlayer()),
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
