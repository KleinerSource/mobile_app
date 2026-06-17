import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/media_info.dart';
import '../../core/platform/app_theme.dart';
import '../movies/movies_providers.dart';
import 'playback_decision.dart';
import 'player_controller_host.dart';
import 'player_controls.dart';
import 'player_gesture_layer.dart';
import 'player_overlay_indicators.dart';

/// 全屏视频播放页 · media_kit 内核 (ffmpeg + 硬解) + 自绘手势层
///
/// 手势: 水平滑动快进退 / 长按加速 / 左侧亮度 / 右侧音量 / 单击显隐控制条。
/// 自动选源: 默认直传, 可手动切「省流量」(HLS)。退出时上报进度。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.movieId,
    required this.title,
    this.startPositionSec = 0,
  });

  final int movieId;
  final String title;
  final int startPositionSec;

  static Future<void> open(
    BuildContext context, {
    required int movieId,
    required String title,
    int startPositionSec = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          movieId: movieId,
          title: title,
          startPositionSec: startPositionSec,
        ),
      ),
    );
  }

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  final PlayerControllerHost _host = PlayerControllerHost();
  bool _loading = true;
  String? _error;

  // 选源
  String? _streamUrl;
  String? _hlsUrl;
  MediaInfo? _mediaInfo;
  bool _saveData = false;

  // 进度 (退出时一次性上报)
  int _lastPositionSec = 0;
  int _lastDurationSec = 0;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _completedSub;

  // 临时 UI 状态
  bool _controlsVisible = true;
  Timer? _hideTimer;
  PlayerIndicator? _indicator;
  Timer? _indicatorTimer;
  double _brightness = 0.5;
  double _volume = 0.5;
  double? _restoreBrightness;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    FlutterVolumeController.updateShowSystemUI(false);
    _initLevels();
    _load();
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

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completedSub?.cancel();
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values);
    FlutterVolumeController.updateShowSystemUI(true);
    if (_restoreBrightness != null) {
      // ignore: discarded_futures
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    }
    if (_lastDurationSec > 0 && _lastPositionSec > 0) {
      // ignore: discarded_futures
      ref.read(moviesRepositoryProvider).upsertWatchRecord(
            widget.movieId,
            positionSec: _lastPositionSec,
            durationSec: _lastDurationSec,
            completed: _lastPositionSec >= (_lastDurationSec * 0.95),
          );
    }
    // ignore: discarded_futures
    _host.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = ref.read(serverConfigProvider);
      if (cfg == null) {
        throw StateError('未配置服务器');
      }
      final base = cfg.apiBase;
      _streamUrl = '$base/movies/id/${widget.movieId}/stream';
      _hlsUrl = '$base/movies/id/${widget.movieId}/stream.m3u8';

      try {
        _mediaInfo =
            await ref.read(moviesRepositoryProvider).mediaInfo(widget.movieId);
      } catch (_) {}

      final src = _resolveSource();
      await _host.open(
        src.url,
        startAt: widget.startPositionSec > 0
            ? Duration(seconds: widget.startPositionSec)
            : null,
      );
      _bindProgress();

      if (!mounted) return;
      setState(() => _loading = false);
      _restartHideTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = toApiException(e).message;
        _loading = false;
      });
    }
  }

  /// 默认直传; 仅当用户切「省流量」时经 PlaybackDecision 走 HLS
  PlaybackSource _resolveSource() {
    if (!_saveData) {
      return PlaybackSource(
        url: _streamUrl!,
        type: PlaybackSourceType.direct,
        reason: 'default direct',
      );
    }
    return PlaybackDecision.decide(
      streamUrl: _streamUrl!,
      hlsUrl: _hlsUrl!,
      mediaInfo: _mediaInfo,
      forceHls: true,
    );
  }

  void _bindProgress() {
    _posSub = _host.positionStream.listen((p) {
      _lastPositionSec = p.inSeconds;
    });
    _durSub = _host.durationStream.listen((d) {
      _lastDurationSec = d.inSeconds;
    });
    _completedSub = _host.completedStream.listen((done) {
      if (done && _lastDurationSec > 0) _lastPositionSec = _lastDurationSec;
    });
  }

  // ===== 选源切换 =====

  Future<void> _toggleSaveData() async {
    final resume = _host.position;
    setState(() => _saveData = !_saveData);
    final src = _resolveSource();
    await _host.open(src.url, startAt: resume);
  }

  // ===== 控制条显隐 =====

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

  void _onInteraction() => _restartHideTimer();

  // ===== 指示器 =====

  void _showIndicator(PlayerIndicator ind, {bool autoHide = true}) {
    _indicatorTimer?.cancel();
    setState(() => _indicator = ind);
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

  // ===== 手势回调 =====

  void _onRateBoost(double rate) {
    // ignore: discarded_futures
    _host.setRate(rate);
    _showIndicator(PlayerIndicator.speed(rate), autoHide: false);
  }

  void _onRateBoostEnd() {
    // ignore: discarded_futures
    _host.setRate(1.0);
    _hideIndicator();
  }

  void _onSeekPreview(Duration target, int deltaMs) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _body()),
            // 常驻返回键 (始终可见, 不随控制条显隐)
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
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
      return _ErrorView(message: _error!, onRetry: _load);
    }
    return Stack(
      children: [
        // 1. 视频画面 (关掉 media_kit 自带控件/手势)
        Positioned.fill(
          child: Video(
            controller: _host.controller,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),
        // 2. 手势层
        Positioned.fill(
          child: PlayerGestureLayer(
            positionGetter: () => _host.position,
            durationGetter: () => _host.duration,
            onTap: _toggleControls,
            onRateBoost: _onRateBoost,
            onRateBoostEnd: _onRateBoostEnd,
            onSeekPreview: _onSeekPreview,
            onSeekCommit: _onSeekCommit,
            onBrightnessDelta: _onBrightnessDelta,
            onVolumeDelta: _onVolumeDelta,
            onAxisDragEnd: _hideIndicator,
          ),
        ),
        // 3. 中央指示器 (纯展示)
        Positioned.fill(
          child: PlayerOverlayIndicators(indicator: _indicator),
        ),
        // 4. 控制层 (隐藏时穿透手势)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: PlayerControls(
                player: _host.player,
                title: widget.title,
                saveData: _saveData,
                onTogglePlay: _host.playOrPause,
                onSeek: (d) => _host.seek(d),
                onToggleSaveData: _toggleSaveData,
                onInteraction: _onInteraction,
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
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
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
