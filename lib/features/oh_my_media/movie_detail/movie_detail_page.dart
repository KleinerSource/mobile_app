import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/related_movie.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/models/actor.dart';
import 'package:omm/core/models/watch_record.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/actor_avatar.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_providers.dart';
import 'package:omm/features/oh_my_media/lists/add_to_list_sheet.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/player/video/video_player_page.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/features/player/common/player_queue.dart';
import 'package:omm/features/player/video/video_player_session_factory.dart';
import 'package:omm/features/player/common/player_settings.dart';
import 'package:omm/features/oh_my_media/resources/resource_movies_page.dart';
import 'package:omm/features/oh_my_media/person_detail/person_detail_page.dart';
import 'dbo_diff_sheet.dart';
import 'resources_sheet.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'movie_editor_sheet.dart';
import 'movie_detail_formatters.dart';
import 'movie_detail_media_viewers.dart';
import 'movie_detail_scaffold.dart';
import 'cast_section.dart';
import 'cover_badges.dart';
import 'media_stream_cards.dart';
import 'thunder_subtitle_sheet.dart';
import 'audio_extraction_sheet.dart';
import 'package:omm/features/home/home_movie_view_state.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/i18n/poster_badge_visibility_provider.dart';

class MovieDetailPage extends ConsumerStatefulWidget {
  const MovieDetailPage({
    super.key,
    required this.movieId,
    this.acknowledgeNewResources = true,
  });
  final int movieId;

  /// 已由筛选列表提前发起确认时，交给调用方等待并刷新列表。
  final bool acknowledgeNewResources;

  @override
  ConsumerState<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(homeMovieViewStateProvider).markMovieViewed(widget.movieId),
      );
      if (widget.acknowledgeNewResources) {
        unawaited(_acknowledgeResources());
      }
    });
  }

  Future<void> _acknowledgeResources() async {
    try {
      await ref
          .read(mediaRepositoryProvider)
          .acknowledgeResources(widget.movieId);
    } catch (_) {
      // 确认失败不应阻止用户查看影片详情，下一次进入时继续尝试。
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(movieDetailProvider(widget.movieId));
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = appColors(context);
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.loadFailed, style: AppText.sectionTitle(context)),
                const SizedBox(height: 8),
                Text(
                  toApiException(e).message,
                  style: AppText.body(context),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (movie) => _DetailBody(movie: movie, urlBuilder: urlBuilder),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  /// 氛围背景 · 单张封面,页位恒为 0
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _syncHeroArts();
  }

  @override
  void didUpdateWidget(covariant _DetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 元数据刷新可能更换封面;urlBuilder 缓存版本变化也会改写 URL
    _syncHeroArts();
  }

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPagePosition.dispose();
    super.dispose();
  }

  /// 封面 uuid 与 _HeroHeader 同源: fanart → poster → thumb
  void _syncHeroArts() {
    final movie = widget.movie;
    final uuid = movie.fanartUuid?.isNotEmpty == true
        ? movie.fanartUuid
        : (movie.posterUuid?.isNotEmpty == true
              ? movie.posterUuid
              : (movie.thumbUuid?.isNotEmpty == true ? movie.thumbUuid : null));
    final url = uuid != null && uuid.isNotEmpty ? widget.urlBuilder(uuid) : '';
    final current = _heroArts.value;
    if (current.length == 1 &&
        current[0].movieId == movie.id &&
        current[0].url == url) {
      return;
    }
    _heroArts.value = [HeroArt(movieId: movie.id, url: url)];
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final movie = widget.movie;
    final urlBuilder = widget.urlBuilder;
    final favStatus = ref.watch(favoriteStatusProvider);
    // 初始化收藏状态种子
    if (!favStatus.containsKey(movie.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(favoriteStatusProvider.notifier)
            .seed(movie.id, movie.isFavorited);
      });
    }
    final isFavorited = favStatus[movie.id] ?? movie.isFavorited;

    return MovieDetailScaffold(
      heroArts: _heroArts,
      heroPosition: _heroPagePosition,
      hero: _HeroHeader(movie: movie, urlBuilder: urlBuilder),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: _TitleBlock(movie: movie),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: _ActionRow(movie: movie),
          ),
        ),
        if (movie.plot != null && movie.plot!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: MovieDetailPlot(plot: movie.plot!),
            ),
          ),
        SliverToBoxAdapter(
          child: MovieExtraFanartSection(
            movieId: movie.id,
            movieTitle: movie.title,
            canFetch: movie.num?.trim().isNotEmpty == true,
            trailerUrl: _trailerUrl(movie),
            posterUrl: _trailerPosterUrl(movie, urlBuilder),
          ),
        ),
        if (movie.actors.isNotEmpty)
          SliverToBoxAdapter(
            child: CastSection(
              entries: [
                for (final actor in movie.actors)
                  CastEntry(
                    name: actor.name,
                    imageUrl: _castImageUrl(actor),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PersonDetailPage(actor: actor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: _ActorRelatedMoviesSection(
            movie: movie,
            urlBuilder: urlBuilder,
            onMovieReturned: () =>
                ref.invalidate(movieDetailProvider(movie.id)),
          ),
        ),
        // 分组显示 series / genres / tags
        if (movie.series != null)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: l.movieEditorSeries,
              items: [movie.series!],
              kind: ResourceKind.series,
              hueOffset: 0,
              prefix: '◇ ',
            ),
          ),
        if (movie.genres.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: l.movieEditorGenre,
              items: movie.genres,
              kind: ResourceKind.genre,
              hueOffset: 0,
            ),
          ),
        if (movie.tags.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: l.movieEditorTag,
              items: movie.tags,
              kind: ResourceKind.tag,
              hueOffset: 2,
              prefix: '# ',
            ),
          ),
        SliverToBoxAdapter(child: _DetailsTable(movie: movie)),
        SliverToBoxAdapter(child: _MediaInfoSection(movieId: movie.id)),
        SliverToBoxAdapter(child: _RelatedFilesSection(movie: movie)),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isFavorited ? c.accent : null,
            ),
          ),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final l = AppL10n.of(context);
            try {
              final value = await ref
                  .read(favoriteStatusProvider.notifier)
                  .toggle(movie.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    value ? l.detailFavorited : l.detailUnfavorited,
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text(l.operationFailed('$e'))),
              );
            }
          },
        ),
        const SizedBox(width: 6),
        _MoreMenuButton(movie: movie),
        const SizedBox(width: 6),
      ],
    );
  }

  /// 演员头像地址:与 ActorAvatar 相同的解析规则(null = 字段缺失仍尝试
  /// 加载;空数组 = 明确无头像,跳过请求),供 CastSection 同步拼 URL。
  String? _castImageUrl(ActorItem actor) {
    final config = ref.watch(serverConfigProvider);
    if (config == null) return null;
    if (actor.avatarPaths != null && actor.avatarPaths!.isEmpty) return null;
    return actorAvatarUrl(config, actor.id);
  }
}

