import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/playback/media_browser_playback.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_action_button.dart';
import 'package:omm/features/media_browser/widgets/media_browser_cast_section.dart';
import 'package:omm/features/media_browser/widgets/media_browser_media_info_section.dart';
import 'package:omm/features/media_browser/widgets/media_browser_next_up_section.dart';
import 'package:omm/features/media_browser/widgets/media_browser_similar_section.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/continue_watching_section.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';

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
    final url = urls?.heroImage(series) ?? '';
    final art = HeroArt(
      movieId: series.id,
      url: url,
      imageHeaders: urls?.imageHeaders,
    );
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
    final config = ref.watch(mediaBrowserConfigProvider);
    final seriesNextUp = config?.project == ServerProject.jellyfin
        ? ref.watch(
            mediaBrowserSeriesNextUpProvider(
              MediaBrowserSeriesNextUpRequest(
                serverId: serverId,
                seriesId: _seriesId,
              ),
            ),
          )
        : null;
    final similar = ref.watch(
      mediaBrowserSimilarProvider(
        MediaBrowserSimilarRequest(serverId: serverId, itemId: _seriesId),
      ),
    );
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
                  : urls.value?.poster(series.id, tag: series.primaryImageTag),
              title: series.name,
              year: series.productionYear,
              imageHeaders: urls.value?.imageHeaders,
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
                  child: MediaBrowserActionButton(
                    icon: series.userData.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: series.userData.isFavorite ? '已收藏' : '收藏',
                    active: series.userData.isFavorite,
                    onPressed: _actionBusy
                        ? null
                        : () => _toggleFavorite(series),
                    padding: const EdgeInsets.symmetric(vertical: 11),
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
              if (_castOf(series).isNotEmpty)
                SliverToBoxAdapter(
                  child: MediaBrowserCastSection(
                    people: _castOf(series),
                    urls: urls.value,
                    // fnos 列表接口不支持按人物过滤，点击仅对 Emby/Jellyfin 开放。
                    onOpenPerson:
                        ref.watch(mediaBrowserConfigProvider)?.project ==
                            ServerProject.feiniu
                        ? null
                        : (person) => openMediaBrowserPersonWorks(
                            context,
                            personId: person.id,
                            personName: person.name,
                          ),
                  ),
                ),
              // 剧集条目一般没有文件级媒体源；有（如单文件剧集）才展示。
              SliverToBoxAdapter(
                child: MediaBrowserMediaInfoSection(item: series),
              ),
              if (seriesNextUp != null)
                seriesNextUp.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, __) =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  data: (items) => items.isEmpty
                      ? const SliverToBoxAdapter(child: SizedBox.shrink())
                      : SliverToBoxAdapter(
                          child: MediaBrowserNextUpSection(items: items),
                        ),
                ),
              similar.when(
                loading: () =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (items) => items.isEmpty
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : SliverToBoxAdapter(
                        child: MediaBrowserSimilarSection(items: items),
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

List<MediaBrowserPerson> _castOf(MediaBrowserItem series) => [
  for (final person in series.people)
    if (person.type == 'Actor' && person.name.trim().isNotEmpty) person,
];

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
            MovieDetailFullBleedSection(
              bottom: 14,
              header: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('分集', style: AppText.sectionTitle(context)),
              ),
              child: SizedBox(
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
        return ContinueWatchingSection(
          showTitle: false,
          topPadding: 8,
          entries: [
            for (final episode in page.items)
              ContinueWatchingEntry(
                privacyId: episode.id,
                title: episode.name,
                meta: _episodeMeta(context, episode),
                coverUrl: urls.value?.heroImage(episode),
                imageHeaders: urls.value?.imageHeaders,
                progress: _episodeProgress(episode),
                minutesLeft: _episodeMinutesLeft(episode),
                onOpen: () =>
                    openMediaBrowserPlayback(context, ref, item: episode),
                onResume: () =>
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

String _episodeMeta(BuildContext context, MediaBrowserItem episode) {
  final number = episode.indexNumber ?? 0;
  final runtimeMinutes = episode.runtimeMinutes;
  return runtimeMinutes > 0
      ? '第 $number 集 · $runtimeMinutes 分钟'
      : '第 $number 集';
}

double _episodeProgress(MediaBrowserItem episode) {
  if (episode.userData.played) return 1;
  final runtime = mediaBrowserTicksToSeconds(episode.runTimeTicks);
  if (runtime <= 0) return 0;
  return (episode.userData.resumeSeconds / runtime).clamp(0.0, 1.0);
}

int? _episodeMinutesLeft(MediaBrowserItem episode) {
  final runtimeMinutes = episode.runtimeMinutes;
  if (runtimeMinutes <= 0) return null;
  return (runtimeMinutes * (1 - _episodeProgress(episode))).round();
}
