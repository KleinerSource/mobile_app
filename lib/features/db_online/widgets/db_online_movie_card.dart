import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/sources/media/media_metadata_normalizer.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_metadata_widgets.dart';
import 'package:omm/features/privacy/privacy_providers.dart';

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
    this.landscape = false,
    this.compact = false,
  });

  final DbOnlineMovie movie;
  final ServerConfig? config;
  final double width;
  final VoidCallback? onTap;
  final bool codeOnly;
  final bool landscape;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final imageValue = landscape
        ? movie.coverUrl ?? movie.thumbUrl
        : movie.thumbUrl ?? movie.coverUrl;
    final imageUrl = imageValue == null || config == null
        ? null
        : resolveServerUrl(config!, imageValue);
    final privacyId = movie.id.trim().isEmpty
        ? movie.number.trim()
        : movie.id.trim();
    final privacyEnabled = ref.watch(privacyShieldProvider);
    final revealed = ref.watch(revealedMoviesProvider).contains(privacyId);
    void handleTap() {
      if (privacyEnabled && !revealed) {
        ref.read(revealedMoviesProvider.notifier).reveal(privacyId);
        return;
      }
      onTap?.call();
    }

    if (compact) {
      return CatalogListMovieCard(
        title: movie.title.trim().isEmpty
            ? l.movieCardUntitledTitle
            : movie.title,
        code: movie.number,
        imageUrl: imageUrl,
        imageHeaders: null,
        meta: _metaText(context, movie),
        width: width,
        privacyId: privacyId,
        onTap: handleTap,
      );
    }

    // dbonline 没有 OMM 影片库的多选链路，因此卡片长按不应出现按压反馈。
    // 保留共享卡片的展示层，把点击交给外层 GestureDetector，避免
    // CatalogMovieCard 内部 InkWell 在长按时产生额外的 Material 特效。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: CatalogMovieCard(
        title: movie.title.trim().isEmpty
            ? l.movieCardUntitledTitle
            : movie.title,
        code: movie.number,
        imageUrl: imageUrl,
        meta: _metaText(context, movie),
        width: width,
        rating: normalizeMediaRating(movie.score),
        canPlay: movie.canPlay,
        hasSubtitle: movie.hasCnsub,
        privacyId: privacyId,
        showTitle: !codeOnly,
        showMeta: !codeOnly,
        landscape: landscape,
      ),
    );
  }
}

String _metaText(BuildContext context, DbOnlineMovie movie) {
  final l = AppL10n.of(context);
  return formatMediaCardMeta(
    l,
    year: normalizeMediaYear(movie.releaseDate),
    duration: dboDurationToMinutes(movie.duration),
    emptyText: l.dbOnlineNoMeta,
  );
}
