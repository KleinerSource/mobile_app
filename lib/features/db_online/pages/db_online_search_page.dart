import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/models/db_online_search.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/search_type_menu.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

/// dbonline 搜索页。
///
/// 搜索类型和结果卡片沿用 OMM 搜索页的交互结构；这里只替换 DBO 的
/// 数据请求、影片卡片和详情跳转。
class DbOnlineSearchPage extends ConsumerStatefulWidget {
  const DbOnlineSearchPage({super.key});

  @override
  ConsumerState<DbOnlineSearchPage> createState() => _DbOnlineSearchPageState();
}

enum DbOnlineSearchType { list, actor, series }

extension on DbOnlineSearchType {
  String label(AppL10n l) => switch (this) {
    DbOnlineSearchType.list => l.searchModeList,
    DbOnlineSearchType.actor => l.searchModeActorSearch,
    DbOnlineSearchType.series => l.searchModeSeries,
  };

  String placeholder(AppL10n l) => switch (this) {
    DbOnlineSearchType.list => l.searchPlaceholderList,
    DbOnlineSearchType.actor => l.searchPlaceholderActor,
    DbOnlineSearchType.series => l.searchPlaceholderSeries,
  };

  IconData get icon => switch (this) {
    DbOnlineSearchType.list => Icons.list_alt_outlined,
    DbOnlineSearchType.actor => Icons.person_outline_rounded,
    DbOnlineSearchType.series => Icons.layers_outlined,
  };
}

class _DbOnlineSearchPageState extends ConsumerState<DbOnlineSearchPage> {
  final _controller = TextEditingController();
  String _submittedQuery = '';
  DbOnlineSearchType _searchType = DbOnlineSearchType.list;
  int _searchSerial = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
  }

  void _submitSearch([String? value]) {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) {
      if (_submittedQuery.isNotEmpty) {
        setState(() {
          _submittedQuery = '';
          _searchSerial++;
        });
      }
      return;
    }
    setState(() {
      _submittedQuery = query;
      _searchSerial++;
    });
  }

  void _changeSearchType(DbOnlineSearchType type) {
    if (type == _searchType) return;
    setState(() {
      _searchType = type;
      _submittedQuery = '';
      _searchSerial++;
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
                    SearchTypeMenu<DbOnlineSearchType>(
                      value: _searchType,
                      options: [
                        for (final type in DbOnlineSearchType.values)
                          SearchTypeOption<DbOnlineSearchType>(
                            value: type,
                            label: type.label(l),
                            icon: type.icon,
                          ),
                      ],
                      onChanged: _changeSearchType,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: _searchType.placeholder(l),
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
                        onSubmitted: _submitSearch,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: colors.muted),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _submittedQuery = '';
                            _searchSerial++;
                          });
                        },
                      ),
                    IconButton(
                      tooltip: l.searchTitle,
                      icon: Icon(Icons.search, size: 18, color: colors.muted),
                      onPressed: _submitSearch,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _submittedQuery.isEmpty
                  ? const _DbOnlineSearchEmptyHint()
                  : switch (_searchType) {
                      DbOnlineSearchType.list => _DbOnlineSearchResults(
                        key: ValueKey('list:$_submittedQuery:$_searchSerial'),
                        query: _submittedQuery,
                      ),
                      DbOnlineSearchType.actor => _DbOnlineActorSearchResults(
                        key: ValueKey('actor:$_submittedQuery:$_searchSerial'),
                        query: _submittedQuery,
                      ),
                      DbOnlineSearchType.series => _DbOnlineSeriesSearchResults(
                        key: ValueKey('series:$_submittedQuery:$_searchSerial'),
                        query: _submittedQuery,
                      ),
                    },
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
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
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
                message:
                    _pagingController.error?.toString() ??
                    AppL10n.of(context).loadFailed,
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

class _DbOnlineActorSearchResults extends ConsumerWidget {
  const _DbOnlineActorSearchResults({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(dbOnlineActorSearchProvider(query));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: toApiException(error).message,
        onRetry: () => ref.invalidate(dbOnlineActorSearchProvider(query)),
      ),
      data: (value) {
        if (value.actors.isEmpty) {
          return const _DbOnlineSearchNoResults();
        }
        return CustomScrollView(
          primary: false,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.9,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final actor = value.actors[index];
                  return _DbOnlineSearchEntityCard(
                    name: actor.name,
                    label: AppL10n.of(context).searchModeActorSearch,
                    count: actor.videosCount,
                    icon: Icons.person_outline_rounded,
                  );
                }, childCount: value.actors.length),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DbOnlineSeriesSearchResults extends ConsumerStatefulWidget {
  const _DbOnlineSeriesSearchResults({super.key, required this.query});

  final String query;

  @override
  ConsumerState<_DbOnlineSeriesSearchResults> createState() =>
      _DbOnlineSeriesSearchResultsState();
}

class _DbOnlineSeriesSearchResultsState
    extends ConsumerState<_DbOnlineSeriesSearchResults> {
  static const _pageSize = 24;

  final _pagingController = PagingController<int, DbOnlineSearchEntity>(
    firstPageKey: 1,
  );

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    try {
      final result = await ref.read(
        dbOnlineSeriesSearchPageProvider(
          DbOnlineSeriesSearchPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            query: widget.query,
            page: page,
            limit: _pageSize,
          ),
        ).future,
      );
      if (!mounted) return;

      final current =
          _pagingController.itemList ?? const <DbOnlineSearchEntity>[];
      final seen = <String>{for (final item in current) _entityKey(item)};
      final items = result.items
          .where((item) => seen.add(_entityKey(item)))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
          sliver: PagedSliverGrid<int, DbOnlineSearchEntity>(
            pagingController: _pagingController,
            showNoMoreItemsIndicatorAsGridChild: false,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.9,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            builderDelegate: PagedChildBuilderDelegate<DbOnlineSearchEntity>(
              itemBuilder: (context, item, _) => _DbOnlineSearchEntityCard(
                name: item.name,
                label: AppL10n.of(context).searchModeSeries,
                count: item.moviesCount,
                icon: Icons.layers_outlined,
              ),
              firstPageProgressIndicatorBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (_) => ErrorView(
                message:
                    _pagingController.error?.toString() ??
                    AppL10n.of(context).loadFailed,
                onRetry: _pagingController.refresh,
              ),
              newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                onRetry: _pagingController.retryLastFailedRequest,
              ),
              noItemsFoundIndicatorBuilder: (_) =>
                  const _DbOnlineSearchNoResults(),
              noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DbOnlineSearchEntityCard extends StatelessWidget {
  const _DbOnlineSearchEntityCard({
    required this.name,
    required this.label,
    required this.count,
    required this.icon,
  });

  final String name;
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, size: 22, color: colors.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(label, style: AppText.meta(context)),
                  if (count > 0)
                    Text(
                      AppL10n.of(context).libraryCount(count),
                      style: AppText.meta(context),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DbOnlineSearchNoResults extends StatelessWidget {
  const _DbOnlineSearchNoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppL10n.of(context).searchNoResult,
          style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

String _entityKey(DbOnlineSearchEntity item) {
  final id = item.id.trim();
  return id.isNotEmpty ? 'id:$id' : 'name:${item.name.trim()}';
}
