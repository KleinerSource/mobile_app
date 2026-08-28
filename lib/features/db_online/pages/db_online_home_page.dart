import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/home_movie_section.dart';
import 'package:omm/features/home/recommend_carousel.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/pages/db_online_latest_movies_page.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

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
          movieId: _dbOnlinePrivacyId(movie),
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
    final config = ref.watch(serverConfigProvider);
    final recommend = ref.watch(dbOnlineRecommendProvider);
    final updated = ref.watch(dbOnlineLatestUpdatedProvider);
    final released = ref.watch(dbOnlineLatestReleasedProvider);

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

    final heroMaxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return HomePageScaffold(
      heroArts: _heroArts,
      heroPosition: _heroPagePosition,
      heroReady: heroReady,
      hero: recommend.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) => Stack(
          children: [
            Positioned.fill(
              child: RecommendCarousel.dbOnline(
                items: items,
                imageUrlBuilder: (movie) =>
                    _dbOnlineImageUrl(movie, config, horizontal: true),
                pagePosition: _heroPagePosition,
                onMovieTap: openDbOnlineMovie,
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
      heroFallback: Column(
        children: [
          const HomeGreetingRow(onHero: false),
          _DbOnlineRecommendFallback(
            value: recommend,
            height: heroMaxHeight,
            onRetry: () => ref.invalidate(dbOnlineRecommendProvider),
          ),
        ],
      ),
      onRefresh: _refreshHome,
      slivers: [
        SliverToBoxAdapter(
          child: HomeMovieSection<List<DbOnlineMovie>, DbOnlineMovie>(
            title: '最近更新',
            value: updated,
            itemsOf: (items) => items,
            onRetry: () => ref.invalidate(dbOnlineLatestUpdatedProvider),
            trailing: _SeeAllButton(
              onPressed: () => unawaited(
                _openDbOnlineLatestMovies(context, sortBy: 'update'),
              ),
            ),
            itemKeyBuilder: (movie) =>
                movie.id.isEmpty ? movie.number : movie.id,
            itemBuilder: (context, movie) => DbOnlineMovieCard(
              movie: movie,
              config: config,
              width: 132,
              onTap: () => openDbOnlineMovieUnawaited(context, movie),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: HomeMovieSection<List<DbOnlineMovie>, DbOnlineMovie>(
            title: '最新上架',
            value: released,
            itemsOf: (items) => items,
            onRetry: () => ref.invalidate(dbOnlineLatestReleasedProvider),
            trailing: _SeeAllButton(
              onPressed: () => unawaited(
                _openDbOnlineLatestMovies(context, sortBy: 'release'),
              ),
            ),
            itemKeyBuilder: (movie) =>
                movie.id.isEmpty ? movie.number : movie.id,
            itemBuilder: (context, movie) => DbOnlineMovieCard(
              movie: movie,
              config: config,
              width: 132,
              onTap: () => openDbOnlineMovieUnawaited(context, movie),
            ),
          ),
        ),
      ],
      heroMaxHeight: heroMaxHeight,
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
      label: const Text(
        '查看全部',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

Future<void> _openDbOnlineLatestMovies(
  BuildContext context, {
  required String sortBy,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DbOnlineLatestMoviesPage(sortBy: sortBy),
    ),
  );
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

String _dbOnlinePrivacyId(DbOnlineMovie movie) {
  final id = movie.id.trim();
  return id.isEmpty ? movie.number.trim() : id;
}
