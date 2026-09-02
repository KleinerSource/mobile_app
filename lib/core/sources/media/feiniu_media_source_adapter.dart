import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/features/media_browser/api/feiniu_api.dart';
import 'package:omm/features/media_browser/api/feiniu_models.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'media_browser_media_source.dart';
import 'media_capabilities.dart';
import 'media_models.dart';

/// 飞牛影视媒体源适配器。
///
/// 飞牛的媒体协议与 Emby/Jellyfin 不同，但页面需要的能力相同，因此只
/// 在这里把飞牛 DTO 转成现有 MediaBrowser 模型，避免污染通用页面。
class FeiniuMediaSourceAdapter implements MediaBrowserMediaSource {
  FeiniuMediaSourceAdapter(
    this.api, {
    required this.sessionRepository,
    this.serverId,
    this.endpoint,
  });

  final FeiniuApi api;
  final AuthSessionRepository sessionRepository;
  final String? serverId;
  final String? endpoint;
  final _records = <String, FeiniuPlayRecord>{};

  static const _config = MediaBrowserConfig.feiniu;
  static const _sourceId = SourceId('feiniu');
  Future<Map<String, String>>? _genreNamesFuture;

  @override
  SourceDescriptor get descriptor => SourceDescriptor(
    id: _sourceId,
    kind: SourceKind.feiniu,
    name: _config.displayName,
    serverId: serverId,
    endpoint: endpoint,
  );

  @override
  Set<MediaCapability> get capabilities => const {
    MediaCapability.catalog,
    MediaCapability.movieDetails,
    MediaCapability.playback,
  };

