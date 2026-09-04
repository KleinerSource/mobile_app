import 'package:omm/features/db_online/api/db_online_api.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/models/db_online_search.dart';
import '../common/source_descriptor.dart';
import '../common/source_error_mapper.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'media_capabilities.dart';
import 'media_metadata_normalizer.dart';
import 'media_models.dart';
import 'dbo_media_source.dart';

/// DB Online adapter.  DBO is an online catalogue/playback source, not an
/// OMM-compatible local library manager, so it intentionally implements no
/// library or scan capability.
class DboMediaSourceAdapter implements DboMediaSource {
  DboMediaSourceAdapter(this.api, {this.serverId, this.endpoint});

  final DbOnlineApi api;
  final String? serverId;
  final String? endpoint;

  static const _sourceId = SourceId('dbo');

  @override
  SourceDescriptor get descriptor => SourceDescriptor(
    id: _sourceId,
    kind: SourceKind.dbo,
    name: 'DB Online',
    serverId: serverId,
    endpoint: endpoint,
  );

  @override
  Set<MediaCapability> get capabilities => const {
    MediaCapability.catalog,
    MediaCapability.movieDetails,
    MediaCapability.playback,
    MediaCapability.resources,
  };

  @override
  bool supports(MediaCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<MediaPage<MediaSummary>> listMovies(MediaQuery query) =>
      _call(() async {
        final page = switch (query.mode) {
          MediaCatalogMode.recommended =>
            await api
                .recommend(page: query.page, limit: query.limit)
                .then(
                  (movies) => DbOnlineMoviePage(
                    movies: List<DbOnlineMovie>.from(movies),
                    page: query.page,
                    limit: query.limit,
                    hasMore: movies.length >= query.limit,
                  ),
                ),
          MediaCatalogMode.tagged => await api.taggedMoviesPage(
            filterBy: query.tagFilter ?? '0:t:p::::',
            page: query.page,
            limit: query.limit,
            sortBy: query.sortBy ?? 'update',
            orderBy: query.orderBy ?? 'desc',
          ),
          MediaCatalogMode.search => await api.searchPage(
            query: query.searchText ?? '',
            page: query.page,
            limit: query.limit,
          ),
          MediaCatalogMode.latest => await api.latestPage(
            page: query.page,
            limit: query.limit,
            sortBy: query.sortBy ?? 'update',
            sort: query.orderBy,
          ),
        };
        return MediaPage(
          items: page.movies.map(_summaryFromMovie).toList(growable: false),
          page: page.page,
          limit: page.limit,
          total: page.total,
          hasMore: page.hasMore,
        );
      });

  @override
  Future<MediaPage<MediaSummary>> searchMovies(MediaQuery query) {
    return listMovies(query.copyWith(mode: MediaCatalogMode.search));
  }

  @override
  Future<MediaDetails> getMovie(MediaRef ref) => _call(() async {
    _checkRef(ref);
    final code = ref.alternateValue?.trim();
    final detail = code != null && code.isNotEmpty
        ? await api.detail(code, refresh: true, videoId: ref.value)
        : await api.detailByVideoId(ref.value, refresh: true);
    final summaryRef = MediaRef(
      sourceId: _sourceId,
      value: detail.videoId ?? detail.code,
      alternateValue: detail.videoId == null ? null : detail.code,
    );
    final summary = MediaSummary(
      ref: summaryRef,
      title: normalizeMediaText(detail.title) ?? '',
      code: normalizeMediaText(detail.code),
      year: normalizeMediaYear(detail.date),
      duration: normalizeMediaDurationMinutes(detail.duration),
      rating: normalizeMediaRating(detail.score),
      poster: detail.coverUrl,
      thumbnail: detail.thumbUrl,
      canPlay: detail.canPlay,
      attributes: {
        'date': detail.date,
        'has_cnsub': detail.hasCnsub,
        'watched_count': detail.watchedCount,
        'library': detail.library,
        'play_sources': detail.playSources,
      },
      payload: detail,
    );
    return MediaDetails(
      summary: summary,
      originalTitle: normalizeMediaText(detail.originTitle),
      overview: normalizeMediaText(detail.overview),
      tags: normalizeMediaLabels(detail.tags),
      genres: normalizeMediaLabels(detail.categories.map((item) => item.name)),
      actors: normalizeMediaLabels(detail.actors.map((item) => item.name)),
      attributes: {
        'categories': detail.categories,
        'series': detail.series,
        'relative_movies': detail.relativeMovies,
        'actor_movies': detail.actorMovies,
        'magnets': detail.magnets,
        'ed2ks': detail.ed2ks,
      },
      payload: detail,
    );
  });

  @override
  Future<DbOnlineMovieDetail> getMovieByCode(String code, {String? videoId}) =>
      _call(() => api.detail(code, refresh: true, videoId: videoId));

  @override
  Future<DbOnlineMovieDetail> getMovieByVideoId(String videoId) =>
      _call(() => api.detailByVideoId(videoId, refresh: true));

  @override
  Future<PlaybackDescriptor> resolvePlayback(
    MediaRef ref,
    PlaybackRequest request,
  ) => _call(() async {
    _checkRef(ref);
    final sourceId = request.playSourceId;
    if (sourceId == null || sourceId <= 0) {
      throw const SourceException('DBO 播放需要有效的播放源 ID');
    }
    final code = ref.alternateValue?.trim() ?? ref.value;
    final episodes = await api.onlinePlayEpisodes(
      code,
      sourceId: sourceId,
      videoId: ref.alternateValue == null ? null : ref.value,
    );
    if (episodes.episodes.isEmpty) {
      throw const SourceException('DBO 播放源没有可用剧集');
    }
    final requestedIndex = request.episodeIndex ?? 0;
    final episode = episodes.episodes.firstWhere(
      (item) => item.index == requestedIndex,
      orElse: () => episodes.episodes.first,
    );
    final rawUrl = episode.urlForQuality(request.quality);
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw const SourceException('DBO 播放源未返回有效地址');
    }
    return PlaybackDescriptor(uri: uri, startAt: 0, payload: episode);
  });

