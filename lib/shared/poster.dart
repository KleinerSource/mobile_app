import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// md_center 海报组件 · 真图优先,失败回退到 hue 渐变标题占位。
class Poster extends StatelessWidget {
  const Poster({
    super.key,
    this.url,
    required this.title,
    this.year,
    this.hue,
    this.aspectRatio = 2 / 3,
    this.radius = 10,
    this.restricted = false,
    this.imageAlignment = Alignment.center,
  });

  final String? url;
  final String title;
  final int? year;
  final int? hue;
  final double aspectRatio;
  final double radius;
  final bool restricted;
  final Alignment imageAlignment;

  int _resolveHue() {
    if (hue != null) return hue!;
    if (title.isEmpty) return 220;
    return (title.codeUnits.fold(0, (a, b) => a + b) * 7) % 360;
  }

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

    final h = _resolveHue();
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppHues.top(h), AppHues.bottom(h)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.5),
                  radius: 0.85,
                  colors: [
                    AppHues.highlight(h),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
            if (url != null && url!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                alignment: imageAlignment,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => _PlaceholderLabel(title: title, year: year),
              )
            else
              _PlaceholderLabel(title: title, year: year),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xF2FFFFFF),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.15,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Color(0x66000000),
                    ),
                  ],
                ),
              ),
            ),
            if (year != null) ...[
              const SizedBox(height: 3),
              Text(
                '$year',
                style: const TextStyle(
                  color: Color(0xA6FFFFFF),
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
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
