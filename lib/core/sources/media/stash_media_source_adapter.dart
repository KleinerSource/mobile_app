import 'package:omm/features/media_browser/api/stash_api.dart';
import 'package:omm/features/media_browser/api/stash_models.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'media_browser_media_operations_source.dart';
import 'media_browser_media_source.dart';
import 'media_capabilities.dart';
import 'media_metadata_normalizer.dart';
import 'media_models.dart';

/// Stash Scene 媒体源。
///
/// Stash 的 Scene 没有 MediaBrowser 的目录层级，适配为一个固定的
/// `Scenes` 电影媒体库，以便复用现有列表、详情和播放器页面。
class StashMediaSourceAdapter implements MediaBrowserMediaSource {
  StashMediaSourceAdapter(this.api, {this.serverId, this.endpoint});

  static const _config = MediaBrowserConfig.stash;
  static const _sourceId = SourceId('stash');
  static const _libraryId = 'stash-scenes';
  static const _libraryName = 'Scenes';

  final StashApi api;
  final String? serverId;
  final String? endpoint;
  final _sceneCache = <String, StashScene>{};

  @override
  SourceDescriptor get descriptor => SourceDescriptor(
    id: _sourceId,
    kind: SourceKind.stash,
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
    final page = await itemPage(query);
    return MediaPage(
      items: [for (final item in page.items) _summaryFromItem(item)],
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
    final scene = await _loadScene(ref.value);
    final summary = _summaryFromScene(scene);
    final file = _primaryFile(scene);
    return MediaDetails(
      summary: summary,
      overview: normalizeMediaText(scene.details),
      filePath: file?.path,
      fileSize: file?.size,
      tags: normalizeMediaLabels(scene.tags),
      actors: normalizeMediaLabels(
        scene.performers.map((performer) => performer.name),
      ),
      attributes: <String, Object?>{
        'type': 'Movie',
        'studio': scene.studio?.name,
        'performers': scene.performers,
        'playCount': scene.playCount,
        'lastPlayedAt': scene.lastPlayedAt,
      },
      payload: scene,
    );
  }

  @override
  Future<PlaybackDescriptor> resolvePlayback(
    MediaRef ref,
    PlaybackRequest request,
  ) async {
    _checkRef(ref);
    final scene = await _loadScene(ref.value);
    final streams = await _call(() => api.sceneStreams(ref.value));
    if (streams.isEmpty) throw const SourceException('Stash Scene 没有可用的视频流');
    final stream = streams.first;
    final url = _absoluteUrl(stream.url);
    final file = _primaryFile(scene);
    return PlaybackDescriptor(
      uri: Uri.parse(url),
      mimeType: stream.mimeType ?? playbackMimeTypeForContainer(file?.format),
      headers: await _apiKeyHeaders(),
      startAt: scene.resumeTime,
      payload: stream,
    );
  }

  @override
  Future<String?> userId() async => null;

  @override
  Future<MediaBrowserUser> currentUser() async =>
      const MediaBrowserUser(id: 'stash', name: 'Stash');

  @override
  Future<List<MediaBrowserLibrary>> virtualFolders() async => const [];

  @override
  Future<void> addVirtualFolder({
    required String name,
    required String collectionType,
    required List<String> paths,
  }) => _unsupported('Stash 不支持在应用内管理媒体库');

  @override
  Future<void> removeVirtualFolder(String name) =>
      _unsupported('Stash 不支持在应用内管理媒体库');

  @override
  Future<void> renameVirtualFolder({
    required String name,
    required String newName,
  }) => _unsupported('Stash 不支持在应用内管理媒体库');

  @override
  Future<void> addMediaPath({
    required String libraryName,
    required String path,
  }) => _unsupported('Stash 不支持在应用内管理媒体库');

  @override
  Future<void> removeMediaPath({
    required String libraryName,
    required String path,
  }) => _unsupported('Stash 不支持在应用内管理媒体库');

  @override
  Future<void> updateVirtualFolderOptions({
    required String id,
    required bool enabled,
    Map<String, dynamic> options = const <String, dynamic>{},
  }) => _unsupported('Stash 不支持在应用内管理媒体库');

  @override
  Future<void> refreshLibrary({String? libraryId}) =>
      _unsupported('Stash 不支持在应用内管理媒体库');

  @override
  Future<MediaBrowserLibraryRefreshProgress> libraryRefreshProgress(
    MediaBrowserLibraryRefreshTarget target,
  ) async => const MediaBrowserLibraryRefreshProgress(isRunning: false);

  @override
  Future<List<MediaBrowserItem>> views() async {
    final page = await _call(() => api.findScenes(page: 1, perPage: 1));
    return [
      MediaBrowserItem(
        id: _libraryId,
        name: _libraryName,
        type: 'CollectionFolder',
        collectionType: 'movies',
        childCount: page.total,
        recursiveItemCount: page.total,
      ),
    ];
  }

  @override
  Future<MediaBrowserLibraryStats> libraryStats() async {
    final page = await _call(() => api.findScenes(page: 1, perPage: 1));
    return MediaBrowserLibraryStats(
      movieCount: page.total,
      seriesCount: 0,
      episodeCount: 0,
    );
  }

  @override
  Future<List<MediaBrowserItem>> latestMedia({
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  }) async {
    final page = await itemPage(
      MediaQuery(
        limit: limit,
        sortBy: 'created_at',
        orderBy: 'desc',
        filters: {
          if (parentId != null) 'parentId': parentId,
          if (includeItemTypes != null) 'includeItemTypes': includeItemTypes,
        },
      ),
    );
    return page.items;
  }

  @override
  Future<MediaBrowserItemPage> resumeItems({int limit = 12}) async {
    final page = await _call(() => api.findScenes(page: 1, perPage: 100));
    final items = page.scenes
        .where((scene) => scene.resumeTime > 0 && !_isComplete(scene))
        .take(limit)
        .map(_itemFromScene)
        .toList(growable: false);
    return _pageFromItems(items, total: items.length, limit: limit);
  }

  @override
  Future<MediaBrowserItemPage> nextUp({
    String? parentId,
    int limit = 12,
  }) async => _emptyPage(limit);

  @override
  Future<MediaBrowserItemPage> similar(String itemId, {int limit = 12}) async =>
      _emptyPage(limit);

  @override
  Future<MediaBrowserItemPage> itemPage(MediaQuery query) async {
    final filters = query.filters;
    final normalizedParent = filters['parentId']?.toString().trim() ?? '';
    if (normalizedParent.isNotEmpty && normalizedParent != _libraryId) {
      return _emptyPage(query.limit, startIndex: query.offset);
    }
    final pageSize = query.limit.clamp(1, 100);
    final offset = query.offset.clamp(0, 1 << 30);
    final pageNumber = offset ~/ pageSize + 1;
    final page = await _call(
      () => api.findScenes(
        page: pageNumber,
        perPage: pageSize,
        searchText: query.searchText,
        sortBy: _stashSortBy(query.sortBy),
        sortOrder: _stashSortOrder(query.orderBy),
        tagIds: _splitIds(filters['tagIds']?.toString()),
        performerIds: _splitIds(filters['personIds']?.toString()),
      ),
    );
    final items = page.scenes.map(_itemFromScene).toList(growable: false);
    return MediaBrowserItemPage(
      items: items,
      total: page.total,
      startIndex: offset,
      limit: pageSize,
    );
  }

  @override
  Future<MediaBrowserItem> getItem(String itemId) async =>
      _itemFromScene(await _loadScene(itemId));

  @override
  Future<List<MediaBrowserItem>> seasons(String seriesId) async => const [];

  @override
  Future<MediaBrowserItemPage> episodes(
    String seriesId,
    String seasonId,
  ) async => _emptyPage(0);

  @override
  Future<List<MediaBrowserItem>> albumTracks(String albumId) async => const [];

  @override
  Future<Object?> fetchLyrics(String itemId) async => null;

  @override
  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite) =>
      _unsupported('Stash 暂不支持收藏');