  @override
  bool supports(MediaCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<MediaPage<MediaSummary>> listMovies(MediaQuery query) async {
    final page = await itemPage(
      parentId: query.filters['parentId']?.toString(),
      includeItemTypes: query.filters['includeItemTypes']?.toString(),
      recursive: query.filters['recursive'] is bool
          ? query.filters['recursive'] as bool
          : null,
      searchTerm: query.searchText,
      sortBy: query.sortBy,
      sortOrder: query.orderBy,
      startIndex: query.offset,
      limit: query.limit,
      isFavorite: query.filters['isFavorite'] is bool
          ? query.filters['isFavorite'] as bool
          : null,
    );
    return MediaPage(
      items: page.items.map(_summaryFromBrowserItem).toList(growable: false),
      page: query.page,
      limit: query.limit,
      total: page.total,
      hasMore: page.hasMore,
    );
  }

  @override
  Future<MediaPage<MediaSummary>> searchMovies(MediaQuery query) =>
      listMovies(query.copyWith(mode: MediaCatalogMode.search));

  @override
  Future<MediaDetails> getMovie(MediaRef ref) async {
    _checkRef(ref);
    final browserItem = await _loadBrowserItem(ref.value);
    return MediaDetails(
      summary: _summaryFromBrowserItem(browserItem),
      originalTitle: browserItem.originalTitle,
      overview: browserItem.overview,
      filePath: browserItem.mediaSources.isEmpty
          ? null
          : browserItem.mediaSources.first.path,
      fileSize: browserItem.mediaSources.isEmpty
          ? null
          : browserItem.mediaSources.first.sizeInBytes,
      genres: browserItem.genres,
      actors: [
        for (final person in browserItem.people)
          if (person.type == 'Actor' && person.name.isNotEmpty)
            person.role?.trim().isNotEmpty == true
                ? '${person.name}（${person.role}）'
                : person.name,
      ],
      attributes: <String, Object?>{
        'type': browserItem.type,
        'people': browserItem.people,
        'originalTitle': browserItem.originalTitle,
        'media_sources': browserItem.mediaSources,
      },
      payload: browserItem,
    );
  }

  @override
  Future<String?> userId() async => (await sessionRepository.load())?.userId;

  @override
  Future<List<MediaBrowserItem>> views() async => _call(() async {
    final databases = await api.mediaDbList();
    return databases
        .map((database) => database.toItem())
        .toList(growable: false);
  });

  @override
  Future<MediaBrowserLibraryStats> libraryStats() async => _call(() async {
    final page = await api.itemList(limit: 1);
    return MediaBrowserLibraryStats(
      movieCount: page.total,
      seriesCount: 0,
      episodeCount: 0,
    );
  });

  @override
  Future<List<MediaBrowserItem>> latestMedia({
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  }) async {
    final page = await itemPage(
      parentId: parentId,
      includeItemTypes: includeItemTypes,
      recursive: true,
      sortBy: 'create_time',
      sortOrder: 'Descending',
      limit: limit,
    );
    return page.items;
  }

  @override
  Future<MediaBrowserItemPage> resumeItems({int limit = 12}) async =>
      _call(() async {
        final page = await api.playList(limit: limit);
        return _pageFromItems(
          page.items.map((item) => item.toMediaBrowserItem()),
          total: page.total,
          limit: limit,
        );
      });

  @override
  Future<MediaBrowserItemPage> nextUp({
    String? parentId,
    int limit = 12,
  }) async =>
      const MediaBrowserItemPage(items: [], total: 0, startIndex: 0, limit: 0);

  @override
  Future<MediaBrowserItemPage> itemPage({
    String? parentId,
    String? includeItemTypes,
    bool? recursive,
    String? searchTerm,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? isFavorite,
    String? personIds,
  }) async => _call(() async {
    // fnos 列表接口不支持按人物过滤；演员头像区在 fnos 服务器上不提供
    // 点击跳转，该参数不会被传入。
    assert(personIds == null, 'fnos 不支持按人物过滤条目');
    final offset = startIndex ?? 0;
    final pageSize = limit ?? 24;
    if (isFavorite == true) {
      final favorites = await api.favoriteList(
        startIndex: offset,
        limit: pageSize,
      );
      return _pageFromItems(
        favorites.map((item) => item.toMediaBrowserItem()),
        total: favorites.length,
        startIndex: offset,
        limit: pageSize,
      );
    }
    final page = await api.itemList(
      parentGuid: parentId ?? '',
      excludeFolder: includeItemTypes != null,
      typeTags: _typeTags(includeItemTypes),
      searchTerm: searchTerm,
      startIndex: offset,
      limit: pageSize,
      sortColumn: _sortColumn(sortBy),
      sortType: (sortOrder ?? 'Ascending').toLowerCase().startsWith('desc')
          ? 'DESC'
          : 'ASC',
    );
    final items = includeItemTypes == null
        ? page.items
        : page.items
              .where((item) => _typeMatches(item.type, includeItemTypes))
              .toList(growable: false);
    return _pageFromItems(
      items.map((item) => item.toMediaBrowserItem()),
      total: page.total,
      startIndex: page.startIndex,
      limit: page.limit == 0 ? pageSize : page.limit,
    );
  });

  @override
  Future<MediaBrowserItem> getItem(String itemId) async =>
      _call(() => _loadBrowserItem(itemId));

  @override
  Future<List<MediaBrowserItem>> seasons(String seriesId) async =>
      _call(() async {
        final episodes = await api.episodeList(seriesId);
        final grouped = <String, FeiniuItem>{};
        for (final episode in episodes) {
          final key = episode.parentGuid.isEmpty
              ? '$seriesId-${episode.seasonNumber ?? 0}'
              : episode.parentGuid;
          grouped.putIfAbsent(
            key,
            () => FeiniuItem(
              guid: key,
              title: episode.parentTitle.isEmpty
                  ? '第 ${episode.seasonNumber ?? 0} 季'
                  : episode.parentTitle,
              type: 'Season',
              parentGuid: seriesId,
              tvTitle: episode.tvTitle,
              seasonNumber: episode.seasonNumber,
              poster: episode.poster,
              numberOfEpisodes: episode.numberOfEpisodes,
            ),
          );
        }
        return grouped.values
            .map((item) => item.toMediaBrowserItem())
            .toList(growable: false);
      });

  @override
  Future<MediaBrowserItemPage> episodes(
    String seriesId,
    String seasonId,
  ) async => _call(() async {
    var episodes = await api.episodeList(seasonId);
    if (episodes.isEmpty && seasonId != seriesId) {
      episodes = (await api.episodeList(
        seriesId,
      )).where((item) => item.parentGuid == seasonId).toList(growable: false);
    }
    final items = episodes
        .map((item) => item.toMediaBrowserItem())
        .where((item) => item.isEpisode)
        .toList(growable: false);
    return _pageFromItems(items, total: items.length, limit: items.length);
  });

  @override
  Future<List<MediaBrowserItem>> albumTracks(String albumId) async =>
      _call(() async {
        final page = await api.itemList(
          parentGuid: albumId,
          excludeFolder: true,
          sortColumn: 'sort_index',
          sortType: 'ASC',
          limit: 1000,
        );
        return page.items
            .where((item) => item.isAudio)
            .map((item) => item.toMediaBrowserItem())
            .toList(growable: false);
      });

  @override
  Future<Object?> fetchLyrics(String itemId) async => null;

  @override
  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite) async =>
      _call(() async {
        await api.markFavorite(itemId, favorite);
        return getItem(itemId);
      });

