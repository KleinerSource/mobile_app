import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/api/media_browser_server_urls.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/media_metadata_widgets.dart';

/// Stash 预览播放器的最小协议，便于页面测试注入 Fake 实现。
abstract interface class StashPreviewPlayer {
  ValueListenable<Duration> get duration;

  ValueListenable<Duration> get position;

  Widget buildVideo({BoxFit fit = BoxFit.cover});

  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool autoplay = true,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

typedef StashPreviewPlayerFactory = StashPreviewPlayer Function();

/// 根据列表滚动位置选择当前应自动预览的最上方 Scene。
///
/// 列表项之间有固定间距；当上一张封面离开视口超过 60% 时，立即切到下一张，
/// 不必等下一张卡片真正贴到视口顶部。
int? stashPreviewItemIndexForScroll({
  required double scrollOffset,
  required double cardHeight,
  required double itemGap,
  required int itemCount,
  double leadingPadding = 0,
  double switchOutFraction = 0.6,
}) {
  if (itemCount <= 0 ||
      !scrollOffset.isFinite ||
      !cardHeight.isFinite ||
      cardHeight <= 0 ||
      !itemGap.isFinite ||
      itemGap < 0 ||
      !switchOutFraction.isFinite ||
      switchOutFraction <= 0 ||
      switchOutFraction > 1) {
    return null;
  }
  final offset = (scrollOffset - leadingPadding).clamp(0.0, double.infinity);
  final itemExtent = cardHeight + itemGap;
  final baseIndex = (offset / itemExtent).floor();
  final withinItem = offset - baseIndex * itemExtent;
  final index = withinItem > cardHeight * switchOutFraction
      ? baseIndex + 1
      : baseIndex;
  return index.clamp(0, itemCount - 1);
}

/// 按实际布局位置选择自动预览项。
///
/// Stash 卡片的标签和演员区域高度会随内容变化，不能只用固定列表项高度
/// 推算。只要卡片已经完成布局，就用封面顶部相对滚动视口的位置计算离屏比例。
int? stashPreviewItemIndexForViewport({
  required List<MediaBrowserItem> items,
  required Map<String, GlobalKey> itemKeys,
  required GlobalKey viewportKey,
  required double coverHeight,
  double switchOutFraction = 0.6,
}) {
  return previewItemIndexForViewportKeys(
    itemKeys: items.map((item) => itemKeys[item.id]),
    viewportKey: viewportKey,
    coverHeight: coverHeight,
    switchOutFraction: switchOutFraction,
  );
}

/// 按一组列表项的布局 key 选择当前应自动预览的项。
///
/// Stash 和 OMM 的媒体模型不同，但横版预览需要的视口计算完全一致，
/// 因此这里只复用布局算法，不让 OMM 依赖 Stash 的数据模型。
int? previewItemIndexForViewportKeys({
  required Iterable<GlobalKey?> itemKeys,
  required GlobalKey viewportKey,
  required double coverHeight,
  double switchOutFraction = 0.6,
}) {
  final keys = itemKeys.toList(growable: false);
  if (keys.isEmpty ||
      !coverHeight.isFinite ||
      coverHeight <= 0 ||
      !switchOutFraction.isFinite ||
      switchOutFraction <= 0 ||
      switchOutFraction > 1) {
    return null;
  }
  final viewport = viewportKey.currentContext?.findRenderObject();
  if (viewport is! RenderBox || !viewport.hasSize) return null;
  final viewportTop = viewport.localToGlobal(Offset.zero).dy;
  final viewportBottom = viewportTop + viewport.size.height;
  for (var index = 0; index < keys.length; index++) {
    final card = keys[index]?.currentContext?.findRenderObject();
    if (card is! RenderBox || !card.hasSize) continue;
    final cardTop = card.localToGlobal(Offset.zero).dy;
    final cardBottom = cardTop + card.size.height;
    if (cardBottom <= viewportTop || cardTop >= viewportBottom) continue;
    final hidden = (viewportTop - cardTop).clamp(0.0, coverHeight);
    if (hidden <= coverHeight * switchOutFraction) return index;
  }
  return null;
}

/// 将横版封面上的横向拖动位置转换为预览视频时间。
///
/// 返回值为空时表示播放器还没有有效时长或封面宽度不可用。
Duration? previewSeekPositionForLocalOffset({
  required Offset localPosition,
  required double width,
  required Duration duration,
}) {
  if (!width.isFinite || width <= 0 || duration <= Duration.zero) return null;
  final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
  return Duration(microseconds: (duration.inMicroseconds * fraction).round());
}

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
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool autoplay = true,
  }) async {
    await _player
        .open(
          Media(url, httpHeaders: headers?.isEmpty == true ? null : headers),
          play: autoplay,
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

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

/// Stash Scene 横向卡片：全宽 16:9 封面，横向拖动可调整预览视频时间轴。
class StashSceneCard extends ConsumerStatefulWidget {
  const StashSceneCard({
    super.key,
    required this.item,
    required this.urls,
    required this.width,
    required this.onTap,
    this.coordinator,
    this.playerFactory = _defaultStashPreviewPlayerFactory,
    this.autoPlayPreview = false,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final VoidCallback onTap;
  final StashPreviewCoordinator? coordinator;
  final StashPreviewPlayerFactory playerFactory;

  /// 页面滚动选中该条目时自动播放短预览；横向拖动也可手动启动预览。
  final bool autoPlayPreview;

  @override
  ConsumerState<StashSceneCard> createState() => _StashSceneCardState();
}

StashPreviewPlayer _defaultStashPreviewPlayerFactory() =>
    MediaKitStashPreviewPlayer();

class _StashSceneCardState extends ConsumerState<StashSceneCard> {
  late final VoidCallback _releaseForCoordinator = _releasePreview;
  StashPreviewCoordinator? _coordinator;
  StashPreviewPlayer? _previewPlayer;
  Future<void>? _previewOpening;
  bool _previewing = false;
  bool _previewLoading = false;
  bool _horizontalDragActive = false;
  Offset? _pendingSeekPosition;
  int _gestureGeneration = 0;
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.autoPlayPreview) unawaited(_startPreview());
    });
  }

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
    final itemChanged = oldWidget.item.id != widget.item.id;
    if (itemChanged || oldWidget.playerFactory != widget.playerFactory) {
      unawaited(_stopPreview());
      if (widget.autoPlayPreview) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.autoPlayPreview) unawaited(_startPreview());
        });
      }
      return;
    }
    if (oldWidget.autoPlayPreview != widget.autoPlayPreview) {
      if (widget.autoPlayPreview) {
        unawaited(_startPreview());
      } else {
        unawaited(_stopPreview());
      }
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

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_revealOrAllow()) return;
    _horizontalDragActive = true;
    _pendingSeekPosition = details.localPosition;
    final gestureGeneration = ++_gestureGeneration;
    unawaited(
      _startPreview(autoplay: false, manual: true).then((_) async {
        if (!mounted || gestureGeneration != _gestureGeneration) return;
        final player = _previewPlayer;
        if (player == null) return;
        await _pausePreview();
        final position = _pendingSeekPosition;
        if (position != null) await _seekPreview(position);
        if (!_horizontalDragActive) {
          _pendingSeekPosition = null;
          await _playPreview();
        }
      }),
    );
  }

  Future<void> _startPreview({
    bool autoplay = true,
    bool manual = false,
  }) async {
    if (_previewing) {
      final opening = _previewOpening;
      if (opening != null) {
        try {
          await opening;
        } catch (_) {}
      }
      return;
    }
    if (!manual && !widget.autoPlayPreview) return;
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
    Future<void>? openFuture;
    try {
      openFuture = player.open(
        url,
        headers: widget.urls.directHeaders,
        autoplay: autoplay,
      );
      _previewOpening = openFuture;
      await openFuture;
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
    } finally {
      if (identical(_previewOpening, openFuture)) _previewOpening = null;
    }
  }

  Future<void> _pausePreview() async {
    final player = _previewPlayer;
    if (player == null) return;
    try {
      await player.pause();
    } catch (_) {}
  }

  Future<void> _playPreview() async {
    final player = _previewPlayer;
    if (player == null) return;
    try {
      await player.play();
    } catch (_) {}
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_horizontalDragActive) return;
    _pendingSeekPosition = details.localPosition;
    if (!_previewing || _previewLoading) return;
    unawaited(_seekPreview(details.localPosition));
  }

  Future<void> _seekPreview(Offset localPosition) async {
    final player = _previewPlayer;
    if (player == null) return;
    final target = previewSeekPositionForLocalOffset(
      localPosition: localPosition,
      width: widget.width,
      duration: player.duration.value,
    );
    if (target == null) return;
    try {
      await player.seek(target);
    } catch (_) {}
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _finishHorizontalDrag();
  }

  void _onHorizontalDragCancel() {
    _finishHorizontalDrag();
  }

  void _finishHorizontalDrag() {
    if (!_horizontalDragActive) return;
    _horizontalDragActive = false;
    if (!_previewLoading && _previewOpening == null) {
      _pendingSeekPosition = null;
      unawaited(_playPreview());
    }
  }

  Future<void> _stopPreview({bool rebuild = true}) async {
    _horizontalDragActive = false;
    _pendingSeekPosition = null;
    ++_gestureGeneration;
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
    final colors = appColors(context);
    return SizedBox(
      width: widget.width,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrivacyMask(
                    movieId: widget.item.id,
                    radius: 0,
                    child: previewReady
                        ? previewPlayer.buildVideo()
                        : _CoverImage(
                            url: imageUrl,
                            headers: widget.urls.imageHeaders,
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ProgressBar(
                      value: _itemProgress(widget.item),
                      color: colors.accent,
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onTap,
                      onHorizontalDragStart: _onHorizontalDragStart,
                      onHorizontalDragUpdate: _onHorizontalDragUpdate,
                      onHorizontalDragEnd: _onHorizontalDragEnd,
                      onHorizontalDragCancel: _onHorizontalDragCancel,
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: StashSceneInfo(item: widget.item, landscape: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stash 专用竖版卡片：首页和详情页相似内容使用。
///
/// 只有这里使用右对齐裁剪；其它媒体源仍由各自卡片保持默认居中。
class StashScenePortraitCard extends StatelessWidget {
  const StashScenePortraitCard({
    super.key,
    required this.item,
    required this.urls,
    required this.width,
    required this.onTap,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.primaryImageTag?.trim().isNotEmpty == true
        ? urls.poster(item.id, tag: item.primaryImageTag)
        : urls.heroImage(item);
    final progress = _itemProgress(item);
    return SizedBox(
      width: width,
      child: PrivacyAwareInkWell(
        movieId: item.id,
        onTap: onTap,
        borderRadius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                PrivacyMask(
                  movieId: item.id,
                  radius: 10,
                  child: Poster(
                    url: imageUrl,
                    title: item.name,
                    year: item.productionYear,
                    aspectRatio: 2 / 3,
                    radius: 10,
                    imageAlignment: Alignment.centerRight,
                    httpHeaders: urls.imageHeaders,
                  ),
                ),
                if (progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        valueColor: AlwaysStoppedAnimation(
                          appColors(context).accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            StashSceneInfo(
              item: item,
              landscape: false,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stash 影片的紧凑信息区：首页、搜索、媒体库和详情页共用。
///
/// 横版为「番号 + 名称一行 / 标签 / 演员 / 年份 · 时长」，
/// 竖版为「番号 + 名称两行 / 年份 · 时长」。
class StashSceneInfo extends StatelessWidget {
  const StashSceneInfo({
    super.key,
    required this.item,
    this.landscape = true,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  final MediaBrowserItem item;
  final bool landscape;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final code = item.code?.trim();
    final tags = (item.tags.isNotEmpty ? item.tags : item.genres)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final performers = item.people
        .map((person) => person.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final name = item.name.trim();
    final displayTitle = [
      if (code?.isNotEmpty == true) '[${code!}]',
      if (name.isNotEmpty && name != code) name,
    ].join(' ');
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrivacyText(
            movieId: item.id,
            text: displayTitle,
            maxLines: landscape ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle(context).copyWith(
              color: colors.text,
              fontSize: landscape ? 15 : 14,
              height: 1.2,
            ),
          ),
          if (landscape && tags.isNotEmpty) ...[
            const SizedBox(height: 7),
            _StashCompactIconLine(
              icon: Icons.local_offer_outlined,
              child: PrivacyText(
                movieId: item.id,
                text: tags.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta(context).copyWith(color: colors.text2),
              ),
            ),
          ],
          if (landscape && performers.isNotEmpty) ...[
            const SizedBox(height: 4),
            _StashCompactIconLine(
              icon: Icons.people_alt_outlined,
              child: _StashPerformerRow(names: performers, privacyId: item.id),
            ),
          ],
          if (_stashMetaText(context, item) != null) ...[
            const SizedBox(height: 8),
            _StashInfoWrap(item: item),
          ],
        ],
      ),
    );
  }
}

class _StashInfoWrap extends StatelessWidget {
  const _StashInfoWrap({required this.item});

  final MediaBrowserItem item;

  @override
  Widget build(BuildContext context) {
    final text = _stashMetaText(context, item);
    if (text == null) return const SizedBox.shrink();
    final colors = appColors(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.meta(context).copyWith(color: colors.muted),
    );
  }
}

String? _stashMetaText(BuildContext context, MediaBrowserItem item) {
  final l = AppL10n.of(context);
  final value = formatMediaCardMeta(
    l,
    year: item.productionYear,
    duration: item.runtimeMinutes,
  );
  return value.isEmpty ? null : value;
}

class _StashCompactIconLine extends StatelessWidget {
  const _StashCompactIconLine({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Icon(icon, size: 14, color: colors.muted),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StashPerformerRow extends StatelessWidget {
  const _StashPerformerRow({required this.names, required this.privacyId});

  final List<String> names;
  final String privacyId;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final style = AppText.meta(context).copyWith(color: colors.text2);
    return PrivacyText(
      movieId: privacyId,
      text: names.join('、'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
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
      alignment: Alignment.center,
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