  @override
  Future<MediaBrowserItem> markPlayed(String itemId, bool played) =>
      _unsupported('Stash 暂不支持手动标记已看');

  @override
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) async {}

  @override
  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
    bool isPaused = false,
  }) async {
    final scene = await _loadScene(itemId);
    await _call(
      () => api.saveActivity(
        itemId,
        resumeTime: _secondsFromTicks(positionTicks),
        playDuration: _secondsFromTicks(positionTicks),
      ),
    );
    _sceneCache[itemId] = _withResumeTime(
      scene,
      _secondsFromTicks(positionTicks),
    );
  }

  @override
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) async {
    final scene = await _loadScene(itemId);
    final position = _secondsFromTicks(positionTicks);
    final completed = _isComplete(scene, position: position);
    await _call(
      () => api.saveActivity(
        itemId,
        resumeTime: completed ? 0 : position,
        playDuration: position,
      ),
    );
    if (completed) await _call(() => api.addPlay(itemId));
    _sceneCache[itemId] = _withResumeTime(scene, completed ? 0 : position);
  }

  @override
  Future<String> imageUrl(
    String itemId, {
    String imageType = 'Primary',
    int? maxWidth,
    String? tag,
  }) async {
    final provided = tag?.trim() ?? '';
    if (provided.isNotEmpty) return _absoluteUrl(provided);
    final scene = await _loadScene(itemId);
    final path = _imagePath(scene, imageType);
    if (path == null) return '';
    return _absoluteUrl(path);
  }

  MediaBrowserItem _itemFromScene(StashScene scene) {
    _sceneCache[scene.id] = scene;
    final file = _primaryFile(scene);
    final title = normalizeMediaText(scene.title);
    final code = normalizeMediaText(scene.code);
    final name = title ?? code ?? scene.id;
    return MediaBrowserItem(
      id: scene.id,
      name: name,
      type: 'Movie',
      code: code,
      productionYear: normalizeMediaYear(scene.date),
      communityRating: stashRating100ToTen(scene.rating100),
      runTimeTicks: _ticks(sceneDuration(scene)),
      overview: normalizeMediaText(scene.details),
      genres: const <String>[],
      tags: normalizeMediaLabels(scene.tags),
      tagIds: scene.tagIds,
      people: [
        for (final performer in scene.performers)
          MediaBrowserPerson(
            id: performer.id,
            name: performer.name,
            type: 'Actor',
          ),
      ],
      userData: MediaBrowserUserData(
        playbackPositionTicks: _ticks(scene.resumeTime),
        playCount: scene.playCount,
        played: scene.playCount > 0,
      ),
      primaryImageTag: _imagePath(scene, 'Primary'),
      previewPath: scene.paths.preview,
      backdropImageTags: [
        if (_imagePath(scene, 'Backdrop') case final path?) path,
      ],
      mediaSources: [
        MediaBrowserMediaSourceDto(
          id: file?.id ?? scene.id,
          name: file?.basename ?? name,
          path: file?.path,
          container: file?.format,
          protocol: 'http',
          sizeInBytes: file?.size,
          supportsDirectPlay: true,
          supportsDirectStream: true,
          mediaStreams: _mediaStreamsForFile(file),
        ),
      ],
      payload: scene,
    );
  }

  List<MediaBrowserMediaStream> _mediaStreamsForFile(StashSceneFile? file) {
    if (file == null) return const <MediaBrowserMediaStream>[];

    final hasVideo =
        file.videoCodec?.trim().isNotEmpty == true ||
        file.width != null ||
        file.height != null ||
        file.frameRate != null ||
        file.bitRate != null;
    final hasAudio = file.audioCodec?.trim().isNotEmpty == true;
    return [
      if (hasVideo)
        MediaBrowserMediaStream(
          index: 0,
          type: 'Video',
          codec: file.videoCodec,
          width: file.width,
          height: file.height,
          frameRate: file.frameRate?.toString(),
          bitRate: file.bitRate,
        ),
      if (hasAudio)
        MediaBrowserMediaStream(
          index: 1,
          type: 'Audio',
          codec: file.audioCodec,
        ),
    ];
  }

  MediaSummary _summaryFromItem(MediaBrowserItem item) => MediaSummary(
    ref: MediaRef(sourceId: _sourceId, value: item.id),
    title: normalizeMediaText(item.name) ?? '',
    code: normalizeMediaText(item.code),
    year: normalizeMediaYear(item.productionYear),
    rating: normalizeMediaRating(item.communityRating),
    duration: mediaBrowserTicksToMinutes(item.runTimeTicks),
    poster: _assetUrl(item.primaryImageTag),
    thumbnail: _assetUrl(item.primaryImageTag),
    fanart: item.backdropImageTags.isEmpty
        ? null
        : _assetUrl(item.backdropImageTags.first),
    canPlay: true,
    attributes: <String, Object?>{
      'type': item.type,
      'isFavorite': false,
      'isWatched': item.userData.played,
      'resumeSeconds': item.userData.resumeSeconds,
      'playCount': item.userData.playCount,
    },
    payload: item.payload ?? item,
  );

  MediaSummary _summaryFromScene(StashScene scene) =>
      _summaryFromItem(_itemFromScene(scene));

  Future<StashScene> _loadScene(String id) async {
    final normalized = id.trim();
    final cached = _sceneCache[normalized];
    if (cached != null) return cached;
    final scene = await _call(() => api.findScene(normalized));
    _sceneCache[normalized] = scene;
    return scene;
  }

  Future<Map<String, String>> _apiKeyHeaders() async {
    final key = await api.readApiKey();
    return key == null ? const {} : {'ApiKey': key};
  }

  void _checkRef(MediaRef ref) {
    if (ref.sourceId != _sourceId) {
      throw SourceException('来源 ID 不属于 Stash：${ref.sourceId.value}');
    }
    if (ref.value.trim().isEmpty) {
      throw const SourceException('Stash Scene ID 不能为空');
    }
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

  Future<T> _unsupported<T>(String message) =>
      Future<T>.error(SourceException(message));

  String _stashSortBy(String? sortBy) => switch (sortBy?.trim()) {
    'SortName' => 'title',
    'ProductionYear' => 'date',
    'CommunityRating' => 'rating100',
    _ => 'created_at',
  };

  String _stashSortOrder(String? sortOrder) =>
      (sortOrder?.toLowerCase().startsWith('desc') ?? true) ? 'DESC' : 'ASC';

  String? _imagePath(StashScene scene, String type) {
    final paths = scene.paths;
    if (type.toLowerCase() == 'backdrop') {
      return paths.screenshot ?? paths.webp;
    }
    return paths.screenshot ?? paths.webp;
  }

  String? _assetUrl(String? path) {
    final value = path?.trim() ?? '';
    return value.isEmpty ? null : _absoluteUrl(value);
  }

  String _absoluteUrl(String value) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed?.hasScheme == true && parsed?.host.isNotEmpty == true) {
      return value.trim();
    }
    final base = Uri.parse(endpoint ?? '');
    return base.resolve(value.trim()).toString();
  }

  StashSceneFile? _primaryFile(StashScene scene) {
    for (final file in scene.files) {
      if ((file.duration ?? 0) > 0 || (file.path ?? '').isNotEmpty) return file;
    }
    return scene.files.isEmpty ? null : scene.files.first;
  }

  double sceneDuration(StashScene scene) {
    final duration = _primaryFile(scene)?.duration ?? 0;
    return duration > 0 ? duration : scene.playDuration;
  }

  bool _isComplete(StashScene scene, {double? position}) {
    final duration = sceneDuration(scene);
    final current = position ?? scene.resumeTime;
    return duration > 0 && current >= duration - 1;
  }

  StashScene _withResumeTime(StashScene scene, double resumeTime) => StashScene(
    id: scene.id,
    title: scene.title,
    code: scene.code,
    details: scene.details,
    date: scene.date,
    rating100: scene.rating100,
    resumeTime: resumeTime,
    playDuration: scene.playDuration,
    playCount: scene.playCount,
    lastPlayedAt: scene.lastPlayedAt,
    files: scene.files,
    paths: scene.paths,
    performers: scene.performers,
    studio: scene.studio,
    tags: scene.tags,
    tagIds: scene.tagIds,
  );

  MediaBrowserItemPage _emptyPage(int limit, {int startIndex = 0}) =>
      MediaBrowserItemPage(
        items: const [],
        total: 0,
        startIndex: startIndex,
        limit: limit,
      );

  MediaBrowserItemPage _pageFromItems(
    Iterable<MediaBrowserItem> items, {
    required int total,
    required int limit,
  }) {
    final values = items.toList(growable: false);
    return MediaBrowserItemPage(
      items: values,
      total: total,
      startIndex: 0,
      limit: limit,
    );
  }

  int _ticks(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return 0;
    return (seconds * mediaBrowserTicksPerSecond).round();
  }

  double _secondsFromTicks(int ticks) =>
      ticks <= 0 ? 0 : ticks / mediaBrowserTicksPerSecond;
}

List<String> _splitIds(String? value) => (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList(growable: false);
