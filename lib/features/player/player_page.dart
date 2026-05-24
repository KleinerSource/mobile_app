import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/media_info.dart';
import '../../core/platform/app_theme.dart';
import '../movies/movies_providers.dart';
import 'playback_decision.dart';

/// 全屏视频播放页 · 自动选源 (直传 / HLS), 退出时上报进度
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
  BetterPlayerController? _controller;
  bool _loading = true;
  String? _error;

  /// 最近一次进度 (用于退出时一次性上报, 节省 watch_record 写入)
  int _lastPositionSec = 0;
  int _lastDurationSec = 0;

  @override
  void initState() {
    super.initState();
    // 强制横屏 + 沉浸式 (退出时还原)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load();
  }

  @override
  void dispose() {
    _controller?.removeEventsListener(_onEvent);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values);
    // 上报最后进度
    if (_lastDurationSec > 0 && _lastPositionSec > 0) {
      // ignore: discarded_futures
      ref.read(moviesRepositoryProvider).upsertWatchRecord(
            widget.movieId,
            positionSec: _lastPositionSec,
            durationSec: _lastDurationSec,
            completed: _lastPositionSec >= (_lastDurationSec * 0.95),
          );
    }
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
      final streamUrl = '$base/movies/id/${widget.movieId}/stream';
      final hlsUrl = '$base/movies/id/${widget.movieId}/stream.m3u8';

      // 拉 media-info (失败 → 直传)
      MediaInfo? info;
      try {
        info = await ref
            .read(moviesRepositoryProvider)
            .mediaInfo(widget.movieId);
      } catch (_) {}

      final src = PlaybackDecision.decide(
        streamUrl: streamUrl,
        hlsUrl: hlsUrl,
        mediaInfo: info,
      );

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        src.url,
        videoFormat:
            src.isHls ? BetterPlayerVideoFormat.hls : BetterPlayerVideoFormat.other,
        cacheConfiguration: const BetterPlayerCacheConfiguration(
          useCache: false,
        ),
        notificationConfiguration: BetterPlayerNotificationConfiguration(
          showNotification: true,
          title: widget.title,
        ),
      );

      final controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: true,
          fit: BoxFit.contain,
          handleLifecycle: true,
          allowedScreenSleep: false,
          autoDispose: false,
          startAt: widget.startPositionSec > 0
              ? Duration(seconds: widget.startPositionSec)
              : null,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            enableQualities: false,
            enableSubtitles: true,
            enablePip: true,
          ),
          errorBuilder: (ctx, err) => _ErrorView(
            message: err ?? '播放失败',
            onRetry: _load,
          ),
        ),
        betterPlayerDataSource: dataSource,
      );
      controller.addEventsListener(_onEvent);

      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = toApiException(e).message;
        _loading = false;
      });
    }
  }

  void _onEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
      final pos = event.parameters?['progress'];
      final dur = event.parameters?['duration'];
      if (pos is Duration) _lastPositionSec = pos.inSeconds;
      if (dur is Duration) _lastDurationSec = dur.inSeconds;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _body()),
            // 顶部返回按钮 (始终可见, 即便控件隐藏)
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
    final ctl = _controller;
    if (ctl == null) {
      return const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: BetterPlayer(controller: ctl),
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
