import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/url_resolver.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/db_online_movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../player/player_page.dart';
import '../settings/settings_common.dart';
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
    final target = code?.trim().isNotEmpty == true
        ? code!.trim()
        : videoId?.trim() ?? '';
    final value = code?.trim().isNotEmpty == true
        ? ref.watch(dbOnlineMovieDetailProvider(code!.trim()))
        : ref.watch(dbOnlineMovieDetailByVideoIdProvider(videoId!.trim()));
    final config = ref.watch(serverConfigProvider);
    return Scaffold(
      backgroundColor: appColors(context).bg,
      appBar: AppBar(title: Text(target), backgroundColor: Colors.transparent),
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

class _DbOnlineDetailBody extends StatelessWidget {
  const _DbOnlineDetailBody({required this.movie, required this.config});

  final DbOnlineMovieDetail movie;
  final ServerConfig? config;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final image = movie.coverUrl ?? movie.thumbUrl;
    final imageUrl = config == null || image == null
        ? null
        : resolveServerUrl(config!, image);
    return GlowBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                height: 186,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl == null
                      ? ColoredBox(
                          color: colors.surface,
                          child: const Icon(Icons.movie_outlined, size: 36),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: colors.surface,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.code,
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(movie.title, style: AppText.pageTitle(context)),
                    const SizedBox(height: 12),
                    Text(
                      _movieMeta(movie),
                      style: TextStyle(color: colors.muted),
                    ),
                    if (movie.canPlay) ...[
                      const SizedBox(height: 16),
                      _PlayButton(movie: movie),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (movie.overview?.isNotEmpty == true)
            _InfoSection(title: '简介', child: Text(movie.overview!)),
          if (movie.previews.isNotEmpty && config != null)
            _InfoSection(
              title: '预览图',
              child: SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: movie.previews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      resolveServerUrl(config!, movie.previews[index]),
                      width: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 180,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _InfoSection(
            title: '主创与分类',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (movie.director?.name.isNotEmpty == true)
                  _InfoChip('导演 · ${movie.director!.name}'),
                if (movie.maker?.name.isNotEmpty == true)
                  _InfoChip('片商 · ${movie.maker!.name}'),
                if (movie.publisher?.name.isNotEmpty == true)
                  _InfoChip('发行 · ${movie.publisher!.name}'),
                if (movie.series?.name.isNotEmpty == true)
                  _InfoChip('系列 · ${movie.series!.name}'),
                for (final item in movie.categories) _InfoChip(item.name),
                for (final item in movie.actors)
                  if (item.name.isNotEmpty) _InfoChip(_actorLabel(item)),
              ],
            ),
          ),
          if (movie.relativeMovies.isNotEmpty && config != null)
            _RelatedMovieSection(
              title: '相关推荐',
              movies: movie.relativeMovies,
              config: config!,
            ),
          if (movie.actorMovies.isNotEmpty && config != null)
            _RelatedMovieSection(
              title: '同演员作品',
              movies: movie.actorMovies,
              config: config!,
            ),
          if (movie.magnets.isNotEmpty)
            _InfoSection(
              title: '磁力资源 (${movie.magnets.length})',
              child: _ResourceList<DbOnlineMagnet>(
                items: movie.magnets,
                label: (item) => item.name,
                value: (item) => item.magnet,
              ),
            ),
          if (movie.ed2ks.isNotEmpty)
            _InfoSection(
              title: 'ED2K 资源 (${movie.ed2ks.length})',
              child: _ResourceList<DbOnlineEd2k>(
                items: movie.ed2ks,
                label: (item) => item.name,
                value: (item) => item.ed2k,
              ),
            ),
          if (movie.library?.inLibrary == true)
            _InfoSection(
              title: '媒体库',
              child: Text(
                movie.library?.name ?? movie.library?.source ?? '已入库',
              ),
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
    return _InfoSection(
      title: title,
      child: SizedBox(
        height: 206,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: movies.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) =>
              _RelatedMovieCard(movie: movies[index], config: config),
        ),
      ),
    );
  }
}

class _RelatedMovieCard extends StatelessWidget {
  const _RelatedMovieCard({required this.movie, required this.config});

  final DbOnlineRecommendedMovie movie;
  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final image = movie.thumbUrl == null
        ? null
        : resolveServerUrl(config, movie.thumbUrl!);
    final code = movie.number.trim();
    final videoId = movie.id?.trim() ?? '';
    return SizedBox(
      width: 126,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: code.isEmpty && videoId.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => code.isNotEmpty
                      ? DbOnlineMovieDetailPage(code: code)
                      : DbOnlineMovieDetailPage.byVideoId(videoId: videoId),
                ),
              ),
        child: Ink(
          decoration: settingsCardDecoration(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image == null
                          ? ColoredBox(
                              color: colors.surface,
                              child: const Icon(Icons.movie_outlined),
                            )
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: colors.surface,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      if (movie.canPlay)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code.isEmpty ? '未命名影片' : code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (movie.title?.isNotEmpty == true &&
                          movie.title != code) ...[
                        const SizedBox(height: 2),
                        Text(
                          movie.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
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
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.movie});

  final DbOnlineMovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final source = movie.playSources.where((item) => item.id > 0).firstOrNull;
    return FilledButton.icon(
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
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(source == null ? '暂无在线播放源' : '在线播放'),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.sectionTitle(context)),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: settingsCardDecoration(context),
            child: Padding(padding: const EdgeInsets.all(14), child: child),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Chip(
      label: Text(label),
      backgroundColor: colors.surface,
      side: BorderSide(color: colors.divider),
    );
  }
}

class _ResourceList<T> extends StatelessWidget {
  const _ResourceList({
    required this.items,
    required this.label,
    required this.value,
  });

  final List<T> items;
  final String Function(T) label;
  final String Function(T) value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 18),
          Text(label(items[i]), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          SelectableText(
            value(items[i]),
            maxLines: 2,
            style: TextStyle(color: appColors(context).muted, fontSize: 11),
          ),
        ],
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

String _movieMeta(DbOnlineMovieDetail movie) {
  final parts = <String>[];
  if (movie.date?.isNotEmpty == true) parts.add(movie.date!);
  if (movie.duration != null && movie.duration! > 0) {
    parts.add('${movie.duration} 分钟');
  }
  if (movie.score != null) parts.add('评分 ${movie.score!.toStringAsFixed(1)}');
  if (movie.watchedCount != null && movie.watchedCount! > 0) {
    parts.add('${movie.watchedCount} 人评分');
  }
  if (movie.magnets.isNotEmpty) parts.add('${movie.magnets.length} 磁链');
  return parts.isEmpty ? '暂无信息' : parts.join(' · ');
}
