import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/features/media_browser/api/media_browser_api.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import '../common/source_descriptor.dart';
import '../common/source_error_mapper.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'media_capabilities.dart';
import 'media_browser_media_source.dart';
import 'media_models.dart';
import 'playback_device_profile.dart';

/// MediaBrowser（Emby/Jellyfin）adapter。
///
/// 两家都是独立的外部媒体服务器：目录/详情/播放走通用能力，媒体库管理
/// 与扫描由服务端完成，因此不实现这两类能力。直链播放优先（static=true
/// 原始文件），需要转码时使用 PlaybackInfo 返回的 TranscodingUrl。
/// 项目差异（路径前缀 / token 参数 / 显示名）全部来自 [config]。
class MediaBrowserMediaSourceAdapter implements MediaBrowserMediaSource {
  MediaBrowserMediaSourceAdapter(
    this.api, {
    required this.sessionRepository,
    this.serverId,
    this.endpoint,
  });

  final MediaBrowserApi api;
  final AuthSessionRepository sessionRepository;
  final String? serverId;
  final String? endpoint;

  MediaBrowserConfig get config => api.config;

  SourceId get _sourceId => SourceId(config.sourceId);

  @override
  SourceDescriptor get descriptor => SourceDescriptor(
    id: _sourceId,
    kind: switch (config.project) {
      ServerProject.emby => SourceKind.emby,
      ServerProject.jellyfin => SourceKind.jellyfin,
      _ => throw ArgumentError('非 MediaBrowser 项目：${config.project}'),
    },
    name: config.displayName,
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
  Future<String?> userId() async =>
      (await sessionRepository.load())?.userId;

  @override
  Future<MediaPage<MediaSummary>> listMovies(MediaQuery query) =>
      _call(() async {
        final uid = await _requireUserId();
        final filters = query.filters;
        final defaultSort = switch (query.mode) {
          MediaCatalogMode.latest => 'DateCreated',
          MediaCatalogMode.recommended => 'CommunityRating',
          _ => 'SortName',
        };
        final page = await api.items(
          uid,
          parentId: filters['parentId']?.toString(),
          includeItemTypes: filters['includeItemTypes']?.toString(),
          recursive: filters['recursive'] is bool
              ? filters['recursive'] as bool
              : null,
          searchTerm: query.searchText,
          sortBy: query.sortBy ?? defaultSort,
          sortOrder: (query.orderBy ?? 'desc') == 'asc'
              ? 'Ascending'
              : 'Descending',
          startIndex: query.offset,
          limit: query.limit,
          isFavorite: filters['isFavorite'] is bool
              ? filters['isFavorite'] as bool
              : null,
        );
        return MediaPage(
          items: await Future.wait(page.items.map(_summaryFromItem)),
          page: query.page,
          limit: query.limit,
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
    final uid = await _requireUserId();
    final item = await api.item(uid, ref.value);
    return _detailsFromItem(item);
  });

  @override
  Future<PlaybackDescriptor> resolvePlayback(
    MediaRef ref,
    PlaybackRequest request,
  ) => _call(() async {
    _checkRef(ref);
    final uid = await _requireUserId();
    final token = await sessionRepository.accessToken();
    final base = endpoint ?? '';
    final item = await api.item(uid, ref.value);
    final info = await api.playbackInfo(
      uid,
      ref.value,
      deviceProfile: playbackDeviceProfile(),
    );
    final mediaSource = info.mediaSources.isEmpty ? null : info.mediaSources.first;
    if (mediaSource == null || mediaSource.id.isEmpty) {
      throw SourceException('${config.displayName} 条目没有可用的媒体源');
    }
    final wantTranscode =
        request.forceVideoTranscode ||
        (request.quality != 'auto' &&
            request.quality.trim().isNotEmpty &&
            mediaSource.transcodingUrl?.trim().isNotEmpty == true);
    final transcodingUrl = mediaSource.transcodingUrl?.trim();
    final isTranscode = wantTranscode &&
        transcodingUrl != null &&
        transcodingUrl.isNotEmpty;
    final Uri uri;
    if (isTranscode) {
      uri = Uri.parse(MediaBrowserApi.resolveUrl(base, transcodingUrl));
    } else {
      uri = Uri.parse(
        MediaBrowserApi.streamUrl(
          config: config,
          baseUrl: base,
          itemId: ref.value,
          mediaSourceId: mediaSource.id,
          token: token,
        ),
      );
    }
    return PlaybackDescriptor(
      uri: uri,
      // 直连 URL 没有扩展名，带上容器提示让播放器选择正确的内核
      // （如 MKV 路由到 FFmpeg），避免 AVPlayer 报格式不支持。
      mimeType: isTranscode
          ? 'application/vnd.apple.mpegurl'
          : playbackMimeTypeForContainer(mediaSource.container),
      startAt: _resumeSeconds(item).toDouble(),
      isTranscode: isTranscode,
      audioTracks: _tracks(mediaSource, 'Audio'),
      subtitleTracks: _tracks(mediaSource, 'Subtitle'),
      payload: info,
    );
  });

  @override
  Future<List<MediaBrowserItem>> views() => _call(() async {
    final uid = await _requireUserId();
    return api.views(uid);
  });

  @override
  Future<List<MediaBrowserItem>> latestMedia({
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  }) => _call(() async {
    final uid = await _requireUserId();
    return api.latestMedia(
      uid,
      parentId: parentId,
      includeItemTypes: includeItemTypes,
      limit: limit,
    );
  });

  @override
  Future<MediaBrowserItemPage> resumeItems({int limit = 12}) => _call(() async {
    final uid = await _requireUserId();
    return api.resumeItems(uid, limit: limit);
  });

  @override
  Future<MediaBrowserItemPage> nextUp({String? parentId, int limit = 12}) => _call(() async {
    final uid = await _requireUserId();
    return api.nextUp(uid, parentId: parentId, limit: limit);
  });

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
  }) => _call(() async {
    final uid = await _requireUserId();
    return api.items(
      uid,
      parentId: parentId,
      includeItemTypes: includeItemTypes,
      recursive: recursive,
      searchTerm: searchTerm,
      sortBy: sortBy,
      sortOrder: sortOrder,
      startIndex: startIndex,
      limit: limit,
      isFavorite: isFavorite,
    );
  });

