import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/player/video/video_player_page.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/features/player/video/video_player_session_factory.dart';

class MovieExtraFanartSection extends ConsumerStatefulWidget {
  const MovieExtraFanartSection({
    super.key,
    required this.movieId,
    required this.movieTitle,
    required this.canFetch,
    required this.trailerUrl,
    required this.posterUrl,
  });

  final int movieId;
  final String movieTitle;
  final bool canFetch;
  final String? trailerUrl;
  final String? posterUrl;

  @override
  ConsumerState<MovieExtraFanartSection> createState() =>
      _MovieExtraFanartSectionState();
}

class _MovieExtraFanartSectionState
    extends ConsumerState<MovieExtraFanartSection> {
  final ScrollController _previewController = ScrollController();
  bool _fetching = false;

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  double _cardWidth(BuildContext context) {
    return (MediaQuery.sizeOf(context).width * 0.72)
        .clamp(220.0, 300.0)
        .toDouble();
  }

  void _syncPreviewScroll(BuildContext context, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_previewController.hasClients) return;
      final cardWidth = _cardWidth(context);
      final viewport = _previewController.position.viewportDimension;
      final target = index * (cardWidth + 10) - (viewport - cardWidth) / 2;
      final position = target
          .clamp(0.0, _previewController.position.maxScrollExtent)
          .toDouble();
      unawaited(
        _previewController.animateTo(
          position,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Future<void> _fetchExtraFanarts() async {
    if (_fetching || !widget.canFetch) return;
    setState(() => _fetching = true);
    try {
      await ref
          .read(mediaRepositoryProvider)
          .downloadExtraFanarts(widget.movieId);
      if (!mounted) return;
      ref.invalidate(extraFanartsProvider(widget.movieId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('预览图获取完成')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取预览图失败: ${toApiException(error).message}')),
      );
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Widget _header(BuildContext context, {required bool hasImages}) {
    return Row(
      children: [
        Expanded(child: Text('预览图', style: AppText.sectionTitle(context))),
        if (widget.canFetch)
          TextButton.icon(
            onPressed: _fetching ? null : _fetchExtraFanarts,
            icon: _fetching
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 17),
            label: Text(hasImages ? '重新获取' : '获取'),
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, String message, IconData icon) {
    final c = appColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.body(context))),
        ],
      ),
    );
  }

  Widget _trailerOnlyPreview(BuildContext context) {
    final cardWidth = _cardWidth(context);
    final cardHeight = cardWidth * 9 / 16;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, hasImages: true),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight,
            child: SizedBox(
              width: cardWidth,
              child: _TrailerThumbnail(
                posterUrl: widget.posterUrl,
                onTap: () => _playTrailer(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(extraFanartsProvider(widget.movieId));
    return async.when(
      loading: () => widget.trailerUrl != null
          ? _trailerOnlyPreview(context)
          : Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, hasImages: false),
                  const SizedBox(height: 12),
                  _emptyState(
                    context,
                    '正在加载预览图',
                    Icons.hourglass_empty_rounded,
                  ),
                ],
              ),
            ),
      error: (error, _) => widget.trailerUrl != null
          ? _trailerOnlyPreview(context)
          : Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, hasImages: false),
                  const SizedBox(height: 12),
                  _emptyState(
                    context,
                    '预览图加载失败: ${toApiException(error).message}',
                    Icons.broken_image_outlined,
                  ),
                ],
              ),
            ),
      data: (urls) {
        final hasTrailer = widget.trailerUrl != null;
        if (!hasTrailer && urls.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, hasImages: false),
                const SizedBox(height: 12),
                _emptyState(context, '暂无预览图', Icons.photo_library_outlined),
              ],
            ),
          );
        }

        final cardWidth = _cardWidth(context);
        final cardHeight = cardWidth * 9 / 16;
        final itemCount = urls.length + (hasTrailer ? 1 : 0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, hasImages: true),
              const SizedBox(height: 12),
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  controller: _previewController,
                  scrollDirection: Axis.horizontal,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (hasTrailer && index == 0) {
                      return SizedBox(
                        width: cardWidth,
                        child: _TrailerThumbnail(
                          posterUrl: widget.posterUrl,
                          onTap: () => _playTrailer(context),
                        ),
                      );
                    }

                    final imageIndex = index - (hasTrailer ? 1 : 0);
                    final url = urls[imageIndex];
                    return SizedBox(
                      width: cardWidth,
                      child: Material(
                        color: appColors(context).surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            unawaited(_openViewer(context, urls, index));
                          },
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: appColors(context).muted,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openViewer(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    _syncPreviewScroll(context, initialIndex);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭预览图',
      // 背景由灯箱自身绘制，才能在下滑时和内容一起实时淡出。
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => _ExtraFanartViewer(
        urls: urls,
        trailerUrl: widget.trailerUrl,
        posterUrl: widget.posterUrl,
        initialIndex: initialIndex,
        onPageChanged: (index) => _syncPreviewScroll(context, index),
      ),
    );
  }

  void _playTrailer(BuildContext context) {
    final url = widget.trailerUrl;
    if (url == null) return;
    unawaited(
      VideoPlayerPage.open(
        context,
        movieId: widget.movieId,
        title: '${widget.movieTitle} · 预告片',
        directUrl: url,
        engineKind: PlaybackEngineKind.libmpv,
      ),
    );
  }
}

