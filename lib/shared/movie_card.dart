import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/models/movie.dart';
import '../core/ui/app_badge.dart';
import '../core/ui/tokens.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.posterUrlBuilder,
    this.onTap,
  });

  final MovieListItem movie;
  final String Function(String uuid) posterUrlBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final progress = movie.watchRecord?.progressRatio ?? 0.0;
    final completed = movie.watchRecord?.completed ?? false;
    final rating = movie.rating;
    final ratingText = (rating != null && rating > 0)
        ? rating.toStringAsFixed(1)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.poster),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.posterBorder, width: 1),
                      borderRadius: BorderRadius.circular(AppRadius.poster),
                    ),
                    child: movie.posterUuid != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrlBuilder(movie.posterUuid!),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => ColoredBox(color: c.surface),
                            errorWidget: (_, __, ___) =>
                                ColoredBox(color: c.surface),
                          )
                        : ColoredBox(color: c.surface),
                  ),
                  Positioned(top: 5, left: 5, child: _topLeftBadge(c)),
                  if (completed)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: AppBadge(
                        icon: Icons.check_circle_outline,
                        label: '已看完',
                        background: c.badgeCompleted,
                      ),
                    ),
                  Positioned(
                    left: 5,
                    right: 5,
                    bottom: 5,
                    child: _bottomBadgeRow(c, ratingText),
                  ),
                  if (progress > 0 && !completed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        key: const ValueKey('movie-progress'),
                        height: 2,
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: c.progressTrack,
                          valueColor: AlwaysStoppedAnimation(c.brand),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          _metaRow(c),
        ],
      ),
    );
  }

  Widget _topLeftBadge(AppColors c) {
    if (movie.isUpdated) {
      return AppBadge(
        icon: Icons.refresh,
        label: '已更新',
        background: c.badgeUpdated,
      );
    }
    if (movie.isFavorited) {
      return AppBadge(
        icon: Icons.favorite,
        label: '已收藏',
        background: c.badgeFavorited,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _bottomBadgeRow(AppColors c, String? ratingText) {
    final children = <Widget>[];
    if (movie.hasExternalSubtitle) {
      children.add(AppBadge(
        icon: Icons.closed_caption_outlined,
        background: c.badgeSubtitle,
      ));
    }
    if (ratingText != null) {
      children.add(AppBadge(
        icon: Icons.star,
        label: ratingText,
        background: c.shade,
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: children,
    );
  }

  Widget _metaRow(AppColors c) {
    final parts = <Widget>[];
    final num = movie.num;
    if (num != null && num.isNotEmpty) {
      parts.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          num,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: c.text,
            height: 1.1,
          ),
        ),
      ));
    }
    if (movie.year != null) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 4));
      parts.add(Text(
        '${movie.year}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: c.textMuted,
        ),
      ));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts,
    );
  }
}
