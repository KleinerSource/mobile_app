import 'package:flutter/material.dart';

import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/models/db_online_movie.dart';
import '../../shared/movie_card.dart';

/// dbonline 字段适配器。
///
/// 卡片本身由共享 [CatalogMovieCard] 渲染，这里只负责解析 dbonline 的
/// 字符串番号、图片地址和元数据，避免再维护一套独立 UI。
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
    return CatalogMovieCard(
      title: movie.title.isEmpty ? movie.number : movie.title,
      code: movie.number,
      imageUrl: imageUrl,
      meta: _metaText(movie),
      width: width,
      rating: movie.score,
      canPlay: movie.canPlay,
      onTap: onTap,
    );
  }
}

String _metaText(DbOnlineMovie movie) {
  final parts = <String>[];
  final year = _yearFromDate(movie.releaseDate);
  if (year != null) parts.add('$year');
  final duration = _durationMinutes(movie.duration);
  if (duration != null && duration > 0) parts.add('${duration}m');
  if (movie.library != null) parts.add(movie.library!);
  if (movie.hasCnsub) parts.add('中字');
  return parts.isEmpty ? '暂无信息' : parts.join(' · ');
}

int? _yearFromDate(String? value) {
  final match = RegExp(r'^(\d{4})').firstMatch(value?.trim() ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _durationMinutes(String? value) {
  final match = RegExp(r'\d+').firstMatch(value?.trim() ?? '');
  return match == null ? null : int.tryParse(match.group(0)!);
}
