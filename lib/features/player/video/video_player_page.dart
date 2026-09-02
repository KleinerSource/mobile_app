import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/api/dio_factory.dart';
import '../../../core/api/url_resolver.dart';
import '../../../core/auth/auth_session_provider.dart';
import '../../../core/config/server_config.dart';
import '../../../core/config/server_config_provider.dart';
import '../../../core/models/playback.dart' as playback_models;
import '../../../core/models/watch_record.dart';
import '../../../core/platform/app_log_store.dart';
import '../../../core/platform/screen_brightness_channel.dart';
import '../../../core/sources/common/source_exception.dart';
import '../../../core/sources/common/source_id.dart';
import '../../../core/sources/files/file_playback_progress.dart';
import '../../../core/sources/media/media_models.dart' as source_models;
import '../../../core/sources/media/media_source_providers.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import '../common/engine_playback_route.dart';
import '../common/playback_engine.dart';
import 'player_decode_status.dart';
import 'player_device_stats.dart';
import 'player_error_disposition.dart';
import 'player_error_view.dart';
import '../common/player_overlay_indicators.dart';
import '../common/player_queue.dart';
import 'player_resume.dart';
import '../common/player_settings.dart';
import '../common/player_session_controller.dart';
import 'video_player_session_factory.dart';
import 'video_player_view.dart';
import 'subtitle_adjustment_sheet.dart';
import 'subtitle_settings.dart';

const _directPlaybackDecision = playback_models.PlaybackDecision(
  mode: 'direct_play',
  streamUrl: '',
  directUrl: '',
  qualityOptions: <playback_models.QualityOption>[
    playback_models.QualityOption(id: 'auto', label: '自动', kind: 'auto'),
  ],
  mimeType: '',
  hwAccel: '',
  targetVideo: '',
  targetAudio: '',
  targetWidth: 0,
  targetHeight: 0,
  targetBitrate: 0,
  reasons: <String>[],
  audioTracks: <playback_models.AudioTrack>[],
  subtitleTracks: <playback_models.SubtitleTrack>[],
  startSec: 0,
);

playback_models.PlaybackDecision _directPlaybackDecisionForTracks({
  required List<playback_models.AudioTrack> audioTracks,
  required List<playback_models.SubtitleTrack> subtitleTracks,
}) => playback_models.PlaybackDecision(
  mode: 'direct_play',
  streamUrl: '',
  directUrl: '',
  qualityOptions: const <playback_models.QualityOption>[
    playback_models.QualityOption(id: 'auto', label: '自动', kind: 'auto'),
  ],
  mimeType: '',
  hwAccel: '',
  targetVideo: '',
  targetAudio: '',
  targetHeight: 0,
  targetBitrate: 0,
  reasons: const <String>[],
  audioTracks: audioTracks,
  subtitleTracks: subtitleTracks,
  startSec: 0,
);

const _directPlaybackOperationTimeout = Duration(seconds: 20);
const _playerCleanupTimeout = Duration(seconds: 5);

