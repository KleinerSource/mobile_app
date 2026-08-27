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
import 'db_online_home_providers.dart';
import 'db_online_movie_detail_page.dart';

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
                Text('DBONLINE', style: AppText.eyebrow(context)),
                const SizedBox(height: 4),
                Text('首页', style: AppText.pageTitle(context)),
                const SizedBox(height: 22),
                _DbOnlineSection(
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
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) => DbOnlineMovieCard(
                      movie: items[index],
                      config: config,
                      onTap: () {
                        final movie = items[index];
                        final code = movie.number.trim();
                        final videoId = movie.id.trim();
                        if (code.isEmpty && videoId.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => code.isNotEmpty
                                ? DbOnlineMovieDetailPage(code: code)
                                : DbOnlineMovieDetailPage.byVideoId(
                                    videoId: videoId,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class DbOnlineMovieCard extends StatelessWidget {
  const DbOnlineMovieCard({
    super.key,
    required this.movie,
    required this.config,
    this.onTap,
  });

  final DbOnlineMovie movie;
  final ServerConfig? config;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final imageValue = movie.thumbUrl ?? movie.coverUrl;
    final imageUrl = imageValue == null || config == null
        ? null
        : resolveServerUrl(config!, imageValue);
    return SizedBox(
      width: 142,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: settingsCardDecoration(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageUrl == null
                            ? ColoredBox(
                                color: colors.surface,
                                child: const Icon(Icons.movie_outlined),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: colors.surface,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                              ),
                        if (movie.canPlay)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Semantics(
                              container: true,
                              label: '在线播放',
                              child: Tooltip(
                                message: '在线播放',
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(
                                      alpha: 0.92,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          '在线播放',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.number.isEmpty ? '未命名番号' : movie.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          movie.title.isEmpty ? '未命名影片' : movie.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _metaText(movie),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _metaText(DbOnlineMovie movie) {
  final parts = <String>[];
  if (movie.releaseDate != null) parts.add(movie.releaseDate!);
  if (movie.duration != null) parts.add(movie.duration!);
  if (movie.library != null) parts.add(movie.library!);
  if (movie.magnetsCount > 0) parts.add('${movie.magnetsCount} 磁链');
  if (movie.hasCnsub) parts.add('中字');
  if (movie.score != null) parts.add('评分 ${movie.score!.toStringAsFixed(1)}');
  return parts.isEmpty ? '暂无信息' : parts.join(' · ');
}
