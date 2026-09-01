import 'package:omm/core/sources/media/emby_media_source.dart';
import 'package:omm/features/emby/models/emby_models.dart';

/// Emby Feature 的 Source 门面。
///
/// 页面使用 Emby 自有 DTO，Source 负责网络协议；这里只透传并保持
/// 调用方与 Source 接口解耦（与 DboMediaRepository 同构）。
class EmbyMediaRepository {
  EmbyMediaRepository(this._source);

  final EmbyMediaSource _source;

  Future<String?> userId() => _source.userId();

  Future<List<EmbyItem>> views() => _source.views();

  Future<List<EmbyItem>> latestMedia({
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  }) => _source.latestMedia(
    parentId: parentId,
    includeItemTypes: includeItemTypes,
    limit: limit,
  );

  Future<EmbyItemPage> resumeItems({int limit = 12}) =>
      _source.resumeItems(limit: limit);

  Future<EmbyItemPage> nextUp({String? parentId, int limit = 12}) =>
      _source.nextUp(parentId: parentId, limit: limit);

  Future<EmbyItemPage> itemPage({
    String? parentId,
    String? includeItemTypes,
    bool? recursive,
    String? searchTerm,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? isFavorite,
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
  );

  Future<EmbyItem> getItem(String itemId) => _source.getItem(itemId);

  Future<List<EmbyItem>> seasons(String seriesId) =>
      _source.seasons(seriesId);

  Future<EmbyItemPage> episodes(String seasonId) =>
      _source.episodes(seasonId);

  Future<EmbyItem> markFavorite(String itemId, bool favorite) =>
      _source.markFavorite(itemId, favorite);

  Future<EmbyItem> markPlayed(String itemId, bool played) =>
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
  }) => _source.imageUrl(
    itemId,
    imageType: imageType,
    maxWidth: maxWidth,
  );
}
