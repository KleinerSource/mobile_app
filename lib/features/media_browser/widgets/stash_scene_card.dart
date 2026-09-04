import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/api/media_browser_server_urls.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';

/// Stash 预览播放器的最小协议，便于页面测试注入 Fake 实现。
abstract interface class StashPreviewPlayer {
  ValueListenable<Duration> get duration;

  ValueListenable<Duration> get position;

  Widget buildVideo({BoxFit fit = BoxFit.cover});

  Future<void> open(String url, {Map<String, String>? headers});

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

typedef StashPreviewPlayerFactory = StashPreviewPlayer Function();

/// 默认使用 media_kit 的 Stash 短视频播放器。
class MediaKitStashPreviewPlayer implements StashPreviewPlayer {
  MediaKitStashPreviewPlayer()
    : _player = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          bufferSize: 8 * 1024 * 1024,
        ),
      ) {
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        _duration.value = value;
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) {
        _position.value = value;
      }),
    );
  }

  final Player _player;
  late final VideoController _controller;
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  ValueListenable<Duration> get duration => _duration;

  @override
  ValueListenable<Duration> get position => _position;

  @override
  Widget buildVideo({BoxFit fit = BoxFit.cover}) => Video(
    controller: _controller,
    controls: NoVideoControls,
    fit: fit,
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );

  @override
  Future<void> open(String url, {Map<String, String>? headers}) async {
    await _player
        .open(
          Media(url, httpHeaders: headers?.isEmpty == true ? null : headers),
          play: true,
        )
        .timeout(const Duration(seconds: 3));
    try {
      await _controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // 某些平台不回报首帧，但播放器可能已经可以正常显示。
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    _duration.dispose();
    _position.dispose();
  }
}

/// 页面级预览协调器，保证同一媒体列表同时只有一个预览播放器。
class StashPreviewCoordinator {
  VoidCallback? _activeRelease;

  void claim(VoidCallback release) {
    if (identical(_activeRelease, release)) return;
    _activeRelease?.call();
    _activeRelease = release;
  }

  void release(VoidCallback release) {
    if (identical(_activeRelease, release)) _activeRelease = null;
  }

  void dispose() {
    _activeRelease?.call();
    _activeRelease = null;
  }
}

/// 为媒体库/搜索页提供页面级 Stash 预览协调器。
class StashPreviewScope extends StatefulWidget {
  const StashPreviewScope({super.key, required this.child});

  final Widget child;

  static StashPreviewCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_StashPreviewInherited>()
      ?.coordinator;

  @override
  State<StashPreviewScope> createState() => _StashPreviewScopeState();
}

class _StashPreviewScopeState extends State<StashPreviewScope> {
  final _coordinator = StashPreviewCoordinator();

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StashPreviewInherited(coordinator: _coordinator, child: widget.child);
}

class _StashPreviewInherited extends InheritedWidget {
  const _StashPreviewInherited({
    required this.coordinator,
    required super.child,
  });

  final StashPreviewCoordinator coordinator;

  @override
  bool updateShouldNotify(_StashPreviewInherited oldWidget) =>
      coordinator != oldWidget.coordinator;
}

/// Stash Scene 横向卡片：全宽 16:9 封面，长按后可拖动预览视频时间轴。
class StashSceneCard extends ConsumerStatefulWidget {
  const StashSceneCard({
    super.key,
    required this.item,
    required this.urls,
    required this.width,
    required this.onTap,
    this.coordinator,
    this.playerFactory = _defaultStashPreviewPlayerFactory,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final VoidCallback onTap;
  final StashPreviewCoordinator? coordinator;
  final StashPreviewPlayerFactory playerFactory;

  @override
  ConsumerState<StashSceneCard> createState() => _StashSceneCardState();
}

StashPreviewPlayer _defaultStashPreviewPlayerFactory() =>
    MediaKitStashPreviewPlayer();

class _StashSceneCardState extends ConsumerState<StashSceneCard> {
  late final VoidCallback _releaseForCoordinator = _releasePreview;
  StashPreviewCoordinator? _coordinator;
  StashPreviewPlayer? _previewPlayer;
  bool _previewing = false;
  bool _previewLoading = false;
  int _previewGeneration = 0;

  void _releasePreview() {
    unawaited(_stopPreview());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= widget.coordinator ?? StashPreviewScope.maybeOf(context);
  }

  @override
  void didUpdateWidget(covariant StashSceneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.playerFactory != widget.playerFactory) {
      unawaited(_stopPreview());
    }
  }

  @override
  void dispose() {
    _coordinator?.release(_releaseForCoordinator);
    unawaited(_stopPreview(rebuild: false));
    super.dispose();
  }

  bool _revealOrAllow() {
    final shielded = ref.read(privacyShieldProvider);
    final revealed = ref.read(revealedMoviesProvider).contains(widget.item.id);
    if (shielded && !revealed) {
      ref.read(revealedMoviesProvider.notifier).reveal(widget.item.id);
      return false;
    }
    return true;
  }

  void _onTap() {
    if (_revealOrAllow()) widget.onTap();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!_revealOrAllow()) return;
    AppHaptics.light();
    unawaited(_startPreview());
  }

