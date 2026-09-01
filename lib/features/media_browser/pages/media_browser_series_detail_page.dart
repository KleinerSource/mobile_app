import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/playback/media_browser_playback.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/shared/poster.dart';

/// MediaBrowser 剧集详情页：季切换 + 集列表。
///
/// 每一集展示缩略图、季集号、标题与观看状态；点击直接从当前进度
/// （或下一待看集）开始播放。
class MediaBrowserSeriesDetailPage extends ConsumerStatefulWidget {
  const MediaBrowserSeriesDetailPage({super.key, required this.seriesId});

  final String seriesId;

  @override
  ConsumerState<MediaBrowserSeriesDetailPage> createState() =>
      _MediaBrowserSeriesDetailPageState();
}

class _MediaBrowserSeriesDetailPageState
    extends ConsumerState<MediaBrowserSeriesDetailPage> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPosition = ValueNotifier(0.0);
  String? _selectedSeasonId;
  bool _actionBusy = false;

  String get _seriesId => widget.seriesId;

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPosition.dispose();
    super.dispose();
  }

  void _syncHeroArt(MediaBrowserItem series, MediaBrowserServerUrls? urls) {
    final url = urls == null
        ? ''
        : series.backdropImageTags.isEmpty
        ? (series.primaryImageTag == null ? '' : urls.poster(series.id))
        : urls.backdrop(series.id);
    final art = HeroArt(movieId: series.id, url: url);
    final current = _heroArts.value;
    if (current.length == 1 &&
        current.first.movieId == art.movieId &&
        current.first.url == art.url) {
      return;
    }
    _heroArts.value = [art];
  }

  Future<void> _toggleFavorite(MediaBrowserItem series) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(mediaBrowserMediaRepositoryProvider)
          .markFavorite(series.id, !series.userData.isFavorite);
      _invalidateDetail();
    } catch (error) {
      _showError(toApiException(error).message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _invalidateDetail() {
    final serverId = ref.read(serverConfigProvider)?.activeServerId ?? '';
    ref.invalidate(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(serverId: serverId, itemId: _seriesId),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final detail = ref.watch(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(serverId: serverId, itemId: _seriesId),
      ),
    );
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败', style: AppText.sectionTitle(context)),
              const SizedBox(height: 8),
              Text(toApiException(error).message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(
                  mediaBrowserItemDetailProvider(
                    MediaBrowserItemDetailRequest(
                      serverId: serverId,
                      itemId: _seriesId,
                    ),
                  ),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (series) {
          _syncHeroArt(series, urls.value);
          return MovieDetailScaffold(
            heroArts: _heroArts,
            heroPosition: _heroPosition,
            hero: MovieDetailHero(
              imageUrl: series.primaryImageTag == null
                  ? null
                  : urls.value?.poster(series.id),
              title: series.name,
              year: series.productionYear,
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                  child: MovieDetailTitle(
                    title: series.name,
                    year: series.productionYear,
                    rating: series.communityRating,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _actionBusy
                              ? null
                              : () => _toggleFavorite(series),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: series.userData.isFavorite
                                ? colors.accent
                                : colors.text,
                            side: BorderSide(
                              color: series.userData.isFavorite
                                  ? colors.accent.withValues(alpha: 0.55)
                                  : colors.cardBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: Icon(
                            series.userData.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                          ),
                          label: Text(
                            series.userData.isFavorite ? '已收藏' : '收藏',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (series.overview?.trim().isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    child: MovieDetailPlot(plot: series.overview!),
                  ),
                ),
              SliverToBoxAdapter(
                child: _SeasonSection(
                  seriesId: _seriesId,
                  selectedSeasonId: _selectedSeasonId,
                  onSeasonSelected: (seasonId) =>
                      setState(() => _selectedSeasonId = seasonId),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }
}

/// 季切换 chips + 对应集列表。
class _SeasonSection extends ConsumerWidget {
  const _SeasonSection({
    required this.seriesId,
    required this.selectedSeasonId,
    required this.onSeasonSelected,
  });

  final String seriesId;
  final String? selectedSeasonId;
  final ValueChanged<String> onSeasonSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final seasons = ref.watch(
      mediaBrowserSeasonsProvider(
        MediaBrowserSeasonsRequest(serverId: serverId, seriesId: seriesId),
      ),
    );
    final colors = appColors(context);
    return seasons.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
        child: Text(
          toApiException(error).message,
          style: TextStyle(color: colors.muted),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('暂无剧集分集', style: AppText.meta(context))),
          );
        }
        final activeId =
            selectedSeasonId == null ||
                list.every((season) => season.id != selectedSeasonId)
            ? list.first.id
            : selectedSeasonId!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: MovieDetailSection(
                title: '分集',
                bottom: 0,
                child: SizedBox.shrink(),
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final season = list[index];
                  final selected = season.id == activeId;
                  return _SeasonChip(
                    label: _seasonLabel(season),
                    selected: selected,
                    onTap: () => onSeasonSelected(season.id),
                  );
                },
              ),
            ),
            _EpisodeList(seriesId: seriesId, seasonId: activeId),
          ],
        );
      },
    );
  }
}

String _seasonLabel(MediaBrowserItem season) {
  final index = season.indexNumber;
  if (index == null) return season.name;
  if (index == 0) return '特别篇';
  return '第 $index 季';
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.15)
              : colors.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colors.accent.withValues(alpha: 0.5)
                : colors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.accent : colors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EpisodeList extends ConsumerWidget {
  const _EpisodeList({required this.seriesId, required this.seasonId});

  final String seriesId;
  final String seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final episodes = ref.watch(
      mediaBrowserEpisodesProvider(
        MediaBrowserEpisodesRequest(
          serverId: serverId,
          seriesId: seriesId,
          seasonId: seasonId,
        ),
      ),
    );
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    final colors = appColors(context);
    return episodes.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
        child: Row(
          children: [
            Expanded(
              child: Text(
                toApiException(error).message,
                style: TextStyle(color: colors.muted),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(
                mediaBrowserEpisodesProvider(
                  MediaBrowserEpisodesRequest(
                    serverId: serverId,
                    seriesId: seriesId,
                    seasonId: seasonId,
                  ),
                ),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('本季暂无剧集', style: AppText.meta(context))),
          );
        }
        return Column(
          children: [
            for (final episode in page.items)
              _EpisodeTile(
                episode: episode,
                imageUrl: episode.primaryImageTag == null
                    ? null
                    : urls.value?.thumb(episode.id),
                onTap: () =>
                    openMediaBrowserPlayback(context, ref, item: episode),
                // 与 OMM/电影详情页一致：长按先选内核（libmpv / KSPlayer）。
                onLongPress: playbackEnginePickerEnabled
                    ? () => openMediaBrowserPlaybackWithEnginePicker(
                        context,
                        ref,
                        item: episode,
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.imageUrl,
    required this.onTap,
    this.onLongPress,
  });

  final MediaBrowserItem episode;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final played = episode.userData.played;
    final resumePct = _resumePct(episode);
    final number = episode.indexNumber ?? 0;
    final runtimeMinutes = episode.runtimeMinutes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 112,
                    height: 63,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Poster(
                          url: imageUrl,
                          title: episode.name,
                          aspectRatio: 16 / 9,
                          radius: 0,
                        ),
                        if (played)
                          Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        if (!played && resumePct > 0)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: resumePct,
                              minHeight: 3,
                              backgroundColor: Colors.black45,
                              valueColor: AlwaysStoppedAnimation(colors.accent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        runtimeMinutes > 0
                            ? '第 $number 集 · $runtimeMinutes 分钟'
                            : '第 $number 集',
                        style: AppText.movieCardMeta(context).copyWith(
                          color: played ? colors.muted : colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        episode.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardTitle(
                          context,
                        ).copyWith(color: played ? colors.muted : colors.text),
                      ),
                      if (episode.overview?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          episode.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.movieCardMeta(
                            context,
                          ).copyWith(color: colors.muted),
                        ),
                      ],
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

  double _resumePct(MediaBrowserItem episode) {
    final runtime = mediaBrowserTicksToSeconds(episode.runTimeTicks);
    if (runtime <= 0) return 0;
    return (episode.userData.resumeSeconds / runtime).clamp(0.0, 1.0);
  }
}
