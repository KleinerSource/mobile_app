import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:omm/features/cache/image_cache_manager.dart';

import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

/// omm 海报组件 · 真图优先, 失败回退到极简占位符 (深色块 + 图标 + 番号/标题)。
class Poster extends StatelessWidget {
  const Poster({
    super.key,
    this.url,
    this.urls,
    required this.title,
    this.year,
    this.aspectRatio = 2 / 3,
    this.radius = 10,
    this.restricted = false,
    this.imageAlignment = Alignment.center,
    this.imageFit = BoxFit.cover,
    this.backgroundColor,
    this.httpHeaders,
  });

  final String? url;

  /// 多图模式按顺序并排显示，最多取三张。
  final List<String>? urls;
  final String title;
  final int? year;
  final double aspectRatio;
  final double radius;
  final bool restricted;
  final Alignment imageAlignment;
  final BoxFit imageFit;
  final Color? backgroundColor;
  final Map<String, String>? httpHeaders;

  @override
  Widget build(BuildContext context) {
    if (restricted) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            color: const Color(0xFF0A0807),
            alignment: Alignment.center,
            child: Text(
              'R18',
              style: AppText.mono(
                context,
                size: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ).copyWith(letterSpacing: 4.2),
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PlaceholderBase(color: backgroundColor),
            if (_imageUrls.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _imageUrls.length; i++) ...[
                    if (i > 0)
                      const SizedBox(
                        width: 2,
                        child: ColoredBox(color: Colors.black54),
                      ),
                    Expanded(child: _networkImage(context, _imageUrls[i])),
                  ],
                ],
              )
            else if (url != null && url!.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final logicalWidth = constraints.maxWidth;
                  final physicalWidth =
                      logicalWidth.isFinite && logicalWidth > 0
                      ? (logicalWidth * MediaQuery.devicePixelRatioOf(context))
                            .round()
                      : null;
                  return _RetryNetworkPoster(
                    imageUrl: url!,
                    title: title,
                    year: year,
                    httpHeaders: httpHeaders,
                    alignment: imageAlignment,
                    fit: imageFit,
                    memCacheWidth: physicalWidth,
                  );
                },
              )
            else
              _PlaceholderLabel(title: title, year: year),
          ],
        ),
      ),
    );
  }

  List<String> get _imageUrls => [
    ...(urls ?? const <String>[]),
  ].where((value) => value.trim().isNotEmpty).take(3).toList(growable: false);

  Widget _networkImage(BuildContext context, String imageUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth = constraints.maxWidth;
        final physicalWidth = logicalWidth.isFinite && logicalWidth > 0
            ? (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round()
            : null;
        return _RetryNetworkPoster(
          imageUrl: imageUrl,
          title: title,
          year: year,
          httpHeaders: httpHeaders,
          fit: imageFit,
          memCacheWidth: physicalWidth,
        );
      },
    );
  }
}

const _posterDiskCacheWidth = 1080;

/// 带自动重试的封面图 · 瞬时失败（网络抖动、扫描期间图片文件暂时缺失
/// 返回 404 等）时按次数换 key 重新加载；重试耗尽才落到最终占位符。
///
/// 没有这层重试时 CachedNetworkImage 的 errorWidget 是终态，一次抖动
/// 就让封面一直空到卡片滚出屏幕重建为止。
class _RetryNetworkPoster extends StatefulWidget {
  const _RetryNetworkPoster({
    required this.imageUrl,
    required this.title,
    required this.year,
    this.httpHeaders,
    this.alignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
  });

  final String imageUrl;
  final String title;
  final int? year;
  final Map<String, String>? httpHeaders;
  final Alignment alignment;
  final BoxFit fit;
  final int? memCacheWidth;

  @override
  State<_RetryNetworkPoster> createState() => _RetryNetworkPosterState();
}

class _RetryNetworkPosterState extends State<_RetryNetworkPoster> {
  static const maxRetries = 2;
  static const retryDelay = Duration(milliseconds: 500);