class _TrailerThumbnail extends StatelessWidget {
  const _TrailerThumbnail({required this.posterUrl, required this.onTap});

  final String? posterUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final imageUrl = posterUrl?.trim() ?? '';
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _trailerPlaceholder(context),
              )
            else
              _trailerPlaceholder(context),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.play_arrow_rounded, size: 24),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Text(
                l.detailTrailer,
                style: AppText.body(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _trailerPlaceholder(BuildContext context) {
  final c = appColors(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.surfaceAlt, c.surface],
      ),
    ),
  );
}

/// 让文件来源也复用 OMM 详情页已有的图片灯箱实现。
///
/// [loadBytes] 按页面懒加载，图片查看器本身的布局和手势仍完全由 OMM
/// 灯箱统一处理。
Future<void> showImageLightbox(
  BuildContext context, {
  required int itemCount,
  required Future<Uint8List> Function(int index) loadBytes,
  int initialIndex = 0,
  bool useRootNavigator = true,
}) {
  if (itemCount <= 0) return Future<void>.value();
  final safeIndex = initialIndex.clamp(0, itemCount - 1).toInt();
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: true,
    barrierLabel: '关闭预览图',
    barrierColor: Colors.transparent,
    pageBuilder: (_, __, ___) => _ExtraFanartViewer(
      urls: const <String>[],
      imageCount: itemCount,
      loadBytes: loadBytes,
      trailerUrl: null,
      posterUrl: null,
      initialIndex: safeIndex,
      onPageChanged: (_) {},
    ),
  );
}

/// OMM URL 图片灯箱入口，继续使用同一套灯箱和手势逻辑。
Future<void> showMovieImageLightbox(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  final validUrls = urls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
  if (validUrls.isEmpty) return Future<void>.value();
  final safeIndex = initialIndex.clamp(0, validUrls.length - 1).toInt();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭预览图',
    barrierColor: Colors.transparent,
    pageBuilder: (_, __, ___) => _ExtraFanartViewer(
      urls: validUrls,
      trailerUrl: null,
      posterUrl: null,
      initialIndex: safeIndex,
      onPageChanged: (_) {},
    ),
  );
}

class _ExtraFanartViewer extends StatefulWidget {
  const _ExtraFanartViewer({
    required this.urls,
    this.imageCount,
    this.loadBytes,
    required this.trailerUrl,
    required this.posterUrl,
    required this.initialIndex,
    required this.onPageChanged,
  });

