import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/providers.dart';
import '../../core/api/url_resolver.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/playback.dart' as playback_models;
import '../../core/models/watch_record.dart';
import '../home/home_providers.dart';
import '../movies/movies_providers.dart';
import 'playback_engine.dart';
import 'player_controls.dart';
import 'player_decode_status.dart';
import 'player_debug_overlay.dart';
import 'player_device_stats.dart';
import 'player_error_disposition.dart';
import 'player_error_view.dart';
import 'player_gesture_layer.dart';
import 'player_overlay_indicators.dart';
import 'player_queue.dart';
import 'player_resume.dart';
import 'player_settings.dart';
import 'player_session_controller.dart';
import 'player_session_factory.dart';
import 'player_status_overlay.dart';
import 'subtitle_adjustment_sheet.dart';
import 'subtitle_content_fetcher.dart';
import 'subtitle_rendering.dart';
import 'subtitle_settings.dart';

const _directPlaybackDecision = playback_models.PlaybackDecision(
  mode: 'direct_play',
  streamUrl: '',
  mimeType: '',
  hwAccel: '',
  targetVideo: '',
  targetAudio: '',
  targetHeight: 0,
  targetBitrate: 0,
  reasons: <String>[],
  audioTracks: <playback_models.AudioTrack>[],
  subtitleTracks: <playback_models.SubtitleTrack>[],
  startSec: 0,
);

