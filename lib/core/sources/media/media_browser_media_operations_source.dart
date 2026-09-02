import 'package:omm/features/media_browser/models/media_browser_models.dart';

/// MediaBrowser（Emby/Jellyfin）保留给 Feature 的扩展能力。
///
/// 这些方法返回服务器自有 DTO，供 Emby/Jellyfin 专属页面使用；请求仍由
/// Source Adapter 负责，页面和 Provider 不直接接触 `MediaBrowserApi`。
abstract interface class MediaBrowserMediaOperationsSource {
  /// 当前登录用户的 ID；未登录时为 null。
  Future<String?> userId();

  /// 媒体库（Views）列表。
  Future<List<MediaBrowserItem>> views();

  /// 媒体库统计。
  Future<MediaBrowserLibraryStats> libraryStats();

  /// 「最新入库」。
  Future<List<MediaBrowserItem>> latestMedia({
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  });

  /// 「继续观看」。
  Future<MediaBrowserItemPage> resumeItems({int limit = 12});

  /// 剧集「下一集」。
  Future<MediaBrowserItemPage> nextUp({String? parentId, int limit = 12});

  /// 通用条目分页查询（库浏览 / 搜索共用）。
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
  });

  /// 条目详情（完整字段）。
  Future<MediaBrowserItem> getItem(String itemId);

  /// 剧集的季列表。
  Future<List<MediaBrowserItem>> seasons(String seriesId);

  /// 某一季的集列表。
  Future<MediaBrowserItemPage> episodes(String seriesId, String seasonId);

  /// 专辑的曲目列表，按光盘号 + 曲号排序。
  Future<List<MediaBrowserItem>> albumTracks(String albumId);

  /// 音频歌词原始响应；服务器无歌词时为 null，格式由调用方解析。
  Future<Object?> fetchLyrics(String itemId);

  /// 收藏 / 取消收藏，返回带最新 UserData 的条目。
  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite);

  /// 标记已看 / 未看，返回带最新 UserData 的条目。
  Future<MediaBrowserItem> markPlayed(String itemId, bool played);

  /// 播放会话上报：开始 / 进度 / 结束。
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  });

  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
    bool isPaused = false,
  });

  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  });

  /// 海报 / 背景图绝对地址。不带 token（图片端点默认免鉴权，URL 进图片
  /// 缓存后 token 轮换会打穿缓存）；[tag] 是服务器侧图片版本号，参与
  /// 拼接用于换图后打破缓存。
  Future<String> imageUrl(
    String itemId, {
    String imageType = 'Primary',
    int? maxWidth,
    String? tag,
  });
}
