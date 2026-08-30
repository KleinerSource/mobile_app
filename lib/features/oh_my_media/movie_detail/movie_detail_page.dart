import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_providers.dart';
import 'package:omm/features/oh_my_media/lists/add_to_list_sheet.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/player/video/video_player_page.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/features/player/common/player_queue.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/features/player/video/video_player_session_factory.dart';
import 'package:omm/features/player/common/player_settings.dart';
import 'package:omm/features/oh_my_media/resources/resource_movies_page.dart';
import 'package:omm/features/oh_my_media/person_detail/person_detail_page.dart';
import 'dbo_diff_sheet.dart';
import 'resources_sheet.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'movie_editor_sheet.dart';
import 'movie_detail_formatters.dart';
import 'movie_detail_scaffold.dart';
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
                Text('加载失败', style: AppText.sectionTitle(context)),
                const SizedBox(height: 8),
                Text(
                  '$e',
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
          child: _ExtraFanartSection(
            movieId: movie.id,
            movieTitle: movie.title,
            canFetch: movie.num?.trim().isNotEmpty == true,
            trailerUrl: _trailerUrl(movie),
            posterUrl: _trailerPosterUrl(movie, urlBuilder),
          ),
        ),
        if (movie.actors.isNotEmpty)
          SliverToBoxAdapter(child: _CastSection(actors: movie.actors)),
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
              label: '系列',
              items: [movie.series!],
              kind: ResourceKind.series,
              hueOffset: 0,
              prefix: '◇ ',
            ),
          ),
        if (movie.genres.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '分类',
              items: movie.genres,
              kind: ResourceKind.genre,
              hueOffset: 0,
            ),
          ),
        if (movie.tags.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '标签',
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
              messenger.showSnackBar(SnackBar(content: Text('操作失败: $e')));
            }
          },
        ),
        const SizedBox(width: 6),
        _MoreMenuButton(movie: movie),
        const SizedBox(width: 6),
      ],
    );
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
    final watchRecord = ref
        .watch(movieWatchRecordProvider(movie.id))
        .valueOrNull;
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

class _ExtraFanartSection extends ConsumerStatefulWidget {
  const _ExtraFanartSection({
    required this.movieId,
    required this.movieTitle,
    required this.canFetch,
    required this.trailerUrl,
    required this.posterUrl,
  });

  final int movieId;
  final String movieTitle;
  final bool canFetch;
  final String? trailerUrl;
  final String? posterUrl;

  @override
  ConsumerState<_ExtraFanartSection> createState() =>
      _ExtraFanartSectionState();
}

class _ExtraFanartSectionState extends ConsumerState<_ExtraFanartSection> {
  final ScrollController _previewController = ScrollController();
  bool _fetching = false;

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  double _cardWidth(BuildContext context) {
    return (MediaQuery.sizeOf(context).width * 0.72)
        .clamp(220.0, 300.0)
        .toDouble();
  }