  @override
  Future<MediaBrowserItem> markPlayed(String itemId, bool played) async =>
      _call(() async {
        await api.markWatched(itemId, played);
        return getItem(itemId);
      });

  @override
  Future<PlaybackDescriptor> resolvePlayback(
    MediaRef ref,
    PlaybackRequest request,
  ) async => _call(() async {
    _checkRef(ref);
    final item = await api.item(ref.value);
    final streams = await api.streamList(ref.value);
    final file = streams.files.isEmpty ? null : streams.files.first;
    final itemMediaGuid = item.mediaGuid.isNotEmpty
        ? item.mediaGuid
        : file?.mediaGuid ?? '';
    final audio = request.audioStreamIndex == null
        ? streams.audio.firstWhere(
            (stream) => stream.isDefault,
            orElse: () => streams.audio.isEmpty
                ? const FeiniuStream(guid: '', title: '', kind: 'audio')
                : streams.audio.first,
          )
        : streams.audio.firstWhere(
            (stream) => stream.index == request.audioStreamIndex,
            orElse: () => streams.audio.isEmpty
                ? const FeiniuStream(guid: '', title: '', kind: 'audio')
                : streams.audio.first,
          );
    final subtitle = request.subtitleTrackId == null
        ? streams.subtitle.firstWhere(
            (stream) => stream.isDefault,
            orElse: () =>
                const FeiniuStream(guid: '', title: '', kind: 'subtitle'),
          )
        : streams.subtitle.firstWhere(
            (stream) => stream.guid == request.subtitleTrackId,
            orElse: () =>
                const FeiniuStream(guid: '', title: '', kind: 'subtitle'),
          );
    final info = await api.playInfo(
      itemGuid: ref.value,
      mediaGuid: itemMediaGuid,
      videoGuid: streams.video.isEmpty
          ? item.videoGuid
          : streams.video.first.guid,
      audioGuid: audio.guid.isEmpty ? item.audioGuid : audio.guid,
      subtitleGuid: subtitle.guid.isEmpty ? item.subtitleGuid : subtitle.guid,
    );
    final mediaGuid = info.mediaGuid.isEmpty ? itemMediaGuid : info.mediaGuid;
    if (mediaGuid.isEmpty) throw const SourceException('飞牛条目没有可用的媒体文件');
    final url = info.playLink.trim().isEmpty
        ? FeiniuApi.mediaRangeUrl(endpoint ?? '', mediaGuid)
        : FeiniuApi.resolveUrl(endpoint ?? '', info.playLink);
    final containerPath = file?.path.trim().isNotEmpty == true
        ? file!.path
        : item.fileName;
    final record = _recordFrom(info, item, url);
    _records[ref.value] = record;
    return PlaybackDescriptor(
      uri: Uri.parse(url),
      headers: FeiniuApi.mediaHeaders(await sessionRepository.accessToken()),
      mimeType: playbackMimeTypeForContainer(_extension(containerPath)),
      startAt:
          (info.positionSeconds > 0 ? info.positionSeconds : item.resumeSeconds)
              .toDouble(),
      audioTracks: [
        for (final stream in streams.audio)
          PlaybackTrack(
            id: stream.guid.isEmpty ? stream.index.toString() : stream.guid,
            label: stream.title.isEmpty
                ? '音轨 ${stream.index + 1}'
                : stream.title,
            language: stream.language,
            kind: 'audio',
            index: stream.index,
            codec: stream.codecName,
            channels: stream.channels,
            isDefault: stream.isDefault,
            isExternal: stream.isExternal,
          ),
      ],
      subtitleTracks: [
        for (final stream in streams.subtitle)
          PlaybackTrack(
            id: stream.guid.isEmpty ? stream.index.toString() : stream.guid,
            label: stream.title.isEmpty
                ? '字幕 ${stream.index + 1}'
                : stream.title,
            language: stream.language,
            kind: 'subtitle',
            index: stream.index,
            codec: stream.codecName ?? stream.format,
            isDefault: stream.isDefault,
            isForced: stream.isForced,
            isExternal: stream.isExternal,
            url: stream.isExternal && stream.guid.isNotEmpty
                ? FeiniuApi.subtitleUrl(endpoint ?? '', stream.guid)
                : null,
            source: stream.isExternal ? 'external' : 'embedded',
            playable: !stream.isBitmap,
          ),
      ],
      payload: info,
    );
  });