String? _trailerUrl(MovieDetail movie) {
  final value = movie.trailer?.trim() ?? '';
  final uri = Uri.tryParse(value);
  if (value.isEmpty ||
      uri == null ||
      uri.host.isEmpty ||
      (uri.scheme.toLowerCase() != 'http' &&
          uri.scheme.toLowerCase() != 'https')) {
    return null;
  }
  return uri.toString();
}

String? _trailerPosterUrl(
  MovieDetail movie,
  String Function(String) urlBuilder,
) {
  for (final candidate in [
    movie.fanartUuid,
    movie.thumbUuid,
    movie.posterUuid,
  ]) {
    final uuid = candidate?.trim() ?? '';
    if (uuid.isNotEmpty) return urlBuilder(uuid);
  }
  return null;
}

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // fanart fallback poster fallback thumb
    final heroUuid = movie.fanartUuid?.isNotEmpty == true
        ? movie.fanartUuid
        : (movie.posterUuid?.isNotEmpty == true
              ? movie.posterUuid
              : (movie.thumbUuid?.isNotEmpty == true ? movie.thumbUuid : null));

    // 技术徽章(编码/HDR/字幕/破解/UHD...)基于媒体探测 + 文件名后缀
    final mediaInfo = ref.watch(mediaInfoProvider(movie.id)).value;
    final video = mediaInfo?.streams.video;
    final badgeVisibility = ref.watch(posterBadgeVisibilityProvider);
    final subtitleFiles = movie.relatedFiles
        .where(
          (file) =>
              file.type?.trim().toLowerCase() == 'subtitle' &&
              file.path.trim().isNotEmpty,
        )
        .toList();
    // 外挂字幕 = 非 AI 的外挂字幕;AI 字幕单独标识,两者互斥分类
    final hasExternalSubtitle =
        movie.hasExternalSubtitle ||
        subtitleFiles.any((f) => !isAISubtitlePath(f.path));
    // AI 字幕: 详情接口字段优先,回退按字幕文件名识别(.ai. 标记段)
    final hasAISubtitle =
        movie.hasAiSubtitle ||
        subtitleFiles.any((f) => isAISubtitlePath(f.path));
    final badges = buildCoverBadges(
      filePath: movie.filePath,
      fileSize: movie.fileSize,
      video: video,
      hasExternalSubtitle: hasExternalSubtitle,
      hasAISubtitle: hasAISubtitle,
      hasMuxedSubtitle:
          movie.hasInternalSubtitle ||
          mediaInfo?.streams.subtitleStreams.isNotEmpty == true,
    ).where((badge) => badgeVisibility.isEnabled(badge.kind)).toList();
    final imageUrl = heroUuid == null ? null : urlBuilder(heroUuid);

    return MovieDetailHero(
      imageUrl: imageUrl,
      title: movie.title,
      year: movie.year,
      bottomOverlay: badges.isEmpty ? null : CoverBadgeRow(badges: badges),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    return MovieDetailTitle(
      title: movie.title,
      originalTitle: movie.originalTitle,
      year: movie.year,
      runtime: movie.runtime,
      rating: movie.rating,
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.movie});

  final MovieDetail movie;

  int _startPositionSec(WatchRecord? watchRecord) {
    if (watchRecord != null) return watchRecord.resumePositionSec;

    final wr = movie.watchRecord;
    if (wr == null || wr.completed) return 0;
    final r = wr.progressRatio.clamp(0.0, 1.0);
    final runtimeMin = movie.runtime ?? 0;
    if (runtimeMin <= 0 || r <= 0) return 0;
    return (runtimeMin * 60 * r).round();
  }

  double _progressRatio(WatchRecord? watchRecord) {
    if (watchRecord != null) {
      if (watchRecord.completed || watchRecord.durationSec <= 0) return 0;
      return (watchRecord.lastPositionSec / watchRecord.durationSec)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final summary = movie.watchRecord;
    if (summary == null || summary.completed) return 0;
    return summary.progressRatio.clamp(0.0, 1.0).toDouble();
  }

  List<PlayerQueueItem> _playerQueue(int startPositionSec) {
    final items = <PlayerQueueItem>[
      PlayerQueueItem(
        movieId: movie.id,
        title: movie.title,
        startPositionSec: startPositionSec,
        part: movie.moviePart,
      ),
      for (final related in movie.partMovies)
        if (related.id != movie.id)
          PlayerQueueItem(
            movieId: related.id,
            title: related.title,
            part: related.moviePart,
          ),
    ];
    if (items.every((item) => item.part?.isNotEmpty == true)) {
      items.sort(_comparePlayerQueueItems);
    }
    return items;
  }

  int _comparePlayerQueueItems(PlayerQueueItem a, PlayerQueueItem b) {
    final aPart = _partNumber(a.part);
    final bPart = _partNumber(b.part);
    if (aPart == null || bPart == null) return 0;
    return aPart.compareTo(bPart);
  }

  int? _partNumber(String? part) {
    final match = RegExp(r'(\d+)').firstMatch(part ?? '');
    return int.tryParse(match?.group(1) ?? '');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final watchRecord = ref.watch(movieWatchRecordProvider(movie.id)).value;
    final startPositionSec = _startPositionSec(watchRecord);
    final progressRatio = _progressRatio(watchRecord);
    final playLabel = startPositionSec > 0
        ? '${l.detailPlay} (${formatResumePosition(startPositionSec)})'
        : l.detailPlay;
    final playerQueue = _playerQueue(startPositionSec);
    final playerQueueIndex = playerQueue.indexWhere(
      (item) => item.movieId == movie.id,
    );
    final engineKinds = availablePlaybackEngineKinds();

    Future<void> openPlayer(PlaybackEngineKind? engineKind) async {
      final changesBeforePlayback = MovieDataChanges.snapshot(
        movieId: movie.id,
      );
      await VideoPlayerPage.open(
        context,
        movieId: movie.id,
        title: movie.title,
        engineKind: engineKind,
        startPositionSec: startPositionSec,
        queue: playerQueue,
        queueIndex: playerQueueIndex < 0 ? 0 : playerQueueIndex,
      );
      // 播放器确实上报过进度时才重新拉取观看记录,没看就退出则沿用缓存。
      if (context.mounted &&
          changesBeforePlayback.latest.progressChangedSince(
            changesBeforePlayback,
          )) {
        ref.invalidate(movieWatchRecordProvider(movie.id));
      }
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.text,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (progressRatio > 0)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progressRatio,
                          heightFactor: 1,
                          child: ColoredBox(
                            color: c.bg.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => openPlayer(null),
                    onLongPress: engineKinds.length < 2
                        ? null
                        : () async {
                            final defaultEngine = ref
                                .read(playerSettingsProvider)
                                .iosEngine;
                            final engineKind = await showPlaybackEnginePicker(
                              context,
                              engineKinds: engineKinds,
                              defaultEngineKind: defaultEngine,
                            );
                            if (engineKind != null && context.mounted) {
                              await openPlayer(engineKind);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: c.bg,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          playLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => AddToListSheet.show(
              context,
              movieId: movie.id,
              movieTitle: movie.title,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.text,
              side: BorderSide(color: c.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              AppL10n.of(context).detailAddList,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActorRelatedMoviesSection extends StatelessWidget {
  const _ActorRelatedMoviesSection({
    required this.movie,
    required this.urlBuilder,
    required this.onMovieReturned,
  });

  final MovieDetail movie;
  final String Function(String) urlBuilder;
  final VoidCallback onMovieReturned;

  List<RelatedMovie> _randomMovies() {
    final seen = <int>{};
    final candidates = movie.actorRelatedMovies.where((item) {
      final isCurrentMovie = item.id == movie.id;
      final isPartMovie = item.moviePart?.trim().isNotEmpty == true;
      return !isCurrentMovie && !isPartMovie && seen.add(item.id);
    }).toList()..shuffle(Random(movie.id));
    return candidates.take(5).toList(growable: false);
  }

  MovieListItem _toMovieListItem(RelatedMovie item) {
    return MovieListItem(
      id: item.id,
      title: item.title,
      num: item.num,
      year: item.year,
      rating: item.rating,
      runtime: item.runtime,
      posterUuid: item.posterUuid ?? item.thumbUuid ?? item.fanartUuid,
      thumbUuid: item.thumbUuid,
      fanartUuid: item.fanartUuid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final relatedMovies = _randomMovies();
    if (relatedMovies.isEmpty) return const SizedBox.shrink();
    final l = AppL10n.of(context);

    return MovieDetailFullBleedSection(
      header: Text(
        l.detailActorRelatedMovies,
        style: AppText.sectionTitle(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 与影片库三列网格保持相同的横向内边距、间距和宽高比。
          const columns = 3;
          const horizontalPadding = 44.0;
          const crossAxisSpacing = 10.0;
          const childAspectRatio = 0.55;
          final cardWidth =
              (constraints.maxWidth -
                  horizontalPadding -
                  crossAxisSpacing * (columns - 1)) /
              columns;
          return SizedBox(
            height: cardWidth / childAspectRatio,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: relatedMovies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, index) {
                final related = relatedMovies[index];
                return SizedBox(
                  width: cardWidth,
                  child: MovieCard(
                    movie: _toMovieListItem(related),
                    posterUrlBuilder: urlBuilder,
                    onTap: () async {
                      final changesBeforeVisit = MovieDataChanges.snapshot(
                        movieId: related.id,
                      );
                      await Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => MovieDetailPage(movieId: related.id),
                        ),
                      );
                      // 关联影片的元数据/封面变更会影响本区块展示;
                      // 仅浏览未编辑时沿用缓存,不重新拉取详情。
                      if (ctx.mounted &&
                          changesBeforeVisit.latest.displayChangedSince(
                            changesBeforeVisit,
                          )) {
                        onMovieReturned();
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 单类 taxonomy 分组 (系列 / 分类 / 标签),带 label + Wrap 多彩 chips。
/// 每个 chip 点击跳 ResourceMoviesPage 按该维度过滤。
class _TaxonomySection extends StatelessWidget {
  const _TaxonomySection({
    required this.label,
    required this.items,
    required this.kind,
    this.hueOffset = 0,
    this.prefix = '',
  });

  final String label;
  final List<ResourceItem> items;
  final ResourceKind kind;
  final int hueOffset;
  final String prefix;

  void _open(BuildContext context, ResourceItem r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResourceMoviesPage(kind: kind, resource: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.sectionTitle(context)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                HueChip(
                  label: '$prefix${items[i].name}',
                  hue: AppHues.all[(i + hueOffset) % AppHues.all.length],
                  onTap: () => _open(context, items[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 相关文件 section · 优先展示 related_files (含 label+path),
/// fallback 显示单条 file_path。
class _RelatedFilesSection extends StatelessWidget {
  const _RelatedFilesSection({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final files = <({String label, String path})>[];
    if (movie.relatedFiles.isNotEmpty) {
      for (final f in movie.relatedFiles) {
        files.add((label: f.label ?? f.type ?? l.detailFile, path: f.path));
      }
    } else if (movie.filePath != null && movie.filePath!.isNotEmpty) {
      files.add((label: l.detailMovieFile, path: movie.filePath!));
    }
    if (files.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.detailFilePath, style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < files.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < files.length - 1
                    ? Border(bottom: BorderSide(color: c.divider))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    files[i].label,
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    files[i].path,
                    style: TextStyle(
                      color: c.text2,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsTable extends ConsumerWidget {
  const _DetailsTable({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final rows = <List<String>>[];
    if (movie.num != null && movie.num!.isNotEmpty) {
      rows.add([l.detailNumber, movie.num!]);
    }
    if (movie.country != null && movie.country!.isNotEmpty) {
      rows.add([l.detailCountry, movie.country!]);
    }
    // 时长优先用媒体探测结果，缺失时回退 NFO 元数据 runtime
    final durationSec = ref
        .watch(mediaInfoProvider(movie.id))
        .value
        ?.durationSec;
    if (durationSec != null && durationSec > 0) {
      rows.add([l.detailRuntime, _formatDurationSec(durationSec, l)]);
    } else if (movie.runtime != null && movie.runtime! > 0) {
      rows.add([l.detailRuntime, l.detailRuntimeMinutes(movie.runtime!)]);
    }
    if (movie.fileSize != null && movie.fileSize! > 0) {
      rows.add([l.detailFileSize, _formatBytes(movie.fileSize!)]);
    }
    if (movie.moviePart != null && movie.moviePart!.isNotEmpty) {
      rows.add([l.detailPart, movie.moviePart!]);
    }
    if (movie.lastDownloadedAt != null && movie.lastDownloadedAt!.isNotEmpty) {
      rows.add([l.detailDownloadedAt, movie.lastDownloadedAt!]);
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.detailDetails, style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(bottom: BorderSide(color: c.divider))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      rows[i][0].toUpperCase(),
                      style: TextStyle(
                        color: c.muted,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i][1],
                      style: TextStyle(
                        color: c.text,
                        fontFamily: rows[i][0] == 'File'
                            ? 'monospace'
                            : 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: rows[i][0] == 'File' ? 11.5 : 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(2)} ${units[unit]}';
}

/// 媒体探测时长 → "1h 02m 30s" 风格，供详细信息表使用。
String _formatDurationSec(double sec, AppL10n l) {
  final s = sec.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  final minutes = m.toString().padLeft(2, '0');
  final seconds = ss.toString().padLeft(2, '0');
  return h > 0
      ? l.detailDurationHours(h, minutes, seconds)
      : l.detailDurationMinutes(m, seconds);
}

/// 媒体技术信息 section (容器/大小 + 视频/音频/字幕流卡片)
class _MediaInfoSection extends ConsumerWidget {
  const _MediaInfoSection({required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaInfoProvider(movieId));
    return async.maybeWhen(
      data: (detail) {
        if (detail == null) return const SizedBox.shrink();
        final streams = detail.streams;
        final c = appColors(context);
        final l = AppL10n.of(context);
        final rows = <List<String>>[];
        if (detail.container != null) {
          rows.add([l.detailContainer, detail.container!]);
        }
        if (detail.fileSize != null && detail.fileSize! > 0) {
          rows.add([l.detailSize, _formatBytes(detail.fileSize!)]);
        }
        final hasCards = streams.hasContent;
        if (rows.isEmpty && !hasCards) return const SizedBox.shrink();
        return MovieDetailFullBleedSection(
          bottom: 32,
          header: Text(l.detailMediaInfo, style: AppText.sectionTitle(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 96,
                                child: Text(
                                  r[0],
                                  style: TextStyle(
                                    color: c.muted,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  r[1],
                                  style: TextStyle(
                                    color: c.text,
                                    fontFamily: 'monospace',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (hasCards) ...[
                if (rows.isNotEmpty) const SizedBox(height: 10),
                MediaStreamCards(
                  detail: detail,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ============ More menu (... popup) ============
class _MoreMenuButton extends ConsumerWidget {
  const _MoreMenuButton({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return GlassMenuAnchor<String>(
      width: 244,
      entries: _movieMoreEntries(c, l),
      tooltip: l.more,
      offset: const Offset(0, 8),
      placement: GlassMenuPlacement.below,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz, size: 18),
      ),
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            await MovieEditorSheet.show(context, movie);
            break;
          case 'subtitle':
            await ThunderSubtitleSheet.show(context, movie.id);
            break;
          case 'audio_extract':
            final taskId = await AudioExtractionSheet.show(
              context,
              movie: movie,
            );
            if (taskId != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.detailAudioExtractionSubmitted),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            break;
          case 'resources':
            await ResourcesSheet.show(context, movie: movie);
            break;
          case 'dbo_meta':
            await DboDiffSheet.show(context, movie);
            break;
          case 'sync_nfo':
            await _confirmAndRun(
              context,
              ref,
              title: l.detailSyncNfoTitle,
              message: l.detailSyncNfoMessage,
              run: () => ref.read(mediaRepositoryProvider).syncNfo(movie.id),
              successMsg: l.detailSyncNfoSuccess,
            );
            break;
          case 'refresh_nfo':
            await _confirmAndRun(
              context,
              ref,
              title: l.detailRefreshNfoTitle,
              message: l.detailRefreshNfoMessage,
              run: () =>
                  ref.read(mediaRepositoryProvider).refreshFromNfo(movie.id),
              successMsg: l.detailRefreshNfoSuccess,
              refreshDetail: true,
            );
            break;
          case 'delete':
            await _confirmDelete(context, ref, movie);
            break;
        }
      },
    );
  }

  List<GlassMenuEntry<String>> _movieMoreEntries(AppColors c, AppL10n l) => [
    GlassMenuEntry<String>.action(
      value: 'edit',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.edit_outlined,
        label: l.detailEditMovie,
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.divider(dividerColor: c.divider),
    GlassMenuEntry<String>.action(
      value: 'dbo_meta',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.cloud_download_outlined,
        label: l.detailFetchMetadata,
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.action(
      value: 'resources',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.link,
        label: l.detailFetchResources,
        selected: selected,
        onTap: onTap,
      ),
    ),
    if ((movie.num ?? '').trim().isNotEmpty)
      GlassMenuEntry<String>.action(
        value: 'subtitle',
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.subtitles_outlined,
          label: l.detailFetchSubtitles,
          selected: selected,
          onTap: onTap,
        ),
      ),
    GlassMenuEntry<String>.action(
      value: 'audio_extract',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.audiotrack_outlined,
        label: l.detailExtractAudio,
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.divider(dividerColor: c.divider),
    GlassMenuEntry<String>.action(
      value: 'sync_nfo',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.upload_outlined,
        label: l.detailSyncNfoTitle,
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.action(
      value: 'refresh_nfo',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.refresh,
        label: l.detailRefreshNfoTitle,
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.divider(dividerColor: c.divider),
    GlassMenuEntry<String>.action(
      value: 'delete',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.delete_outline,
        label: l.delete,
        foregroundColor: c.danger,
        selected: selected,
        onTap: onTap,
      ),
    ),
  ];

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required Future<void> Function() run,
    required String successMsg,
    bool refreshDetail = false,
  }) async {
    final l = AppL10n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await run();
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMsg),
          duration: const Duration(seconds: 1),
        ),
      );
      if (refreshDetail) {
        // ignore: unused_result
        ref.refresh(movieDetailProvider(movie.id));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.operationFailed(toApiException(e).message))),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MovieDetail movie,
  ) async {
    final l = AppL10n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.detailDeleteMovieTitle),
        content: Text(l.detailDeleteMovieMessage(movie.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(mediaRepositoryProvider).deleteMovie(movie.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.deleted),
          duration: const Duration(seconds: 1),
        ),
      );
      // 返回上一页
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.deleteFailed(toApiException(e).message))),
      );
    }
  }
}
