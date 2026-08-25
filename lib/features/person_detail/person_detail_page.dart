import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/envelope.dart';
import '../../core/api/providers.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/actor.dart';
import '../../core/models/movie.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
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
import '../movies/movie_data_changes.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

/// 演员 / 导演详情页 · 封面轮播 + 简介 + 作品集 (用 actor_ids filter 反查)。
/// 影片详情演员列表与演员管理共用本页。
class PersonDetailPage extends ConsumerStatefulWidget {
  const PersonDetailPage({super.key, required this.actor, this.onUpdated});

  final ActorItem actor;

  /// 同步演员关联成功后通知调用方刷新(演员管理列表等)
  final Future<void> Function()? onUpdated;

  @override
  ConsumerState<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends ConsumerState<PersonDetailPage> {
  static const _pageSize = 30;

  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  late String _biography;

  /// 封面头像数组 · 进页快照可能随同步演员关联过期,同步成功后重新拉取
  List<String>? _avatarPaths;
  String? _avatarCacheBust;
  int? _totalCount;
  int _requestSerial = 0;

  /// 氛围背景 · 演员头像大模糊,跟随封面轮播切换
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _biography = widget.actor.biography?.trim() ?? '';
    _avatarPaths = widget.actor.avatarPaths;
    // 影片详情入口的 ActorItem 不含 avatar_path 数组(影片详情接口未返回),
    // 需拉取演员详情补全,否则封面与氛围背景张数未知无法轮播
    if (_avatarPaths == null) unawaited(_refreshActorProfile());
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
    final paths = _avatarPaths;
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
    final requestSerial = _requestSerial;
    try {
      final filter = MovieFilter(
        actorIds: [widget.actor.id],
        sortBy: 'created_at',
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
        id: widget.actor.id,
        mappedValue: widget.actor.name,
        originalValues: [widget.actor.name],
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
    // 同步会替换后端 avatar_path 数组(张数可能变化),重新拉取演员详情刷新封面
    unawaited(_refreshActorProfile());
    _reload(preserveScroll: true);
    await widget.onUpdated?.call();
  }

  /// 重新拉取演员详情,把最新的 avatar_path 数组同步到封面轮播与氛围背景;
  /// 数组未变化时不更新缓存版本,避免封面无谓重载。拉取失败静默,不影响作品集刷新。
  Future<void> _refreshActorProfile() async {
    try {
      final raw = await ref
          .read(requiredApiClientProvider)
          .catalog
          .detail('actors', widget.actor.id);
      final actor = unwrapStd<ActorItem>(
        raw,
        (d) => ActorItem.fromJson(Map<String, dynamic>.from(d as Map)),
      );
      if (!mounted || _sameAvatarPaths(_avatarPaths, actor.avatarPaths)) return;
      // 首次补全(null → 数组)时首图 URL 不变,无需换缓存版本强制重载
      final hadSnapshot = _avatarPaths != null;
      setState(() {
        _avatarPaths = actor.avatarPaths;
        if (hadSnapshot) {
          _avatarCacheBust = DateTime.now().microsecondsSinceEpoch.toString();
        }
      });
    } catch (_) {
      // 保留当前封面,作品集刷新不受影响
    }
  }

  bool _sameAvatarPaths(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _reload({bool preserveScroll = false}) {
    _requestSerial++;
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _controller.refresh();
  }

  Future<void> _openMovie(int movieId) async {
    final changesBeforeVisit = MovieDataChanges.snapshot();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
    );
    if (!mounted) return;
    // 详情页内没有任何真实变更时沿用缓存,不刷新。
    final now = MovieDataChanges.snapshot();
    if (now.imagesChangedSince(changesBeforeVisit)) refreshImageCache(ref);
    if (now.metadata != changesBeforeVisit.metadata ||
        now.progress != changesBeforeVisit.progress) {
      await _refreshAfterMovie();
    }
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
    final l = AppL10n.of(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final hue = actorHueFromName(widget.actor.name);
    // 状态栏穿透: 封面延伸到状态栏底下,悬浮操作行单独避开状态栏
    final statusBarTop = MediaQuery.paddingOf(context).top;
    _syncHeroArt(ref.watch(serverConfigProvider));
    // 封面占版面上部约 42%: 名称/简介与影片列表首屏即可见
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
                      key: const ValueKey('person-hero'),
                      child: ActorHeroHeader(
                        actorId: widget.actor.id,
                        name: widget.actor.name,
                        hue: hue,
                        actorType: widget.actor.actorType,
                        avatarPaths: _avatarPaths,
                        cacheBust: _avatarCacheBust,
                        pagePosition: _heroPagePosition,
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
                            l.detailFilmography,
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
                      itemBuilder: (ctx, movie, _) => MovieCard(
                        movie: movie,
                        posterUrlBuilder: urlBuilder,
                        onTap: () => unawaited(_openMovie(movie.id)),
                      ),
                      firstPageProgressIndicatorBuilder: (_) =>
                          const Center(child: CupertinoActivityIndicator()),
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
              ],
            ),
          ),
          // -------- 悬浮操作行 · 封面推出屏外后返回/同步仍可达 --------
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
