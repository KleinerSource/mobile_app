import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// omm 海报组件 · 真图优先, 失败回退到极简占位符 (深色块 + 图标 + 番号/标题)。
class Poster extends StatelessWidget {
  const Poster({
    super.key,
    this.url,
    required this.title,
    this.year,
    this.aspectRatio = 2 / 3,
    this.radius = 10,
    this.restricted = false,
    this.imageAlignment = Alignment.center,
  });

  final String? url;
  final String title;
  final int? year;
  final double aspectRatio;
  final double radius;
  final bool restricted;
  final Alignment imageAlignment;

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
            const _PlaceholderBase(),
            if (url != null && url!.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final logicalWidth = constraints.maxWidth;
                  final physicalWidth =
                      logicalWidth.isFinite && logicalWidth > 0
                      ? (logicalWidth * MediaQuery.devicePixelRatioOf(context))
                            .round()
                      : null;
                  return CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    alignment: imageAlignment,
                    memCacheWidth: physicalWidth,
                    maxWidthDiskCache: 1080,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) =>
                        _PlaceholderLabel(title: title, year: year),
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
}

/// 占位符底色 · 一个素净的深灰色块, 跟 app 主题协调
class _PlaceholderBase extends StatelessWidget {
  const _PlaceholderBase();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B1D24) : const Color(0xFFE8EAEF),
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
    final color = appColors(context).accent;
    return Semantics(
      container: true,
      label: '在线播放',
      child: Tooltip(
        message: '在线播放',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 5 : 7,
              vertical: 4,
            ),
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
                  const Text(
                    '在线播放',
                    style: TextStyle(
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
