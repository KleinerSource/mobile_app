import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

/// MediaBrowser（Emby/Jellyfin）Feature 的 Source 门面。
///
/// 页面使用服务器自有 DTO，Source 负责网络协议；这里只透传并保持
/// 调用方与 Source 接口解耦（与 DboMediaRepository 同构）。
class MediaBrowserMediaRepository {
  MediaBrowserMediaRepository(this._source);

  final MediaBrowserMediaSource _source;

  Future<String?> userId() => _source.userId();

  Future<MediaBrowserUser> currentUser() => _source.currentUser();

  Future<List<MediaBrowserLibrary>> virtualFolders() =>
      _source.virtualFolders();

  Future<void> addVirtualFolder({
    required String name,
    required String collectionType,
    required List<String> paths,
  }) =>
      _source.addVirtualFolder(
        name: name,
        collectionType: collectionType,
        paths: paths,
      );

  Future<void> removeVirtualFolder(String name) =>
      _source.removeVirtualFolder(name);

  Future<void> renameVirtualFolder({
    required String name,
    required String newName,
  }) =>
      _source.renameVirtualFolder(name: name, newName: newName);

  Future<void> addMediaPath({
    required String libraryName,
    required String path,
  }) =>
      _source.addMediaPath(libraryName: libraryName, path: path);

  Future<void> removeMediaPath({
    required String libraryName,
    required String path,
  }) =>
      _source.removeMediaPath(libraryName: libraryName, path: path);

  Future<void> updateVirtualFolderOptions({
    required String id,
    required bool enabled,
    Map<String, dynamic> options = const <String, dynamic>{},
  }) =>
      _source.updateVirtualFolderOptions(
        id: id,
        enabled: enabled,
        options: options,
      );

  Future<void> refreshLibrary() => _source.refreshLibrary();

  Future<List<MediaBrowserItem>> views() => _source.views();

  Future<MediaBrowserLibraryStats> libraryStats() => _source.libraryStats();

  Future<List<MediaBrowserItem>> latestMedia({
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  }) => _source.latestMedia(
    parentId: parentId,
    includeItemTypes: includeItemTypes,
    limit: limit,
  );

  Future<MediaBrowserItemPage> resumeItems({int limit = 12}) =>
      _source.resumeItems(limit: limit);

  Future<MediaBrowserItemPage> nextUp({String? parentId, int limit = 12}) =>
      _source.nextUp(parentId: parentId, limit: limit);

  Future<MediaBrowserItemPage> similar(String itemId, {int limit = 12}) =>
      _source.similar(itemId, limit: limit);

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
  }) => _source.itemPage(
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

  Future<MediaBrowserItem> getItem(String itemId) => _source.getItem(itemId);

  Future<List<MediaBrowserItem>> seasons(String seriesId) =>
      _source.seasons(seriesId);

  Future<MediaBrowserItemPage> episodes(String seriesId, String seasonId) =>
      _source.episodes(seriesId, seasonId);

  Future<List<MediaBrowserItem>> albumTracks(String albumId) =>
      _source.albumTracks(albumId);

  Future<Object?> fetchLyrics(String itemId) => _source.fetchLyrics(itemId);

  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite) =>
      _source.markFavorite(itemId, favorite);

  Future<MediaBrowserItem> markPlayed(String itemId, bool played) =>
      _source.markPlayed(itemId, played);

  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) => _source.reportPlaybackStart(
    itemId: itemId,
    positionTicks: positionTicks,
    playSessionId: playSessionId,
  );

  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
    bool isPaused = false,
  }) => _source.reportPlaybackProgress(
    itemId: itemId,
    positionTicks: positionTicks,
    playSessionId: playSessionId,
    isPaused: isPaused,
  );

  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) => _source.reportPlaybackStopped(
    itemId: itemId,
    positionTicks: positionTicks,
    playSessionId: playSessionId,
  );

  Future<String> imageUrl(
    String itemId, {
    String imageType = 'Primary',
    int? maxWidth,
    String? tag,
  }) => _source.imageUrl(
    itemId,
    imageType: imageType,
    maxWidth: maxWidth,
    tag: tag,
  );
}
