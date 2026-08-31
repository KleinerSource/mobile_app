import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/library.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/movie_card.dart';
import '../../shared/poster.dart';
import '../../shared/collection_card_layout.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_providers.dart';
import 'package:omm/features/oh_my_media/libraries/library_movies_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import '../player/video/video_player_page.dart';
import '../privacy/privacy_mask.dart';
import 'hero_backdrop.dart';
import 'home_movie_section.dart';
import 'home_providers.dart';
import 'home_movie_view_state.dart';
import 'recommend_carousel.dart';

const _homeSectionGap = 24.0;
const _homeSectionTitleGap = 14.0;

/// omm 首页 · 现代化半屏 hero 设计:
/// - 背景为当前轮播封面的大模糊毛玻璃氛围层
/// - hero 轮播满铺占半屏,上滑先收窄再推出,显出下方卡片
/// - 模块顺序 (对齐 frontend_new Dashboard.vue):
///   1. RecommendCarousel (hero · 最近添加里 fanart 不为空的前 10 条)
///   2. Continue Watching (有观看进度未完成的)
///   3. Recently Added (横向卡片)
///   4. Your libraries (媒体库 · 最底部)
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 与轮播页对齐的封面艺术列表 · 驱动氛围背景
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);

  /// 轮播连续页位 · 由 RecommendCarousel 驱动
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPagePosition.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    refreshImageCache(ref);
    await refreshHomeProviders(
      refreshRecentlyAdded: () => ref.refresh(recentlyAddedProvider.future),
      refreshContinueWatching: () =>
          ref.refresh(continueWatchingProvider.future),
      refreshLibraries: () => ref.refresh(librariesProvider.future),
      refreshLibraryCovers: () =>
          ref.refresh(libraryCoverImagesProvider.future),
      refreshRecommendCarousel: () =>
          ref.refresh(recommendCarouselProvider.future),
    );
  }

  void _refreshMovieSections(MovieDataChanges before) {
    if (!mounted) return;
    final now = before.latest;
    // 仅在影片数据真实变更(编辑元数据/替换封面/上报播放进度等)时刷新对应区块;
    // 封面缓存只在图片内容被替换时才重新拉取。
    if (now.metadata != before.metadata || now.images != before.images) {
      if (now.images != before.images) refreshImageCache(ref);
      ref.invalidate(recentlyAddedProvider);
      ref.invalidate(recommendCarouselProvider);
    }
    if (now.progress != before.progress || now.metadata != before.metadata) {
      ref.invalidate(continueWatchingProvider);
    }
  }

  Future<void> _openRecentMovies() async {
    final changesBeforeVisit = MovieDataChanges.snapshot();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MoviesPage(
          initialFilter: MovieFilter(sortBy: 'created_at', sortOrder: 'desc'),
          maxItems: 30,
        ),
      ),
    );
    if (mounted) _refreshMovieSections(changesBeforeVisit);
  }

  Future<void> _openRecentMovie(MovieListItem movie) async {
    final changesBeforeVisit = MovieDataChanges.snapshot(movieId: movie.id);
    unawaited(ref.read(homeMovieViewStateProvider).markMovieViewed(movie.id));
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movie.id)),
    );
    if (mounted) _refreshMovieSections(changesBeforeVisit);
  }

  /// 轮播数据变化时同步封面艺术列表(与页位一一对应,含无封面占位)
  void _syncHeroArts(List<MovieListItem> items) {
    final urlBuilder = ref.read(imageUrlBuilderProvider);
    HeroArt toArt(MovieListItem movie) {
      final uuid = movie.fanartUuid ?? movie.posterUuid ?? movie.thumbUuid;
      return HeroArt(
        movieId: movie.id,
        url: uuid == null || uuid.isEmpty ? '' : urlBuilder(uuid),
      );
    }

    final arts = [for (final movie in items) toArt(movie)];
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

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final recent = ref.watch(recentlyAddedProvider);
    final continueW = ref.watch(continueWatchingProvider);
    final carousel = ref.watch(recommendCarouselProvider);
    final libraries = ref.watch(librariesProvider);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final viewedMovieIds = ref
        .watch(homeMovieViewStateProvider)
        .viewedMovieIds();

    // hero 数据就绪且非空才渲染半屏折叠头
    final heroReady = carousel.when(
      loading: () => false,
      error: (_, __) => false,
      data: (items) => items.isNotEmpty,
    );
    carousel.whenData((items) {
      if (items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _heroArts.value.isNotEmpty) {
            _heroArts.value = const [];
          }
        });
      } else {
        _syncHeroArts(items);
      }
    });

    return HomePageScaffold(
      heroArts: _heroArts,
      heroPosition: _heroPagePosition,
      heroReady: heroReady,
      hero: carousel.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) => Stack(
          children: [
            Positioned.fill(
              child: RecommendCarousel(
                items: items,
                urlBuilder: urlBuilder,
                pagePosition: _heroPagePosition,
                onMovieReturned: _refreshMovieSections,
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: HomeGreetingRow(onHero: true),
            ),
          ],
        ),
      ),
      heroFallback: const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: HomeGreetingRow(onHero: false),
      ),
      onRefresh: _refreshHome,
      slivers: [
        // -------- 2. Continue Watching --------
        continueW.when(
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (items) {
            if (items.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: _ContinueWatchingSection(
                items: items,
                urlBuilder: urlBuilder,
                onMovieReturned: _refreshMovieSections,
              ),
            );
          },
        ),

        // -------- 3. Recently Added --------
        SliverToBoxAdapter(
          child: HomeMovieSection<PagedResult<MovieListItem>, MovieListItem>(
            title: l.homeFreshTitle,
            value: recent,
            itemsOf: (paged) => paged.items,
            onRetry: () => ref.invalidate(recentlyAddedProvider),
            itemKeyBuilder: (movie) => movie.id,
            trailing: TextButton.icon(
              onPressed: () => unawaited(_openRecentMovies()),
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              label: Text(
                l.homeSeeAll,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            itemBuilder: (context, movie) {
              final isNew = isUnreadRecentlyAddedMovie(movie, viewedMovieIds);
              return Stack(
                children: [
                  MovieCard(
                    movie: movie,
                    posterUrlBuilder: urlBuilder,
                    onTap: () => _openRecentMovie(movie),
                  ),
                  if (isNew)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // -------- 4. Your libraries (最底部) --------
        SliverToBoxAdapter(
          child: libraries.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (libs) {
              if (libs.isEmpty) return const SizedBox.shrink();
              return _CollectionsSection(
                libraries: libs,
                onMovieReturned: _refreshMovieSections,
              );
            },
          ),
        ),
      ],
      heroMaxHeight: MediaQuery.sizeOf(context).height * 0.5,
    );
  }
}

// ============ Continue Watching ============
class _ContinueWatchingSection extends StatelessWidget {
  const _ContinueWatchingSection({
    required this.items,
    required this.urlBuilder,
    required this.onMovieReturned,
  });
  final List<MovieListItem> items;
  final String Function(String) urlBuilder;
  final ValueChanged<MovieDataChanges> onMovieReturned;

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        (MediaQuery.sizeOf(context).width * 0.7)
            .clamp(260.0, 520.0)
            .toDouble() *
        0.72;
    final coverHeight = cardWidth / (16 / 10);
    const titleAreaHeight = 60.0;

    return Padding(
      // 顶部间距与全出血 hero 衔接
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              AppL10n.of(context).homePickupTitle,
              style: AppText.sectionTitle(context),
            ),
          ),
          const SizedBox(height: _homeSectionTitleGap),
          SizedBox(
            height: coverHeight + 8 + titleAreaHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => SizedBox(
                width: cardWidth,
                child: _ContinueWatchingCard(
                  key: ValueKey(items[index].id),
                  movie: items[index],
                  urlBuilder: urlBuilder,
                  onMovieReturned: onMovieReturned,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({
    super.key,
    required this.movie,
    required this.urlBuilder,
    required this.onMovieReturned,
  });

  final MovieListItem movie;
  final String Function(String) urlBuilder;
  final ValueChanged<MovieDataChanges> onMovieReturned;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final progress = (movie.watchRecord?.progressRatio ?? 0).clamp(0.0, 1.0);
    final minutesLeft = movie.runtime != null
        ? (movie.runtime! * (1 - progress)).round()
        : null;

    return PrivacyAwareInkWell(
      movieId: movie.id,
      borderRadius: 22,
      onTap: () async {
        final changesBeforeVisit = MovieDataChanges.snapshot(movieId: movie.id);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movie.id)),
        );
        if (context.mounted) onMovieReturned(changesBeforeVisit);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrivacyMask(
                    movieId: movie.id,
                    radius: 0,
                    child: Poster(
                      url: movie.fanartUuid != null
                          ? urlBuilder(movie.fanartUuid!)
                          : (movie.posterUuid != null
                                ? urlBuilder(movie.posterUuid!)
                                : null),
                      title: movie.title,
                      year: movie.year,
                      aspectRatio: 16 / 10,
                      radius: 0,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                button: true,
                                label: AppL10n.of(context).homeResume,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    final changesBeforeVisit =
                                        MovieDataChanges.snapshot(
                                          movieId: movie.id,
                                        );
                                    await VideoPlayerPage.open(
                                      context,
                                      movieId: movie.id,
                                      title: movie.title,
                                    );
                                    // 播放器确实上报过进度时刷新继续观看区块。
                                    onMovieReturned(changesBeforeVisit);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              if (minutesLeft != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  AppL10n.of(
                                    context,
                                  ).homeMinutesLeft(minutesLeft),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              valueColor: AlwaysStoppedAnimation(c.accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          PrivacyText(
            movieId: movie.id,
            text: movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if (movie.year != null || movie.runtime != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (movie.year != null) '${movie.year}',
                  if (movie.runtime != null && movie.runtime! > 0)
                    '${movie.runtime}m',
                ].join(' · '),
                style: TextStyle(
                  color: c.muted,
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============ Your libraries (媒体库 · 最底部) ============
class _CollectionsSection extends ConsumerWidget {
  const _CollectionsSection({
    required this.libraries,
    required this.onMovieReturned,
  });
  final List<LibraryItem> libraries;
  final ValueChanged<MovieDataChanges> onMovieReturned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 封面单独渐进加载 · 未就绪时卡片先以品牌渐变呈现
    final covers =
        ref.watch(libraryCoverImagesProvider).value ??
        const <int, Uint8List>{};
    return Padding(
      padding: const EdgeInsets.only(top: _homeSectionGap, bottom: 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 卡片尺寸沿用两侧 22 留白的可用宽度，列表本身全宽可滚到屏幕边缘
          final cardWidth = collectionCardWidth(constraints.maxWidth - 44);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  AppL10n.of(context).homeYourLibraries,
                  style: AppText.sectionTitle(context),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: cardWidth / (5 / 3),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: libraries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => SizedBox(
                    key: ValueKey(libraries[i].id),
                    width: cardWidth,
                    child: _LibraryCard(
                      library: libraries[i],
                      hue: AppHues.all[i % AppHues.all.length],
                      cover: covers[libraries[i].id],
                      onMovieReturned: onMovieReturned,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.hue,
    required this.onMovieReturned,
    this.cover,
  });
  final LibraryItem library;
  final int hue;
  final ValueChanged<MovieDataChanges> onMovieReturned;

  /// 后端内联返回的封面图字节 · 为空时回退品牌渐变
  final Uint8List? cover;

  @override
  Widget build(BuildContext context) {
    return PrivacyAwareInkWell(
      movieId: library.id,
      scope: PrivacyScope.library,
      onTap: () async {
        final changesBeforeVisit = MovieDataChanges.snapshot();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LibraryMoviesPage(library: library),
          ),
        );
        if (context.mounted) onMovieReturned(changesBeforeVisit);
      },
      borderRadius: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 5 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景: 封面就绪后淡入替换品牌渐变
              PrivacyMask(
                movieId: library.id,
                scope: PrivacyScope.library,
                radius: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: cover != null
                      ? KeyedSubtree(
                          key: ValueKey('cover-${library.id}'),
                          child: Image.memory(cover!, fit: BoxFit.cover),
                        )
                      : KeyedSubtree(
                          key: ValueKey('hue-$hue'),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppHues.top(hue), AppHues.bottom(hue)],
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -30,
                                  right: -30,
                                  width: 100,
                                  height: 100,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppHues.highlight(hue),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              // 封面上的压暗渐变,保证白色文字可读
              if (cover != null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                        Colors.black87,
                      ],
                      stops: [0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrivacyText(
                        movieId: library.id,
                        scope: PrivacyScope.library,
                        text: library.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppL10n.of(context).libraryCount(library.fileCount),
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
