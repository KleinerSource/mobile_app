import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/pagination_footer.dart';

import 'db_online_movie_card.dart';

/// 只共享 DBO 影片分页展示，查询、去重和末页判断由页面负责。
class DbOnlineMoviePagedSliver extends StatelessWidget {
  const DbOnlineMoviePagedSliver({
    super.key,
    required this.controller,
    required this.mode,
    required this.config,
    required this.movieKey,
    required this.onOpen,
    required this.emptyBuilder,
    this.showRating = true,
  });

  final PagingController<int, DbOnlineMovie> controller;
  final MediaViewMode mode;
  final ServerConfig? config;
  final String Function(DbOnlineMovie movie) movieKey;
  final ValueChanged<DbOnlineMovie> onOpen;
  final WidgetBuilder emptyBuilder;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final delegate = PagedChildBuilderDelegate<DbOnlineMovie>(
      itemBuilder: (context, movie, _) {
        final card = DbOnlineMovieCard(
          key: ValueKey(movieKey(movie)),
          movie: movie,
          config: config,
          width: double.infinity,
          landscape: mode == MediaViewMode.landscape,
          compact: mode == MediaViewMode.list,
          previewList: mode == MediaViewMode.list,
          showRating: showRating,
          subscriptionActionsEnabled: true,
          onTap: () => onOpen(movie),
        );
        return mode == MediaViewMode.landscape
            ? MediaLandscapeListItem(child: card)
            : card;
      },
      firstPageProgressIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Center(
          child: CircularProgressIndicator(color: appColors(context).accent),
        ),
      ),
      newPageProgressIndicatorBuilder: (_) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView.list(
        retryLabel: l.dbOnlineRetry,
        message: controller.error?.toString() ?? l.loadFailed,
        onRetry: controller.retryLastFailedRequest,
      ),
      newPageErrorIndicatorBuilder: (_) =>
          PaginationRetry(onRetry: controller.retryLastFailedRequest),
      noItemsFoundIndicatorBuilder: emptyBuilder,
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );
    return switch (mode) {
      MediaViewMode.portrait => PagedSliverGrid<int, DbOnlineMovie>(
        pagingController: controller,
        showNoMoreItemsIndicatorAsGridChild: false,
        gridDelegate: const MediaGridDelegate(),
        builderDelegate: delegate,
      ),
      MediaViewMode.landscape => MediaLandscapePagedSliver<int, DbOnlineMovie>(
        pagingController: controller,
        builderDelegate: delegate,
      ),
      MediaViewMode.list => PagedSliverList<int, DbOnlineMovie>(
        pagingController: controller,
        builderDelegate: delegate,
      ),
    };
  }
}
