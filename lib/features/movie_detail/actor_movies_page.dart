import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/actor.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/actor_detail_header.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/movie_card.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/actor_avatar.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/status_bar_scroll_to_top.dart';
import '../actor_associations/widgets/actor_association_sync_sheet.dart';
import '../home/hero_backdrop.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';
import 'movie_detail_page.dart';

/// 演员/导演下的影片列表
class ActorMoviesPage extends ConsumerStatefulWidget {
  const ActorMoviesPage({super.key, required this.actor});
  final ActorItem actor;

  @override
  ConsumerState<ActorMoviesPage> createState() => _ActorMoviesPageState();
}

class _ActorMoviesPageState extends ConsumerState<ActorMoviesPage> {
  static const _pageSize = 30;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  int? _totalCount;
  late String _currentBiography;
  String? _avatarCacheBust;

  /// 氛围背景 · 演员头像大模糊,页位恒为 0
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _currentBiography = widget.actor.biography?.trim() ?? '';
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPagePosition.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 封面数组/缓存版本变化时同步氛围背景艺术列表
  void _syncHeroArt(ServerConfig? config) {
    final paths = widget.actor.avatarPaths;
    final count = paths == null ? 1 : paths.length;
    final arts = (config == null || count == 0)
        ? const <HeroArt>[]
        : [
            for (var i = 0; i < count; i++)
              HeroArt(
                movieId: widget.actor.id,
                url: actorAvatarUrl(
                  config,
                  widget.actor.id,
                  cacheBust: _avatarCacheBust,
                  index: i,
                ),
              ),
          ];
    final current = _heroArts.value;
    final same =
        current.length == arts.length &&
        [
          for (var i = 0; i < arts.length; i++)
            current[i].movieId == arts[i].movieId &&
                current[i].url == arts[i].url,
        ].every((ok) => ok);
    if (!same) _heroArts.value = arts;
  }

  Future<void> _fetch(int offset) async {
    try {
      final filter = MovieFilter(
        actorIds: [widget.actor.id],
        sortBy: 'created_at',
        sortOrder: 'desc',
      );
      final page = await ref
          .read(moviesRepositoryProvider)
          .list(filter, limit: _pageSize, offset: offset);
      if (mounted) setState(() => _totalCount = page.totalCount);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      _scrollRestorer.restoreAfterPage(_scrollController);
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  Future<void> _syncActor() async {
    final actor = widget.actor;
    final rule = MappingRule(
      id: actor.id,
      mappedValue: actor.name,
      originalValues: [actor.name],
    );
    final synced = await ActorAssociationSyncSheet.show(
      context,
      rule,
      currentBiography: _currentBiography,
      onBiographyApplied: (biography) {
        if (mounted) setState(() => _currentBiography = biography);
      },
      onAvatarApplied: () {
        if (mounted) {
          setState(() {
            _avatarCacheBust = DateTime.now().microsecondsSinceEpoch.toString();
          });
        }
      },
    );
    if (synced == true && mounted) _reload(preserveScroll: true);
  }

  void _reload({bool preserveScroll = false}) {
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _controller.refresh();
  }

  Future<void> _openMovie(int movieId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
    );
    if (mounted) await _refreshAfterMovie();
  }

  Future<void> _refreshAfterMovie() async {
    final refreshed = await refreshPagedListInBackground<MovieListItem>(
      controller: _controller,
      loadFirstPage: (limit) async {
        final page = await ref
            .read(moviesRepositoryProvider)
            .list(
              MovieFilter(
                actorIds: [widget.actor.id],
                sortBy: 'created_at',
                sortOrder: 'desc',
              ),
              limit: limit,
              offset: 0,
            );
        _totalCount = page.totalCount;
        return page;
      },
    );
    if (mounted && refreshed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final hue = actorHueFromName(widget.actor.name);
    // 状态栏穿透: 封面延伸到状态栏底下,悬浮操作行单独避开状态栏
    final statusBarTop = MediaQuery.paddingOf(context).top;
    _syncHeroArt(ref.watch(serverConfigProvider));
    // 封面占版面上部约 42%: 名称/数量压封面底部,影片列表首屏即可见
    final heroMaxHeight = MediaQuery.sizeOf(context).height * 0.42;
    final heroMinHeight = heroMaxHeight * 0.62;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // -------- 氛围背景: 演员头像大模糊(同首页/影片详情体系) --------
          HeroBackdrop(arts: _heroArts, position: _heroPagePosition),
          StatusBarScrollToTop(
            scrollController: _scrollController,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // -------- 封面 (上滑先收窄再推出 · 多张时轮播) --------
                SliverPersistentHeader(
                  pinned: false,
                  delegate: ActorHeroDelegate(
                    minHeight: heroMinHeight,
                    maxHeight: heroMaxHeight,
                    child: KeyedSubtree(
                      key: const ValueKey('actor-hero'),
                      child: ActorHeroHeader(
                        actorId: widget.actor.id,
                        name: widget.actor.name,
                        hue: hue,
                        actorType: widget.actor.actorType,
                        avatarPaths: widget.actor.avatarPaths,
                        cacheBust: _avatarCacheBust,
                        pagePosition: _heroPagePosition,
                      ),
                    ),
                  ),
                ),
                if (_currentBiography.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ActorBiography(biography: _currentBiography),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            '相关影片',
                            style: AppText.sectionTitle(context),
                          ),
                        ),
                        if (_totalCount != null)
                          Text(
                            '${_totalCount!} 部',
                            style: AppText.meta(context),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
                  sliver: PagedSliverGrid<int, MovieListItem>(
                    pagingController: _controller,
                    showNoMoreItemsIndicatorAsGridChild: false,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 14,
                        ),
                    builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                      itemBuilder: (ctx, m, idx) => MovieCard(
                        movie: m,
                        posterUrlBuilder: urlBuilder,
                        onTap: () => unawaited(_openMovie(m.id)),
                      ),
                      firstPageProgressIndicatorBuilder: (_) =>
                          const Center(child: CupertinoActivityIndicator()),
                      firstPageErrorIndicatorBuilder: (_) => ErrorView(
                        message: _controller.error?.toString() ?? '加载失败',
                        onRetry: () => _controller.refresh(),
                      ),
                      noItemsFoundIndicatorBuilder: (_) =>
                          const EmptyView(message: '没有该演员的影片'),
                      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // -------- 悬浮操作行 · 头图推出屏外后返回/同步仍可达 --------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, statusBarTop + 6, 6, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 18),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '同步演员关联',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_sync_outlined, size: 18),
                    ),
                    onPressed: _syncActor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorBiography extends StatelessWidget {
  const _ActorBiography({required this.biography});

  final String biography;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Text(biography, style: AppText.body(context)),
    );
  }
}
