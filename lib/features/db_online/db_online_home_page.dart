import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/db_online_movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import '../home/recommend_carousel.dart';
import '../home/server_switcher.dart';
import 'db_online_movie_card.dart';
import 'db_online_home_providers.dart';
import 'db_online_movie_detail_page.dart';

export 'db_online_movie_card.dart';

class DbOnlineHomePage extends ConsumerWidget {
  const DbOnlineHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: RefreshIndicator(
        onRefresh: () async {
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
        },
        child: GlowBackground(
          child: SafeArea(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 120),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DBONLINE', style: AppText.eyebrow(context)),
                          const SizedBox(height: 4),
                          Text('首页', style: AppText.pageTitle(context)),
                        ],
                      ),
                    ),
                    const HomeServerSwitcher(),
                  ],
                ),
                const SizedBox(height: 22),
                _DbOnlineRecommendSection(
                  title: '佳片推荐',
                  value: ref.watch(dbOnlineRecommendProvider),
                  config: config,
                  onRetry: () => ref.invalidate(dbOnlineRecommendProvider),
                ),
                const SizedBox(height: 24),
                _DbOnlineSection(
                  title: '最近更新',
                  value: ref.watch(dbOnlineLatestUpdatedProvider),
                  config: config,
                  onRetry: () => ref.invalidate(dbOnlineLatestUpdatedProvider),
                ),
                const SizedBox(height: 24),
                _DbOnlineSection(
                  title: '最新上架',
                  value: ref.watch(dbOnlineLatestReleasedProvider),
                  config: config,
                  onRetry: () => ref.invalidate(dbOnlineLatestReleasedProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DbOnlineRecommendSection extends StatelessWidget {
  const _DbOnlineRecommendSection({
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
    final heroHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.sectionTitle(context)),
        const SizedBox(height: 10),
        value.when(
          loading: () => SizedBox(
            height: heroHeight,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Container(
            height: 150,
            alignment: Alignment.center,
            decoration: settingsCardDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toApiException(error).message,
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
          data: (items) => items.isEmpty
              ? Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: settingsCardDecoration(context),
                  child: Text('暂无数据', style: TextStyle(color: colors.muted)),
                )
              : SizedBox(
                  height: heroHeight,
                  child: RecommendCarousel.dbOnline(
                    items: items,
                    imageUrlBuilder: (movie) {
                      final raw = movie.thumbUrl ?? movie.coverUrl;
                      if (config == null || raw == null) return '';
                      return resolveServerUrl(config!, raw);
                    },
                    onMovieTap: (context, movie) =>
                        _openDbOnlineMovie(context, movie),
                  ),
                ),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.sectionTitle(context)),
        const SizedBox(height: 10),
        value.when(
          loading: () => const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Container(
            height: 130,
            alignment: Alignment.center,
            decoration: settingsCardDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toApiException(error).message,
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
          data: (items) => items.isEmpty
              ? Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: settingsCardDecoration(context),
                  child: Text('暂无数据', style: TextStyle(color: colors.muted)),
                )
              : SizedBox(
                  // 与 OMM 影片卡片的 2:3 海报 + 标题/元数据高度保持一致。
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) => DbOnlineMovieCard(
                      movie: items[index],
                      config: config,
                      onTap: () {
                        unawaited(_openDbOnlineMovie(context, items[index]));
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
