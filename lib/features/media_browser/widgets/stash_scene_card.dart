import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/api/media_browser_server_urls.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/media_metadata_widgets.dart';
import 'package:omm/shared/landscape_media_card.dart';
import 'package:omm/shared/preview/preview_player.dart';
import 'package:omm/shared/preview/preview_scrub_controller.dart';
import 'package:omm/shared/preview/preview_seek.dart';
import 'package:omm/shared/preview/preview_surface.dart';

/// Stash Scene 横向卡片：全宽 16:9 封面，横向拖动可调整预览视频时间轴。
class StashSceneCard extends ConsumerStatefulWidget {
  const StashSceneCard({
    super.key,
    required this.item,
    required this.urls,
    required this.width,
    required this.onTap,
    this.coordinator,
    this.playerFactory = _defaultPreviewPlayerFactory,
    this.autoPlayPreview = false,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final VoidCallback onTap;
  final PreviewCoordinator? coordinator;
  final PreviewPlayerFactory playerFactory;

  /// 页面滚动选中该条目时自动播放短预览；横向拖动也可手动启动预览。
  final bool autoPlayPreview;

  @override
  ConsumerState<StashSceneCard> createState() => _StashSceneCardState();
}

PreviewPlayer _defaultPreviewPlayerFactory() => MediaKitPreviewPlayer();

class _StashSceneCardState extends ConsumerState<StashSceneCard> {
  late final VoidCallback _releaseForCoordinator = _releasePreview;
  PreviewCoordinator? _coordinator;
  PreviewPlayer? _previewPlayer;
  Future<void>? _previewOpening;
  bool _previewing = false;
  bool _previewLoading = false;
  int _previewGeneration = 0;
  late final PreviewScrubController _scrubController = PreviewScrubController(
    ensurePreview: () => _startPreview(autoplay: false, manual: true),
    isReady: _isPreviewReady,
    pause: _pausePreview,
    play: _playPreview,
    seek: _seekPreview,
  );

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
    _coordinator ??= widget.coordinator ?? PreviewScope.maybeOf(context);
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
    _scrubController.dispose();
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
    _scrubController.start(details.localPosition);
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
    _scrubController.update(details.localPosition);
  }

  bool _isPreviewReady() =>
      _previewPlayer != null &&
      _previewing &&
      !_previewLoading &&
      _previewOpening == null;

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
    _scrubController.end();
  }

  void _onHorizontalDragCancel() {
    _scrubController.cancel();
  }

  Future<void> _stopPreview({bool rebuild = true}) async {
    _scrubController.reset();
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
    final l = AppL10n.of(context);
    final hasPreviewVideo =
        widget.urls.preview(widget.item.previewPath)?.trim().isNotEmpty == true;
    return LandscapeMediaCard(
      width: widget.width,
      cover: PrivacyMask(
        movieId: widget.item.id,
        radius: 0,
        child: previewReady
            ? previewPlayer.buildVideo()
            : _CoverImage(url: imageUrl, headers: widget.urls.imageHeaders),
      ),
      coverOverlay: PreviewGestureSurface(
        onTap: _onTap,
        loading: _previewLoading,
        showHint: previewReady,
        showAvailabilityBadge: hasPreviewVideo && !_previewing,
        availabilityLabel: l.previewVideoAsset,
        bottomOverlay: _ProgressBar(
          value: _itemProgress(widget.item),
          color: colors.accent,
        ),
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onHorizontalDragCancel: _onHorizontalDragCancel,
        child: const SizedBox.expand(),
      ),
      info: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: StashSceneInfo(item: widget.item, landscape: true),
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
