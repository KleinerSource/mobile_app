import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/models/db_online_movie.dart';
import '../../shared/movie_card.dart';
import '../privacy/privacy_providers.dart';

/// dbonline 字段适配器。
///
/// 卡片本身由共享 [CatalogMovieCard] 渲染，这里只负责解析 dbonline 的
/// 字符串番号、图片地址和元数据，避免再维护一套独立 UI。
class DbOnlineMovieCard extends ConsumerWidget {
  const DbOnlineMovieCard({
    super.key,
    required this.movie,
    required this.config,
    this.width = 112,
    this.onTap,
    this.codeOnly = false,
  });

  final DbOnlineMovie movie;
  final ServerConfig? config;
  final double width;
  final VoidCallback? onTap;
  final bool codeOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageValue = movie.thumbUrl ?? movie.coverUrl;
    final imageUrl = imageValue == null || config == null
        ? null
        : resolveServerUrl(config!, imageValue);
    final privacyEnabled = ref.watch(privacyShieldProvider);
    final revealed = ref.watch(revealedMoviesProvider).contains(movie.id);
    // dbonline 没有 OMM 影片库的多选链路，因此卡片长按不应出现按压反馈。
    // 保留共享卡片的展示层，把点击交给外层 GestureDetector，避免
    // CatalogMovieCard 内部 InkWell 在长按时产生额外的 Material 特效。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (privacyEnabled && !revealed) {
          ref.read(revealedMoviesProvider.notifier).reveal(movie.id);
          return;
        }
        onTap?.call();
      },
      child: CatalogMovieCard(
        title: movie.title.isEmpty ? movie.number : movie.title,
        code: movie.number,
        imageUrl: imageUrl,
        meta: _metaText(movie),
        width: width,
        rating: movie.score,
        canPlay: movie.canPlay,
        hasSubtitle: movie.hasCnsub,
        privacyId: movie.id,
        showTitle: !codeOnly,
        showMeta: !codeOnly,
      ),
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
