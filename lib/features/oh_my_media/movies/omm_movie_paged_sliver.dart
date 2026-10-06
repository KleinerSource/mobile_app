import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/media_list_row.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/poster.dart';

/// OMM 影片紧凑列表行：缩略图 + 标题 + 元信息 + 进度，供无独立
/// 视图切换的影片列表页在全局视图模式为 list 时复用。
class OmmMovieListRow extends StatelessWidget {
  const OmmMovieListRow({
    super.key,
    required this.movie,
    required this.urlBuilder,
    this.onTap,
  });

  final MovieListItem movie;
  final String Function(String uuid) urlBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final progress = (movie.watchRecord?.progressRatio ?? 0).clamp(0.0, 1.0);
    final completed = movie.watchRecord?.completed ?? false;
    final hasRating = movie.rating != null && movie.rating! > 0;
    final meta = <String>[
      if (movie.year != null) '${movie.year}',
      if (movie.runtime != null && movie.runtime! > 0)
        l.mediaDurationMinutes(movie.runtime!),
      if (hasRating) '★ ${movie.rating!.toStringAsFixed(1)}',
    ].join(' · ');

    return MediaListRow(
      thumbnail: PrivacyMask(
        movieId: movie.id,
        radius: 8,
        child: Poster(
          url: movie.posterUuid != null ? urlBuilder(movie.posterUuid!) : null,
          title: movie.title,
          year: movie.year,
          radius: 8,
        ),
      ),
      title: PrivacyText(
        movieId: movie.id,
        text: movie.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c.text,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.25,
        ),
      ),
      meta: meta.isNotEmpty ? Text(meta, style: AppText.meta(context)) : null,
      additional: !completed && progress > 0
          ? Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: c.chipBg,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : null,
      trailing: completed
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                l.watchedDone,
                style: TextStyle(
                  color: c.accent,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            )
          : Icon(Icons.chevron_right, color: c.muted, size: 20),
      privacyId: movie.id,
      privacyAwareTap: true,
      onTap: onTap,
    );
  }
}

/// OMM 影片分页列表：按全局（按服务器）视图模式自动切换海报网格、
/// 16:9 横向卡片或紧凑列表行，页面无需各自维护视图状态。
class OmmMoviePagedSliver extends ConsumerWidget {
  const OmmMoviePagedSliver({
    super.key,
    required this.controller,
    required this.urlBuilder,
    required this.onOpenMovie,
    required this.emptyMessage,
  });

  final PagingController<int, MovieListItem> controller;
  final String Function(String uuid) urlBuilder;
  final ValueChanged<MovieListItem> onOpenMovie;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final viewMode = ref.watch(mediaServerViewModeProvider);

    Widget itemBuilder(BuildContext ctx, MovieListItem movie, int index) {
      if (viewMode == MediaViewMode.list) {
        return OmmMovieListRow(
          movie: movie,
          urlBuilder: urlBuilder,
          onTap: () => onOpenMovie(movie),
        );
      }
      final card = MovieCard(
        movie: movie,
        posterUrlBuilder: urlBuilder,
        landscape: viewMode == MediaViewMode.landscape,
        onTap: () => onOpenMovie(movie),
      );
      return viewMode == MediaViewMode.landscape
          ? MediaLandscapeListItem(child: card)
          : card;
    }

    final delegate = PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: itemBuilder,
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: controller.error == null
            ? l.loadFailed
            : localizedErrorMessage(l, controller.error!),
        onRetry: () => controller.refresh(),
      ),
      newPageErrorIndicatorBuilder: (_) =>
          PaginationRetry(onRetry: controller.retryLastFailedRequest),
      noItemsFoundIndicatorBuilder: (_) => EmptyView(message: emptyMessage),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );

    if (viewMode == MediaViewMode.portrait) {
      return PagedSliverGrid<int, MovieListItem>(
        pagingController: controller,
        showNoMoreItemsIndicatorAsGridChild: false,
        gridDelegate: const MediaGridDelegate(),
        builderDelegate: delegate,
      );
    }
    if (viewMode == MediaViewMode.landscape) {
      return MediaLandscapePagedSliver<int, MovieListItem>(
        pagingController: controller,
        builderDelegate: delegate,
      );
    }
    return PagedSliverList<int, MovieListItem>(
      pagingController: controller,
      builderDelegate: delegate,
    );
  }
}
