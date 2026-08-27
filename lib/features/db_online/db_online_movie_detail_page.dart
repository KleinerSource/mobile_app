import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/providers.dart';
import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/db_online_movie.dart';
import '../../core/platform/app_action_sheet.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/filter_chip.dart';
import '../../shared/poster.dart';
import '../home/hero_backdrop.dart';
import '../movie_detail/movie_detail_page.dart' show showMovieImageLightbox;
import '../player/player_page.dart';
import '../settings/settings_common.dart';
import '../movie_detail/movie_detail_scaffold.dart';
import 'db_online_movie_card.dart';
import 'db_online_home_providers.dart';

class DbOnlineMovieDetailPage extends ConsumerWidget {
  const DbOnlineMovieDetailPage({super.key, required this.code})
    : videoId = null,
      assert(code != null);

  const DbOnlineMovieDetailPage.byVideoId({super.key, required this.videoId})
    : code = null,
      assert(videoId != null);

  final String? code;
  final String? videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = code?.trim().isNotEmpty == true
        ? ref.watch(dbOnlineMovieDetailProvider(code!.trim()))
        : ref.watch(dbOnlineMovieDetailByVideoIdProvider(videoId!.trim()));
    final config = ref.watch(serverConfigProvider);
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: toApiException(error).message,
          onRetry: () {
            if (code?.trim().isNotEmpty == true) {
              ref.invalidate(dbOnlineMovieDetailProvider(code!.trim()));
            } else {
              ref.invalidate(
                dbOnlineMovieDetailByVideoIdProvider(videoId!.trim()),
              );
            }
          },
        ),
        data: (movie) => _DbOnlineDetailBody(
          movie: movie,
          config: config,
          loadPlaybackMovie: () {
            final client = ref.read(requiredApiClientProvider).dbOnline;
            if (movie.code.trim().isNotEmpty) {
              return client.detail(
                movie.code,
                refresh: true,
                videoId: movie.videoId,
              );
            }
            final videoId = movie.videoId?.trim() ?? '';
            if (videoId.isEmpty) {
              throw StateError('影片缺少番号和 video_id');
            }
            return client.detailByVideoId(videoId, refresh: true);
          },
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('加载失败', style: AppText.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _DbOnlineDetailBody extends StatefulWidget {
  const _DbOnlineDetailBody({
    required this.movie,
    required this.config,
    required this.loadPlaybackMovie,
  });

  final DbOnlineMovieDetail movie;
  final ServerConfig? config;
  final Future<DbOnlineMovieDetail> Function() loadPlaybackMovie;

  @override
  State<_DbOnlineDetailBody> createState() => _DbOnlineDetailBodyState();
}

class _DbOnlineDetailBodyState extends State<_DbOnlineDetailBody> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPosition = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _syncHeroArt();
  }

  @override
  void didUpdateWidget(covariant _DbOnlineDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHeroArt();
  }

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPosition.dispose();
    super.dispose();
  }

  void _syncHeroArt() {
    final rawImage = widget.movie.coverUrl ?? widget.movie.thumbUrl;
    final image = widget.config == null || rawImage == null
        ? ''
        : resolveServerUrl(widget.config!, rawImage);
    final art = HeroArt(movieId: _stableHeroId(widget.movie.code), url: image);
    final current = _heroArts.value;
    if (current.length == 1 &&
        current.first.movieId == art.movieId &&
        current.first.url == art.url) {
      return;
    }
    _heroArts.value = [art];
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final config = widget.config;
    final image = movie.coverUrl ?? movie.thumbUrl;
    final imageUrl = config == null || image == null
        ? null
        : resolveServerUrl(config, image);
    return MovieDetailScaffold(
      heroArts: _heroArts,
      heroPosition: _heroPosition,
      hero: MovieDetailHero(
        imageUrl: imageUrl,
        title: movie.title,
        year: _yearFromDate(movie.date),
        bottomOverlay: movie.canPlay ? const OnlinePlayBadge() : null,
        onTap: imageUrl == null
            ? null
            : () {
                showMovieImageLightbox(context, urls: [imageUrl]);
              },
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: MovieDetailTitle(
              title: movie.title.trim().isEmpty ? movie.code : movie.title,
              originalTitle: movie.originTitle,
              year: _yearFromDate(movie.date),
              runtime: movie.duration,
              rating: movie.score,
            ),
          ),
        ),
        if (movie.canPlay)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: _PlayButton(
                movie: movie,
                loadPlaybackMovie: widget.loadPlaybackMovie,
              ),
            ),
          ),
        if (movie.overview?.isNotEmpty == true)
          SliverToBoxAdapter(
            child: MovieDetailSection(
              title: '简介',
              child: Text(
                movie.overview!,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(context).copyWith(height: 1.55),
              ),
            ),
          ),
        if (movie.previews.isNotEmpty && config != null)
          SliverToBoxAdapter(
            child: MovieDetailSection(
              title: '预览图',
              child: _DbOnlinePreviewRow(movie: movie, config: config),
            ),
          ),
        if (movie.actors.isNotEmpty)
          SliverToBoxAdapter(
            child: _DbOnlineChipSection(
              title: '演员',
              labels: [
                for (final actor in movie.actors)
                  if (actor.name.trim().isNotEmpty) _actorLabel(actor),
              ],
            ),
          ),
        if (_hasPersonName(movie.series))
          SliverToBoxAdapter(
            child: _DbOnlineChipSection(
              title: '系列',
              labels: [movie.series!.name],
              prefix: '◇ ',
            ),
          ),
        if (movie.categories.isNotEmpty)
          SliverToBoxAdapter(
            child: _DbOnlineChipSection(
              title: '分类',
              labels: [
                for (final category in movie.categories)
                  if (category.name.trim().isNotEmpty) category.name,
              ],
            ),
          ),
        if (_hasDetails(movie))
          SliverToBoxAdapter(
            child: MovieDetailSection(
              title: '详细信息',
              child: _DetailsTable(movie: movie),
            ),
          ),
        if (movie.relativeMovies.isNotEmpty && config != null)
          SliverToBoxAdapter(
            child: _RelatedMovieSection(
              title: '相关推荐',
              movies: movie.relativeMovies,
              config: config,
            ),
          ),
        if (movie.actorMovies.isNotEmpty && config != null)
          SliverToBoxAdapter(
            child: _RelatedMovieSection(
              title: '同演员作品',
              movies: movie.actorMovies,
              config: config,
            ),
          ),
        if (movie.library?.inLibrary == true)
          SliverToBoxAdapter(
            child: MovieDetailSection(
              title: '媒体库',
              child: Text(
                movie.library?.name ?? movie.library?.source ?? '已入库',
                style: AppText.body(context),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}

int _stableHeroId(String value) {
  return value.codeUnits.fold(0, (result, codeUnit) => result * 31 + codeUnit);
}

int? _yearFromDate(String? date) {
  final match = RegExp(r'^(\d{4})').firstMatch(date?.trim() ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

class _DbOnlinePreviewRow extends StatelessWidget {
  const _DbOnlinePreviewRow({required this.movie, required this.config});

  final DbOnlineMovieDetail movie;
  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.72)
        .clamp(220.0, 300.0)
        .toDouble();
    final urls = [
      for (final preview in movie.previews) resolveServerUrl(config, preview),
    ];
    return SizedBox(
      height: cardWidth * 9 / 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => SizedBox(
          width: cardWidth,
          child: Material(
            color: appColors(context).surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showMovieImageLightbox(
                context,
                urls: urls,
                initialIndex: index,
              ),
              child: Poster(
                url: urls[index],
                title: movie.title,
                aspectRatio: 16 / 9,
                radius: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _hasPersonName(DbOnlinePerson? person) =>
    person?.name.trim().isNotEmpty == true;

bool _hasDetails(DbOnlineMovieDetail movie) =>
    movie.code.trim().isNotEmpty ||
    movie.date?.trim().isNotEmpty == true ||
    (movie.watchedCount != null && movie.watchedCount! > 0);

class _DbOnlineChipSection extends StatelessWidget {
  const _DbOnlineChipSection({
    required this.title,
    required this.labels,
    this.prefix = '',
  });

  final String title;
  final List<String> labels;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final items = labels.where((item) => item.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return MovieDetailSection(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < items.length; i++)
            HueChip(
              label: '$prefix${items[i]}',
              hue: AppHues.all[i % AppHues.all.length],
            ),
        ],
      ),
    );
  }
}

String _actorLabel(DbOnlinePerson actor) {
  final labels = <String>[actor.name];
  if (actor.nameZht?.isNotEmpty == true && actor.nameZht != actor.name) {
    labels.add(actor.nameZht!);
  }
  if (actor.otherName?.isNotEmpty == true) labels.add('(${actor.otherName})');
  if (actor.gender?.isNotEmpty == true) labels.add(actor.gender!);
  if (actor.uncensored) labels.add('无码');
  return labels.join(' ');
}

class _RelatedMovieSection extends StatelessWidget {
  const _RelatedMovieSection({
    required this.title,
    required this.movies,
    required this.config,
  });

  final String title;
  final List<DbOnlineRecommendedMovie> movies;
  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    return MovieDetailSection(
      title: title,
      child: SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: movies.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            final movie = movies[index];
            final score = double.tryParse(movie.score ?? '');
            return DbOnlineMovieCard(
              width: 112,
              movie: DbOnlineMovie(
                id: movie.id ?? movie.number,
                number: movie.number,
                title: movie.title ?? movie.number,
                coverUrl: movie.coverUrl,
                thumbUrl: movie.thumbUrl,
                releaseDate: movie.releaseDate,
                duration: movie.duration == null
                    ? null
                    : '${movie.duration} 分钟',
                score: score,
                canPlay: movie.canPlay,
              ),
              config: config,
              onTap:
                  movie.number.trim().isEmpty &&
                      movie.id?.trim().isNotEmpty != true
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => movie.number.trim().isNotEmpty
                            ? DbOnlineMovieDetailPage(code: movie.number)
                            : DbOnlineMovieDetailPage.byVideoId(
                                videoId: movie.id!,
                              ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.movie, required this.loadPlaybackMovie});

  final DbOnlineMovieDetail movie;
  final Future<DbOnlineMovieDetail> Function() loadPlaybackMovie;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _openDbOnlinePlayback(
          context,
          movie,
          loadPlaybackMovie: loadPlaybackMovie,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.text,
          foregroundColor: colors.bg,
          disabledBackgroundColor: colors.surfaceAlt,
          disabledForegroundColor: colors.muted,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text(
          '在线播放',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

Future<void> _openDbOnlinePlayback(
  BuildContext context,
  DbOnlineMovieDetail movie, {
  Future<DbOnlineMovieDetail> Function()? loadPlaybackMovie,
}) async {
  var resolvedMovie = movie;
  var sources = resolvedMovie.playSources
      .where((item) => item.id > 0)
      .toList(growable: false);
  if (sources.isEmpty && loadPlaybackMovie != null) {
    try {
      resolvedMovie = await loadPlaybackMovie();
      sources = resolvedMovie.playSources
          .where((item) => item.id > 0)
          .toList(growable: false);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
      }
      return;
    }
  }
  if (sources.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无有效在线播放源')));
    }
    return;
  }
  if (!context.mounted) return;

  // 只有一个播放源时直接进入播放流程，不额外打断用户选择。
  final source = sources.length == 1
      ? sources.first
      : await showAppActionSheet<DbOnlinePlaySource>(
          context: context,
          title: '选择播放源',
          actions: _playSourceActions(sources),
        );
  if (source == null || !context.mounted) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => DbOnlinePlaybackPage(
        code: resolvedMovie.code,
        videoId: resolvedMovie.videoId,
        sources: sources,
        initialSourceId: source.id,
      ),
    ),
  );
}

List<AppActionSheetAction<DbOnlinePlaySource>> _playSourceActions(
  List<DbOnlinePlaySource> sources,
) {
  return [
    for (final item in sources)
      AppActionSheetAction<DbOnlinePlaySource>(
        label: item.name.trim().isEmpty ? '在线播放源 ${item.id}' : item.name.trim(),
        value: item,
      ),
  ];
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.movie});

  final DbOnlineMovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final rows = <(String, String)>[];
    if (movie.code.trim().isNotEmpty) rows.add(('番号', movie.code));
    if (movie.date?.trim().isNotEmpty == true) rows.add(('日期', movie.date!));
    if (movie.watchedCount != null && movie.watchedCount! > 0) {
      rows.add(('评分人数', '${movie.watchedCount}'));
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: i < rows.length - 1
                  ? Border(bottom: BorderSide(color: colors.divider))
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    rows[i].$1,
                    style: TextStyle(
                      color: colors.muted,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    style: TextStyle(
                      color: colors.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class DbOnlinePlaybackPage extends ConsumerStatefulWidget {
  const DbOnlinePlaybackPage({
    super.key,
    required this.code,
    required this.sources,
    this.videoId,
    this.initialSourceId,
  });

  final String code;
  final String? videoId;
  final List<DbOnlinePlaySource> sources;
  final int? initialSourceId;

  @override
  ConsumerState<DbOnlinePlaybackPage> createState() =>
      _DbOnlinePlaybackPageState();
}

class _DbOnlinePlaybackPageState extends ConsumerState<DbOnlinePlaybackPage> {
  late DbOnlinePlaySource _source;

  @override
  void initState() {
    super.initState();
    final validSources = widget.sources.where((item) => item.id > 0).toList();
    _source = validSources.firstWhere(
      (item) => item.id == widget.initialSourceId,
      orElse: () => const DbOnlinePlaySource(id: 0, name: ''),
    );
    if (_source.id <= 0 && validSources.isNotEmpty) {
      _source = validSources.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = DbOnlinePlayRequest(
      code: widget.code,
      sourceId: _source.id,
      videoId: widget.videoId,
    );
    final value = _source.id <= 0
        ? const AsyncValue<DbOnlinePlayEpisodes>.error(
            '暂无有效在线播放源',
            StackTrace.empty,
          )
        : ref.watch(dbOnlinePlayEpisodesProvider(request));
    final validSources = widget.sources.where((item) => item.id > 0).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _source.name.trim().isEmpty ? '在线播放' : '在线播放 · ${_source.name}',
        ),
        actions: [
          if (validSources.length > 1)
            IconButton(
              tooltip: '切换播放源',
              icon: const Icon(Icons.alt_route_outlined),
              onPressed: _switchSource,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_source.name.trim().isNotEmpty) ...[
            Text(_source.name, style: AppText.meta(context)),
            const SizedBox(height: 18),
          ],
          value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorBody(
              message: toApiException(error).message,
              onRetry: () =>
                  ref.invalidate(dbOnlinePlayEpisodesProvider(request)),
            ),
            data: (episodes) => episodes.episodes.isEmpty
                ? const Center(child: Text('暂无可播放剧集'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('剧集', style: AppText.sectionTitle(context)),
                      const SizedBox(height: 10),
                      for (final episode in episodes.episodes)
                        _EpisodeTile(code: widget.code, episode: episode),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchSource() async {
    final validSources = widget.sources.where((item) => item.id > 0).toList();
    if (validSources.length <= 1) return;
    final selected = await showAppActionSheet<DbOnlinePlaySource>(
      context: context,
      title: '选择播放源',
      actions: _playSourceActions(validSources),
    );
    if (!mounted || selected == null || selected.id == _source.id) return;
    setState(() => _source = selected);
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.code, required this.episode});

  final String code;
  final DbOnlinePlayEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualities = episode.qualities;
    final fallbackUrl = episode.urlForQuality(null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: settingsCardDecoration(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  episode.name.isEmpty
                      ? '第 ${episode.index > 0 ? episode.index : 1} 集'
                      : episode.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (qualities.length <= 1)
                IconButton(
                  tooltip: '播放',
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  onPressed: fallbackUrl.isEmpty
                      ? null
                      : () => _openPlayer(context, ref, fallbackUrl),
                )
              else
                PopupMenuButton<DbOnlinePlayQuality>(
                  tooltip: '选择清晰度',
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  onSelected: (quality) =>
                      _openPlayer(context, ref, quality.url),
                  itemBuilder: (_) => [
                    for (final quality in qualities)
                      PopupMenuItem(value: quality, child: Text(quality.name)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context, WidgetRef ref, String rawUrl) {
    final config = ref.read(serverConfigProvider);
    if (config == null) return;
    final url = resolveServerUrl(config, rawUrl);
    PlayerPage.openDirect(
      context,
      title: '$code · ${episode.name}',
      directUrl: url,
    );
  }
}
