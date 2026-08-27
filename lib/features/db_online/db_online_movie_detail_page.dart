import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/db_online_movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/filter_chip.dart';
import '../../shared/poster.dart';
import '../home/hero_backdrop.dart';
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
        data: (movie) => _DbOnlineDetailBody(movie: movie, config: config),
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
  const _DbOnlineDetailBody({required this.movie, required this.config});

  final DbOnlineMovieDetail movie;
  final ServerConfig? config;

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
      hero: _DbOnlineHeroHeader(
        imageUrl: imageUrl,
        title: movie.title,
        code: movie.code,
        canPlay: movie.canPlay,
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: _DbOnlineTitleBlock(movie: movie),
          ),
        ),
        if (movie.canPlay && movie.playSources.any((item) => item.id > 0))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: _PlayButton(movie: movie),
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
              child: SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: movie.previews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => SizedBox(
                    width: 180,
                    child: Poster(
                      url: resolveServerUrl(config, movie.previews[index]),
                      title: movie.title,
                      aspectRatio: 16 / 9,
                      radius: 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_hasCredits(movie))
          SliverToBoxAdapter(
            child: MovieDetailSection(
              title: '主创与分类',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _creditChips(movie),
              ),
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

class _DbOnlineHeroHeader extends StatelessWidget {
  const _DbOnlineHeroHeader({
    required this.imageUrl,
    required this.title,
    required this.code,
    required this.canPlay,
  });

  final String? imageUrl;
  final String title;
  final String code;
  final bool canPlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.45, 1.0],
          ).createShader(bounds),
          child: Poster(
            url: imageUrl,
            title: title.isEmpty ? code : title,
            aspectRatio: 16 / 9,
            radius: 0,
            imageAlignment: const Alignment(0, -0.6),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35],
            ),
          ),
        ),
        if (canPlay)
          const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OnlinePlayBadge(),
            ),
          ),
      ],
    );
  }
}

class _DbOnlineTitleBlock extends StatelessWidget {
  const _DbOnlineTitleBlock({required this.movie});

  final DbOnlineMovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final title = movie.title.trim().isEmpty ? movie.code : movie.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (movie.code.trim().isNotEmpty)
          Text(movie.code, style: AppText.eyebrow(context)),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: appColors(context).text,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.84,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        if (_movieMeta(movie) case final meta?)
          Text(meta, style: AppText.meta(context)),
      ],
    );
  }
}

bool _hasCredits(DbOnlineMovieDetail movie) =>
    _hasPersonName(movie.director) ||
    _hasPersonName(movie.maker) ||
    _hasPersonName(movie.publisher) ||
    _hasPersonName(movie.series) ||
    movie.categories.any((item) => item.name.trim().isNotEmpty) ||
    movie.actors.any((item) => item.name.trim().isNotEmpty);

bool _hasPersonName(DbOnlinePerson? person) =>
    person?.name.trim().isNotEmpty == true;

bool _hasDetails(DbOnlineMovieDetail movie) =>
    movie.code.trim().isNotEmpty ||
    movie.date?.trim().isNotEmpty == true ||
    (movie.duration != null && movie.duration! > 0) ||
    movie.score != null ||
    (movie.watchedCount != null && movie.watchedCount! > 0);

List<Widget> _creditChips(DbOnlineMovieDetail movie) {
  final labels = <String>[];
  if (_hasPersonName(movie.director)) {
    labels.add('导演 · ${movie.director!.name}');
  }
  if (_hasPersonName(movie.maker)) {
    labels.add('片商 · ${movie.maker!.name}');
  }
  if (_hasPersonName(movie.publisher)) {
    labels.add('发行 · ${movie.publisher!.name}');
  }
  if (_hasPersonName(movie.series)) {
    labels.add('系列 · ${movie.series!.name}');
  }
  labels.addAll(
    movie.categories.map((item) => item.name).where((x) => x.trim().isNotEmpty),
  );
  labels.addAll(
    movie.actors.where((item) => item.name.trim().isNotEmpty).map(_actorLabel),
  );
  return [
    for (var i = 0; i < labels.length; i++)
      HueChip(label: labels[i], hue: AppHues.all[i % AppHues.all.length]),
  ];
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
  const _PlayButton({required this.movie});

  final DbOnlineMovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final source = movie.playSources.where((item) => item.id > 0).firstOrNull;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: source == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DbOnlinePlaybackPage(
                    code: movie.code,
                    videoId: movie.videoId,
                    sources: movie.playSources,
                  ),
                ),
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
        label: Text(
          source == null ? '暂无在线播放源' : '在线播放',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
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
    if (movie.duration != null && movie.duration! > 0) {
      rows.add(('时长', '${movie.duration} MIN'));
    }
    if (movie.score != null) {
      rows.add(('评分', movie.score!.toStringAsFixed(1)));
    }
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
  });

  final String code;
  final String? videoId;
  final List<DbOnlinePlaySource> sources;

  @override
  ConsumerState<DbOnlinePlaybackPage> createState() =>
      _DbOnlinePlaybackPageState();
}

class _DbOnlinePlaybackPageState extends ConsumerState<DbOnlinePlaybackPage> {
  late DbOnlinePlaySource _source;

  @override
  void initState() {
    super.initState();
    _source = widget.sources.firstWhere(
      (item) => item.id > 0,
      orElse: () => const DbOnlinePlaySource(id: 0, name: ''),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('在线播放')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.sources.where((item) => item.id > 0).length > 1)
            DropdownButtonFormField<int>(
              initialValue: _source.id,
              decoration: const InputDecoration(labelText: '播放源'),
              items: [
                for (final item in widget.sources.where((item) => item.id > 0))
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (id) {
                final selected = widget.sources
                    .where((item) => item.id == id)
                    .firstOrNull;
                if (selected != null) setState(() => _source = selected);
              },
            ),
          const SizedBox(height: 18),
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

String? _movieMeta(DbOnlineMovieDetail movie) {
  final parts = <String>[];
  if (movie.date?.isNotEmpty == true) parts.add(movie.date!);
  if (movie.duration != null && movie.duration! > 0) {
    parts.add('${movie.duration} 分钟');
  }
  if (movie.score != null) parts.add('评分 ${movie.score!.toStringAsFixed(1)}');
  if (movie.watchedCount != null && movie.watchedCount! > 0) {
    parts.add('${movie.watchedCount} 人评分');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
