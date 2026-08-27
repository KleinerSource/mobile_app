import 'package:flutter/material.dart';

import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/models/db_online_movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/poster.dart';

/// dbonline 影片卡片。
///
/// 海报、标题字号、间距和角标均复用 OMM 的 [Poster] 与共享视觉规范，
/// 只保留 dbonline 自身的字符串番号和在线播放状态字段。
class DbOnlineMovieCard extends StatelessWidget {
  const DbOnlineMovieCard({
    super.key,
    required this.movie,
    required this.config,
    this.width = 112,
    this.onTap,
  });

  final DbOnlineMovie movie;
  final ServerConfig? config;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageValue = movie.thumbUrl ?? movie.coverUrl;
    final imageUrl = imageValue == null || config == null
        ? null
        : resolveServerUrl(config!, imageValue);
    final colors = appColors(context);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Poster(
                    url: imageUrl,
                    title: movie.title.isEmpty ? movie.number : movie.title,
                    radius: 10,
                  ),
                  if (movie.canPlay)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: OnlinePlayBadge(),
                    ),
                  if (movie.score != null && movie.score! > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: RatingBadge(rating: movie.score!),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                movie.number.isEmpty ? '未命名番号' : movie.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.accent,
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                movie.title.isEmpty ? '未命名影片' : movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _metaText(movie),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.muted,
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _metaText(DbOnlineMovie movie) {
  final parts = <String>[];
  if (movie.releaseDate != null) parts.add(movie.releaseDate!);
  if (movie.duration != null) parts.add(movie.duration!);
  if (movie.library != null) parts.add(movie.library!);
  if (movie.magnetsCount > 0) parts.add('${movie.magnetsCount} 磁链');
  if (movie.hasCnsub) parts.add('中字');
  if (movie.score != null) parts.add('评分 ${movie.score!.toStringAsFixed(1)}');
  return parts.isEmpty ? '暂无信息' : parts.join(' · ');
}
