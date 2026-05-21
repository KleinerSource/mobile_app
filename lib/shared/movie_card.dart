import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/models/movie.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.posterUrlBuilder,
    this.onTap,
    this.onLongPress,
  });

  final MovieListItem movie;
  final String Function(String uuid) posterUrlBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final progress = movie.watchRecord?.progressRatio ?? 0.0;
    final completed = movie.watchRecord?.completed ?? false;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: movie.posterUuid != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrlBuilder(movie.posterUuid!),
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: Color(0xFFEFEFEF)),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFFEFEFEF)),
                        )
                      : const ColoredBox(color: Color(0xFFEFEFEF)),
                ),
                if (completed)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已看完',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                if (!completed && progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
