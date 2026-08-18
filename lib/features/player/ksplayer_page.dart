import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
import 'ksplayer_platform.dart';
import 'player_queue.dart';
import 'player_resume.dart';
import 'player_settings.dart';
import 'player_system_levels.dart';

class KsPlayerPage extends ConsumerStatefulWidget {
  const KsPlayerPage({
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

  @override
  ConsumerState<KsPlayerPage> createState() => _KsPlayerPageState();
}

class _KsPlayerPageState extends ConsumerState<KsPlayerPage>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  _KsPlayerConfig? _config;
  KsPlayerPlatformController? _controller;
  final PlayerSystemLevels _systemLevels = PlayerSystemLevels();
  bool _isLeaving = false;
  bool _isPlaying = false;
  bool _wasPlayingBeforePause = false;
  bool _isLifecyclePaused = false;
  bool _transcodeSessionActive = false;
  int _lastPositionSec = 0;
  int _lastDurationSec = 0;
  int _loadGeneration = 0;
  Timer? _progressReportTimer;
  Future<void> _progressReportChain = Future<void>.value();
  Future<void>? _cleanupFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_systemLevels.initialize());
    WakelockPlus.enable();
    unawaited(_applyEntryOrientation(ref.read(playerSettingsProvider)));
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isLeaving) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_isLifecyclePaused) {
          unawaited(_reportProgress());
          break;
        }
        _isLifecyclePaused = true;
        _wasPlayingBeforePause = _isPlaying;
        if (_wasPlayingBeforePause) {
          unawaited(_controller?.pause() ?? Future<void>.value());
        }
        unawaited(_reportProgress());
      case AppLifecycleState.resumed:
        if (!_isLifecyclePaused) break;
        _isLifecyclePaused = false;
        if (_wasPlayingBeforePause) {
          _wasPlayingBeforePause = false;
          unawaited(_controller?.play() ?? Future<void>.value());
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    _isLeaving = true;
    _loadGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _progressReportTimer?.cancel();
    unawaited(_cleanup());
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    _systemLevels.restore();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _applyEntryOrientation(PlayerSettings settings) async {
    final orientations = switch (settings.entryOrientation) {
      PlayerEntryOrientation.unchanged => null,
      PlayerEntryOrientation.forceLandscape => [
          settings.landscapeSide == PlayerLandscapeSide.cameraLeft
              ? DeviceOrientation.landscapeLeft
              : DeviceOrientation.landscapeRight,
        ],
      PlayerEntryOrientation.forcePortrait => [
          DeviceOrientation.portraitUp,
        ],
    };
    if (orientations != null) {
      await SystemChrome.setPreferredOrientations(orientations);
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted || _isLeaving) return;
    await _systemLevels.initialize();
    if (!mounted || _isLeaving || generation != _loadGeneration) return;
    setState(() {
      _loading = true;
      _error = null;
      _config = null;
    });

    try {
      if (!Platform.isIOS) {
        throw StateError('KSPlayer 仅支持 iOS');
      }
      final cfg = ref.read(serverConfigProvider);
      if (cfg == null) throw StateError('未配置服务器');
      final client = ref.read(requiredApiClientProvider);
      final token = await ref.read(authSessionRepositoryProvider).accessToken();
      if (!mounted || _isLeaving || generation != _loadGeneration) return;

      final decision = await client.playback.decision(
        widget.movieId,
        playback_models.PlaybackClientCaps.mobile(
          qualityPreset: 'original',
          userAgent: 'md_center/${Platform.operatingSystem}',
        ),
      );
      final rawDirectUrl = await client.playback.streamUrl(widget.movieId);
      final directUrl = resolveProtectedUrl(cfg, rawDirectUrl, token);
      final directHeaders = !isExternalUrl(cfg, rawDirectUrl)
          ? _authorizationHeaders(token)
          : null;

      WatchRecord? savedRecord;
      final settings = ref.read(playerSettingsProvider);
      if (settings.resumeFromLastPosition && widget.startPositionSec <= 0) {
        try {
          savedRecord = await ref
              .read(moviesRepositoryProvider)
              .watchRecord(widget.movieId);
        } catch (_) {
          // 观看记录失败不阻塞首次播放。
        }
      }
      final resumePositionSec = resolveResumePosition(
        enabled: settings.resumeFromLastPosition,
        explicitPositionSec: widget.startPositionSec,
        record: savedRecord,
      );

      final subtitleUrls = decision.subtitleTracks
          .where((track) =>
              !track.isEmbedded && track.canLoad && track.url.trim().isNotEmpty)
          .map((track) => _protectedSubtitleUrl(cfg, track.url, token))
          .whereType<String>()
          .toSet()
          .toList();
      final definitions = <Map<String, Object?>>[
        _definition('原画', directUrl, directHeaders),
        for (final quality in const ['1080p', '720p', '480p'])
          _definition(
            quality,
            _fallbackHlsUrl(cfg, token, quality),
            null,
          ),
      ];

      if (!mounted || _isLeaving || generation != _loadGeneration) return;
      setState(() {
        _config = _KsPlayerConfig(
          url: directUrl,
          headers: directHeaders,
          title: widget.title,
          startPosition: resumePositionSec > 0
              ? Duration(seconds: resumePositionSec)
              : Duration.zero,
          subtitleUrls: subtitleUrls,
          definitions: definitions,
        );
        _loading = false;
      });
      _startProgressReporting();
    } catch (error) {
      if (!mounted || _isLeaving || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _onNativeEvent(String method, dynamic arguments) async {
    if (_isLeaving) return;
    final values = arguments is Map ? arguments : const <Object?, Object?>{};
    switch (method) {
      case 'time':
        final positionMs = _number(values['position_ms']);
        final durationMs = _number(values['duration_ms']);
        _lastPositionSec = (positionMs / 1000).floor();
        _lastDurationSec = (durationMs / 1000).floor();
        _isPlaying = values['is_playing'] == true;
      case 'state':
        _isPlaying = values['is_playing'] == true;
        if (values['value'] == 'playedToTheEnd') {
          if (_lastDurationSec > 0) _lastPositionSec = _lastDurationSec;
          unawaited(_reportProgress());
          unawaited(_stopTranscodeSession());
        }
      case 'finished':
        if (_lastDurationSec > 0) _lastPositionSec = _lastDurationSec;
        _isPlaying = false;
        unawaited(_reportProgress());
        unawaited(_stopTranscodeSession());
      case 'definitionChanged':
        final label = values['label'] as String?;
        final usesTranscode = label?.trim().isNotEmpty == true &&
            label != '原画';
        if (_transcodeSessionActive && !usesTranscode) {
          unawaited(_stopTranscodeSession());
        }
        _transcodeSessionActive = usesTranscode;
      case 'back':
        await _exitPlayer();
      case 'error':
        unawaited(_stopTranscodeSession());
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = values['message']?.toString() ?? 'KSPlayer 播放失败';
        });
      default:
        break;
    }
  }

  Future<void> _switchMedia(int index) async {
    if (_isLeaving || index < 0 || index >= widget.queue.length) return;
    final item = widget.queue[index];
    _isLeaving = true;
    _loadGeneration++;
    await _cleanup();
    if (!mounted) return;
    _invalidateHomeMovieLists();
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => KsPlayerPage(
          movieId: item.movieId,
          title: item.title,
          startPositionSec: item.startPositionSec,
          queue: widget.queue,
          queueIndex: index,
        ),
      ),
    );
  }

  Future<void> _exitPlayer() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _loadGeneration++;
    await _cleanup();
    if (!mounted) return;
    _invalidateHomeMovieLists();
    Navigator.of(context).pop();
  }

  Future<void> _cleanup() {
    return _cleanupFuture ??= _cleanupInternal();
  }

  Future<void> _cleanupInternal() async {
    _progressReportTimer?.cancel();
    await _reportProgress();
    await _stopTranscodeSession();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.stop();
        await controller.dispose();
      } catch (_) {}
    }
  }

  Future<void> _stopTranscodeSession() async {
    if (!_transcodeSessionActive) return;
    _transcodeSessionActive = false;
    try {
      await ref.read(requiredApiClientProvider).playback.stop(widget.movieId);
    } catch (_) {}
  }

  void _startProgressReporting() {
    _progressReportTimer?.cancel();
    _progressReportTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!_isLeaving) unawaited(_reportProgress());
      },
    );
  }

  Future<void> _reportProgress() {
    final next = _progressReportChain.then<void>((_) async {
      final positionSec = _lastPositionSec;
      final durationSec = _lastDurationSec;
      if (durationSec <= 0 || positionSec <= 0) return;
      try {
        await ref.read(moviesRepositoryProvider).upsertWatchRecord(
              widget.movieId,
              positionSec: positionSec,
              durationSec: durationSec,
              completed: positionSec >= durationSec * 0.95,
            );
      } catch (_) {
        // 播放页退出时网络断开不能阻塞页面退出。
      }
    });
    _progressReportChain = next;
    return next;
  }

  Map<String, String>? _authorizationHeaders(String? token) {
    final value = token?.trim() ?? '';
    if (value.isEmpty) return null;
    return {'Authorization': 'Bearer $value'};
  }

  String? _protectedSubtitleUrl(
    ServerConfig cfg,
    String raw,
    String? token,
  ) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (isExternalUrl(cfg, value)) return value;
    return resolveProtectedUrl(cfg, value, token);
  }

  String _fallbackHlsUrl(ServerConfig cfg, String? token, String quality) {
    final path =
        '/api/movies/id/${widget.movieId}/stream.m3u8?quality=$quality';
    return appendQueryToken(resolveServerUrl(cfg, path), token);
  }

  Map<String, Object?> _definition(
    String label,
    String url,
    Map<String, String>? headers,
  ) {
    return {
      'label': label,
      'url': url,
      if (headers != null && headers.isNotEmpty) 'headers': headers,
    };
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _onNativeCreated(KsPlayerPlatformController controller) {
    if (_isLeaving) {
      unawaited(controller.dispose());
      return;
    }
    _controller = controller;
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
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(_load()),
                child: const Text('重试'),
              ),
              TextButton(
                onPressed: () => unawaited(_exitPlayer()),
                child: const Text('退出'),
              ),
            ],
          ),
        ),
      );
    }
    final config = _config;
    if (config == null) return const SizedBox.shrink();
    final showQueueButtons = ref.watch(playerSettingsProvider).showMediaSwitchButton;
    return Stack(
      children: [
        Positioned.fill(
          child: KsPlayerPlatformView(
            creationParams: config.creationParams,
            onCreated: _onNativeCreated,
            onEvent: _onNativeEvent,
          ),
        ),
        if (showQueueButtons &&
            (widget.queueIndex > 0 ||
                widget.queueIndex < widget.queue.length - 1))
          Positioned(
            bottom: 18,
            left: 18,
            right: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.queueIndex > 0)
                  _QueueButton(
                    icon: Icons.skip_previous,
                    label: '上一部',
                    onPressed: () =>
                        unawaited(_switchMedia(widget.queueIndex - 1)),
                  )
                else
                  const SizedBox.shrink(),
                if (widget.queueIndex < widget.queue.length - 1)
                  _QueueButton(
                    icon: Icons.skip_next,
                    label: '下一部',
                    onPressed: () =>
                        unawaited(_switchMedia(widget.queueIndex + 1)),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
      ],
    );
  }
}

class _KsPlayerConfig {
  const _KsPlayerConfig({
    required this.url,
    required this.headers,
    required this.title,
    required this.startPosition,
    required this.subtitleUrls,
    required this.definitions,
  });

  final String url;
  final Map<String, String>? headers;
  final String title;
  final Duration startPosition;
  final List<String> subtitleUrls;
  final List<Map<String, Object?>> definitions;

  Map<String, Object?> get creationParams => {
        'url': url,
        if (headers != null && headers!.isNotEmpty) 'headers': headers,
        'title': title,
        'start_position_ms': startPosition.inMilliseconds,
        'subtitle_urls': subtitleUrls,
        'definitions': definitions,
      };
}

class _QueueButton extends StatelessWidget {
  const _QueueButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: colors.surface.withValues(alpha: 0.88),
        foregroundColor: colors.text,
      ),
    );
  }
}