  Future<void> _startPreview() async {
    if (_previewing) return;
    final url = widget.urls.preview(widget.item.previewPath);
    if (url == null || url.isEmpty) return;

    _coordinator?.claim(_releaseForCoordinator);
    final generation = ++_previewGeneration;
    final player = widget.playerFactory();
    _previewPlayer = player;
    if (mounted) {
      setState(() {
        _previewing = true;
        _previewLoading = true;
      });
    }
    try {
      await player.open(url, headers: widget.urls.directHeaders);
      if (!mounted ||
          generation != _previewGeneration ||
          player != _previewPlayer) {
        await player.dispose();
        return;
      }
      if (mounted) setState(() => _previewLoading = false);
    } catch (_) {
      if (generation == _previewGeneration && player == _previewPlayer) {
        await _stopPreview();
      } else {
        await player.dispose();
      }
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_previewing || _previewLoading) return;
    final offset = details.offsetFromOrigin;
    if (offset.dx.abs() < 10 || offset.dx.abs() <= offset.dy.abs()) return;
    final player = _previewPlayer;
    if (player == null) return;
    final duration = player.duration.value;
    if (duration <= Duration.zero) return;
    final width = widget.width <= 0 ? 1 : widget.width;
    final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
    final target = Duration(
      microseconds: (duration.inMicroseconds * fraction).round(),
    );
    unawaited(player.seek(target));
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    unawaited(_stopPreview());
  }

  Future<void> _stopPreview({bool rebuild = true}) async {
    ++_previewGeneration;
    final player = _previewPlayer;
    _previewPlayer = null;
    _coordinator?.release(_releaseForCoordinator);
    if (rebuild && mounted) {
      setState(() {
        _previewing = false;
        _previewLoading = false;
      });
    }
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final previewPlayer = _previewPlayer;
    final previewReady =
        _previewing && !_previewLoading && previewPlayer != null;
    final imageUrl = widget.urls.heroImage(widget.item);
    final meta = _metaText(context);
    final performers = widget.item.people
        .map((person) => person.name.trim())
        .where((name) => name.isNotEmpty)
        .take(3)
        .join(' · ');
    return SizedBox(
      width: widget.width,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PrivacyMask(
                movieId: widget.item.id,
                radius: 16,
                child: previewReady
                    ? previewPlayer.buildVideo()
                    : _CoverImage(
                        url: imageUrl,
                        headers: widget.urls.imageHeaders,
                      ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x14000000),
                      Color(0xD9000000),
                    ],
                    stops: [0.35, 0.55, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrivacyText(
                      movieId: widget.item.id,
                      text: widget.item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle(context).copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.2,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      PrivacyText(
                        movieId: widget.item.id,
                        text: meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardMeta(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                    if (performers.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      PrivacyText(
                        movieId: widget.item.id,
                        text: performers,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardMeta(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProgressBar(
                  value: previewReady
                      ? _ratio(
                          previewPlayer.position.value,
                          previewPlayer.duration.value,
                        )
                      : _itemProgress(widget.item),
                  color: appColors(context).accent,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTap,
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: _onLongPressMoveUpdate,
                  onLongPressEnd: _onLongPressEnd,
                  child: const SizedBox.expand(),
                ),
              ),
              if (_previewLoading)
                const Positioned(
                  top: 14,
                  right: 14,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (previewReady)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(
                    Icons.swipe_rounded,
                    size: 20,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _metaText(BuildContext context) {
    final parts = <String>[];
    final base = mediaBrowserItemMetaText(context, widget.item);
    if (base.isNotEmpty) parts.add(base);
    final rating = widget.item.communityRating;
    if (rating != null && rating > 0) {
      parts.add('★ ${rating.toStringAsFixed(1)}');
    }
    return parts.join(' · ');
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.headers});

  final String? url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return const _CoverPlaceholder();
    return Image.network(
      value,
      fit: BoxFit.cover,
      headers: headers,
      errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black26,
    child: Center(
      child: Icon(
        Icons.movie_outlined,
        size: 42,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 3,
    child: LinearProgressIndicator(
      value: value > 0 ? value : 0,
      backgroundColor: Colors.white24,
      color: color,
    ),
  );
}

double _itemProgress(MediaBrowserItem item) {
  final duration = item.runTimeTicks ?? 0;
  if (duration <= 0 || item.userData.resumeSeconds <= 0) return 0;
  final seconds = mediaBrowserTicksToSeconds(duration);
  if (seconds <= 0) return 0;
  return (item.userData.resumeSeconds / seconds).clamp(0.0, 1.0);
}

double _ratio(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
}
