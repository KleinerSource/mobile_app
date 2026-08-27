import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/db_online_movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/debouncer.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../../shared/pagination_footer.dart';
import 'db_online_home_providers.dart';
import 'db_online_movie_card.dart';
import 'db_online_movie_navigation.dart';

/// dbonline 搜索页。
///
/// 搜索输入、延迟触发、分页网格、空态和错误重试沿用 OMM 搜索页的交互
/// 结构；这里只替换 DBO 的数据请求、影片卡片和详情跳转。
class DbOnlineSearchPage extends ConsumerStatefulWidget {
  const DbOnlineSearchPage({super.key});

  @override
  ConsumerState<DbOnlineSearchPage> createState() => _DbOnlineSearchPageState();
}

class _DbOnlineSearchPageState extends ConsumerState<DbOnlineSearchPage> {
  final _controller = TextEditingController();
  final _debounce = Debouncer();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce.run(() {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DBONLINE', style: AppText.eyebrow(context)),
                  const SizedBox(height: 3),
                  Text(l.searchFind, style: AppText.pageTitle(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.cardBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, size: 18, color: colors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: l.searchPlaceholderTitle,
                          hintStyle: TextStyle(
                            color: colors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: _onChanged,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: colors.muted),
                        onPressed: () {
                          _debounce.cancel();
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? const _DbOnlineSearchEmptyHint()
                  : _DbOnlineSearchResults(
                      key: ValueKey(_query),
                      query: _query,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DbOnlineSearchEmptyHint extends StatelessWidget {
  const _DbOnlineSearchEmptyHint();

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: colors.muted2),
          const SizedBox(height: 12),
          Text(
            l.searchEmpty,
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(l.searchHint2, style: AppText.meta(context)),
        ],
      ),
    );
  }
}

class _DbOnlineSearchResults extends ConsumerStatefulWidget {
  const _DbOnlineSearchResults({super.key, required this.query});

  final String query;

  @override
  ConsumerState<_DbOnlineSearchResults> createState() =>
      _DbOnlineSearchResultsState();
}

class _DbOnlineSearchResultsState
    extends ConsumerState<_DbOnlineSearchResults> {
  static const _pageSize = 24;

  final _pagingController = PagingController<int, DbOnlineMovie>(
    firstPageKey: 1,
  );
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    try {
      final result = await ref.read(
        dbOnlineSearchPageProvider(
          DbOnlineSearchPageRequest(
            query: widget.query,
            page: page,
            limit: _pageSize,
          ),
        ).future,
      );
      if (!mounted) return;

      final current = _pagingController.itemList ?? const <DbOnlineMovie>[];
      final seen = <String>{for (final movie in current) _movieKey(movie)};
      final items = result.movies
          .where((movie) => seen.add(_movieKey(movie)))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.movies.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, page + 1);
      }
    } catch (error) {
      if (!mounted) return;
      _pagingController.error = toApiException(error).message;
    }
  }

  String _movieKey(DbOnlineMovie movie) {
    final id = movie.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'number:${movie.number.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(serverConfigProvider);
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = (width - 44 - 20) / 3;

    return CustomScrollView(
      controller: _scrollController,
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
          sliver: PagedSliverGrid<int, DbOnlineMovie>(
            pagingController: _pagingController,
            showNoMoreItemsIndicatorAsGridChild: false,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
            ),
            builderDelegate: PagedChildBuilderDelegate<DbOnlineMovie>(
              itemBuilder: (context, movie, _) => DbOnlineMovieCard(
                key: ValueKey(_movieKey(movie)),
                movie: movie,
                config: config,
                width: itemWidth,
                onTap: () => openDbOnlineMovieUnawaited(context, movie),
              ),
              firstPageProgressIndicatorBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (_) => ErrorView(
                message: _pagingController.error?.toString() ?? '加载失败',
                onRetry: _pagingController.refresh,
              ),
              newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                onRetry: _pagingController.retryLastFailedRequest,
              ),
              noItemsFoundIndicatorBuilder: (_) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppL10n.of(context).searchNoResult,
                    style: AppText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
            ),
          ),
        ),
      ],
    );
  }
}