  @override
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) => _report(itemId, positionTicks);

  @override
  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
    bool isPaused = false,
  }) => _report(itemId, positionTicks);

  @override
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) async {
    await _report(itemId, positionTicks);
    final record = _records.remove(itemId);
    if (record != null) {
      await api.stopPlay(
        itemGuid: record.itemGuid,
        mediaGuid: record.mediaGuid,
      );
    }
  }

  @override
  Future<String> imageUrl(
    String itemId, {
    String imageType = 'Primary',
    int? maxWidth,
    String? tag,
  }) async {
    final value = tag?.trim() ?? '';
    if (value.isNotEmpty) {
      return FeiniuApi.resolveAssetUrl(endpoint ?? '', value);
    }
    final suffix = switch (imageType.toLowerCase()) {
      'backdrop' => 'backdrop.jpg',
      'thumb' => 'thumb.jpg',
      _ => 'poster.jpg',
    };
    return FeiniuApi.resolveAssetUrl(
      endpoint ?? '',
      '/mediadb/${Uri.encodeComponent(itemId)}/$suffix',
    );
  }

  Future<MediaBrowserItem> _loadBrowserItem(String itemId) async {
    final item = await api.item(itemId);
    final guid = item.guid.isEmpty ? itemId : item.guid;
    final needsStreams = item.isPlayable || item.mediaGuid.isNotEmpty;
    final needsPeople =
        item.people.isEmpty &&
        (item.type == 'Movie' || item.type == 'Series' || item.isEpisode);
    final needsGenres = item.genres.any(
      (genre) => int.tryParse(genre.trim()) != null,
    );

    final streamsFuture = needsStreams
        ? api.streamList(guid)
        : Future.value(const FeiniuStreamList());
    final peopleFuture = needsPeople
        ? api.personList(guid)
        : Future.value(const <FeiniuPerson>[]);
    final genresFuture = needsGenres
        ? (_genreNamesFuture ??= api.genreMap())
        : Future.value(const <String, String>{});
    final values = await Future.wait<Object>([
      streamsFuture,
      peopleFuture,
      genresFuture,
    ]);
    final streams = values[0] as FeiniuStreamList;
    final people = values[1] as List<FeiniuPerson>;
    final genreNames = values[2] as Map<String, String>;
    final resolvedPeople = item.people.isNotEmpty
        ? item.people
        : people
              .map((person) => person.toMediaBrowserPerson())
              .toList(growable: false);
    final resolvedGenres = item.genres
        .map((genre) => genreNames[genre] ?? genre)
        .toList(growable: false);
    return item.toMediaBrowserItem(
      resolvedGenres: resolvedGenres,
      resolvedPeople: resolvedPeople,
      streamList: streams,
    );
  }

  Future<void> _report(String itemId, int positionTicks) async =>
      _call(() async {
        final record = await _recordFor(itemId);
        await api.recordPlay(_withPosition(record, positionTicks));
      });

  Future<FeiniuPlayRecord> _recordFor(String itemId) async {
    final cached = _records[itemId];
    if (cached != null) return cached;
    final item = await api.item(itemId);
    final info = await api.playInfo(
      itemGuid: itemId,
      mediaGuid: item.mediaGuid,
      videoGuid: item.videoGuid,
      audioGuid: item.audioGuid,
      subtitleGuid: item.subtitleGuid,
    );
    final mediaGuid = info.mediaGuid.isEmpty ? item.mediaGuid : info.mediaGuid;
    final record = _recordFrom(
      info,
      item,
      FeiniuApi.mediaRangeUrl(endpoint ?? '', mediaGuid),
    );
    _records[itemId] = record;
    return record;
  }

  FeiniuPlayRecord _recordFrom(
    FeiniuPlayInfo info,
    FeiniuItem item,
    String url,
  ) => FeiniuPlayRecord(
    itemGuid: info.itemGuid.isEmpty ? item.guid : info.itemGuid,
    mediaGuid: info.mediaGuid.isEmpty ? item.mediaGuid : info.mediaGuid,
    videoGuid: info.videoGuid.isEmpty ? item.videoGuid : info.videoGuid,
    audioGuid: info.audioGuid.isEmpty ? item.audioGuid : info.audioGuid,
    subtitleGuid: info.subtitleGuid.isEmpty
        ? item.subtitleGuid
        : info.subtitleGuid,
    playLink: info.playLink.isEmpty ? url : info.playLink,
    positionSeconds: info.positionSeconds,
    durationSeconds: info.durationSeconds > 0
        ? info.durationSeconds
        : item.durationSeconds,
  );

  FeiniuPlayRecord _withPosition(FeiniuPlayRecord record, int positionTicks) {
    final position = secondsFromTicks(positionTicks);
    return FeiniuPlayRecord(
      itemGuid: record.itemGuid,
      mediaGuid: record.mediaGuid,
      videoGuid: record.videoGuid,
      audioGuid: record.audioGuid,
      subtitleGuid: record.subtitleGuid,
      playLink: record.playLink,
      positionSeconds: position,
      durationSeconds: record.durationSeconds,
    );
  }

  int secondsFromTicks(int ticks) =>
      ticks <= 0 ? 0 : (ticks / 10000000).round();

  MediaBrowserItemPage _pageFromItems(
    Iterable<MediaBrowserItem> items, {
    required int total,
    int startIndex = 0,
    int limit = 0,
  }) {
    final values = items.toList(growable: false);
    return MediaBrowserItemPage(
      items: values,
      total: total,
      startIndex: startIndex,
      limit: limit == 0 ? values.length : limit,
    );
  }

  MediaSummary _summaryFromBrowserItem(MediaBrowserItem item) {
    return MediaSummary(
      ref: MediaRef(sourceId: _sourceId, value: item.id),
      title: item.name,
      year: item.productionYear,
      rating: item.communityRating,
      duration: item.runtimeMinutes,
      poster: _assetUrl(item.primaryImageTag),
      thumbnail: _assetUrl(item.thumbImageTag ?? item.primaryImageTag),
      fanart: item.backdropImageTags.isEmpty
          ? null
          : _assetUrl(item.backdropImageTags.first),
      canPlay: item.isPlayable || item.isAudio,
      attributes: <String, Object?>{
        'type': item.type,
        'isFavorite': item.userData.isFavorite,
        'isWatched': item.userData.played,
        'resumeSeconds': item.userData.resumeSeconds,
      },
      payload: item,
    );
  }

  String _sortColumn(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.contains('date') || normalized.contains('create')
        ? 'create_time'
        : 'sort_title';
  }

  List<String>? _typeTags(String? includeItemTypes) {
    final values = includeItemTypes
        ?.split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (values == null || values.isEmpty) return null;
    final tags = <String>[];
    for (final value in values) {
      final tag = switch (value.toLowerCase()) {
        'movie' => 'Movie',
        'series' || 'season' || 'episode' => 'TV',
        'music' || 'musicalbum' || 'audio' => 'Music',
        'collectionfolder' || 'directory' => 'Directory',
        _ => value,
      };
      if (!tags.contains(tag)) tags.add(tag);
    }
    return tags;
  }

  bool _typeMatches(String value, String requested) => requested
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .contains(value.toLowerCase());

  String? _assetUrl(String? path) {
    final value = path?.trim() ?? '';
    return value.isEmpty
        ? null
        : FeiniuApi.resolveAssetUrl(endpoint ?? '', value);
  }

  void _checkRef(MediaRef ref) {
    if (ref.sourceId != _sourceId) {
      throw SourceException(
        '来源 ID 不属于 ${_config.displayName}：${ref.sourceId.value}',
      );
    }
    if (ref.value.trim().isEmpty) throw const SourceException('飞牛条目 ID 不能为空');
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SourceException {
      rethrow;
    } catch (error) {
      throw SourceException(error.toString());
    }
  }

  static String? _extension(String value) {
    final index = value.lastIndexOf('.');
    if (index < 0 || index == value.length - 1) return null;
    return value.substring(index + 1).toLowerCase();
  }
}