  void _syncPreviewScroll(BuildContext context, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_previewController.hasClients) return;
      final cardWidth = _cardWidth(context);
      final viewport = _previewController.position.viewportDimension;
      final target = index * (cardWidth + 10) - (viewport - cardWidth) / 2;
      final position = target
          .clamp(0.0, _previewController.position.maxScrollExtent)
          .toDouble();
      unawaited(
        _previewController.animateTo(
          position,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Future<void> _fetchExtraFanarts() async {
    if (_fetching || !widget.canFetch) return;
    setState(() => _fetching = true);
    try {
      await ref
          .read(mediaRepositoryProvider)
          .downloadExtraFanarts(widget.movieId);
      if (!mounted) return;
      ref.invalidate(extraFanartsProvider(widget.movieId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('预览图获取完成')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取预览图失败: ${toApiException(error).message}')),
      );
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Widget _header(BuildContext context, {required bool hasImages}) {
    return Row(
      children: [
        Expanded(child: Text('预览图', style: AppText.sectionTitle(context))),
        if (widget.canFetch)
          TextButton.icon(
            onPressed: _fetching ? null : _fetchExtraFanarts,
            icon: _fetching
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 17),
            label: Text(hasImages ? '重新获取' : '获取'),
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, String message, IconData icon) {
    final c = appColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.body(context))),
        ],
      ),
    );
  }

  Widget _trailerOnlyPreview(BuildContext context) {
    final cardWidth = _cardWidth(context);
    final cardHeight = cardWidth * 9 / 16;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, hasImages: true),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight,
            child: SizedBox(
              width: cardWidth,
              child: _TrailerThumbnail(
                posterUrl: widget.posterUrl,
                onTap: () => _playTrailer(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(extraFanartsProvider(widget.movieId));
    return async.when(
      loading: () => widget.trailerUrl != null
          ? _trailerOnlyPreview(context)
          : Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, hasImages: false),
                  const SizedBox(height: 12),
                  _emptyState(
                    context,
                    '正在加载预览图',
                    Icons.hourglass_empty_rounded,
                  ),
                ],
              ),
            ),
      error: (error, _) => widget.trailerUrl != null
          ? _trailerOnlyPreview(context)
          : Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, hasImages: false),
                  const SizedBox(height: 12),
                  _emptyState(
                    context,
                    '预览图加载失败: ${toApiException(error).message}',
                    Icons.broken_image_outlined,
                  ),
                ],
              ),
            ),
      data: (urls) {
        final hasTrailer = widget.trailerUrl != null;
        if (!hasTrailer && urls.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, hasImages: false),
                const SizedBox(height: 12),
                _emptyState(context, '暂无预览图', Icons.photo_library_outlined),
              ],
            ),
          );
        }

        final cardWidth = _cardWidth(context);
        final cardHeight = cardWidth * 9 / 16;
        final itemCount = urls.length + (hasTrailer ? 1 : 0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, hasImages: true),
              const SizedBox(height: 12),
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  controller: _previewController,
                  scrollDirection: Axis.horizontal,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (hasTrailer && index == 0) {
                      return SizedBox(
                        width: cardWidth,
                        child: _TrailerThumbnail(
                          posterUrl: widget.posterUrl,
                          onTap: () => _playTrailer(context),
                        ),
                      );
                    }

                    final imageIndex = index - (hasTrailer ? 1 : 0);
                    final url = urls[imageIndex];
                    return SizedBox(
                      width: cardWidth,
                      child: Material(
                        color: appColors(context).surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            unawaited(_openViewer(context, urls, index));
                          },
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: appColors(context).muted,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openViewer(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    _syncPreviewScroll(context, initialIndex);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭预览图',
      // 背景由灯箱自身绘制，才能在下滑时和内容一起实时淡出。
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => _ExtraFanartViewer(
        urls: urls,
        trailerUrl: widget.trailerUrl,
        posterUrl: widget.posterUrl,
        initialIndex: initialIndex,
        onPageChanged: (index) => _syncPreviewScroll(context, index),
      ),
    );
  }

  void _playTrailer(BuildContext context) {
    final url = widget.trailerUrl;
    if (url == null) return;
    unawaited(
      VideoPlayerPage.open(
        context,
        movieId: widget.movieId,
        title: '${widget.movieTitle} · 预告片',
        directUrl: url,
        engineKind: PlaybackEngineKind.libmpv,
      ),
    );
  }
}

class _TrailerThumbnail extends StatelessWidget {
  const _TrailerThumbnail({required this.posterUrl, required this.onTap});

  final String? posterUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final imageUrl = posterUrl?.trim() ?? '';
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _trailerPlaceholder(context),
              )
            else
              _trailerPlaceholder(context),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.play_arrow_rounded, size: 24),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Text(
                l.detailTrailer,
                style: AppText.body(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _trailerPlaceholder(BuildContext context) {
  final c = appColors(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.surfaceAlt, c.surface],
      ),
    ),
  );
}

