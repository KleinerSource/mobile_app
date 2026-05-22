import 'package:flutter/material.dart';

import '../core/models/movie.dart';
import '../core/platform/app_theme.dart';
import 'poster.dart';

/// md_center 标准影片卡片 · 海报 + 评分角标 + 进度条 + 标题元数据
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.posterUrlBuilder,
    this.onTap,
    this.onLongPress,
    this.restricted = false,
  });

  final MovieListItem movie;
  final String Function(String uuid) posterUrlBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    final progress = movie.watchRecord?.progressRatio ?? 0.0;
    final completed = movie.watchRecord?.completed ?? false;
    final c = appColors(context);
    final hasRating = movie.rating != null && movie.rating! > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Poster(
                url: movie.posterUuid != null
                    ? posterUrlBuilder(movie.posterUuid!)
                    : null,
                title: movie.title,
                year: movie.year,
                restricted: restricted,
              ),
              if (!restricted && hasRating)
                Positioned(
                  top: 6,
                  right: 6,
                  child: RatingBadge(rating: movie.rating!),
                ),
              if (restricted)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.warning.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'R18',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              if (!restricted && completed)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '已看',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (!restricted && !completed && progress > 0)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            restricted ? 'Restricted' : movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: restricted ? c.muted : c.text,
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontStyle: restricted ? FontStyle.italic : FontStyle.normal,
              height: 1.2,
            ),
          ),
          if (!restricted && (movie.year != null || movie.runtime != null))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _meta(movie),
                style: TextStyle(
                  color: c.muted,
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _meta(MovieListItem m) {
    final parts = <String>[];
    if (m.year != null) parts.add('${m.year}');
    if (m.runtime != null && m.runtime! > 0) parts.add('${m.runtime}m');
    return parts.join(' · ');
  }
}