  int _attempt = 0;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant _RetryNetworkPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换图（如缓存版本号变化）时重置重试进度。
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  /// 与 [CachedNetworkImage] 内部构造的 provider 键一致，用于重试前驱逐。
  ImageProvider<Object> get _imageProvider => ResizeImage.resizeIfNeeded(
    widget.memCacheWidth,
    null,
    CachedNetworkImageProvider(
      widget.imageUrl,
      cacheManager: AppImageCacheManager.instance,
      maxWidth: _posterDiskCacheWidth,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      cacheManager: AppImageCacheManager.instance,
      key: ValueKey('$_attempt:${widget.imageUrl}'),
      imageUrl: widget.imageUrl,
      httpHeaders: widget.httpHeaders,
      fit: widget.fit,
      alignment: widget.alignment,
      memCacheWidth: widget.memCacheWidth,
      maxWidthDiskCache: _posterDiskCacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) {
        final timer = _retryTimer;
        if (_attempt < maxRetries && timer == null) {
          _retryTimer = Timer(retryDelay, () {
            if (!mounted) return;
            // 带 memCacheWidth 时 ImageCache 的键是 ResizeImageKey，
            // CachedNetworkImage 出错只驱逐内层 provider；不在这里驱逐，
            // 重试会直接拿到同一个已失败的 completer。
            unawaited(_imageProvider.evict());
            setState(() {
              _attempt++;
              _retryTimer = null;
            });
          });
          // 重试等待期间保持灰底，不闪占位符文案。
          return const SizedBox.shrink();
        }
        if (timer != null) return const SizedBox.shrink();
        return _PlaceholderLabel(title: widget.title, year: widget.year);
      },
    );
  }
}

/// 占位符底色 · 一个素净的深灰色块, 跟 app 主题协调
class _PlaceholderBase extends StatelessWidget {
  const _PlaceholderBase({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            color ?? (dark ? const Color(0xFF1B1D24) : const Color(0xFFE8EAEF)),
      ),
    );
  }
}

class _PlaceholderLabel extends StatelessWidget {
  const _PlaceholderLabel({required this.title, this.year});
  final String title;
  final int? year;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.32);
    final fgStrong = dark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = (constraints.maxWidth * 0.32).clamp(28.0, 80.0);
        final contentWidth = constraints.maxWidth > 24
            ? constraints.maxWidth - 24
            : constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.movie_outlined, size: iconSize, color: fg),
                    const SizedBox(height: 10),
                    Text(
                      title.trim().isEmpty ? '—' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fgStrong,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    if (year != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$year',
                        style: TextStyle(
                          color: fg,
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 评分角标 · 黑色玻璃 + 黄星 + 数字。
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(8, 8),
            painter: _StarPainter(color: const Color(0xFFFFD600)),
          ),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 在线播放徽章 · 影片卡片与详情页共用。
class OnlinePlayBadge extends StatelessWidget {
  const OnlinePlayBadge({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final color = appColors(context).accent;
    return Semantics(
      container: true,
      label: l.posterOnlinePlay,
      child: Tooltip(
        message: l.posterOnlinePlay,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: iconOnly ? 18 : null,
            height: iconOnly ? 18 : null,
            alignment: Alignment.center,
            padding: iconOnly
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 12,
                  color: Colors.white,
                ),
                if (!iconOnly) ...[
                  const SizedBox(width: 2),
                  Text(
                    l.posterOnlinePlay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path();
    final points = [
      Offset(size.width / 2, size.height * 0.04),
      Offset(size.width * 0.62, size.height * 0.36),
      Offset(size.width * 0.96, size.height * 0.37),
      Offset(size.width * 0.69, size.height * 0.59),
      Offset(size.width * 0.79, size.height * 0.93),
      Offset(size.width / 2, size.height * 0.73),
      Offset(size.width * 0.21, size.height * 0.93),
      Offset(size.width * 0.31, size.height * 0.59),
      Offset(size.width * 0.04, size.height * 0.37),
      Offset(size.width * 0.38, size.height * 0.36),
    ];
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
}