/// 全屏视频播放页。播放源由后端协商，页面只负责编排回退、进度和用户控制。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.movieId,
    required this.title,
    this.directUrl,
    this.engineKind,
    this.startPositionSec = 0,
    this.queue = const <PlayerQueueItem>[],
    this.queueIndex = 0,
  });

  final int movieId;
  final String title;
  final String? directUrl;
  final PlaybackEngineKind? engineKind;
  final int startPositionSec;
  final List<PlayerQueueItem> queue;
  final int queueIndex;

  static Future<void> open(
    BuildContext context, {
    required int movieId,
    required String title,
    String? directUrl,
    PlaybackEngineKind? engineKind,
    int startPositionSec = 0,
    List<PlayerQueueItem> queue = const <PlayerQueueItem>[],
    int queueIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          movieId: movieId,
          title: title,
          directUrl: directUrl,
          engineKind: engineKind,
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

  late final PlayerSessionController _host;
  final PlayerDeviceStatsReader _deviceStatsReader = PlayerDeviceStatsReader();

  bool _loading = true;
  String? _error;
  String _quality = 'original';
  playback_models.PlaybackDecision? _decision;
  playback_models.SubtitleTrack? _selectedSubtitle;
  SubtitleAdjustments _subtitleAdjustments = const SubtitleAdjustments();
  SubtitleVerticalOffsetBounds _subtitleOffsetBounds =
      const SubtitleVerticalOffsetBounds();
  bool _usingHls = false;
  String? _pictureInPictureUrl;
  Map<String, String>? _pictureInPictureHeaders;
  bool _pictureInPictureActive = false;
  bool _pictureInPictureWasPlaying = false;
  bool _clientHardwareAcceleration = true;
  int? _audioStreamIndex;
  String? _subtitleTrackId;
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
  Future<void> _brightnessOperations = Future<void>.value();
  bool _brightnessScopeStarted = false;
  bool _brightnessReady = false;
  bool _wasPlayingBeforePause = false;
  Duration _backgroundPosition = Duration.zero;
  bool _playbackErrorReported = false;
  String? _pendingPlaybackError;
  Timer? _rateChangeGraceTimer;
  DateTime? _subtitleLoadGuardUntil;
  bool _isLandscape = true;
  bool _isRateBoosting = false;
  double _playbackRate = 1.0;
  bool _pictureInPictureRequesting = false;
  bool _isLeaving = false;
  Future<void> _loadQueue = Future<void>.value();
  bool _orientationInitialized = false;

  bool get _isDirectPlayback => widget.directUrl?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(playerSettingsProvider);
    _host = createPlayerSession(
      engineKind: widget.engineKind,
      iosEnginePreference: settings.iosEngine,
    );
    _subtitleAdjustments = ref.read(subtitleSettingsProvider).adjustments;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_applyEntryOrientation(ref.read(playerSettingsProvider)));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    FlutterVolumeController.updateShowSystemUI(false);
    // ignore: discarded_futures
    WakelockPlus.enable();
    unawaited(_initLevels());
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
    _brightnessScopeStarted = true;
    await _queueBrightnessOperation(() async {
      try {
        final currentBrightness = await ScreenBrightness.instance.application;
        if (!_isLeaving) {
          _brightness = currentBrightness;
        }
      } catch (_) {}
      _brightnessReady = true;
    });
    try {
      _volume = await FlutterVolumeController.getVolume() ?? 0.5;
    } catch (_) {}
  }

  Future<void> _queueBrightnessOperation(Future<void> Function() operation) {
    final next = _brightnessOperations.then<void>((_) async {
      try {
        await operation();
      } catch (_) {}
    });
    _brightnessOperations = next;
    return next;
  }

  void _resetApplicationBrightness() {
    if (!_brightnessScopeStarted) return;
    // The plugin owns app background/foreground restoration. This reset is
    // only for leaving the player route, including an initialization race.
    unawaited(
      _queueBrightnessOperation(
        ScreenBrightness.instance.resetApplicationScreenBrightness,
      ),
    );
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
        !_pictureInPictureRequesting &&
        !_pictureInPictureActive) {
      _onRateBoostEnd();
      _wasPlayingBeforePause = _host.playing;
      _backgroundPosition = _host.position;
      unawaited(_reportProgress());
      // ignore: discarded_futures
      _host.pause();
      if (_transcodeSessionActive) {
        // ignore: discarded_futures
        _stopTranscodeSession();
        if (mounted) setState(() => _serverDecodeStatus = null);
      }
    } else if (state == AppLifecycleState.resumed &&
        _wasPlayingBeforePause &&
        !_pictureInPictureActive) {
      if (_usingHls) {
        // HLS 会话在后台已停止，恢复时以当前位置重新协商并起播。
        // ignore: discarded_futures
        _load(resume: _backgroundPosition);
      } else {
        // ignore: discarded_futures
        _host.play();
      }
    }
  }

  @override
  void dispose() {
    final wasLeaving = _isLeaving;
    _isLeaving = true;
    _loadGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    if (_pictureInPictureActive || _pictureInPictureRequesting) {
      unawaited(_host.stopPictureInPicture());
    }
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
    _resetApplicationBrightness();
    if (!wasLeaving) unawaited(_reportProgress());
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
    if (_isDirectPlayback) return Future<void>.value();
    final next = _progressReportChain.then<void>((_) async {
      final position = _host.position.inSeconds;
      final duration = _host.duration.inSeconds;
      final positionSec = position > 0 ? position : _lastPositionSec;
      final durationSec = duration > 0 ? duration : _lastDurationSec;
      _lastPositionSec = positionSec;
      _lastDurationSec = durationSec;
      if (durationSec <= 0 || positionSec <= 0) return;

      try {
        await ref
            .read(moviesRepositoryProvider)
            .upsertWatchRecord(
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

  Future<void> _load({String? quality, Duration? resume}) {
    _rateChangeGraceTimer?.cancel();
    _rateChangeGraceTimer = null;
    _pendingPlaybackError = null;
    _playbackErrorReported = false;
    final generation = ++_loadGeneration;

    final next = _loadQueue.then<void>(
      (_) => _loadInternal(
        generation: generation,
        quality: quality,
        resume: resume,
      ),
    );
    _loadQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _loadInternal({
    required int generation,
    String? quality,
    Duration? resume,
  }) async {
    if (_isLeaving || generation != _loadGeneration) return;
    final selectedQuality = quality ?? _quality;
    final cachedDecision = quality == null ? _decision : null;
    _onRateBoostEnd();
    await _stopTranscodeSession();
    await _stopPlayer();
    if (!mounted || generation != _loadGeneration) return;
    _pictureInPictureUrl = null;
    _pictureInPictureHeaders = null;
    setState(() {
      _loading = true;
      _error = null;
      _quality = selectedQuality;
      _decision = null;
      _selectedSubtitle = null;
      _serverDecodeStatus = null;
    });

    try {
      final trailerUrl = widget.directUrl?.trim();
      if (trailerUrl != null && trailerUrl.isNotEmpty) {
        await _host.configure(
          preloadBytes: ref.read(playerSettingsProvider).preloadSize.bytes,
          hardwareAcceleration: _clientHardwareAcceleration,
        );
        if (!mounted || generation != _loadGeneration) return;

        await _openDirectWithClientFallback(trailerUrl, null);
        if (!mounted || generation != _loadGeneration) {
          await _stopPlayer();
          return;
        }
        _decision = _directPlaybackDecision;
        _bindProgress();
        setState(() => _loading = false);
        _restartHideTimer();
        return;
      }

      final cfg = ref.read(serverConfigProvider);
      if (cfg == null) throw StateError('未配置服务器');
      final client = ref.read(requiredApiClientProvider);
      final token = await ref.read(authSessionRepositoryProvider).accessToken();
      if (!mounted || generation != _loadGeneration) return;

      if (!_clientHardwareAcceleration && quality != null) {
        await _host.configure(hardwareAcceleration: true);
        _clientHardwareAcceleration = true;
      }
      if (!mounted || generation != _loadGeneration) return;

      final decision =
          cachedDecision ??
          await client.playback.decision(
            widget.movieId,
            _clientCaps(selectedQuality),
          );
      if (!mounted || generation != _loadGeneration) return;
      _decision = decision;

      final engineRoute = _host.playbackRoute(
        quality: selectedQuality,
        decision: decision,
      );
      final useBackendStream = engineRoute.useBackendStream;
      final useServerRoute = engineRoute.useServerRoute;
      final usesManagedTranscode = engineRoute.usesManagedTranscode;
      _transcodeSessionActive = usesManagedTranscode;
      String? directUrl;
      Map<String, String>? directHeaders;
      if (useBackendStream) {
        final rawDecisionUrl = decision.streamUrl.trim();
        if (rawDecisionUrl.isEmpty) {
          throw StateError('播放决策未返回 stream_url');
        }
        // 受限原生内核不使用非公开 header 注入。站内地址统一转换为 token query，
        // 外部 header-only 地址由后端 remux/direct-stream/transcode 适配。
        directUrl = _protectedUrl(cfg, rawDecisionUrl, token);
      } else if (!useServerRoute) {
        // 直传需要先拿到 .strm 的最终远程地址（远程地址可能实际是 HLS）。
        final rawDirectUrl = await client.playback.streamUrl(widget.movieId);
        directUrl = _protectedUrl(cfg, rawDirectUrl, token);
        directHeaders = !isExternalUrl(cfg, rawDirectUrl)
            ? _authorizationHeaders(token)
            : null;
      }

      // 预载档位在每次打开时读取，修改档位后下一次打开即生效。
      await _host.configure(
        preloadBytes: ref.read(playerSettingsProvider).preloadSize.bytes,
        hardwareAcceleration: _clientHardwareAcceleration,
      );
      if (!mounted || generation != _loadGeneration) return;

      // 自动画质不采纳后端的服务端转码建议，始终把原始媒体交给
      // media_kit/libmpv；只有用户明确选择固定画质时才使用 HLS。
      final direct = !useServerRoute;
      _serverDecodeStatus = usesManagedTranscode
          ? PlayerDecodeStatus.server(engine: decision.hwAccel)
          : null;

      final resumeFromLastPosition = ref
          .read(playerSettingsProvider)
          .resumeFromLastPosition;
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
      final startAt =
          resume ??
          (resumePositionSec > 0 ? Duration(seconds: resumePositionSec) : null);
      if (useBackendStream) {
        await _openBackendStream(directUrl!, startAt, decision);
      } else if (direct) {
        await _openDirectWithClientFallback(
          directUrl!,
          startAt,
          formatHint: decision.container,
          headers: directHeaders,
          mediaInfo: _mediaInfoForDecision(decision),
        );
      } else {
        final hlsUrl = _fallbackHlsUrl(cfg, token, selectedQuality);
        await _openHlsWithClientFallback(
          hlsUrl,
          startAt,
          mediaInfo: _mediaInfoForDecision(decision),
        );
      }
      if (!mounted || generation != _loadGeneration) {
        await _stopPlayer();
        return;
      }
      if (_playbackRate != 1.0) {
        await _host.setRate(_playbackRate);
      }

      if (!mounted || generation != _loadGeneration) return;
      _bindProgress();
      if (usesManagedTranscode) {
        _transcodeSessionActive = true;
        _startTranscodeMonitoring(selectedQuality);
      }
      setState(() => _loading = false);
      _restartHideTimer();
      await _applyDefaultTracks(cfg, token, decision);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      _playbackErrorReported = true;
      _loadGeneration++;
      setState(() {
        _error = toApiException(error).message;
        _loading = false;
      });
      unawaited(_stopAfterPlaybackError());
    }
  }

  Future<void> _openDirectWithClientFallback(
    String url,
    Duration? startAt, {
    Map<String, String>? headers,
    String? formatHint,
    PlaybackMediaInfo? mediaInfo,
  }) async {
    try {
      await _host.open(
        url,
        startAt: startAt,
        headers: headers,
        formatHint: formatHint,
        mediaInfo: mediaInfo,
      );
    } catch (_) {
      if (!_clientHardwareAcceleration) rethrow;
      await _host.configure(hardwareAcceleration: false);
      _clientHardwareAcceleration = false;
      await _host.open(
        url,
        startAt: startAt,
        headers: headers,
        formatHint: formatHint,
        mediaInfo: mediaInfo,
      );
    }
    _usingHls = false;
    _pictureInPictureUrl = _pictureInPictureSourceUrl(url);
    _pictureInPictureHeaders = headers == null
        ? null
        : Map<String, String>.from(headers);
  }

  Future<void> _openHlsWithClientFallback(
    String url,
    Duration? startAt, {
    PlaybackMediaInfo? mediaInfo,
  }) async {
    try {
      await _host.open(url, startAt: startAt, mediaInfo: mediaInfo);
    } catch (_) {
      if (!_clientHardwareAcceleration) rethrow;
      await _host.configure(hardwareAcceleration: false);
      _clientHardwareAcceleration = false;
      await _host.open(url, startAt: startAt, mediaInfo: mediaInfo);
    }
    _usingHls = true;
    _pictureInPictureUrl = _pictureInPictureSourceUrl(url);
    _pictureInPictureHeaders = null;
  }

  Future<void> _openBackendStream(
    String url,
    Duration? startAt,
    playback_models.PlaybackDecision decision,
  ) async {
    final lowerUrl = url.toLowerCase();
    final isHls = decision.isTranscode || lowerUrl.contains('.m3u8');
    await _host.open(
      url,
      startAt: startAt,
      formatHint: isHls ? null : decision.container,
      mediaInfo: _mediaInfoForDecision(decision),
    );
    _usingHls = isHls;
    _pictureInPictureUrl = _pictureInPictureSourceUrl(url);
    _pictureInPictureHeaders = null;
  }

  PlaybackMediaInfo? _mediaInfoForDecision(
    playback_models.PlaybackDecision decision,
  ) {
    final container = decision.container.trim();
    final videoCodec = decision.videoCodec.trim().isNotEmpty
        ? decision.videoCodec.trim()
        : decision.targetVideo.trim();
    final audioCodec = decision.targetAudio.trim();
    final bitrate = decision.targetBitrate > 0
        ? decision.targetBitrate
        : decision.bitRate > 0
        ? decision.bitRate
        : null;
    if (container.isEmpty &&
        videoCodec.isEmpty &&
        audioCodec.isEmpty &&
        bitrate == null) {
      return null;
    }
    return PlaybackMediaInfo(
      container: container.isEmpty ? null : container,
      videoCodec: videoCodec.isEmpty ? null : videoCodec,
      videoBitrate: bitrate,
      audioCodec: audioCodec.isEmpty ? null : audioCodec,
    );
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
          if (subtitleSelectionKey(track) == rememberedKey && track.canLoad) {
            defaultSubtitle = track;
            break;
          }
        }
      }
      for (final track in decision.subtitleTracks) {
        // 位图外挂字幕没有可加载地址，跳过以免自动加载注定失败。
        if (defaultSubtitle == null && track.isDefault && track.canLoad) {
          defaultSubtitle = track;
          break;
        }
      }
    }
    if (_host.usesBackendSubtitleSelection && _subtitleTrackId != null) {
      for (final track in decision.subtitleTracks) {
        final id = track.id.isNotEmpty ? track.id : track.index.toString();
        if (id == _subtitleTrackId) {
          _setSelectedSubtitle(track);
          break;
        }
      }
    } else if (defaultSubtitle != null) {
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
      await _applyAudioTrack(defaultAudio, allowBackendReload: false);
    }
  }

  Future<void> _applyAudioTrack(
    playback_models.AudioTrack track, {
    bool allowBackendReload = true,
  }) async {
    if (await _host.trySelectAudioTrack(track, _decision)) {
      _audioStreamIndex = track.index;
      return;
    }
    if (!allowBackendReload) return;
    _audioStreamIndex = track.index;
    final wasPlaying = _host.playing;
    final position = _host.position;
    await _load(quality: _quality, resume: position);
    if (!wasPlaying && mounted && !_isLeaving) await _host.pause();
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
    _progressReportTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isLeaving) unawaited(_reportProgress());
    });
  }

  void _onPlayerError(String message) {
    if (!mounted || _isLeaving || _playbackErrorReported) {
      return;
    }
    final disposition = classifyPlayerError(
      subtitleGuardUntil: _subtitleLoadGuardUntil,
      now: DateTime.now(),
      mainMediaLoaded: _mainMediaLoaded,
    );
    if (disposition == PlayerErrorDisposition.subtitleWarning) {
      // 字幕拉取失败不影响主媒体播放，降级为提示并清空选中状态，
      // 避免字幕菜单停留在一条实际没有加载成功的轨道上。
      _setSelectedSubtitle(null);
      _showError('字幕加载失败: ${toApiException(message).message}，视频将继续播放');
      return;
    }
    if (_rateChangeGraceTimer != null) {
      _pendingPlaybackError = message;
      return;
    }
    _showPlaybackError(message);
  }

  /// 主媒体是否已完成装载。字幕加载窗口内收到报错时，只有主媒体已就绪
  /// 才能断定报错来自字幕请求而非主媒体本身。
  bool get _mainMediaLoaded {
    return _host.mainMediaLoaded;
  }

  void _showPlaybackError(String message) {
    if (!mounted || _isLeaving || _playbackErrorReported) return;
    _playbackErrorReported = true;
    _rateChangeGraceTimer?.cancel();
    _rateChangeGraceTimer = null;
    _pendingPlaybackError = null;
    // 让当前加载/播放任务失效，避免停止播放器后旧请求又把页面改回播放状态。
    _loadGeneration++;
    setState(() {
      _error = toApiException(message).message;
      _loading = false;
    });
    unawaited(_stopAfterPlaybackError());
  }

  Future<void> _stopAfterPlaybackError() async {
    try {
      await _stopPlayer();
      await _stopTranscodeSession();
    } catch (_) {}
  }

  Future<void> _onQualityChanged(String quality) async {
    if (_isDirectPlayback) return;
    final position = _host.position;
    await _load(quality: quality, resume: position);
  }

  void _togglePlay() {
    if (_isLeaving) return;
    if (_host.playing) {
      _backgroundPosition = _host.position;
      // HLS 会话不能在暂停期间继续占用服务端转码资源。
      // ignore: discarded_futures
      _host.pause();
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
    _host.play();
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
        if (_usingHls) {
          // HLS 转码流不包含字幕轨道（位图字幕由服务端烧录），按轨道 ID
          // 选择必然失败；文字轨道直接走后端的 VTT 转换端点。
          if (track.url.trim().isEmpty) {
            throw StateError('该字幕在转码画质下不可用，请改用原画画质');
          }
          await _loadSubtitleTrack(cfg, token, track);
        } else {
          try {
            await _host.setSubtitleTrackById(
              track.index.toString(),
              fallbackIndex: embeddedOrdinal,
              nativeRendering: track.isPgs,
            );
          } catch (_) {
            // 直传下轨道 ID 偶发与原生内核侧不一致时，同样回退到 URL。
            if (track.url.trim().isEmpty) rethrow;
            await _loadSubtitleTrack(cfg, token, track);
          }
        }
        _setSelectedSubtitle(track);
        return true;
      }
      if (!track.canLoad || track.url.trim().isEmpty) {
        throw StateError('字幕地址不可用');
      }
      await _loadSubtitleTrack(cfg, token, track);
      _setSelectedSubtitle(track);
      return true;
    } catch (error) {
      if (showError && mounted) {
        _showError('字幕加载失败: ${toApiException(error).message}');
      }
      return false;
    }
  }

  /// 客户端自行下载字幕并交给 mpv 本地加载。
  ///
  /// 字幕请求完全走 Dio（带鉴权、令牌刷新与超时重试），接口返回 404/超时
  /// 等失败只会抛出异常走 SnackBar 提示，不会把错误带进 mpv 错误流中断播放。
  Future<void> _loadSubtitleTrack(
    ServerConfig cfg,
    String? token,
    playback_models.SubtitleTrack track,
  ) async {
    final url = _protectedUrl(cfg, track.url, token);
    final content = await fetchSubtitleContent(
      ref.read(requiredApiClientProvider).dio,
      url,
    );
    // mpv 解析本地字幕文件仍可能向错误流写入报错，加载前后设置降级窗口。
    _subtitleLoadGuardUntil = DateTime.now().add(const Duration(seconds: 15));
    await _host.setSubtitleData(
      content,
      title: track.title.isEmpty ? null : track.title,
      language: track.language.isEmpty ? null : track.language,
    );
  }

  Future<void> _onSubtitleChanged(playback_models.SubtitleTrack? track) async {
    if (_host.shouldReloadForSubtitle(
      track,
      hasBackendSelection: _subtitleTrackId != null,
    )) {
      await _applyBackendSubtitleDecision(track);
      return;
    }
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
        embeddedOrdinal: track == null ? null : _embeddedSubtitleOrdinal(track),
      );
      if (loaded &&
          ref.read(subtitleSettingsProvider).rememberSelectedSubtitle) {
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

  Future<void> _applyBackendSubtitleDecision(
    playback_models.SubtitleTrack? track,
  ) async {
    final nextId = track == null
        ? null
        : (track.id.isNotEmpty ? track.id : track.index.toString());
    if (_subtitleTrackId == nextId && track != null) {
      _setSelectedSubtitle(track);
      return;
    }
    _subtitleTrackId = nextId;
    final wasPlaying = _host.playing;
    final position = _host.position;
    await _load(quality: _quality, resume: position);
    if (!mounted || _isLeaving) return;
    if (!wasPlaying) await _host.pause();
    if (track == null) {
      _setSelectedSubtitle(null);
    } else {
      final decision = _decision;
      playback_models.SubtitleTrack? selected;
      if (decision != null) {
        for (final candidate in decision.subtitleTracks) {
          final id = candidate.id.isNotEmpty
              ? candidate.id
              : candidate.index.toString();
          if (id == nextId) {
            selected = candidate;
            break;
          }
        }
      }
      _setSelectedSubtitle(selected ?? track);
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
    final bounded = _subtitleOffsetBounds.clampAdjustments(next);
    setState(() => _subtitleAdjustments = bounded);
    unawaited(
      ref
          .read(subtitleSettingsProvider.notifier)
          .updateAdjustments(bounded)
          .catchError((_) {}),
    );
  }

  void _onSubtitleOffsetBoundsChanged(SubtitleVerticalOffsetBounds bounds) {
    if (!mounted || _isLeaving) return;
    final bounded = bounds.clampAdjustments(_subtitleAdjustments);
    final boundsChanged = _subtitleOffsetBounds != bounds;
    final valueChanged =
        bounded.verticalOffset != _subtitleAdjustments.verticalOffset;
    if (!boundsChanged && !valueChanged) return;
    setState(() {
      _subtitleOffsetBounds = bounds;
      if (valueChanged) _subtitleAdjustments = bounded;
    });
    if (valueChanged) {
      unawaited(
        ref
            .read(subtitleSettingsProvider.notifier)
            .updateAdjustments(bounded)
            .catchError((_) {}),
      );
    }
  }

  Future<void> _showSubtitleSettings() async {
    if (!mounted || _isLeaving) return;
    final wasPlaying = _host.playing;
    final initial = _subtitleOffsetBounds.clampAdjustments(
      _subtitleAdjustments,
    );
    if (initial.verticalOffset != _subtitleAdjustments.verticalOffset) {
      _updateSubtitleAdjustments(initial);
    }
    try {
      if (wasPlaying) {
        await _host.pause();
      }
      if (!mounted || _isLeaving) return;
      await showSubtitleAdjustmentDialog(
        context: context,
        initial: initial,
        onChanged: _updateSubtitleAdjustments,
        verticalOffsetBounds: _subtitleOffsetBounds,
      );
    } finally {
      if (wasPlaying && mounted && !_isLeaving) {
        await _host.play();
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyPlaybackError() async {
    final message = _error;
    if (message == null || message.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) _showError('完整播放错误已复制');
    } catch (_) {
      if (mounted) _showError('复制播放错误失败');
    }
  }

  Future<void> _exportPlaybackError() async {
    final message = _error;
    if (message == null || message.isEmpty) return;
    try {
      final stamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final fileName = 'oh-my-media-playback-error-$stamp.txt';
      final renderObject = context.findRenderObject();
      final sharePositionOrigin = renderObject is RenderBox
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          subject: 'Oh-My-Media 播放错误',
          text: 'Oh-My-Media 播放错误日志',
          sharePositionOrigin: sharePositionOrigin,
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(message)),
              name: fileName,
              mimeType: 'text/plain',
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        _showError('当前设备不支持导出，请复制完整错误');
      }
    } catch (_) {
      if (mounted) _showError('导出播放错误失败，可尝试复制完整错误');
    }
  }

  Future<void> _stopTranscodeSession({bool waitForServer = true}) async {
    final shouldStopServerSession = _transcodeSessionActive;
    _transcodeSessionActive = false;
    final stopFuture = shouldStopServerSession
        ? ref.read(requiredApiClientProvider).playback.stop(widget.movieId)
        : null;
    await _eventsSub?.cancel();
    _eventsSub = null;
    _transcodePollTimer?.cancel();
    _transcodePollTimer = null;
    if (!shouldStopServerSession) return;
    if (stopFuture == null) return;
    if (!waitForServer) {
      // 服务器会话停止属于网络清理，不应阻塞本地播放器退出。
      unawaited(stopFuture.catchError((_) {}));
      return;
    }
    try {
      await stopFuture;
    } catch (_) {}
  }

  void _startTranscodeMonitoring(String quality) {
    _eventsSub?.cancel();
    _transcodePollTimer?.cancel();
    final api = ref.read(requiredApiClientProvider).playback;
    _eventsSub = api
        .events(widget.movieId, quality: quality)
        .listen(
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

  List<PlayerDecodeStatus> get _decodeStatuses => PlayerDecodeStatus.primary(
    usingHls: _usingHls,
    localHardware: _clientHardwareAcceleration,
    clientEngine: _host.value.engineKind,
    serverStatus: _serverDecodeStatus,
  );

  Map<String, String>? _authorizationHeaders(String? token) {
    final value = token?.trim() ?? '';
    if (value.isEmpty) return null;
    return {'Authorization': 'Bearer $value'};
  }

  String _fallbackHlsUrl(ServerConfig cfg, String? token, String quality) {
    final selected = quality == 'original' ? 'auto' : quality;
    final path =
        '/api/movies/id/${widget.movieId}/stream.m3u8?quality=$selected';
    return appendQueryToken(resolveServerUrl(cfg, path), token);
  }

  String _protectedUrl(ServerConfig cfg, String raw, String? token) {
    return resolveProtectedUrl(cfg, raw, token);
  }

  playback_models.PlaybackClientCaps _clientCaps(String quality) {
    return _host.clientCaps(
      quality: quality,
      audioStreamIndex: _audioStreamIndex,
      subtitleTrackId: _subtitleTrackId,
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
      if (pending != null) _showPlaybackError(pending);
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
    if (_isLeaving || _pictureInPictureRequesting || _pictureInPictureActive) {
      return;
    }
    _pictureInPictureRequesting = true;
    final wasPlaying = _host.playing;
    final position = _host.position;
    _pictureInPictureWasPlaying = wasPlaying;
    _backgroundPosition = position;
    try {
      final source = await _resolvePictureInPictureSource();
      if (source == null) {
        _pictureInPictureWasPlaying = false;
        if (mounted) _showError('当前播放源暂不支持画中画');
        return;
      }
      if (wasPlaying) {
        await _host.pause();
      }
      final entered = await _host.enterPictureInPicture(
        PlaybackPictureInPictureRequest(
          url: source.url,
          headers: source.headers,
          position: position,
          autoplay: wasPlaying,
          onStopped: _onPictureInPictureStoppedDuration,
        ),
      );
      if (!entered) {
        if (wasPlaying && mounted && !_isLeaving) {
          await _host.play();
        }
        _pictureInPictureWasPlaying = false;
        if (mounted) _showError('当前设备或播放内核不支持画中画');
        return;
      }
      _pictureInPictureActive = true;
    } catch (_) {
      if (wasPlaying && mounted && !_isLeaving) {
        await _host.play();
      }
      _pictureInPictureWasPlaying = false;
      if (mounted) _showError('画中画启动失败，请稍后重试');
    } finally {
      _pictureInPictureRequesting = false;
    }
  }

  Future<_PictureInPictureSource?> _resolvePictureInPictureSource() async {
    final currentUrl = _pictureInPictureUrl;
    if (currentUrl == null || currentUrl.trim().isEmpty) return null;
    return _PictureInPictureSource(
      url: currentUrl,
      headers: _pictureInPictureHeaders,
    );
  }

  String _pictureInPictureSourceUrl(String url) {
    final value = url.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return uri.toString();
    return Uri.file(value).toString();
  }

  Future<void> _onPictureInPictureStopped(int positionMs) async {
    final wasPlaying = _pictureInPictureWasPlaying;
    _pictureInPictureActive = false;
    _pictureInPictureWasPlaying = false;
    if (!mounted || _isLeaving) return;

    var position = positionMs > 0
        ? Duration(milliseconds: positionMs)
        : _backgroundPosition;
    final duration = _host.duration;
    if (duration > Duration.zero && position > duration) {
      position = duration;
    }
    if (position > Duration.zero) {
      await _host.seek(position);
    }
    if (wasPlaying) {
      await _host.play();
    } else {
      await _host.pause();
    }
    unawaited(_reportProgress());
  }

  Future<void> _onPictureInPictureStoppedDuration(Duration position) {
    return _onPictureInPictureStopped(position.inMilliseconds);
  }

  Future<void> _switchMedia(int index) async {
    if (_isLeaving || index < 0 || index >= widget.queue.length) return;
    final item = widget.queue[index];
    _isLeaving = true;
    _loadGeneration++;
    _hideTimer?.cancel();
    _onRateBoostEnd();
    // 进度上报不能阻塞本地播放器停止和下一部视频打开。
    unawaited(_reportProgress());
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
              engineKind: widget.engineKind,
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
        nextIsLandscape ? [_landscapeOrientation(side)] : _portraitOrientations,
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
    if (!_brightnessReady || _isLeaving) return;
    _brightness = (_brightness + delta).clamp(0.0, 1.0);
    final brightness = _brightness;
    unawaited(
      _queueBrightnessOperation(
        () => ScreenBrightness.instance.setApplicationScreenBrightness(
          brightness,
        ),
      ),
    );
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

  /// 停止当前媒体。本地停止不再承担任何缓存收尾，失败由 dispose 兜底。
  Future<void> _stopPlayer() async {
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
    // 观看进度上报、本地停播和服务器会话清理都不能阻塞路由返回。
    unawaited(_reportProgress());
    unawaited(_stopPlayer());
    unawaited(_stopTranscodeSession(waitForServer: false));
    if (mounted) {
      _invalidateHomeMovieLists();
      Navigator.of(context).pop();
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
          child: Stack(children: [Positioned.fill(child: _body())]),
        ),
      ),
    );
  }

  Widget _body() {
    final settings = ref.watch(playerSettingsProvider);
    final subtitleSettings = ref.watch(subtitleSettingsProvider);
    final capabilities = _host.capabilities;
    if (_loading) {
      return Stack(
        children: [
          Positioned.fill(child: _host.buildSurface()),
          Positioned.fill(
            child: _LoadingView(onExit: () => unawaited(_exitPlayer())),
          ),
        ],
      );
    }
    if (_error != null) {
      return PlayerErrorView(
        message: _error!,
        onRetry: _load,
        onCopy: _copyPlaybackError,
        onExport: _exportPlaybackError,
        onExit: () => unawaited(_exitPlayer()),
      );
    }
    final decision = _decision;
    if (decision == null) {
      return PlayerErrorView(
        message: '播放决策为空',
        onRetry: _load,
        onCopy: _copyPlaybackError,
        onExport: _exportPlaybackError,
        onExit: () => unawaited(_exitPlayer()),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: _host.buildSurface()),
        if (capabilities.textSubtitles)
          Positioned.fill(
            child: PlayerSubtitleOverlay(
              controller: _host,
              selectedTrack: _selectedSubtitle,
              settings: subtitleSettings,
              adjustments: _subtitleAdjustments,
              onVerticalOffsetBoundsChanged: _onSubtitleOffsetBoundsChanged,
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
            rateControlEnabled: capabilities.playbackRate,
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
        if (settings.debugMode)
          Positioned(
            top: 42,
            left: 20,
            right: 20,
            child: PlayerDebugOverlay(stateListenable: _host),
          ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: PlayerControls(
                controller: _host,
                previewSourceUri: _pictureInPictureUrl,
                previewSourceHeaders: _pictureInPictureHeaders,
                quality: _quality,
                showQualityButton: !_isDirectPlayback,
                onQualityChanged: _onQualityChanged,
                subtitleTracks: capabilities.textSubtitles
                    ? decision.subtitleTracks
                    : const [],
                selectedSubtitle: _selectedSubtitle,
                onSubtitleChanged: (track) =>
                    unawaited(_onSubtitleChanged(track)),
                onOpenSubtitleSettings: () =>
                    unawaited(_showSubtitleSettings()),
                audioTracks: capabilities.audioTracks
                    ? decision.audioTracks
                    : const [],
                onAudioChanged: (track) => unawaited(_applyAudioTrack(track)),
                decodeStatuses: _decodeStatuses,
                hapticProgressBar: settings.hapticProgressBar,
                showPlayPauseButton: settings.showPlayPauseButton,
                showSeekButtons: settings.showSeekButtons,
                showSpeedButton:
                    settings.showSpeedButton && capabilities.playbackRate,
                showPipButton:
                    settings.showPipButton && capabilities.pictureInPicture,
                showOrientationButton: settings.showOrientationButton,
                showMediaSwitchButton: settings.showMediaSwitchButton,
                playbackRate: _playbackRate,
                onPictureInPicture: () => unawaited(_enterPictureInPicture()),
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

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('正在加载影片…', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onExit,
              tooltip: '退出播放',
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _PictureInPictureSource {
  const _PictureInPictureSource({required this.url, required this.headers});

  final String url;
  final Map<String, String>? headers;
}
