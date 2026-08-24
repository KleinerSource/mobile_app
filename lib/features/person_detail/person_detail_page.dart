import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/movie.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/actor_avatar.dart';
import '../../shared/actor_detail_header.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/movie_card.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/status_bar_scroll_to_top.dart';
import '../actor_associations/widgets/actor_association_sync_sheet.dart';
import '../home/hero_backdrop.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

/// 演员 / 导演详情页 · 大头像 + 作品集 (用 actor_ids filter 反查)
class PersonDetailPage extends ConsumerStatefulWidget {
  const PersonDetailPage({
    super.key,
    required this.actorId,
    required this.name,
    this.actorType,
    this.biography,
    this.avatarPath,
    this.onUpdated,
  });

  final int actorId;
  final String name;
  final String? actorType;
  final String? biography;
  final String? avatarPath;
  final Future<void> Function()? onUpdated;

  @override
  ConsumerState<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends ConsumerState<PersonDetailPage> {
  static const _pageSize = 60;

  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  late String _biography;
  String? _avatarCacheBust;
  int? _totalCount;
  int _requestSerial = 0;

  /// 氛围背景 · 演员头像大模糊,页位恒为 0
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _biography = widget.biography?.trim() ?? '';
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

  /// 头像同步刷新后 cacheBust 变化,氛围背景 URL 跟随更新
  void _syncHeroArt(ServerConfig? config) {
    final url = config == null
        ? ''
        : actorAvatarUrl(config, widget.actorId, cacheBust: _avatarCacheBust);
    final current = _heroArts.value;
    if (current.length == 1 &&
        current[0].movieId == widget.actorId &&
        current[0].url == url) {
      return;
    }
    _heroArts.value = [HeroArt(movieId: widget.actorId, url: url)];
  }

  Future<void> _fetch(int offset) async {
    final requestSerial = _requestSerial;
    try {
      final filter = MovieFilter(
        actorIds: [widget.actorId],
        sortBy: 'year',
        sortOrder: 'desc',
      );
      final page = await ref
          .read(moviesRepositoryProvider)
          .list(filter, limit: _pageSize, offset: offset);
      if (!mounted || requestSerial != _requestSerial) return;

      setState(() => _totalCount = page.totalCount);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      _scrollRestorer.restoreAfterPage(_scrollController);
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
    }
  }

  Future<void> _syncActor() async {
    final synced = await ActorAssociationSyncSheet.show(
      context,
      MappingRule(
        id: widget.actorId,
        mappedValue: widget.name,
        originalValues: [widget.name],
      ),
      currentBiography: _biography,
      onBiographyApplied: (biography) {
        if (mounted) setState(() => _biography = biography.trim());
      },
      onAvatarApplied: () {
        if (mounted) {
          setState(() {
            _avatarCacheBust = DateTime.now().microsecondsSinceEpoch.toString();
          });
        }
      },
    );
    if (synced != true || !mounted) return;
    _reload(preserveScroll: true);
    await widget.onUpdated?.call();
  }

  void _reload({bool preserveScroll = false}) {
    _requestSerial++;
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
                actorIds: [widget.actorId],
                sortBy: 'year',
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
    final hue = actorHueFromName(widget.name);
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
                // -------- 封面 (整屏满铺 · 信息压毛玻璃区) --------
                SliverPersistentHeader(
                  pinned: false,
                  delegate: ActorHeroDelegate(
                    minHeight: heroMinHeight,
                    maxHeight: heroMaxHeight,
                    child: KeyedSubtree(
                      key: const ValueKey('person-hero'),
                      child: ActorHeroHeader(
                        actorId: widget.actorId,
                        name: widget.name,
                        hue: hue,
                        actorType: widget.actorType,
                        movieCount: _totalCount,
                        avatarPath: widget.avatarPath,
                        cacheBust: _avatarCacheBust,
                      ),
                    ),
                  ),
                ),
                if (_biography.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                      child: Text(_biography, style: AppText.body(context)),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            'Filmography',
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
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
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
                      itemBuilder: (ctx, movie, _) => MovieCard(
                        movie: movie,
                        posterUrlBuilder: urlBuilder,
                        onTap: () => unawaited(_openMovie(movie.id)),
                      ),
                      firstPageProgressIndicatorBuilder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                      firstPageErrorIndicatorBuilder: (_) => ErrorView(
                        message: _controller.error?.toString() ?? '加载失败',
                        onRetry: () => _controller.refresh,
                      ),
                      newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                        onRetry: () => _controller.retryLastFailedRequest,
                      ),
                      noItemsFoundIndicatorBuilder: (_) =>
                          const EmptyView(message: '没有该演员的影片'),
                      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
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
