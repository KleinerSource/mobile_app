import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/db_online_movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/actor_detail_header.dart';
import '../home/hero_backdrop.dart';
import '../home/recommend_carousel.dart';
import '../home/server_switcher.dart';
import 'db_online_home_providers.dart';
import 'db_online_movie_card.dart';
import 'db_online_movie_detail_page.dart';

export 'db_online_movie_card.dart';

const _dbOnlineSectionGap = 24.0;
const _dbOnlineSectionTitleGap = 14.0;

/// dbonline 首页复用 OMM 首页的氛围背景、半屏折叠 hero、轮播和顶部服务器切换器。
/// 仅替换数据提供者和详情跳转，避免维护另一套首页布局。
class DbOnlineHomePage extends ConsumerStatefulWidget {
  const DbOnlineHomePage({super.key});

  @override
  ConsumerState<DbOnlineHomePage> createState() => _DbOnlineHomePageState();
}

class _DbOnlineHomePageState extends ConsumerState<DbOnlineHomePage> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPagePosition.dispose();
    super.dispose();
  }

  String _greeting(AppL10n l) {
    final hour = DateTime.now().hour;
    if (hour < 5) return l.greetingNight;
    if (hour < 12) return l.greetingMorning;
    if (hour < 18) return l.greetingAfternoon;
    if (hour < 22) return l.greetingEvening;
    return l.greetingNight;
  }

  Future<void> _refreshHome() async {
    ref.invalidate(dbOnlineRecommendProvider);
    ref.invalidate(dbOnlineLatestUpdatedProvider);
    ref.invalidate(dbOnlineLatestReleasedProvider);
    await Future.wait([
      ref
          .read(dbOnlineRecommendProvider.future)
          .catchError((_) => const <DbOnlineMovie>[]),
      ref
          .read(dbOnlineLatestUpdatedProvider.future)
          .catchError((_) => const <DbOnlineMovie>[]),
      ref
          .read(dbOnlineLatestReleasedProvider.future)
          .catchError((_) => const <DbOnlineMovie>[]),
    ]);
  }

  void _syncHeroArts(List<DbOnlineMovie> items, ServerConfig? config) {
    final arts = [
      for (final movie in items)
        HeroArt(
          movieId: _dbOnlineHeroId(
            movie.id.trim().isNotEmpty ? movie.id : movie.number,
          ),
          url: _dbOnlineImageUrl(movie, config, horizontal: true),
        ),
    ];
    final current = _heroArts.value;
    final same =
        current.length == arts.length &&
        [
          for (var i = 0; i < arts.length; i++)
            current[i].movieId == arts[i].movieId &&
                current[i].url == arts[i].url,
        ].every((value) => value);
    if (!same) _heroArts.value = arts;
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final config = ref.watch(serverConfigProvider);
    final recommend = ref.watch(dbOnlineRecommendProvider);
    final updated = ref.watch(dbOnlineLatestUpdatedProvider);
    final released = ref.watch(dbOnlineLatestReleasedProvider);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroMaxHeight = screenHeight * 0.5;
    final heroMinHeight = heroMaxHeight * 0.62;
    final topInset = MediaQuery.paddingOf(context).top;

    Widget greetingRow({required bool onHero}) => Padding(
      padding: EdgeInsets.fromLTRB(22, 12 + topInset, 22, 0),
      child: Row(
        children: [
          Expanded(
            child: onHero
                ? IgnorePointer(
                    child: Text(
                      _greeting(l),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.24,
                      ),
                    ),
                  )
                : Text(
                    _greeting(l),
                    style: TextStyle(
                      color: colors.muted,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.24,
                    ),
                  ),
          ),
          const HomeServerSwitcher(),
        ],
      ),
    );

    final heroReady = recommend.when(
      loading: () => false,
      error: (_, __) => false,
      data: (items) => items.isNotEmpty,
    );
    recommend.whenData((items) {
      if (items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _heroArts.value.isNotEmpty) {
            _heroArts.value = const [];
          }
        });
      } else {
        _syncHeroArts(items, config);
      }
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        HeroBackdrop(arts: _heroArts, position: _heroPagePosition),
        SafeArea(
          top: false,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (heroReady)
                  recommend.when(
                    loading: () =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (_, __) =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    data: (items) => SliverPersistentHeader(
                      pinned: false,
                      delegate: CollapsibleHeroDelegate(
                        minHeight: heroMinHeight,
                        maxHeight: heroMaxHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: RecommendCarousel.dbOnline(
                                items: items,
                                imageUrlBuilder: (movie) => _dbOnlineImageUrl(
                                  movie,
                                  config,
                                  horizontal: true,
                                ),
                                pagePosition: _heroPagePosition,
                                onMovieTap: _openDbOnlineMovie,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: greetingRow(onHero: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        greetingRow(onHero: false),
                        _DbOnlineRecommendFallback(
                          value: recommend,
                          height: heroMaxHeight,
                          onRetry: () =>
                              ref.invalidate(dbOnlineRecommendProvider),
                        ),
                      ],
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _DbOnlineSection(
                    title: '最近更新',
                    value: updated,
                    config: config,
                    onRetry: () =>
                        ref.invalidate(dbOnlineLatestUpdatedProvider),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DbOnlineSection(
                    title: '最新上架',
                    value: released,
                    config: config,
                    onRetry: () =>
                        ref.invalidate(dbOnlineLatestReleasedProvider),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DbOnlineRecommendFallback extends StatelessWidget {
  const _DbOnlineRecommendFallback({
    required this.value,
    required this.height,
    required this.onRetry,
  });

  final AsyncValue<List<DbOnlineMovie>> value;
  final double height;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return SizedBox(
      height: height,
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    toApiException(error).message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Text('暂无数据', style: TextStyle(color: colors.muted)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

Future<void> _openDbOnlineMovie(
  BuildContext context,
  DbOnlineMovie movie,
) async {
  final code = movie.number.trim();
  final videoId = movie.id.trim();
  if (code.isEmpty && videoId.isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => code.isNotEmpty
          ? DbOnlineMovieDetailPage(code: code)
          : DbOnlineMovieDetailPage.byVideoId(videoId: videoId),
    ),
  );
}

class _DbOnlineSection extends StatelessWidget {
  const _DbOnlineSection({
    required this.title,
    required this.value,
    required this.config,
    required this.onRetry,
  });

  final String title;
  final AsyncValue<List<DbOnlineMovie>> value;
  final ServerConfig? config;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(top: _dbOnlineSectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(title, style: AppText.sectionTitle(context)),
          ),
          const SizedBox(height: _dbOnlineSectionTitleGap),
          value.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        toApiException(error).message,
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                    TextButton(onPressed: onRetry, child: const Text('重试')),
                  ],
                ),
              ),
            ),
            data: (items) => items.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 268,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final movie = items[index];
                        return SizedBox(
                          key: ValueKey(
                            movie.id.isEmpty ? movie.number : movie.id,
                          ),
                          width: 132,
                          child: DbOnlineMovieCard(
                            movie: movie,
                            config: config,
                            width: 132,
                            onTap: () =>
                                unawaited(_openDbOnlineMovie(context, movie)),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _dbOnlineImageUrl(
  DbOnlineMovie movie,
  ServerConfig? config, {
  required bool horizontal,
}) {
  // dbonline 的 cover_url 是横版画报，thumb_url 是竖版缩略图；轮播优先画报。
  final primary = horizontal ? movie.coverUrl : movie.thumbUrl;
  final fallback = horizontal ? movie.thumbUrl : movie.coverUrl;
  final raw = primary?.trim().isNotEmpty == true ? primary : fallback;
  if (raw == null || raw.trim().isEmpty || config == null) return '';
  return resolveServerUrl(config, raw);
}

int _dbOnlineHeroId(String value) {
  final hash = value.codeUnits.fold(0, (result, codeUnit) {
    return result * 31 + codeUnit;
  });
  return hash == 0 ? 1 : hash;
}
