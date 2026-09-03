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
  Future<String?> userId() async => (await sessionRepository.load())?.userId;

  @override
  Future<MediaBrowserUser> currentUser() => _call(() async {
    final uid = await _requireUserId();
    return api.validateSession(uid);
  });

  @override
  Future<List<MediaBrowserLibrary>> virtualFolders() =>
      _call(() => api.virtualFolders());

  @override
  Future<void> addVirtualFolder({
    required String name,
    required String collectionType,
    required List<String> paths,
  }) => _call(
    () => api.addVirtualFolder(
      name: name,
      collectionType: collectionType,
      paths: paths,
    ),
  );

  @override
  Future<void> removeVirtualFolder(String name) =>
      _call(() => api.removeVirtualFolder(name));

  @override
  Future<void> renameVirtualFolder({
    required String name,
    required String newName,
  }) => _call(() => api.renameVirtualFolder(name: name, newName: newName));

  @override
  Future<void> addMediaPath({
    required String libraryName,
    required String path,
  }) => _call(() => api.addMediaPath(libraryName: libraryName, path: path));

  @override
  Future<void> removeMediaPath({
    required String libraryName,
    required String path,
  }) => _call(() => api.removeMediaPath(libraryName: libraryName, path: path));

  @override
  Future<void> updateVirtualFolderOptions({
    required String id,
    required bool enabled,
    Map<String, dynamic> options = const <String, dynamic>{},
  }) => _call(
    () => api.updateVirtualFolderOptions(
      id: id,
      enabled: enabled,
      options: options,
    ),
  );

  @override
  Future<void> refreshLibrary() => _call(() => api.refreshLibrary());

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
    final mediaSource = info.mediaSources.isEmpty
        ? null
        : info.mediaSources.first;
    if (mediaSource == null || mediaSource.id.isEmpty) {
      throw SourceException('${config.displayName} 条目没有可用的媒体源');
    }
    final wantTranscode =
        request.forceVideoTranscode ||
        (request.quality != 'auto' &&
            request.quality.trim().isNotEmpty &&
            mediaSource.transcodingUrl?.trim().isNotEmpty == true);
    final transcodingUrl = mediaSource.transcodingUrl?.trim();
    final isTranscode =
        wantTranscode && transcodingUrl != null && transcodingUrl.isNotEmpty;
    // strm 条目的 Path 是外部直链（Protocol=Http），服务器 static 代理端点
    // 无法转发远程内容，与官方客户端一致直接播放该外链。
    final externalUri = isTranscode
        ? null
        : _externalHttpUri(mediaSource, base, token, config);
    final Uri uri;
    if (isTranscode) {
      uri = Uri.parse(MediaBrowserApi.resolveUrl(base, transcodingUrl));
    } else if (externalUri != null) {
      uri = externalUri;
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
          : externalUri == null
          ? playbackMimeTypeForContainer(mediaSource.container)
          : playbackMimeTypeForContainer(mediaSource.container) ??
                playbackMimeTypeForContainer(_urlExtension(externalUri)),
      startAt: _resumeSeconds(item).toDouble(),
      isTranscode: isTranscode,
      audioTracks: _tracks(mediaSource, 'Audio'),
      subtitleTracks: _subtitleTracks(
        mediaSource,
        itemId: ref.value,
        baseUrl: base,
        token: token,
      ),
      payload: info,
    );
  });

  @override
  Future<List<MediaBrowserItem>> views() => _call(() async {
    final uid = await _requireUserId();
    return api.views(uid);
  });

  @override
  Future<MediaBrowserLibraryStats> libraryStats() => _call(() async {
    final uid = await _requireUserId();
    return api.libraryStats(uid);
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
  Future<MediaBrowserItemPage> nextUp({String? parentId, int limit = 12}) =>
      _call(() async {
        final uid = await _requireUserId();
        return api.nextUp(uid, parentId: parentId, limit: limit);
      });

  @override
  Future<MediaBrowserItemPage> similar(String itemId, {int limit = 12}) =>
      _call(() async {
        final uid = await _requireUserId();
        return api.similar(uid, itemId, limit: limit);
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
    String? personIds,
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
      personIds: personIds,
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
  Future<MediaBrowserItemPage> episodes(String seriesId, String seasonId) =>
      _call(() async {
        final uid = await _requireUserId();
        return api.episodes(uid, seriesId, seasonId);
      });

  @override
  Future<List<MediaBrowserItem>> albumTracks(String albumId) => _call(() async {
    final uid = await _requireUserId();
    // 专辑通常几十首内，一次性取全（Limit 放宽防截断），不分页。
    final page = await api.items(
      uid,
      parentId: albumId,
      includeItemTypes: 'Audio',
      recursive: true,
      sortBy: 'ParentIndexNumber,IndexNumber',
      limit: 1000,
    );
    return page.items;
  });

  @override
  Future<Object?> fetchLyrics(String itemId) => _call(() => api.lyrics(itemId));

  @override
  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite) =>
      _call(() async {
        final uid = await _requireUserId();
        return api.markFavorite(uid, itemId, favorite);
      });

  @override
  Future<MediaBrowserItem> markPlayed(String itemId, bool played) =>
      _call(() async {
        final uid = await _requireUserId();
        return api.markPlayed(uid, itemId, played);
      });

  @override
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) => _call(
    () => api.reportPlaybackStart(
      itemId: itemId,
      positionTicks: positionTicks,
      playSessionId: playSessionId,
    ),
  );

  @override
  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
    bool isPaused = false,
  }) => _call(
    () => api.reportPlaybackProgress(
      itemId: itemId,
      positionTicks: positionTicks,
      playSessionId: playSessionId,
      isPaused: isPaused,
    ),
  );

  @override
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) => _call(
    () => api.reportPlaybackStopped(
      itemId: itemId,
      positionTicks: positionTicks,
      playSessionId: playSessionId,
    ),
  );

  @override
  Future<String> imageUrl(
    String itemId, {
    String imageType = 'Primary',
    int? maxWidth,
    String? tag,
  }) async {
    return MediaBrowserApi.imageUrl(
      config: config,
      baseUrl: endpoint ?? '',
      itemId: itemId,
      imageType: imageType,
      maxWidth: maxWidth,
      tag: tag,
    );
  }

  Future<MediaSummary> _summaryFromItem(MediaBrowserItem item) async {
    return MediaSummary(
      ref: _refFor(item),
      title: item.name,
      year: item.productionYear,
      rating: item.communityRating,
      duration: mediaBrowserTicksToSeconds(item.runTimeTicks),
      poster: await imageUrl(item.id, maxWidth: 440, tag: item.primaryImageTag),
      thumbnail: item.thumbImageTag == null
          ? null
          : await imageUrl(
              item.id,
              imageType: 'Thumb',
              maxWidth: 440,
              tag: item.thumbImageTag,
            ),
      fanart: item.backdropImageTags.isEmpty
          ? null
          : await imageUrl(
              item.id,
              imageType: 'Backdrop',
              maxWidth: 1280,
              tag: item.backdropImageTags.first,
            ),
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
      filePath: item.mediaSources.isEmpty ? null : item.mediaSources.first.path,
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

  MediaRef _refFor(MediaBrowserItem item) =>
      MediaRef(sourceId: _sourceId, value: item.id);

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
                : stream.codec ??
                      '${type == 'Audio' ? '音轨' : '字幕'} ${stream.index + 1}',
            language: stream.language,
            kind: type.toLowerCase(),
            index: stream.index,
            codec: stream.codec,
            channels: stream.channels,
            isDefault: stream.isDefault,
            isForced: stream.isForced,
            isExternal: stream.isExternal,
            source: stream.isExternal ? 'external' : 'embedded',
          ),
    ];
  }

  /// 字幕轨在外挂文本字幕上补直连下载地址（服务器转 WebVTT），播放页
  /// 下载后交给 mpv 本地加载；外挂位图（PGS .sup）无法客户端渲染，
  /// 标记不可用；内嵌位图（MKV 内 PGS）由 mpv 原生渲染，仍可选中。
  List<PlaybackTrack> _subtitleTracks(
    MediaBrowserMediaSourceDto source, {
    required String itemId,
    required String baseUrl,
    required String? token,
  }) {
    return [
      for (final track in _tracks(source, 'Subtitle'))
        () {
          final stream = source.mediaStreams.firstWhere(
            (candidate) => candidate.index.toString() == track.id,
          );
          final url = stream.isExternal && !stream.isBitmap
              ? MediaBrowserApi.subtitleStreamUrl(
                  config: config,
                  baseUrl: baseUrl,
                  itemId: itemId,
                  mediaSourceId: source.id,
                  streamIndex: stream.index,
                  token: token,
                )
              : null;
          return PlaybackTrack(
            id: track.id,
            label: track.label,
            language: track.language,
            kind: track.kind,
            index: track.index,
            codec: track.codec,
            channels: track.channels,
            isDefault: track.isDefault,
            isForced: track.isForced,
            isExternal: track.isExternal,
            url: url,
            source: track.source,
            playable: !stream.isBitmap || !stream.isExternal,
          );
        }(),
    ];
  }

  /// strm / 远程条目的 MediaSource.Path 是外部 http(s) 直链，直接返回它
  /// 作为播放地址；本地文件的 Path 是文件系统路径，永远不满足条件。
  /// 外链指回本服务器自身时补 token，避免 401；解析失败返回 null 落回
  /// static 代理地址。
  Uri? _externalHttpUri(
    MediaBrowserMediaSourceDto source,
    String baseUrl,
    String? token,
    MediaBrowserConfig config,
  ) {
    final path = source.path?.trim();
    if (path == null || !_isHttpUrl(path)) return null;
    var uri = Uri.tryParse(path) ?? Uri.tryParse(Uri.encodeFull(path));
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final serverHost = Uri.tryParse(baseUrl)?.host.toLowerCase();
    final sameHost =
        serverHost != null &&
        serverHost.isNotEmpty &&
        uri.host.toLowerCase() == serverHost;
    if (sameHost && token?.trim().isNotEmpty == true) {
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          config.tokenQueryParam: token!.trim(),
        },
      );
    }
    return uri;
  }

  static bool _isHttpUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// 取 URL 路径的文件扩展名（不含点），无扩展名返回 null。strm 条目的
  /// Container 常为 "strm" 或为空，扩展名是内核选择提示的最后来源。
  static String? _urlExtension(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    final fileName = segments.last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) return null;
    return fileName.substring(dotIndex + 1).toLowerCase();
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