  @override
  Future<MediaBrowserItem> getItem(String itemId) => _call(() async {
    final uid = await _requireUserId();
    return api.item(uid, itemId);
  });

  @override
  Future<List<MediaBrowserItem>> seasons(String seriesId) => _call(() async {
    final uid = await _requireUserId();
    return api.seasons(uid, seriesId);
  });

  @override
  Future<MediaBrowserItemPage> episodes(String seasonId) => _call(() async {
    final uid = await _requireUserId();
    return api.episodes(uid, seasonId);
  });

  @override
  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite) => _call(() async {
    final uid = await _requireUserId();
    return api.markFavorite(uid, itemId, favorite);
  });

  @override
  Future<MediaBrowserItem> markPlayed(String itemId, bool played) => _call(() async {
    final uid = await _requireUserId();
    return api.markPlayed(uid, itemId, played);
  });

  @override
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) => _call(() => api.reportPlaybackStart(
    itemId: itemId,
    positionTicks: positionTicks,
    playSessionId: playSessionId,
  ));

  @override
  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
    bool isPaused = false,
  }) => _call(() => api.reportPlaybackProgress(
    itemId: itemId,
    positionTicks: positionTicks,
    playSessionId: playSessionId,
    isPaused: isPaused,
  ));

  @override
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) => _call(() => api.reportPlaybackStopped(
    itemId: itemId,
    positionTicks: positionTicks,
    playSessionId: playSessionId,
  ));

  @override
  Future<String> imageUrl(
    String itemId, {
    String imageType = 'Primary',
    int? maxWidth,
  }) async {
    final token = await sessionRepository.accessToken();
    return MediaBrowserApi.imageUrl(
      config: config,
      baseUrl: endpoint ?? '',
      itemId: itemId,
      imageType: imageType,
      maxWidth: maxWidth,
      token: token,
    );
  }

  Future<MediaSummary> _summaryFromItem(MediaBrowserItem item) async {
    return MediaSummary(
      ref: _refFor(item),
      title: item.name,
      year: item.productionYear,
      rating: item.communityRating,
      duration: mediaBrowserTicksToSeconds(item.runTimeTicks),
      poster: await imageUrl(item.id, maxWidth: 440),
      thumbnail: item.thumbImageTag == null
          ? null
          : await imageUrl(item.id, imageType: 'Thumb', maxWidth: 440),
      fanart: item.backdropImageTags.isEmpty
          ? null
          : await imageUrl(item.id, imageType: 'Backdrop', maxWidth: 1280),
      canPlay: item.isPlayable,
      attributes: {
        'type': item.type,
        'series_name': item.seriesName,
        'parent_index_number': item.parentIndexNumber,
        'index_number': item.indexNumber,
        'played': item.userData.played,
        'is_favorite': item.userData.isFavorite,
        'resume_pct': _resumePercent(item),
      },
      payload: item,
    );
  }

  Future<MediaDetails> _detailsFromItem(MediaBrowserItem item) async {
    return MediaDetails(
      summary: await _summaryFromItem(item),
      overview: item.overview,
      filePath: item.mediaSources.isEmpty
          ? null
          : item.mediaSources.first.path,
      fileSize: item.mediaSources.isEmpty
          ? null
          : item.mediaSources.first.sizeInBytes,
      genres: item.genres,
      actors: [
        for (final person in item.people)
          if (person.name.isNotEmpty)
            person.role?.trim().isNotEmpty == true
                ? '${person.name}（${person.role}）'
                : person.name,
      ],
      attributes: {
        'type': item.type,
        'series_id': item.seriesId,
        'season_id': item.seasonId,
        'collection_type': item.collectionType,
        'people': item.people,
        'media_sources': item.mediaSources,
        'child_count': item.childCount,
        'recursive_item_count': item.recursiveItemCount,
      },
      payload: item,
    );
  }

  MediaRef _refFor(MediaBrowserItem item) => MediaRef(sourceId: _sourceId, value: item.id);

  /// 恢复播放位置：看完（>= 95%）的条目从头开始。
  int _resumeSeconds(MediaBrowserItem item) {
    final resume = item.userData.resumeSeconds;
    if (resume <= 0) return 0;
    final runtime = mediaBrowserTicksToSeconds(item.runTimeTicks);
    if (runtime > 0 && resume >= runtime * 0.95) return 0;
    return resume;
  }

  double _resumePercent(MediaBrowserItem item) {
    final runtime = mediaBrowserTicksToSeconds(item.runTimeTicks);
    if (runtime <= 0) return 0;
    return (item.userData.resumeSeconds / runtime).clamp(0.0, 1.0);
  }

  List<PlaybackTrack> _tracks(MediaBrowserMediaSourceDto source, String type) {
    return [
      for (final stream in source.mediaStreams)
        if (stream.type == type && stream.index >= 0)
          PlaybackTrack(
            id: stream.index.toString(),
            label: stream.displayTitle?.trim().isNotEmpty == true
                ? stream.displayTitle!.trim()
                : stream.codec ?? stream.type,
            language: stream.language,
            kind: type.toLowerCase(),
          ),
    ];
  }

  Future<String> _requireUserId() async {
    final uid = (await sessionRepository.load())?.userId;
    if (uid == null || uid.trim().isEmpty) {
      throw SourceException('${config.displayName} 用户信息缺失，请重新登录');
    }
    return uid;
  }

  void _checkRef(MediaRef ref) {
    if (ref.sourceId != _sourceId) {
      throw SourceException(
        '来源 ID 不属于 ${config.displayName}：${ref.sourceId.value}',
      );
    }
    if (ref.value.trim().isEmpty) {
      throw SourceException('${config.displayName} 条目 ID 不能为空');
    }
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SourceException {
      rethrow;
    } catch (error) {
      throw mapSourceError(error, fallback: '${config.displayName} 请求失败');
    }
  }
}
