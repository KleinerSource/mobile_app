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
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/poster.dart';

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
  if (items.isEmpty ||
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
  for (var index = 0; index < items.length; index++) {
    final card = itemKeys[items[index].id]?.currentContext?.findRenderObject();
    if (card is! RenderBox || !card.hasSize) continue;
    final cardTop = card.localToGlobal(Offset.zero).dy;
    final hidden = (viewportTop - cardTop).clamp(0.0, coverHeight);
    if (hidden <= coverHeight * switchOutFraction) return index;
  }
  return null;
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
    this.autoPlayPreview = false,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final VoidCallback onTap;
  final StashPreviewCoordinator? coordinator;
  final StashPreviewPlayerFactory playerFactory;

  /// 页面滚动选中该条目时自动播放短预览；手动长按仍可在 false 时启动。
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
  bool _previewing = false;
  bool _previewLoading = false;
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
    final colors = appColors(context);
    return SizedBox(
      width: widget.width,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.72),
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
                      value: previewReady
                          ? _ratio(
                              previewPlayer.position.value,
                              previewPlayer.duration.value,
                            )
                          : _itemProgress(widget.item),
                      color: colors.accent,
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
/// 横版为「番号 + 名称一行 / 本地化类型 badge + 演员 / 年份 · 时长」，
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
    final l = AppL10n.of(context);
    final code = item.code?.trim();
    final type = _stashTypeLabel(context, item.type);
    final performers = item.people
        .map((person) => person.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final name = item.name.trim().isEmpty ? (code ?? '') : item.name;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final codeWidth = (constraints.maxWidth * 0.42)
                  .clamp(80.0, 136.0)
                  .toDouble();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (code?.isNotEmpty == true) ...[
                    _StashNumberBadge(
                      text: '${l.movieEditorNumber} $code',
                      privacyId: item.id,
                      maxWidth: codeWidth,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: PrivacyText(
                      movieId: item.id,
                      text: name,
                      maxLines: landscape ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle(context).copyWith(
                        color: colors.text,
                        fontSize: landscape ? 15 : 14,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (landscape && (type != null || performers.isNotEmpty)) ...[
            const SizedBox(height: 7),
            _StashCompactIconLine(
              icon: performers.isNotEmpty
                  ? Icons.people_alt_outlined
                  : Icons.local_offer_outlined,
              child: Row(
                children: [
                  if (type != null)
                    _StashTypeBadge(text: type, privacyId: item.id),
                  if (type != null && performers.isNotEmpty)
                    const SizedBox(width: 6),
                  if (performers.isNotEmpty)
                    Expanded(
                      child: _StashPerformerRow(
                        names: performers,
                        privacyId: item.id,
                      ),
                    ),
                ],
              ),
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

String? _stashTypeLabel(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase();
  final l = AppL10n.of(context);
  return switch (normalized) {
    'movie' => l.mediaBrowserTypeMovies,
    'series' => l.mediaBrowserTypeTvShows,
    'musicalbum' => l.mediaBrowserTypeAlbums,
    'audio' => l.mediaBrowserTypeSongs,
    _ when normalized.isEmpty => null,
    _ => value.trim(),
  };
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
  final values = <String>[
    if (item.productionYear != null) '${item.productionYear}',
    if (item.runtimeMinutes > 0) l.mediaDurationMinutes(item.runtimeMinutes),
  ];
  return values.isEmpty ? null : values.join(' · ');
}

class _StashNumberBadge extends StatelessWidget {
  const _StashNumberBadge({
    required this.text,
    required this.privacyId,
    required this.maxWidth,
  });

  final String text;
  final String privacyId;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: PrivacyText(
            movieId: privacyId,
            text: text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.meta(
              context,
            ).copyWith(color: colors.text2, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
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

class _StashTypeBadge extends StatelessWidget {
  const _StashTypeBadge({required this.text, required this.privacyId});

  final String text;
  final String privacyId;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          border: Border.all(color: colors.cardBorder),
          borderRadius: BorderRadius.circular(7),
        ),
        child: PrivacyText(
          movieId: privacyId,
          text: text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.meta(context).copyWith(
            color: colors.text2,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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

double _ratio(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
}