/// 全屏视频播放页。播放源由后端协商，页面只负责编排回退、进度和用户控制。
class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.movieId,
    required this.title,
    this.directUrl,
    this.directHeaders,
    this.directFormatHint,
    this.engineKind,
    this.directPlaybackFileName,
    this.directAudioTracks = const <playback_models.AudioTrack>[],
    this.directSubtitleTracks = const <playback_models.SubtitleTrack>[],
    this.directProgressReporter,
    this.directPreferFfmpegForHls = false,
    this.startPositionSec = 0,
    this.queue = const <PlayerQueueItem>[],
    this.queueIndex = 0,
    this.onQueueDispose,
  });

  /// 打开外部/第三方直连媒体。该模式不需要 OMM 的整数影片 ID，
  /// 也不会请求播放决策或上报 OMM 观看记录。
  const VideoPlayerPage.direct({
    super.key,
    required this.title,
    required this.directUrl,
    this.directHeaders,
    this.directFormatHint,
    this.engineKind,
    this.directPlaybackFileName,
    this.directAudioTracks = const <playback_models.AudioTrack>[],
    this.directSubtitleTracks = const <playback_models.SubtitleTrack>[],
    this.directProgressReporter,
    this.directPreferFfmpegForHls = false,
    this.startPositionSec = 0,
    this.queue = const <PlayerQueueItem>[],
    this.queueIndex = 0,
    this.onQueueDispose,
  }) : movieId = null;

  final int? movieId;
  final String title;
  final String? directUrl;
  final Map<String, String>? directHeaders;
  final String? directFormatHint;
  final PlaybackEngineKind? engineKind;
  final String? directPlaybackFileName;
  final List<playback_models.AudioTrack> directAudioTracks;
  final List<playback_models.SubtitleTrack> directSubtitleTracks;

  /// 退出直连播放时向服务器上报最终进度的回调（例如 Emby 的
  /// Sessions/Playing/Stopped）。与本地文件续播记录互不影响。
  final Future<void> Function(int positionSec, int durationSec, bool completed)?
  directProgressReporter;

  /// 直链 HLS 是否优先使用 KSPlayer 的 FFmpeg 内核。仅文件源
  /// （WebDAV/SMB）使用；OMM 转码流与 DBO 在线流保持默认 AVPlayer。
  final bool directPreferFfmpegForHls;
  final int startPositionSec;
  final List<PlayerQueueItem> queue;
  final int queueIndex;

  /// 由队列创建者持有的资源清理回调，例如文件播放代理。
  /// 切换队列项时会传递给 replacement 页面，最终退出时才执行。
  final Future<void> Function()? onQueueDispose;

  static Future<void> open(
    BuildContext context, {
    required int movieId,
    required String title,
    String? directUrl,
    Map<String, String>? directHeaders,
    String? directFormatHint,
    PlaybackEngineKind? engineKind,
    int startPositionSec = 0,
    List<PlayerQueueItem> queue = const <PlayerQueueItem>[],
    int queueIndex = 0,
    Future<void> Function()? onQueueDispose,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          movieId: movieId,
          title: title,
          directUrl: directUrl,
          directHeaders: directHeaders,
          directFormatHint: directFormatHint,
          engineKind: engineKind,
          startPositionSec: startPositionSec,
          queue: queue,
          queueIndex: queueIndex,
          onQueueDispose: onQueueDispose,
        ),
      ),
    );
  }

  static Future<void> openDirect(
    BuildContext context, {
    required String title,
    required String directUrl,
    Map<String, String>? directHeaders,
    String? directFormatHint,
    PlaybackEngineKind? engineKind,
    String? directPlaybackFileName,
    List<playback_models.AudioTrack> directAudioTracks =
        const <playback_models.AudioTrack>[],
    List<playback_models.SubtitleTrack> directSubtitleTracks =
        const <playback_models.SubtitleTrack>[],
    Future<void> Function(int positionSec, int durationSec, bool completed)?
    directProgressReporter,
    bool directPreferFfmpegForHls = false,
    int startPositionSec = 0,
    List<PlayerQueueItem> queue = const <PlayerQueueItem>[],
    int queueIndex = 0,
    Future<void> Function()? onQueueDispose,
    bool useRootNavigator = false,
  }) {
    appLog(
      '[VideoPlayerPage] openDirect 入队: engine=${engineKind?.value ?? 'default'} '
      'url=$directUrl',
    );
    return Navigator.of(context, rootNavigator: useRootNavigator).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage.direct(
          title: title,
          directUrl: directUrl,
          directHeaders: directHeaders,
          directFormatHint: directFormatHint,
          engineKind: engineKind,
          directPlaybackFileName: directPlaybackFileName,
          directAudioTracks: directAudioTracks,
          directSubtitleTracks: directSubtitleTracks,
          directProgressReporter: directProgressReporter,
          directPreferFfmpegForHls: directPreferFfmpegForHls,
          startPositionSec: startPositionSec,
          queue: queue,
          queueIndex: queueIndex,
          onQueueDispose: onQueueDispose,
        ),
      ),
    );
  }

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver {
  static const List<DeviceOrientation> _portraitOrientations = [
    DeviceOrientation.portraitUp,
  ];

  late final PlayerSessionController _host;
  late final FilePlaybackProgressRepository _filePlaybackProgress;
  final PlayerDeviceStatsReader _deviceStatsReader =
      const PlayerDeviceStatsReader();

  bool _loading = true;
  String? _error;
  String _quality = 'auto';
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
  int _transcodeMonitoringGeneration = 0;
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
  StreamSubscription<double>? _volumeChangedSub;
  Timer? _indicatorTimer;
  double _brightness = 0.5;
  double _volume = 0.5;
  DateTime? _lastVolumeGestureAt;
  Future<void> _brightnessOperations = Future<void>.value();
  bool _brightnessReady = false;
  bool _wasPlayingBeforePause = false;
  Duration _backgroundPosition = Duration.zero;
  bool _playbackErrorReported = false;
  bool _serverFallbackAttempted = false;
  String? _pendingPlaybackError;
  Timer? _rateChangeGraceTimer;
  DateTime? _subtitleLoadGuardUntil;
  bool _isLandscape = true;
  bool _isRateBoosting = false;
  double _playbackRate = 1.0;
  bool _pictureInPictureRequesting = false;
  bool _isLeaving = false;
  bool _queueOwnershipTransferred = false;
  bool _queueResourcesDisposed = false;
  Future<void> _loadQueue = Future<void>.value();
  bool _orientationInitialized = false;
  // 每个播放页的 Host 都是新建的。首次打开没有旧媒体可清理，尤其是
  // iOS Pigeon stop 在尚未 attach 原生视图时可能等待较久，不能阻塞直链起播。
  bool _playerHasBeenOpened = false;

  bool get _isDirectPlayback => widget.directUrl?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _playerLog(
      '视频播放器页面已创建: direct=${widget.directUrl?.trim().isNotEmpty == true} '
      'engine=${widget.engineKind?.value ?? 'default'}',
    );
    final settings = ref.read(playerSettingsProvider);
    _host = createVideoPlayerSession(
      engineKind: widget.engineKind,
      iosEnginePreference: settings.iosEngine,
    );
    _filePlaybackProgress = FilePlaybackProgressRepository(
      ref.read(sharedPrefsProvider),
    );
    _subtitleAdjustments = ref.read(subtitleSettingsProvider).adjustments;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_applyEntryOrientation(ref.read(playerSettingsProvider)));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 播放器内隐藏系统音量条 (手势调节走自绘指示器)，物理按键改动的音量
    // 通过监听系统广播在播放器内显示同样的音量条。
    FlutterVolumeController.updateShowSystemUI(false);
    _volumeChangedSub = FlutterVolumeController.addListener(
      _onSystemVolumeChanged,
      emitOnStart: false,
    );
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
    // 只读一次当前亮度作为手势增量基线，不保存、不恢复：
    // 退出播放器或 app 时亮度保持最后状态，任何阶段都不回写其他值。
    await _queueBrightnessOperation(() async {
      final currentBrightness = await ScreenBrightnessChannel.read();
      if (currentBrightness != null && !_isLeaving) {
        _brightness = currentBrightness;
      }
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
    _unbindProgress();
    _cancelTranscodeMonitoring();
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
    _volumeChangedSub?.cancel();
    _volumeChangedSub = null;
    if (!wasLeaving) unawaited(_reportProgress());
    final movieId = widget.movieId;
    if (_transcodeSessionActive && movieId != null) {
      _transcodeSessionActive = false;
      try {
        final source = ref.read(ommMediaSourceProvider);
        if (source != null) {
          unawaited(source.stopTranscode(_ommRef(movieId)));
        }
      } catch (_) {}
    }
    // ignore: discarded_futures
    WakelockPlus.disable();
    unawaited(_disposePlayer());
    unawaited(_disposeQueueResources());
    super.dispose();
  }

  Future<void> _reportProgress() {
    if (_isDirectPlayback) return _reportFileProgress();
    final movieId = widget.movieId;
    if (movieId == null) return Future<void>.value();
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
            .read(mediaRepositoryProvider)
            .upsertWatchRecord(
              movieId,
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

  Future<void> _reportFileProgress() {
    final fileName = widget.directPlaybackFileName?.trim();
    final serverReporter = widget.directProgressReporter;
    if ((fileName == null || fileName.isEmpty) && serverReporter == null) {
      return Future<void>.value();
    }
    final next = _progressReportChain.then<void>((_) async {
      final positionSec = _host.position.inSeconds > 0
          ? _host.position.inSeconds
          : _lastPositionSec;
      final durationSec = _host.duration.inSeconds > 0
          ? _host.duration.inSeconds
          : _lastDurationSec;
      _lastPositionSec = positionSec;
      _lastDurationSec = durationSec;
      if (fileName != null && fileName.isNotEmpty) {
        final settings = ref.read(playerSettingsProvider);
        if (settings.resumeFromLastPosition && durationSec > 0) {
          await _filePlaybackProgress.savePosition(
            fileName: fileName,
            positionSec: positionSec,
            durationSec: durationSec,
          );
        }
      }
      if (serverReporter != null && positionSec > 0 && durationSec > 0) {
        // 服务器侧进度（如 Emby 的 Stopped 报告）不受本地续播偏好影响；
        // 与 OMM 观看记录相同，播放超过 95% 视为看完。
        try {
          await serverReporter(
            positionSec,
            durationSec,
            positionSec >= (durationSec * 0.95),
          );
        } catch (_) {
          // 播放器退出时网络可能已经断开，不能影响退出流程。
        }
      }
    });
    _progressReportChain = next;
    return next;
  }

  Future<void> _load({
    String? quality,
    Duration? resume,
    bool serverFallback = false,
    bool forceVideoTranscode = false,
    bool? play,
    playback_models.PlaybackDecision? decisionOverride,
  }) {
    _rateChangeGraceTimer?.cancel();
    _rateChangeGraceTimer = null;
    _pendingPlaybackError = null;
    _playbackErrorReported = false;
    if (!serverFallback) _serverFallbackAttempted = false;
    final generation = ++_loadGeneration;
    _playerLog(
      '排队加载: generation=$generation direct=$_isDirectPlayback '
      'quality=${quality ?? _quality}',
    );

    final next = _loadQueue.then<void>(
      (_) => _loadInternal(
        generation: generation,
        quality: quality,
        resume: resume,
        serverFallback: serverFallback,
        forceVideoTranscode: forceVideoTranscode,
        play: play,
        decisionOverride: decisionOverride,
      ),
    );
    _loadQueue = next.catchError((error) {
      // 清理阶段位于 _loadInternal 的业务 try 之外；不能让 Future 链静默
      // 吞掉异常，否则页面只会停留在“正在加载影片”。
      _playerLog('加载任务异常: $error');
    });
    return next;
  }

  Future<void> _loadInternal({
    required int generation,
    String? quality,
    Duration? resume,
    required bool serverFallback,
    required bool forceVideoTranscode,
    bool? play,
    playback_models.PlaybackDecision? decisionOverride,
  }) async {
    if (!mounted || _isLeaving || generation != _loadGeneration) {
      _playerLog(
        '跳过加载: generation=$generation current=$_loadGeneration '
        'mounted=$mounted leaving=$_isLeaving',
      );
      return;
    }
    _playerLog(
      '开始加载: generation=$generation direct=$_isDirectPlayback '
      'engine=${_host.kind.value}',
    );
    final selectedQuality = quality ?? _quality;
    final cachedDecision =
        decisionOverride ?? (quality == null ? _decision : null);
    final shouldPlay = play ?? true;
    var fallbackResume = resume;
    _onRateBoostEnd();
    _pictureInPictureUrl = null;
    _pictureInPictureHeaders = null;
    _usingHls = false;
    setState(() {
      _loading = true;
      _error = null;
      _quality = selectedQuality;
      _decision = null;
      _selectedSubtitle = null;
      _serverDecodeStatus = null;
    });
    // 先撤掉旧媒体监听并停止本地消费，再等待服务端清理旧转码会话。
    // 首次进入播放页时 Host 没有旧媒体，跳过 stop；iOS 原生 stop 在
    // 尚未打开媒体时可能阻塞 Pigeon 调用，导致直链永远到不了 open。
    _unbindProgress();
    if (_playerHasBeenOpened) {
      _playerLog('停止旧播放器: generation=$generation');
      await _stopPlayer().timeout(
        _playerCleanupTimeout,
        onTimeout: () => _playerLog('停止旧播放器超时，继续打开新媒体'),
      );
      _playerLog('旧播放器已停止: generation=$generation');
    } else {
      _playerLog('首次打开，跳过停止旧播放器');
    }
    if (!mounted || generation != _loadGeneration) return;
    if (_playerHasBeenOpened) {
      _playerLog('清理旧转码会话: generation=$generation');
      await _stopTranscodeSession().timeout(
        _playerCleanupTimeout,
        onTimeout: () => _playerLog('清理旧转码会话超时，继续打开新媒体'),
      );
      _playerLog('旧转码会话已清理: generation=$generation');
    } else {
      _playerLog('首次打开，跳过清理旧转码会话');
    }
    if (!mounted || generation != _loadGeneration) return;

    try {
      final trailerUrl = widget.directUrl?.trim();
      if (trailerUrl != null && trailerUrl.isNotEmpty) {
        if (ref.read(playerSettingsProvider).resumeFromLastPosition) {
          final fileName = widget.directPlaybackFileName?.trim();
          if (fileName != null && fileName.isNotEmpty) {
            final savedProgress = _filePlaybackProgress.load(fileName);
            if (savedProgress != null) {
              fallbackResume = Duration(seconds: savedProgress.positionSec);
            }
          }
        }
        // 文件源的回环代理是按需取流的，内核 open 可能会等待远端首段
        // 数据或容器探测。先展示播放器表面和控件，让播放器自己的 buffering
        // 状态接管等待过程，避免整个页面一直被“正在加载影片”覆盖。
        _decision =
            widget.directAudioTracks.isEmpty &&
                widget.directSubtitleTracks.isEmpty
            ? _directPlaybackDecision
            : _directPlaybackDecisionForTracks(
                audioTracks: widget.directAudioTracks,
                subtitleTracks: widget.directSubtitleTracks,
              );
        _bindProgress();
        setState(() => _loading = false);
        _restartHideTimer();
        _playerLog('开始直链播放: $trailerUrl');
        _playerLog(
          '配置播放器: preload=${ref.read(playerSettingsProvider).preloadSize.bytes}',
        );
        await _host
            .configure(
              preloadBytes: ref.read(playerSettingsProvider).preloadSize.bytes,
              hardwareAcceleration: _clientHardwareAcceleration,
            )
            .timeout(_directPlaybackOperationTimeout);
        _playerLog('播放器配置完成');
        if (!mounted || generation != _loadGeneration) return;

        await _openDirectWithClientFallback(
          trailerUrl,
          fallbackResume,
          play: shouldPlay,
          headers: widget.directHeaders,
          formatHint: widget.directFormatHint,
          preferFfmpegForHls: widget.directPreferFfmpegForHls,
        ).timeout(const Duration(seconds: 45));
        _playerHasBeenOpened = true;
        _playerLog('播放器 open 已返回');
        if (widget.directPlaybackFileName?.trim().isNotEmpty == true) {
          await _waitForFirstFrame();
        }
        if (!mounted || generation != _loadGeneration) {
          await _stopPlayer();
          return;
        }
        return;
      }

      final cfg = ref.read(serverConfigProvider);
      if (cfg == null) throw StateError('未配置服务器');
      final movieId = widget.movieId;
      if (movieId == null) throw StateError('播放影片 ID 缺失');
      final source = ref.read(ommMediaSourceProvider);
      if (source == null) throw const SourceException('OMM 播放来源未就绪');
      final token = await ref.read(authSessionRepositoryProvider).accessToken();
      if (!mounted || generation != _loadGeneration) return;

      if (!_clientHardwareAcceleration && quality != null) {
        await _host.configure(hardwareAcceleration: true);
        _clientHardwareAcceleration = true;
      }
      if (!mounted || generation != _loadGeneration) return;

      final decision =
          cachedDecision ??
          await source.resolvePlaybackDecision(
            _ommRef(movieId),
            _clientCaps(
              selectedQuality,
              forceVideoTranscode: forceVideoTranscode,
            ),
          );
      if (!mounted || generation != _loadGeneration) return;
      _validateDecisionForQuality(
        decision,
        selectedQuality,
        requireHls: serverFallback,
      );
      _decision = decision;

      final engineRoute = _host.playbackRoute(
        quality: selectedQuality,
        decision: decision,
        forceServerRoute:
            serverFallback ||
            _audioStreamIndex != null ||
            _subtitleTrackId != null,
      );
      final useBackendStream = engineRoute.useBackendStream;
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
      } else {
        final rawDirectUrl = decision.directUrl.trim();
        if (rawDirectUrl.isEmpty) {
          throw StateError('服务器版本不兼容：播放决策缺少 direct_url');
        }
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
              .read(mediaRepositoryProvider)
              .watchRecord(movieId);
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
      fallbackResume = startAt;
      if (useBackendStream) {
        await _openBackendStream(
          directUrl,
          startAt,
          decision,
          play: shouldPlay,
        );
      } else {
        await _openDirectWithClientFallback(
          directUrl,
          startAt,
          play: shouldPlay,
          formatHint: decision.container,
          headers: directHeaders,
          mediaInfo: playbackMediaInfoForDecision(decision),
        );
      }
      _playerHasBeenOpened = true;
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
        _startTranscodeMonitoring(selectedQuality, decision);
      }
      setState(() => _loading = false);
      _restartHideTimer();
      await _applyDefaultTracks(cfg, token, decision);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      _playerLog('加载失败: generation=$generation error=$error');
      if (_tryServerFallback(resume: fallbackResume, play: shouldPlay)) return;
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
    bool play = true,
    Map<String, String>? headers,
    String? formatHint,
    PlaybackMediaInfo? mediaInfo,
    bool preferFfmpegForHls = false,
  }) async {
    _playerLog(
      '调用播放器 open: engine=${_host.kind.value} '
      'url=$url formatHint=${formatHint ?? ''}',
    );
    try {
      await _host
          .open(
            url,
            startAt: startAt,
            play: play,
            headers: headers,
            formatHint: formatHint,
            mediaInfo: mediaInfo,
            preferFfmpegForHls: preferFfmpegForHls,
          )
          .timeout(_directPlaybackOperationTimeout);
      _playerLog('播放器 open 成功: engine=${_host.kind.value}');
    } catch (error, stackTrace) {
      _playerLog(
        '播放器 open 失败: engine=${_host.kind.value} '
        'error=$error\n$stackTrace',
      );
      if (!_clientHardwareAcceleration) rethrow;
      _playerLog('硬件解码打开失败或超时，尝试软件解码');
      try {
        await _host.stop().timeout(_playerCleanupTimeout);
      } catch (_) {}
      await _host
          .configure(hardwareAcceleration: false)
          .timeout(_directPlaybackOperationTimeout);
      _clientHardwareAcceleration = false;
      await _host
          .open(
            url,
            startAt: startAt,
            play: play,
            headers: headers,
            formatHint: formatHint,
            mediaInfo: mediaInfo,
            preferFfmpegForHls: preferFfmpegForHls,
          )
          .timeout(_directPlaybackOperationTimeout);
      _playerLog('软件解码播放器 open 成功: engine=${_host.kind.value}');
    }
    // 直连模式也可能是 dbonline 返回的 HLS 清单。记录真实媒体类型，
    // 这样后台恢复时会重新打开清单，而不是对已停止的会话直接 play。
    _usingHls = _isHlsUrl(url, formatHint);
    _pictureInPictureUrl = _pictureInPictureSourceUrl(url);
    _pictureInPictureHeaders = headers == null
        ? null
        : Map<String, String>.from(headers);
  }

  Future<void> _waitForFirstFrame() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (mounted && !_isLeaving && DateTime.now().isBefore(deadline)) {
      if (_host.value.firstFrameRendered) return;
      final error = _host.value.error;
      if (error != null && error.trim().isNotEmpty) {
        throw StateError(error);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('视频首帧加载超时');
  }

  void _playerLog(String message) {
    appLog('[VideoPlayerPage] $message');
  }

  bool _isHlsUrl(String url, String? formatHint) {
    final hint = formatHint?.trim().toLowerCase() ?? '';
    if (hint == 'm3u8' ||
        hint == 'hls' ||
        hint == 'application/vnd.apple.mpegurl') {
      return true;
    }
    final uri = Uri.tryParse(url.trim());
    final path = uri?.path.toLowerCase() ?? url.trim().toLowerCase();
    return path.endsWith('.m3u8');
  }

  Future<void> _openBackendStream(
    String url,
    Duration? startAt,
    playback_models.PlaybackDecision decision, {
    bool play = true,
  }) async {
    final lowerUrl = url.toLowerCase();
    final isHls = decision.isTranscode || lowerUrl.contains('.m3u8');
    await _host.open(
      url,
      startAt: startAt,
      play: play,
      formatHint: isHls ? null : decision.container,
      mediaInfo: playbackMediaInfoForDecision(
        decision,
        preferTargetVideo: isHls,
      ),
    );
    _usingHls = isHls;
    _pictureInPictureUrl = _pictureInPictureSourceUrl(url);
    _pictureInPictureHeaders = null;
  }

  void _validateDecisionForQuality(
    playback_models.PlaybackDecision decision,
    String quality, {
    required bool requireHls,
  }) {
    final normalized = quality.trim().toLowerCase();
    playback_models.QualityOption? selected;
    for (final option in decision.qualityOptions) {
      if (option.id == normalized) {
        selected = option;
        break;
      }
    }
    if (selected == null) {
      throw FormatException('服务器版本不兼容：播放决策未提供清晰度 $normalized');
    }
    final hasHls = decisionHasHlsUrl(decision);
    if (selected.kind == 'transcode' && !hasHls) {
      throw const FormatException('服务器版本不兼容：转码清晰度未返回 HLS 地址');
    }
    if (requireHls && !hasHls) {
      throw StateError('服务器转码回退未返回 HLS 地址');
    }
  }

  bool _tryServerFallback({Duration? resume, bool? play}) {
    if (!mounted || _isLeaving || _isDirectPlayback) return false;
    final decision = _decision;
    if (decision == null) return false;
    final plan = serverFallbackPlanFor(
      quality: _quality,
      alreadyAttempted: _serverFallbackAttempted,
      usingHls: _usingHls,
      decision: decision,
    );
    if (plan == null) return false;

    _serverFallbackAttempted = true;
    final fallbackPosition = resume ?? _host.position;
    final shouldPlay = play ?? _host.playbackIntent;
    unawaited(
      _load(
        quality: _quality,
        resume: fallbackPosition,
        serverFallback: true,
        forceVideoTranscode: plan.forceVideoTranscode,
        play: shouldPlay,
        decisionOverride: plan.reuseDecision ? decision : null,
      ),
    );
    return true;
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
    _unbindProgress();
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

  void _unbindProgress() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _posSub = null;
    _durSub = null;
    _completedSub = null;
    _errorSub = null;
    _progressReportTimer?.cancel();
    _progressReportTimer = null;
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
    if (_tryServerFallback()) return;
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
    final shouldPlay = _host.playbackIntent;
    await _load(quality: quality, resume: position, play: shouldPlay);
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
    final content = _isDirectPlayback
        ? await _fetchDirectSubtitle(url)
        : await _fetchManagedSubtitle(url);
    // mpv 解析本地字幕文件仍可能向错误流写入报错，加载前后设置降级窗口。
    _subtitleLoadGuardUntil = DateTime.now().add(const Duration(seconds: 15));
    await _host.setSubtitleData(
      content,
      title: track.title.isEmpty ? null : track.title,
      language: track.language.isEmpty ? null : track.language,
    );
  }

  Future<String> _fetchManagedSubtitle(String url) async {
    final source = ref.read(ommMediaSourceProvider);
    if (source == null) throw const SourceException('OMM 播放来源未就绪');
    return source.fetchSubtitleContent(url);
  }

  Future<String> _fetchDirectSubtitle(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: widget.directHeaders,
      ),
    );
    return utf8.decode(response.data ?? const <int>[], allowMalformed: true);
  }

  Future<void> _onSubtitleChanged(playback_models.SubtitleTrack? track) async {
    if (!_isDirectPlayback &&
        _host.shouldReloadForSubtitle(
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
    setState(() => _subtitleAdjustments = next);
    unawaited(
      ref
          .read(subtitleSettingsProvider.notifier)
          .updateAdjustments(next)
          .catchError((_) {}),
    );
  }

  // 边界随视口/画面几何实时变化（如横竖屏切换），只记录用于渲染和
  // 调节面板展示；不据此改写用户设定的偏移值，避免不同方向互相覆盖。
  void _onSubtitleOffsetBoundsChanged(SubtitleVerticalOffsetBounds bounds) {
    if (!mounted || _isLeaving) return;
    if (_subtitleOffsetBounds == bounds) return;
    setState(() => _subtitleOffsetBounds = bounds);
  }

  Future<void> _showSubtitleSettings() async {
    if (!mounted || _isLeaving) return;
    final wasPlaying = _host.playing;
    // 弹窗存续期间方向可能变化，打开时定格一次，编辑始终作用于
    // 用户看到字幕的方向分组。
    final orientation = MediaQuery.orientationOf(context);
    try {
      if (wasPlaying) {
        await _host.pause();
      }
      if (!mounted || _isLeaving) return;
      await showSubtitleAdjustmentDialog(
        context: context,
        initial: _subtitleAdjustments,
        onChanged: _updateSubtitleAdjustments,
        orientation: orientation,
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
          subject: 'Oh My Media 播放错误',
          text: 'Oh My Media 播放错误日志',
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
    // SSE 是长连接，cancel() 的 Future 可能要等到底层 HTTP stream 完整收尾。
    // 先让旧回调失效并异步取消，不能让它阻塞后续的清晰度切换队列。
    _cancelTranscodeMonitoring();
    final movieId = widget.movieId;
    final source = ref.read(ommMediaSourceProvider);
    final stopFuture =
        shouldStopServerSession && movieId != null && source != null
        ? source.stopTranscode(_ommRef(movieId))
        : null;
    if (!shouldStopServerSession) return;
    if (stopFuture == null) return;
    if (!waitForServer) {
      // 服务器会话停止属于网络清理，不应阻塞本地播放器退出。
      unawaited(stopFuture.catchError((_) {}));
      return;
    }
    try {
      // 后端 StopByMovie 会等待 FFmpeg 退出，但网络异常不能把 _loadQueue
      // 永久锁住。正常会话在此窗口内都会完成；超时后继续打开新源。
      await stopFuture.timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  void _cancelTranscodeMonitoring() {
    _transcodeMonitoringGeneration++;
    final eventsSub = _eventsSub;
    _eventsSub = null;
    _transcodePollTimer?.cancel();
    _transcodePollTimer = null;
    if (eventsSub != null) {
      unawaited(eventsSub.cancel().catchError((_) {}));
    }
  }

  void _startTranscodeMonitoring(
    String quality,
    playback_models.PlaybackDecision decision,
  ) {
    final movieId = widget.movieId;
    if (movieId == null) return;
    _cancelTranscodeMonitoring();
    _transcodePollTimer?.cancel();
    final monitoringGeneration = _transcodeMonitoringGeneration;
    final source = ref.read(ommMediaSourceProvider);
    if (source == null) return;
    final streamUri = Uri.tryParse(decision.streamUrl);
    final streamQuery = streamUri?.queryParameters ?? const <String, String>{};
    final sessionQuality = streamQuery['quality']?.trim().isNotEmpty == true
        ? streamQuery['quality']!.trim()
        : quality;
    final mode = streamQuery['mode'];
    final audioStreamIndex = int.tryParse(
      streamQuery['audio_stream_index'] ?? '',
    );
    final subtitleTrackId = streamQuery['subtitle_track_id'];
    _eventsSub = source
        .transcodeEvents(
          _ommRef(movieId),
          quality: sessionQuality,
          mode: mode,
          audioStreamIndex: audioStreamIndex,
          subtitleTrackId: subtitleTrackId,
        )
        .listen(
          (status) {
            if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
              _applyTranscodeStatus(status);
            }
          },
          onError: (_) {
            if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
              _startTranscodePolling(
                sessionQuality,
                monitoringGeneration: monitoringGeneration,
                mode: mode,
                audioStreamIndex: audioStreamIndex,
                subtitleTrackId: subtitleTrackId,
              );
            }
          },
          onDone: () {
            if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
              _startTranscodePolling(
                sessionQuality,
                monitoringGeneration: monitoringGeneration,
                mode: mode,
                audioStreamIndex: audioStreamIndex,
                subtitleTrackId: subtitleTrackId,
              );
            }
          },
        );
    _transcodePollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollTranscodeStatus(
        sessionQuality,
        monitoringGeneration: monitoringGeneration,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      ),
    );
  }

  void _startTranscodePolling(
    String quality, {
    required int monitoringGeneration,
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) {
    if (!_isCurrentTranscodeMonitoring(monitoringGeneration)) return;
    if (_transcodePollTimer != null) return;
    _transcodePollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollTranscodeStatus(
        quality,
        monitoringGeneration: monitoringGeneration,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      ),
    );
  }

  Future<void> _pollTranscodeStatus(
    String quality, {
    required int monitoringGeneration,
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) async {
    if (!_isCurrentTranscodeMonitoring(monitoringGeneration) ||
        !_transcodeSessionActive) {
      return;
    }
    final movieId = widget.movieId;
    if (movieId == null) return;
    try {
      final source = ref.read(ommMediaSourceProvider);
      if (source == null) return;
      final status = await source.transcodeStatus(
        _ommRef(movieId),
        quality: quality,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      );
      if (_isCurrentTranscodeMonitoring(monitoringGeneration)) {
        _applyTranscodeStatus(status);
      }
    } catch (_) {}
  }

  bool _isCurrentTranscodeMonitoring(int generation) {
    return mounted &&
        !_isLeaving &&
        generation == _transcodeMonitoringGeneration;
  }

  void _applyTranscodeStatus(playback_models.TranscodeStatus status) {
    if (!mounted || _isLeaving) return;
    // 查询不到会话时后端返回 quality 为空的 inactive 状态。此时保留播放
    // 决策或上一帧给出的真实服务端状态，不能把 HLS 误显示成本地硬解。
    if (!status.active && status.quality.trim().isEmpty) return;
    setState(() {
      _serverDecodeStatus = PlayerDecodeStatus.server(
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

  source_models.MediaRef _ommRef(int movieId) => source_models.MediaRef(
    sourceId: const SourceId('omm'),
    value: '$movieId',
  );

  String _protectedUrl(ServerConfig cfg, String raw, String? token) {
    return resolveProtectedUrl(cfg, raw, token);
  }

  playback_models.PlaybackClientCaps _clientCaps(
    String quality, {
    bool forceVideoTranscode = false,
  }) {
    return _host.clientCaps(
      quality: quality,
      forceVideoTranscode: forceVideoTranscode,
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
      if (pending != null && !_tryServerFallback()) {
        _showPlaybackError(pending);
      }
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
    final directUrl = item.directUrl?.trim();
    if ((directUrl == null || directUrl.isEmpty) && item.movieId == null) {
      return;
    }
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
        _queueOwnershipTransferred = true;
        try {
          await Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute(
              builder: (_) => directUrl != null && directUrl.isNotEmpty
                  ? VideoPlayerPage.direct(
                      title: item.title,
                      directUrl: directUrl,
                      directHeaders: item.directHeaders,
                      directFormatHint: item.directFormatHint,
                      engineKind: widget.engineKind,
                      directPlaybackFileName: item.directPlaybackFileName,
                      directPreferFfmpegForHls: item.directPreferFfmpegForHls,
                      startPositionSec: item.startPositionSec,
                      queue: widget.queue,
                      queueIndex: index,
                      onQueueDispose: widget.onQueueDispose,
                    )
                  : VideoPlayerPage(
                      movieId: item.movieId!,
                      title: item.title,
                      engineKind: widget.engineKind,
                      startPositionSec: item.startPositionSec,
                      queue: widget.queue,
                      queueIndex: index,
                      onQueueDispose: widget.onQueueDispose,
                    ),
            ),
          );
        } catch (_) {
          _queueOwnershipTransferred = false;
          await _disposeQueueResources();
          rethrow;
        }
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
      _queueBrightnessOperation(() => ScreenBrightnessChannel.set(brightness)),
    );
    _showIndicator(PlayerIndicator.brightness(_brightness), autoHide: false);
  }

  void _onVolumeDelta(double delta) {
    _volume = (_volume + delta).clamp(0.0, 1.0);
    _lastVolumeGestureAt = DateTime.now();
    // ignore: discarded_futures
    FlutterVolumeController.setVolume(_volume);
    _showIndicator(PlayerIndicator.volume(_volume), autoHide: false);
  }

  /// 物理音量键等系统侧改动 · 同步基线并在播放器内显示音量条。
  void _onSystemVolumeChanged(double volume) {
    if (_isLeaving) return;
    // 手势 setVolume 的回声事件值滞后于手势自绘进度，重绘会回跳；只把
    // “音量条显示中且贴近最近一次手势”的事件当回声跳过，物理按键的
    // 连续变化必须每次都刷新指示条，否则只显示第一次的值。
    final gestureEcho =
        _indicator?.kind == PlayerIndicatorKind.volume &&
        _lastVolumeGestureAt != null &&
        DateTime.now().difference(_lastVolumeGestureAt!) <
            const Duration(milliseconds: 500);
    _volume = volume;
    if (gestureEcho) return;
    _showIndicator(PlayerIndicator.volume(volume));
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

  Future<void> _disposeQueueResources() async {
    if (_queueResourcesDisposed || _queueOwnershipTransferred) return;
    _queueResourcesDisposed = true;
    final disposeQueue = widget.onQueueDispose;
    if (disposeQueue == null) return;
    try {
      await disposeQueue();
    } catch (error) {
      _playerLog('队列资源清理失败: $error');
    }
  }

  Future<void> _exitPlayer() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _loadGeneration++;
    _hideTimer?.cancel();
    _onRateBoostEnd();
    // 先完成进度上报,让返回页面能准确判断是否需要刷新继续观看区块。
    await _reportProgress();
    unawaited(_stopPlayer());
    unawaited(_stopTranscodeSession(waitForServer: false));
    if (mounted) {
      Navigator.of(context).pop();
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
          child: Stack(children: [Positioned.fill(child: _body())]),
        ),
      ),
    );
  }

  Widget _body() {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: _host,
      builder: (_, playbackState, __) => _bodyForState(playbackState),
    );
  }

  Widget _bodyForState(PlaybackViewState playbackState) {
    if (_loading) {
      return Stack(
        children: [
          Positioned.fill(child: _host.buildSurface()),
          Positioned.fill(
            child: VideoPlayerLoadingView(
              onExit: () => unawaited(_exitPlayer()),
            ),
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
    return VideoPlayerView(
      controller: _host,
      title: widget.title,
      decision: decision,
      isDirectPlayback: _isDirectPlayback,
      selectedSubtitle: _selectedSubtitle,
      subtitleAdjustments: _subtitleAdjustments,
      onSubtitleOffsetBoundsChanged: _onSubtitleOffsetBoundsChanged,
      deviceStats: _deviceStats,
      indicator: _indicator,
      controlsVisible: _controlsVisible,
      pictureInPictureUrl: _pictureInPictureUrl,
      pictureInPictureHeaders: _pictureInPictureHeaders,
      quality: _quality,
      decodeStatuses: _decodeStatuses,
      playbackRate: _playbackRate,
      isLandscape: _isLandscape,
      onToggleControls: _toggleControls,
      onDoubleTapCenter: _onDoubleTapCenter,
      onDoubleTapSeek: _onDoubleTapSeek,
      onRateBoost: _onRateBoost,
      onRateBoostEnd: _onRateBoostEnd,
      onSeekPreview: _onSeekPreview,
      onSeekCommit: _onSeekCommit,
      onBrightnessDelta: _onBrightnessDelta,
      onVolumeDelta: _onVolumeDelta,
      onHideIndicator: _hideIndicator,
      onQualityChanged: _onQualityChanged,
      onSubtitleChanged: (track) => unawaited(_onSubtitleChanged(track)),
      onOpenSubtitleSettings: () => unawaited(_showSubtitleSettings()),
      onAudioChanged: (track) => unawaited(_applyAudioTrack(track)),
      onPictureInPicture: () => unawaited(_enterPictureInPicture()),
      onPreviousMedia: widget.queueIndex > 0
          ? () => unawaited(_switchMedia(widget.queueIndex - 1))
          : null,
      onNextMedia: widget.queueIndex < widget.queue.length - 1
          ? () => unawaited(_switchMedia(widget.queueIndex + 1))
          : null,
      onOrientationToggle: () => unawaited(_toggleOrientation()),
      onTogglePlay: _togglePlay,
      onSeekBackward: () => _onDoubleTapSeek(-10),
      onSeekForward: () => _onDoubleTapSeek(10),
      onRateChanged: _onRateChanged,
      onInteraction: _restartHideTimer,
      onExit: () => unawaited(_exitPlayer()),
    );
  }
}

class _PictureInPictureSource {
  const _PictureInPictureSource({required this.url, required this.headers});

  final String url;
  final Map<String, String>? headers;
}