/// 让文件来源也复用 OMM 详情页已有的图片灯箱实现。
///
/// [loadBytes] 按页面懒加载，图片查看器本身的布局和手势仍完全由 OMM
/// 灯箱统一处理。
Future<void> showImageLightbox(
  BuildContext context, {
  required int itemCount,
  required Future<Uint8List> Function(int index) loadBytes,
  int initialIndex = 0,
  bool useRootNavigator = true,
}) {
  if (itemCount <= 0) return Future<void>.value();
  final safeIndex = initialIndex.clamp(0, itemCount - 1).toInt();
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: true,
    barrierLabel: '关闭预览图',
    barrierColor: Colors.transparent,
    pageBuilder: (_, __, ___) => _ExtraFanartViewer(
      urls: const <String>[],
      imageCount: itemCount,
      loadBytes: loadBytes,
      trailerUrl: null,
      posterUrl: null,
      initialIndex: safeIndex,
      onPageChanged: (_) {},
    ),
  );
}

/// OMM URL 图片灯箱入口，继续使用同一套灯箱和手势逻辑。
Future<void> showMovieImageLightbox(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  final validUrls = urls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
  if (validUrls.isEmpty) return Future<void>.value();
  final safeIndex = initialIndex.clamp(0, validUrls.length - 1).toInt();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭预览图',
    barrierColor: Colors.transparent,
    pageBuilder: (_, __, ___) => _ExtraFanartViewer(
      urls: validUrls,
      trailerUrl: null,
      posterUrl: null,
      initialIndex: safeIndex,
      onPageChanged: (_) {},
    ),
  );
}

class _ExtraFanartViewer extends StatefulWidget {
  const _ExtraFanartViewer({
    required this.urls,
    this.imageCount,
    this.loadBytes,
    required this.trailerUrl,
    required this.posterUrl,
    required this.initialIndex,
    required this.onPageChanged,
  });

  final List<String> urls;
  final int? imageCount;
  final Future<Uint8List> Function(int index)? loadBytes;
  final String? trailerUrl;
  final String? posterUrl;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;

  @override
  State<_ExtraFanartViewer> createState() => _ExtraFanartViewerState();
}

enum _LightboxGestureMode { undecided, horizontal, vertical, imagePan, pinch }