  final List<String> urls;
  final int? imageCount;
  final Future<Uint8List> Function(int index)? loadBytes;
  final String? trailerUrl;
  final String? posterUrl;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;

  @override
  State<_ExtraFanartViewer> createState() => _ExtraFanartViewerState();
}

enum _LightboxGestureMode { undecided, horizontal, vertical, imagePan, pinch }

class _ExtraFanartViewerState extends State<_ExtraFanartViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  late final AnimationController _zoomAnimationController;
  final Map<int, TransformationController> _imageControllers =
      <int, TransformationController>{};
  final Map<int, Future<Uint8List>> _imageBytes = <int, Future<Uint8List>>{};
  final Set<int> _zoomedIndexes = <int>{};
  late int _index;
  double _verticalDragOffset = 0;
  Offset? _doubleTapPosition;
  bool _isDragging = false;
  bool _isTwoFingerGesture = false;
  bool _isClosing = false;
  _LightboxGestureMode _gestureMode = _LightboxGestureMode.undecided;
  Offset _gestureStartFocalPoint = Offset.zero;
  double _lastScaleFactor = 1;
  Animation<Matrix4>? _zoomAnimation;
  TransformationController? _zoomAnimationTarget;

  static const _dragAnimationDuration = Duration(milliseconds: 220);
  static const _zoomAnimationDuration = Duration(milliseconds: 260);

  bool get _hasTrailer => widget.trailerUrl != null;

  int get _imageCount => widget.imageCount ?? widget.urls.length;

  int get _itemCount => _imageCount + (_hasTrailer ? 1 : 0);

  bool _isTrailerIndex(int index) => _hasTrailer && index == 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: _zoomAnimationDuration,
    )..addListener(_onZoomAnimationTick);
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _controller.dispose();
    for (final controller in _imageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _imageControllerFor(int index) {
    return _imageControllers.putIfAbsent(index, () {
      final controller = TransformationController();
      controller.addListener(() => _onImageTransformChanged(index, controller));
      return controller;
    });
  }

  Future<Uint8List> _bytesFor(int index) {
    return _imageBytes.putIfAbsent(index, () => widget.loadBytes!(index));
  }

  void _onImageTransformChanged(
    int index,
    TransformationController controller,
  ) {
    final scale = controller.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.01;
    final wasZoomed = _zoomedIndexes.contains(index);

    // 缩回完整显示时清掉残留平移，确保下滑退出从稳定的初始位置开始。
    if (!isZoomed) {
      final translation = controller.value.getTranslation();
      if (translation.x.abs() > 0.5 || translation.y.abs() > 0.5) {
        controller.value = Matrix4.identity();
      }
    }

    if (isZoomed == wasZoomed) return;
    if (isZoomed) {
      _zoomedIndexes.add(index);
    } else {
      _zoomedIndexes.remove(index);
    }
    if (mounted && index == _index) setState(() {});
  }

  bool _isZoomed(int index) => _zoomedIndexes.contains(index);

  void _onZoomAnimationTick() {
    final animation = _zoomAnimation;
    final target = _zoomAnimationTarget;
    if (animation == null || target == null) return;
    target.value = animation.value;
  }

  void _stopZoomAnimation() {
    _zoomAnimationController.stop();
    _zoomAnimation = null;
    _zoomAnimationTarget = null;
  }

  void _animateImageTransform(
    TransformationController controller,
    Matrix4 target,
  ) {
    _stopZoomAnimation();
    _zoomAnimationController.reset();
    _zoomAnimationTarget = controller;
    _zoomAnimation = Matrix4Tween(begin: controller.value.clone(), end: target)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_zoomAnimationController);
    _zoomAnimationController.forward();
  }

  void _resetImageTransform(int index) {
    final controller = _imageControllers[index];
    if (controller == null) return;
    controller.value = Matrix4.identity();
    _zoomedIndexes.remove(index);
  }

  void _onGestureStart(ScaleStartDetails details) {
    if (_isClosing) return;
    _stopZoomAnimation();
    _gestureStartFocalPoint = details.localFocalPoint;
    _lastScaleFactor = 1;
    _gestureMode = _isZoomed(_index)
        ? _LightboxGestureMode.imagePan
        : _LightboxGestureMode.undecided;
    if (details.pointerCount >= 2) {
      _isTwoFingerGesture = true;
      _gestureMode = _LightboxGestureMode.pinch;
      if (mounted) {
        setState(() {
          _isDragging = false;
          _verticalDragOffset = 0;
        });
      }
    }
  }

  void _onGestureUpdate(ScaleUpdateDetails details) {
    if (_isClosing) return;
    if (details.pointerCount >= 2) {
      _isTwoFingerGesture = true;
      if (_gestureMode != _LightboxGestureMode.pinch) {
        _gestureMode = _LightboxGestureMode.pinch;
        _lastScaleFactor = details.scale;
        return;
      }
      final controller = _imageControllerFor(_index);
      final scaleChange = details.scale / _lastScaleFactor;
      _scaleImageAround(controller, scaleChange, details.localFocalPoint);
      _translateImage(controller, details.focalPointDelta);
      _lastScaleFactor = details.scale;
      return;
    }

    if (_gestureMode == _LightboxGestureMode.pinch) {
      // 双指结束后若仍保持放大，允许剩余的一根手指继续平移图片；
      // 未放大时不把收尾动作误判成翻页或下滑关闭。
      if (_isZoomed(_index)) {
        _gestureMode = _LightboxGestureMode.imagePan;
      } else {
        return;
      }
    }

    final delta = details.focalPointDelta;
    if (_gestureMode == _LightboxGestureMode.imagePan) {
      _translateImage(_imageControllerFor(_index), delta);
      return;
    }

    if (_gestureMode == _LightboxGestureMode.undecided) {
      final total = details.localFocalPoint - _gestureStartFocalPoint;
      if (total.distance < 10) return;
      _gestureMode = total.dx.abs() >= total.dy.abs()
          ? _LightboxGestureMode.horizontal
          : _LightboxGestureMode.vertical;
      if (_gestureMode == _LightboxGestureMode.vertical) {
        _startVerticalGesture();
      }
    }

    switch (_gestureMode) {
      case _LightboxGestureMode.horizontal:
        _updateHorizontalPage(delta.dx);
      case _LightboxGestureMode.vertical:
        _updateVerticalGesture(delta.dy);
      case _LightboxGestureMode.undecided:
      case _LightboxGestureMode.imagePan:
      case _LightboxGestureMode.pinch:
        break;
    }
  }

  void _onGestureEnd(ScaleEndDetails details) {
    if (_isClosing) return;
    final mode = _gestureMode;
    _gestureMode = _LightboxGestureMode.undecided;
    _isTwoFingerGesture = false;
    switch (mode) {
      case _LightboxGestureMode.horizontal:
        _finishHorizontalPage(details.velocity.pixelsPerSecond.dx);
      case _LightboxGestureMode.vertical:
        _finishVerticalDismiss(details.velocity.pixelsPerSecond.dy);
      case _LightboxGestureMode.undecided:
      case _LightboxGestureMode.imagePan:
      case _LightboxGestureMode.pinch:
        break;
    }
  }

  void _scaleImageAround(
    TransformationController controller,
    double scaleChange,
    Offset focalPoint,
  ) {
    final currentScale = controller.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * scaleChange).clamp(1.0, 6.0).toDouble();
    final effectiveScale = targetScale / currentScale;
    if ((effectiveScale - 1).abs() < 0.0001) return;
    final next = controller.value.clone()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(effectiveScale, effectiveScale, effectiveScale, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
    controller.value = next;
  }

  void _translateImage(TransformationController controller, Offset delta) {
    if (delta == Offset.zero) return;
    final next = controller.value.clone();
    final translation = next.getTranslation();
    next.setTranslationRaw(
      translation.x + delta.dx,
      translation.y + delta.dy,
      translation.z,
    );
    controller.value = next;
  }

  void _toggleDoubleTapZoom(int index) {
    if (_isClosing || _isTwoFingerGesture || _isTrailerIndex(index)) return;
    final controller = _imageControllerFor(index);
    final isZoomed =
        _isZoomed(index) || controller.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomed) {
      _animateImageTransform(controller, Matrix4.identity());
      _doubleTapPosition = null;
      return;
    }

    const targetScale = 2.0;
    final focalPoint = _doubleTapPosition;
    final transform = Matrix4.identity();
    if (focalPoint != null) {
      transform.translateByDouble(
        focalPoint.dx * (1 - targetScale),
        focalPoint.dy * (1 - targetScale),
        0,
        1,
      );
    }
    transform.scaleByDouble(targetScale, targetScale, targetScale, 1);
    _animateImageTransform(controller, transform);
    _doubleTapPosition = null;
  }

  void _close() {
    if (mounted && !_isTwoFingerGesture) Navigator.of(context).pop();
  }

  void _startVerticalGesture() {
    setState(() {
      _isDragging = true;
      _verticalDragOffset = 0;
    });
  }

  void _updateVerticalGesture(double delta) {
    setState(() {
      // 只允许向下退出，向上拖动时保持在原位，避免灯箱被拖出屏幕顶部。
      _verticalDragOffset = (_verticalDragOffset + delta)
          .clamp(0.0, double.infinity)
          .toDouble();
    });
  }

  void _finishVerticalDismiss(double velocity) {
    final height = MediaQuery.sizeOf(context).height;
    final shouldClose = _verticalDragOffset > height * 0.2 || velocity > 700;

    if (shouldClose) {
      setState(() {
        _isClosing = true;
        _isDragging = false;
        _verticalDragOffset = height;
      });
      unawaited(
        Future<void>.delayed(_dragAnimationDuration, () {
          if (mounted) Navigator.of(context).pop();
        }),
      );
      return;
    }

    setState(() {
      _isDragging = false;
      _verticalDragOffset = 0;
    });
  }

  void _updateHorizontalPage(double delta) {
    if (!_controller.hasClients || delta == 0) return;
    final position = _controller.position;
    final pixels = (position.pixels - delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (pixels != position.pixels) position.jumpTo(pixels);
  }

  void _finishHorizontalPage(double velocity) {
    if (!_controller.hasClients) return;
    final page = _controller.page ?? _index.toDouble();
    final target = velocity.abs() > 500
        ? (velocity < 0 ? page.ceil() : page.floor())
        : page.round();
    final safeTarget = target.clamp(0, _itemCount - 1).toInt();
    unawaited(
      _controller.animateToPage(
        safeTarget,
        duration: _dragAnimationDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final dragProgress = (_verticalDragOffset / height)
        .clamp(0.0, 1.0)
        .toDouble();
    final animationDuration = _isDragging
        ? Duration.zero
        : _dragAnimationDuration;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            color: Colors.black.withValues(
              alpha: (0.94 * (1 - dragProgress)).clamp(0.0, 0.94).toDouble(),
            ),
          ),
          AnimatedOpacity(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            opacity: (1 - dragProgress).clamp(0.0, 1.0).toDouble(),
            child: AnimatedContainer(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _verticalDragOffset, 0),
              child: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _itemCount,
                      onPageChanged: (value) {
                        _resetImageTransform(_index);
                        setState(() => _index = value);
                        widget.onPageChanged(value);
                      },
                      itemBuilder: (context, index) {
                        final isTrailer = _isTrailerIndex(index);
                        final imageController = isTrailer
                            ? null
                            : _imageControllerFor(index);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: isTrailer ? null : _close,
                          onDoubleTapDown: isTrailer
                              ? null
                              : (details) =>
                                    _doubleTapPosition = details.localPosition,
                          onDoubleTap: isTrailer
                              ? null
                              : () => _toggleDoubleTapZoom(index),
                          onScaleStart: _onGestureStart,
                          onScaleUpdate: _onGestureUpdate,
                          onScaleEnd: _onGestureEnd,
                          child: isTrailer
                              ? _TrailerViewer(
                                  url: widget.trailerUrl!,
                                  posterUrl: widget.posterUrl,
                                  active: index == _index,
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final imageIndex =
                                        index - (_hasTrailer ? 1 : 0);
                                    final loadBytes = widget.loadBytes;
                                    final image = loadBytes == null
                                        ? CachedNetworkImage(
                                            imageUrl: widget.urls[imageIndex],
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white54,
                                                  size: 48,
                                                ),
                                          )
                                        : FutureBuilder<Uint8List>(
                                            future: _bytesFor(imageIndex),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasError) {
                                                return const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white54,
                                                  size: 48,
                                                );
                                              }
                                              final bytes = snapshot.data;
                                              if (bytes == null) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }
                                              return Image.memory(
                                                bytes,
                                                fit: BoxFit.contain,
                                              );
                                            },
                                          );
                                    return IgnorePointer(
                                      child: InteractiveViewer(
                                        transformationController:
                                            imageController!,
                                        minScale: 1,
                                        maxScale: 6,
                                        panEnabled: false,
                                        scaleEnabled: false,
                                        constrained: false,
                                        boundaryMargin: const EdgeInsets.all(
                                          100000,
                                        ),
                                        clipBehavior: Clip.none,
                                        child: SizedBox(
                                          width: constraints.maxWidth,
                                          height: constraints.maxHeight,
                                          child: Center(child: image),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        );
                      },
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: '关闭预览图',
                        onPressed: _close,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_itemCount > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                '${_index + 1} / $_itemCount',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailerViewer extends StatefulWidget {
  const _TrailerViewer({
    required this.url,
    required this.posterUrl,
    required this.active,
  });

  final String url;
  final String? posterUrl;
  final bool active;

  @override
  State<_TrailerViewer> createState() => _TrailerViewerState();
}

class _TrailerViewerState extends State<_TrailerViewer> {
  late final PlayerSessionController _player;
  bool _opened = false;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = createVideoPlayerSession(engineKind: PlaybackEngineKind.libmpv);
  }

  @override
  void didUpdateWidget(covariant _TrailerViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active && _opened) {
      unawaited(_player.pause());
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startPlayback() async {
    if (_opening) return;
    if (_opened) {
      await _player.play();
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await _player.open(widget.url, play: true);
      if (mounted) {
        setState(() => _opened = true);
        if (!widget.active) await _player.pause();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '预告片播放失败');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (!_opened) {
      await _startPlayback();
      return;
    }
    await _player.playOrPause();
  }

  Widget _playButton(BuildContext context, {required bool loading}) {
    final l = AppL10n.of(context);
    return Semantics(
      button: true,
      label: loading ? l.detailTrailer : l.detailPlay,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black87,
                  size: 28,
                ),
        ),
      ),
    );
  }

  Widget _initialStage(BuildContext context) {
    final l = AppL10n.of(context);
    final posterUrl = widget.posterUrl?.trim() ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => _trailerBackdrop(context),
            errorWidget: (_, __, ___) => _trailerBackdrop(context),
          )
        else
          _trailerBackdrop(context),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
        Center(child: _playButton(context, loading: _opening)),
        Positioned(
          left: 12,
          bottom: 10,
          child: Text(
            l.detailTrailer,
            style: AppText.body(
              context,
            ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        if (_error != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _trailerBackdrop(BuildContext context) {
    final c = appColors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surfaceAlt, Colors.black],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _startPlayback,
        child: _initialStage(context),
      );
    }

    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: _player,
      builder: (context, state, _) {
        final isPlaying = state.playing;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayback,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _player.buildSurface(),
              if (!isPlaying || _opening)
                Center(child: _playButton(context, loading: _opening)),
            ],
          ),
        );
      },
    );
  }
}