  @override
  Future<List<MediaResource>> listResources(
    MediaRef ref, {
    String? category,
  }) async {
    final detail = await getMovie(ref);
    final raw = category?.trim().toLowerCase();
    final result = <MediaResource>[];
    final sourcePayload = detail.attributes;
    if (raw == null || raw.isEmpty || raw == 'magnet') {
      final magnets = sourcePayload['magnets'];
      if (magnets is List) {
        for (final item in magnets.whereType<DbOnlineMagnet>()) {
          result.add(
            MediaResource(
              kind: MediaResourceKind.magnet,
              name: item.name,
              value: item.magnet,
              size: item.sizeMb == null
                  ? null
                  : (item.sizeMb! * 1024 * 1024).round(),
              attributes: {'site': item.site, 'tags': item.tags},
            ),
          );
        }
      }
    }
    if (raw == null || raw.isEmpty || raw == 'ed2k') {
      final ed2ks = sourcePayload['ed2ks'];
      if (ed2ks is List) {
        for (final item in ed2ks.whereType<DbOnlineEd2k>()) {
          result.add(
            MediaResource(
              kind: MediaResourceKind.ed2k,
              name: item.name,
              value: item.ed2k,
              size: item.sizeMb == null
                  ? null
                  : (item.sizeMb! * 1024 * 1024).round(),
              attributes: {'site': item.site, 'tags': item.tags},
            ),
          );
        }
      }
    }
    return result;
  }

  @override
  Future<DbOnlinePlayEpisodes> getPlayEpisodes({
    required String code,
    required int sourceId,
    String? videoId,
  }) => _call(
    () => api.onlinePlayEpisodes(code, sourceId: sourceId, videoId: videoId),
  );

  @override
  Future<DbOnlineActorSearchResult> searchActors({required String query}) =>
      _call(() => api.searchActors(query: query));

  @override
  Future<DbOnlineSearchEntityPage> searchSeriesPage({
    required String query,
    int page = 1,
    int limit = 24,
  }) =>
      _call(() => api.searchSeriesPage(query: query, page: page, limit: limit));

  MediaSummary _summaryFromMovie(DbOnlineMovie movie) => MediaSummary(
    ref: MediaRef(
      sourceId: _sourceId,
      value: movie.id,
      alternateValue: movie.number.isEmpty ? null : movie.number,
    ),
    title: normalizeMediaText(movie.title) ?? '',
    code: normalizeMediaText(movie.number),
    year: normalizeMediaYear(movie.releaseDate),
    duration: normalizeMediaDurationMinutes(movie.duration),
    rating: normalizeMediaRating(movie.score),
    poster: movie.coverUrl,
    thumbnail: movie.thumbUrl,
    canPlay: movie.canPlay,
    attributes: {
      'release_date': movie.releaseDate,
      'duration': movie.duration,
      'magnets_count': movie.magnetsCount,
      'has_cnsub': movie.hasCnsub,
      'library': movie.library,
    },
    payload: movie,
  );

  void _checkRef(MediaRef ref) {
    if (ref.sourceId != _sourceId) {
      throw SourceException('来源 ID 不属于 DBO：${ref.sourceId.value}');
    }
    if (ref.value.trim().isEmpty) {
      throw const SourceException('DBO 媒体 ID 不能为空');
    }
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SourceException {
      rethrow;
    } catch (error) {
      throw mapSourceError(error, fallback: 'DBO 请求失败');
    }
  }
}