class _ExtraFanartViewerState extends State<_ExtraFanartViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  late final AnimationController _zoomAnimationController;
  final Map<int, TransformationController> _imageControllers =
      <int, TransformationController>{};
  final Map<int, Future<Uint8List>> _imageBytes = <int, Future<Uint8List>>{};
  final Set<int> _zoomedIndexes = <int>{};
  late int _index;
  double _verticalDragOffset = 0;
  Offset? _doubleTapPosition;
  bool _isDragging = false;
  bool _isTwoFingerGesture = false;
  bool _isClosing = false;
  _LightboxGestureMode _gestureMode = _LightboxGestureMode.undecided;
  Offset _gestureStartFocalPoint = Offset.zero;
  double _lastScaleFactor = 1;
  Animation<Matrix4>? _zoomAnimation;
  TransformationController? _zoomAnimationTarget;

  static const _dragAnimationDuration = Duration(milliseconds: 220);
  static const _zoomAnimationDuration = Duration(milliseconds: 260);

  bool get _hasTrailer => widget.trailerUrl != null;

  int get _imageCount => widget.imageCount ?? widget.urls.length;

  int get _itemCount => _imageCount + (_hasTrailer ? 1 : 0);

  bool _isTrailerIndex(int index) => _hasTrailer && index == 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: _zoomAnimationDuration,
    )..addListener(_onZoomAnimationTick);
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _controller.dispose();
    for (final controller in _imageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _imageControllerFor(int index) {
    return _imageControllers.putIfAbsent(index, () {
      final controller = TransformationController();
      controller.addListener(() => _onImageTransformChanged(index, controller));
      return controller;
    });
  }

  Future<Uint8List> _bytesFor(int index) {
    return _imageBytes.putIfAbsent(index, () => widget.loadBytes!(index));
  }

  void _onImageTransformChanged(
    int index,
    TransformationController controller,
  ) {
    final scale = controller.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.01;
    final wasZoomed = _zoomedIndexes.contains(index);

    // 缩回完整显示时清掉残留平移，确保下滑退出从稳定的初始位置开始。
    if (!isZoomed) {
      final translation = controller.value.getTranslation();
      if (translation.x.abs() > 0.5 || translation.y.abs() > 0.5) {
        controller.value = Matrix4.identity();
      }
    }

    if (isZoomed == wasZoomed) return;
    if (isZoomed) {
      _zoomedIndexes.add(index);
    } else {
      _zoomedIndexes.remove(index);
    }
    if (mounted && index == _index) setState(() {});
  }

  bool _isZoomed(int index) => _zoomedIndexes.contains(index);

  void _onZoomAnimationTick() {
    final animation = _zoomAnimation;
    final target = _zoomAnimationTarget;
    if (animation == null || target == null) return;
    target.value = animation.value;
  }

  void _stopZoomAnimation() {
    _zoomAnimationController.stop();
    _zoomAnimation = null;
    _zoomAnimationTarget = null;
  }

  void _animateImageTransform(
    TransformationController controller,
    Matrix4 target,
  ) {
    _stopZoomAnimation();
    _zoomAnimationController.reset();
    _zoomAnimationTarget = controller;
    _zoomAnimation = Matrix4Tween(begin: controller.value.clone(), end: target)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_zoomAnimationController);
    _zoomAnimationController.forward();
  }

  void _resetImageTransform(int index) {
    final controller = _imageControllers[index];
    if (controller == null) return;
    controller.value = Matrix4.identity();
    _zoomedIndexes.remove(index);
  }

  void _onGestureStart(ScaleStartDetails details) {
    if (_isClosing) return;
    _stopZoomAnimation();
    _gestureStartFocalPoint = details.localFocalPoint;
    _lastScaleFactor = 1;
    _gestureMode = _isZoomed(_index)
        ? _LightboxGestureMode.imagePan
        : _LightboxGestureMode.undecided;
    if (details.pointerCount >= 2) {
      _isTwoFingerGesture = true;
      _gestureMode = _LightboxGestureMode.pinch;
      if (mounted) {
        setState(() {
          _isDragging = false;
          _verticalDragOffset = 0;
        });
      }
    }
  }

  void _onGestureUpdate(ScaleUpdateDetails details) {
    if (_isClosing) return;
    if (details.pointerCount >= 2) {
      _isTwoFingerGesture = true;
      if (_gestureMode != _LightboxGestureMode.pinch) {
        _gestureMode = _LightboxGestureMode.pinch;
        _lastScaleFactor = details.scale;
        return;
      }
      final controller = _imageControllerFor(_index);
      final scaleChange = details.scale / _lastScaleFactor;
      _scaleImageAround(controller, scaleChange, details.localFocalPoint);
      _translateImage(controller, details.focalPointDelta);
      _lastScaleFactor = details.scale;
      return;
    }

    if (_gestureMode == _LightboxGestureMode.pinch) {
      // 双指结束后若仍保持放大，允许剩余的一根手指继续平移图片；
      // 未放大时不把收尾动作误判成翻页或下滑关闭。
      if (_isZoomed(_index)) {
        _gestureMode = _LightboxGestureMode.imagePan;
      } else {
        return;
      }
    }

    final delta = details.focalPointDelta;
    if (_gestureMode == _LightboxGestureMode.imagePan) {
      _translateImage(_imageControllerFor(_index), delta);
      return;
    }

    if (_gestureMode == _LightboxGestureMode.undecided) {
      final total = details.localFocalPoint - _gestureStartFocalPoint;
      if (total.distance < 10) return;
      _gestureMode = total.dx.abs() >= total.dy.abs()
          ? _LightboxGestureMode.horizontal
          : _LightboxGestureMode.vertical;
      if (_gestureMode == _LightboxGestureMode.vertical) {
        _startVerticalGesture();
      }
    }

    switch (_gestureMode) {
      case _LightboxGestureMode.horizontal:
        _updateHorizontalPage(delta.dx);
      case _LightboxGestureMode.vertical:
        _updateVerticalGesture(delta.dy);
      case _LightboxGestureMode.undecided:
      case _LightboxGestureMode.imagePan:
      case _LightboxGestureMode.pinch:
        break;
    }
  }

  void _onGestureEnd(ScaleEndDetails details) {
    if (_isClosing) return;
    final mode = _gestureMode;
    _gestureMode = _LightboxGestureMode.undecided;
    _isTwoFingerGesture = false;
    switch (mode) {
      case _LightboxGestureMode.horizontal:
        _finishHorizontalPage(details.velocity.pixelsPerSecond.dx);
      case _LightboxGestureMode.vertical:
        _finishVerticalDismiss(details.velocity.pixelsPerSecond.dy);
      case _LightboxGestureMode.undecided:
      case _LightboxGestureMode.imagePan:
      case _LightboxGestureMode.pinch:
        break;
    }
  }

  void _scaleImageAround(
    TransformationController controller,
    double scaleChange,
    Offset focalPoint,
  ) {
    final currentScale = controller.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * scaleChange).clamp(1.0, 6.0).toDouble();
    final effectiveScale = targetScale / currentScale;
    if ((effectiveScale - 1).abs() < 0.0001) return;
    final next = controller.value.clone()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(effectiveScale, effectiveScale, effectiveScale, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
    controller.value = next;
  }

  void _translateImage(TransformationController controller, Offset delta) {
    if (delta == Offset.zero) return;
    final next = controller.value.clone();
    final translation = next.getTranslation();
    next.setTranslationRaw(
      translation.x + delta.dx,
      translation.y + delta.dy,
      translation.z,
    );
    controller.value = next;
  }

  void _toggleDoubleTapZoom(int index) {
    if (_isClosing || _isTwoFingerGesture || _isTrailerIndex(index)) return;
    final controller = _imageControllerFor(index);
    final isZoomed =
        _isZoomed(index) || controller.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomed) {
      _animateImageTransform(controller, Matrix4.identity());
      _doubleTapPosition = null;
      return;
    }

    const targetScale = 2.0;
    final focalPoint = _doubleTapPosition;
    final transform = Matrix4.identity();
    if (focalPoint != null) {
      transform.translateByDouble(
        focalPoint.dx * (1 - targetScale),
        focalPoint.dy * (1 - targetScale),
        0,
        1,
      );
    }
    transform.scaleByDouble(targetScale, targetScale, targetScale, 1);
    _animateImageTransform(controller, transform);
    _doubleTapPosition = null;
  }

  void _close() {
    if (mounted && !_isTwoFingerGesture) Navigator.of(context).pop();
  }

  void _startVerticalGesture() {
    setState(() {
      _isDragging = true;
      _verticalDragOffset = 0;
    });
  }

  void _updateVerticalGesture(double delta) {
    setState(() {
      // 只允许向下退出，向上拖动时保持在原位，避免灯箱被拖出屏幕顶部。
      _verticalDragOffset = (_verticalDragOffset + delta)
          .clamp(0.0, double.infinity)
          .toDouble();
    });
  }

  void _finishVerticalDismiss(double velocity) {
    final height = MediaQuery.sizeOf(context).height;
    final shouldClose = _verticalDragOffset > height * 0.2 || velocity > 700;

    if (shouldClose) {
      setState(() {
        _isClosing = true;
        _isDragging = false;
        _verticalDragOffset = height;
      });
      unawaited(
        Future<void>.delayed(_dragAnimationDuration, () {
          if (mounted) Navigator.of(context).pop();
        }),
      );
      return;
    }

    setState(() {
      _isDragging = false;
      _verticalDragOffset = 0;
    });
  }

  void _updateHorizontalPage(double delta) {
    if (!_controller.hasClients || delta == 0) return;
    final position = _controller.position;
    final pixels = (position.pixels - delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (pixels != position.pixels) position.jumpTo(pixels);
  }

  void _finishHorizontalPage(double velocity) {
    if (!_controller.hasClients) return;
    final page = _controller.page ?? _index.toDouble();
    final target = velocity.abs() > 500
        ? (velocity < 0 ? page.ceil() : page.floor())
        : page.round();
    final safeTarget = target.clamp(0, _itemCount - 1).toInt();
    unawaited(
      _controller.animateToPage(
        safeTarget,
        duration: _dragAnimationDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final dragProgress = (_verticalDragOffset / height)
        .clamp(0.0, 1.0)
        .toDouble();
    final animationDuration = _isDragging
        ? Duration.zero
        : _dragAnimationDuration;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            color: Colors.black.withValues(
              alpha: (0.94 * (1 - dragProgress)).clamp(0.0, 0.94).toDouble(),
            ),
          ),
          AnimatedOpacity(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            opacity: (1 - dragProgress).clamp(0.0, 1.0).toDouble(),
            child: AnimatedContainer(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _verticalDragOffset, 0),
              child: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _itemCount,
                      onPageChanged: (value) {
                        _resetImageTransform(_index);
                        setState(() => _index = value);
                        widget.onPageChanged(value);
                      },
                      itemBuilder: (context, index) {
                        final isTrailer = _isTrailerIndex(index);
                        final imageController = isTrailer
                            ? null
                            : _imageControllerFor(index);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: isTrailer ? null : _close,
                          onDoubleTapDown: isTrailer
                              ? null
                              : (details) =>
                                    _doubleTapPosition = details.localPosition,
                          onDoubleTap: isTrailer
                              ? null
                              : () => _toggleDoubleTapZoom(index),
                          onScaleStart: _onGestureStart,
                          onScaleUpdate: _onGestureUpdate,
                          onScaleEnd: _onGestureEnd,
                          child: isTrailer
                              ? _TrailerViewer(
                                  url: widget.trailerUrl!,
                                  posterUrl: widget.posterUrl,
                                  active: index == _index,
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final imageIndex =
                                        index - (_hasTrailer ? 1 : 0);
                                    final loadBytes = widget.loadBytes;
                                    final image = loadBytes == null
                                        ? CachedNetworkImage(
                                            imageUrl: widget.urls[imageIndex],
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white54,
                                                  size: 48,
                                                ),
                                          )
                                        : FutureBuilder<Uint8List>(
                                            future: _bytesFor(imageIndex),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasError) {
                                                return const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white54,
                                                  size: 48,
                                                );
                                              }
                                              final bytes = snapshot.data;
                                              if (bytes == null) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }
                                              return Image.memory(
                                                bytes,
                                                fit: BoxFit.contain,
                                              );
                                            },
                                          );
                                    return IgnorePointer(
                                      child: InteractiveViewer(
                                        transformationController:
                                            imageController!,
                                        minScale: 1,
                                        maxScale: 6,
                                        panEnabled: false,
                                        scaleEnabled: false,
                                        constrained: false,
                                        boundaryMargin: const EdgeInsets.all(
                                          100000,
                                        ),
                                        clipBehavior: Clip.none,
                                        child: SizedBox(
                                          width: constraints.maxWidth,
                                          height: constraints.maxHeight,
                                          child: Center(child: image),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        );
                      },
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: '关闭预览图',
                        onPressed: _close,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_itemCount > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                '${_index + 1} / $_itemCount',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailerViewer extends StatefulWidget {
  const _TrailerViewer({
    required this.url,
    required this.posterUrl,
    required this.active,
  });

  final String url;
  final String? posterUrl;
  final bool active;

  @override
  State<_TrailerViewer> createState() => _TrailerViewerState();
}

class _TrailerViewerState extends State<_TrailerViewer> {
  late final PlayerSessionController _player;
  bool _opened = false;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = createVideoPlayerSession(
      engineKind: PlaybackEngineKind.libmpv,
    );
  }

  @override
  void didUpdateWidget(covariant _TrailerViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active && _opened) {
      unawaited(_player.pause());
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startPlayback() async {
    if (_opening) return;
    if (_opened) {
      await _player.play();
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await _player.open(widget.url, play: true);
      if (mounted) {
        setState(() => _opened = true);
        if (!widget.active) await _player.pause();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '预告片播放失败');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (!_opened) {
      await _startPlayback();
      return;
    }
    await _player.playOrPause();
  }

  Widget _playButton(BuildContext context, {required bool loading}) {
    final l = AppL10n.of(context);
    return Semantics(
      button: true,
      label: loading ? l.detailTrailer : l.detailPlay,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black87,
                  size: 28,
                ),
        ),
      ),
    );
  }

  Widget _initialStage(BuildContext context) {
    final l = AppL10n.of(context);
    final posterUrl = widget.posterUrl?.trim() ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => _trailerBackdrop(context),
            errorWidget: (_, __, ___) => _trailerBackdrop(context),
          )
        else
          _trailerBackdrop(context),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
        Center(child: _playButton(context, loading: _opening)),
        Positioned(
          left: 12,
          bottom: 10,
          child: Text(
            l.detailTrailer,
            style: AppText.body(
              context,
            ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        if (_error != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _trailerBackdrop(BuildContext context) {
    final c = appColors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surfaceAlt, Colors.black],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _startPlayback,
        child: _initialStage(context),
      );
    }

    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: _player,
      builder: (context, state, _) {
        final isPlaying = state.playing;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayback,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _player.buildSurface(),
              if (!isPlaying || _opening)
                Center(child: _playButton(context, loading: _opening)),
            ],
          ),
        );
      },
    );
  }
}

