import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

/// 类别影片列表落地页，与网页端 `/filter?type=category` 一致。
///
/// 数据来自 `/videos/filter` 的一次性全量结果（无分页、无筛选参数），
/// [categoryId] 为类别 external_id，[categoryName] 既作页面标题也在
/// 无 id 时作为名称筛选回退。
class DbOnlineCategoryMoviesPage extends ConsumerStatefulWidget {
  const DbOnlineCategoryMoviesPage({
    super.key,
    this.categoryId = '',
    required this.categoryName,
  });

  final String categoryId;
  final String categoryName;

  @override
  ConsumerState<DbOnlineCategoryMoviesPage> createState() =>
      _DbOnlineCategoryMoviesPageState();
}

class _DbOnlineCategoryMoviesPageState
    extends ConsumerState<DbOnlineCategoryMoviesPage> {
  static const _viewModeKey = 'db_online.category_movies.view_mode.v1';

  final _requests = PagedRequestCoordinator();
  final _controller = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _scrollController = ScrollController();
  Completer<void>? _refreshCompleter;
  MediaViewMode _viewMode = MediaViewMode.portrait;

  @override
  void initState() {
    super.initState();
    _viewMode = mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_viewModeKey),
    );
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _completeRefresh();
    _requests.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    final pageRequest = _requests.begin(page);
    if (pageRequest == null) return;
    try {
      final movies = await ref.read(
        dbOnlineCategoryMoviesProvider(
          DbOnlineCategoryMoviesRequest(
            serverId:
                ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
            categoryId: widget.categoryId,
            categoryName: widget.categoryName,
          ),
        ).future,
      );
      if (!pageRequest.isCurrent || !mounted) return;

      _controller.appendLastPage(movies);
      if (page == 1) _completeRefresh();
    } catch (error) {
      if (!pageRequest.isCurrent) return;
      _controller.error = localizedErrorMessage(AppL10n.of(context), error);
      if (page == 1) _completeRefresh();
    } finally {
      pageRequest.finish();
    }
  }

  Future<void> _refresh() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _requests.invalidate();
    refreshPagedController(
      controller: _controller,
      requests: _requests,
      loadPage: _fetchPage,
    );
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(sharedPrefsProvider).setString(_viewModeKey, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(mediaRuntimeConfigProvider);
    final isPortrait = _viewMode == MediaViewMode.portrait;
    final delegate = PagedChildBuilderDelegate<DbOnlineMovie>(
      itemBuilder: (context, movie, _) {
        final card = DbOnlineMovieCard(
          key: ValueKey(_movieKey(movie)),
          movie: movie,
          config: config,
          width: double.infinity,
          landscape: _viewMode == MediaViewMode.landscape,
          compact: _viewMode == MediaViewMode.list,
          // 列表模式升级为预览条目：左封面 + 右预览图翻页。
          previewList: _viewMode == MediaViewMode.list,
          onTap: () => openDbOnlineMovieUnawaited(context, movie),
        );
        return _viewMode == MediaViewMode.landscape
            ? MediaLandscapeListItem(child: card)
            : card;
      },
      firstPageProgressIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Center(child: CircularProgressIndicator(color: colors.accent)),
      ),
      firstPageErrorIndicatorBuilder: (context) => ErrorView.list(
        retryLabel: AppL10n.of(context).dbOnlineRetry,
        message:
            _controller.error?.toString() ?? AppL10n.of(context).loadFailed,
        onRetry: _controller.retryLastFailedRequest,
      ),
      noItemsFoundIndicatorBuilder: (_) =>
          EmptyView(message: AppL10n.of(context).dbOnlineNoData),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: 'DB ONLINE',
              bottomPadding: PageHeader.aboveListGap,
              title: widget.categoryName,
              trailing: MediaViewModeToggle(
                mode: _viewMode,
                onChanged: (mode) => unawaited(_setViewMode(mode)),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: MediaListLayout.contentPadding,
                    sliver: isPortrait
                        ? PagedSliverGrid<int, DbOnlineMovie>(
                            pagingController: _controller,
                            // 尾部提示整行跨列渲染（与 OMM 影片库一致）。
                            showNoMoreItemsIndicatorAsGridChild: false,
                            gridDelegate: const MediaGridDelegate(),
                            builderDelegate: delegate,
                          )
                        : PagedSliverList<int, DbOnlineMovie>(
                            pagingController: _controller,
                            builderDelegate: delegate,
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _movieKey(DbOnlineMovie movie) {
    final id = movie.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'number:${movie.number.trim()}';
  }
}
