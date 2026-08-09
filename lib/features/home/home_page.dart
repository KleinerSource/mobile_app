import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/library.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../../shared/poster.dart';
import '../libraries/libraries_providers.dart';
import '../libraries/library_movies_page.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movies_providers.dart';
import '../privacy/privacy_mask.dart';
import 'home_providers.dart';
import 'recommend_carousel.dart';

/// md_center 首页
/// 模块顺序 (对齐 frontend_new Dashboard.vue):
///   1. RecommendCarousel (hero · 最近添加里 fanart 不为空的前 10 条)
///   2. Continue Watching (有观看进度未完成的)
///   3. Recently Added (横向卡片)
///   4. Your libraries (媒体库 · 最底部)
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _greeting(AppL10n l) {
    final h = DateTime.now().hour;
    if (h < 5) return l.greetingNight;
    if (h < 12) return l.greetingMorning;
    if (h < 18) return l.greetingAfternoon;
    if (h < 22) return l.greetingEvening;
    return l.greetingNight;
  }

  Future<void> _waitForRefresh(Future<Object?> future) async {
    try {
      await future;
    } catch (_) {
      // 各区块保留自己的错误状态，下拉刷新本身仍应正常结束。
    }
  }

  Future<void> _refreshHome(WidgetRef ref) async {
    refreshImageCache(ref);
    await Future.wait<void>([
      _waitForRefresh(ref.refresh(recentlyAddedProvider.future)),
      _waitForRefresh(ref.refresh(continueWatchingProvider.future)),
      _waitForRefresh(ref.refresh(librariesProvider.future)),
    ]);
    await _waitForRefresh(ref.refresh(recommendCarouselProvider.future));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final recent = ref.watch(recentlyAddedProvider);
    final continueW = ref.watch(continueWatchingProvider);
    final carousel = ref.watch(recommendCarouselProvider);
    final libraries = ref.watch(librariesProvider);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refreshHome(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            // -------- 顶部问候 --------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                child: Text(
                  _greeting(l),
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.24,
                  ),
                ),
              ),
            ),

            // -------- 1. 推荐轮播 (hero) --------
            carousel.when(
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(height: 248, child: Center(child: CircularProgressIndicator())),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (items) {
                if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    child: RecommendCarousel(items: items, urlBuilder: urlBuilder),
                  ),
                );
              },
            ),

            // -------- 2. Continue Watching --------
            continueW.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (items) {
                if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: _ContinueWatchingSection(
                    items: items,
                    urlBuilder: urlBuilder,
                  ),
                );
              },
            ),

            // -------- 3. Recently Added --------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        l.homeFreshTitle,
                        style: AppText.sectionTitle(context),
                      ),
                    ),
                    Text(
                      l.homeSeeAll,
                      style: TextStyle(
                        color: c.accent,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            recent.when(
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text('加载失败: $e', style: AppText.body(context)),
                ),
              ),
              data: (paged) => SliverToBoxAdapter(
                child: _RecentRow(items: paged.items, urlBuilder: urlBuilder),
              ),
            ),

            // -------- 4. Your libraries (最底部) --------
            SliverToBoxAdapter(
              child: libraries.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (libs) {
                  if (libs.isEmpty) return const SizedBox.shrink();
                  return _CollectionsSection(libraries: libs);
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Continue Watching ============
class _ContinueWatchingSection extends StatelessWidget {
  const _ContinueWatchingSection({required this.items, required this.urlBuilder});
  final List<MovieListItem> items;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        (MediaQuery.sizeOf(context).width * 0.7).clamp(260.0, 520.0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppL10n.of(context).homePickupTitle.toUpperCase(),
            style: AppText.eyebrow(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardWidth / (16 / 10),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => SizedBox(
                width: cardWidth,
                child: _ContinueWatchingCard(
                  movie: items[index],
                  urlBuilder: urlBuilder,
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
  const _ContinueWatchingCard({required this.movie, required this.urlBuilder});

  final MovieListItem movie;
  final String Function(String) urlBuilder;

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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movie.id)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrivacyText(
                    movieId: movie.id,
                    text: (movie.seriesName ?? movie.title).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  PrivacyText(
                    movieId: movie.id,
                    text: movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MovieDetailPage(movieId: movie.id),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Resume',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            valueColor: AlwaysStoppedAnimation(c.accent),
                          ),
                        ),
                      ),
                      if (minutesLeft != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          AppL10n.of(context).homeMinutesLeft(minutesLeft),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
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

// ============ Recently Added (横向卡片) ============
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.items, required this.urlBuilder});
  final List<MovieListItem> items;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final it = items[i];
          return SizedBox(
            width: 132,
            child: Stack(
              children: [
                MovieCard(
                  movie: it,
                  posterUrlBuilder: urlBuilder,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MovieDetailPage(movieId: it.id)),
                  ),
                ),
                if (i == 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
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
            ),
          );
        },
      ),
    );
  }
}

// ============ Your libraries (媒体库 · 最底部) ============
class _CollectionsSection extends StatelessWidget {
  const _CollectionsSection({required this.libraries});
  final List<LibraryItem> libraries;

  @override
  Widget build(BuildContext context) {
    final all = libraries.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppL10n.of(context).homeYourLibraries,
              style: AppText.sectionTitle(context)),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (ctx, cons) {
            const gap = 10.0;
            final w = (cons.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(all.length, (i) {
                final hue = AppHues.all[i % AppHues.all.length];
                return SizedBox(
                  width: w,
                  child: _LibraryCard(library: all[i], hue: hue),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.library, required this.hue});
  final LibraryItem library;
  final int hue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LibraryMoviesPage(library: library)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 5 / 3,
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
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '◆',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          library.name,
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
                          '${library.fileCount} titles',
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