class _CastSection extends StatelessWidget {
  const _CastSection({required this.actors});
  final List<ActorItem> actors;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Text('演员', style: AppText.sectionTitle(context)),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              // 顶部预留泛光渐隐空间,避免 BoxShadow 上溢被视口硬切
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              itemCount: actors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final a = actors[i];
                final hue = AppHues.all[i % AppHues.all.length];
                return SizedBox(
                  width: 80,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => PersonDetailPage(actor: a),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppHues.top(hue).withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ActorAvatar(
                            actorId: a.id,
                            name: a.name,
                            hue: hue,
                            size: 76,
                            avatarPaths: a.avatarPaths,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Text('演员关联影片', style: AppText.sectionTitle(context)),
          ),
          LayoutBuilder(
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
                              builder: (_) =>
                                  MovieDetailPage(movieId: related.id),
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
        ],
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
    final files = <({String label, String path})>[];
    if (movie.relatedFiles.isNotEmpty) {
      for (final f in movie.relatedFiles) {
        files.add((label: f.label ?? f.type ?? '文件', path: f.path));
      }
    } else if (movie.filePath != null && movie.filePath!.isNotEmpty) {
      files.add((label: '影片', path: movie.filePath!));
    }
    if (files.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件路径', style: AppText.sectionTitle(context)),
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
    final rows = <List<String>>[];
    if (movie.num != null && movie.num!.isNotEmpty) {
      rows.add(['番号', movie.num!]);
    }
    if (movie.country != null && movie.country!.isNotEmpty) {
      rows.add(['产地', movie.country!]);
    }
    // 时长优先用媒体探测结果，缺失时回退 NFO 元数据 runtime
    final durationSec = ref
        .watch(mediaInfoProvider(movie.id))
        .value
        ?.durationSec;
    if (durationSec != null && durationSec > 0) {
      rows.add(['时长', _formatDurationSec(durationSec)]);
    } else if (movie.runtime != null && movie.runtime! > 0) {
      rows.add(['时长', '${movie.runtime} MIN']);
    }
    if (movie.fileSize != null && movie.fileSize! > 0) {
      rows.add(['文件大小', _formatBytes(movie.fileSize!)]);
    }
    if (movie.moviePart != null && movie.moviePart!.isNotEmpty) {
      rows.add(['分卷', movie.moviePart!]);
    }
    if (movie.lastDownloadedAt != null && movie.lastDownloadedAt!.isNotEmpty) {
      rows.add(['下载时间', movie.lastDownloadedAt!]);
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('详细信息', style: AppText.sectionTitle(context)),
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
String _formatDurationSec(double sec) {
  final s = sec.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  return h > 0
      ? '${h}h ${m.toString().padLeft(2, '0')}m ${ss.toString().padLeft(2, '0')}s'
      : '${m}m ${ss.toString().padLeft(2, '0')}s';
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
        final rows = <List<String>>[];
        if (detail.container != null) rows.add(['容器', detail.container!]);
        if (detail.fileSize != null && detail.fileSize! > 0) {
          rows.add(['大小', _formatBytes(detail.fileSize!)]);
        }
        final hasCards = streams.hasContent;
        if (rows.isEmpty && !hasCards) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('媒体信息', style: AppText.sectionTitle(context)),
              const SizedBox(height: 14),
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
              if (hasCards) ...[
                if (rows.isNotEmpty) const SizedBox(height: 10),
                MediaStreamCards(detail: detail),
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
    return GlassMenuAnchor<String>(
      width: 244,
      entries: _movieMoreEntries(c),
      tooltip: '更多',
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
                const SnackBar(
                  content: Text('音频提取任务已提交，可在任务中心查看进度'),
                  duration: Duration(seconds: 2),
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
              title: '同步到 NFO',
              message: '把当前元数据写入磁盘 NFO 文件?',
              run: () => ref.read(mediaRepositoryProvider).syncNfo(movie.id),
              successMsg: '已同步到 NFO',
            );
            break;
          case 'refresh_nfo':
            await _confirmAndRun(
              context,
              ref,
              title: 'NFO 重载',
              message: '从磁盘 NFO 重新加载,会覆盖当前元数据。',
              run: () =>
                  ref.read(mediaRepositoryProvider).refreshFromNfo(movie.id),
              successMsg: '已从 NFO 重载',
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

  List<GlassMenuEntry<String>> _movieMoreEntries(AppColors c) => [
    GlassMenuEntry<String>.action(
      value: 'edit',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.edit_outlined,
        label: '编辑影片',
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.divider(dividerColor: c.divider),
    GlassMenuEntry<String>.action(
      value: 'dbo_meta',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.cloud_download_outlined,
        label: '获取元数据',
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.action(
      value: 'resources',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.link,
        label: '获取资源',
        selected: selected,
        onTap: onTap,
      ),
    ),
    if ((movie.num ?? '').trim().isNotEmpty)
      GlassMenuEntry<String>.action(
        value: 'subtitle',
        builder: (context, selected, onTap) => GlassMenuRow(
          icon: Icons.subtitles_outlined,
          label: '获取字幕',
          selected: selected,
          onTap: onTap,
        ),
      ),
    GlassMenuEntry<String>.action(
      value: 'audio_extract',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.audiotrack_outlined,
        label: '提取音频',
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.divider(dividerColor: c.divider),
    GlassMenuEntry<String>.action(
      value: 'sync_nfo',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.upload_outlined,
        label: '同步到 NFO',
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.action(
      value: 'refresh_nfo',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.refresh,
        label: '从 NFO 重载',
        selected: selected,
        onTap: onTap,
      ),
    ),
    GlassMenuEntry<String>.divider(dividerColor: c.divider),
    GlassMenuEntry<String>.action(
      value: 'delete',
      builder: (context, selected, onTap) => GlassMenuRow(
        icon: Icons.delete_outline,
        label: '删除',
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
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
        SnackBar(content: Text('操作失败: ${toApiException(e).message}')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MovieDetail movie,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除影片'),
        content: Text(
          '确定删除「${movie.title}」?\n影片文件、海报、剧照、NFO 等关联资源都会被删除,且不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
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
        const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
      );
      // 返回上一页
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
  }
}
