import 'package:flutter/foundation.dart';

import 'package:omm/features/media_browser/models/media_browser_models.dart';

@immutable
class MediaBrowserLibraryRefreshTarget {
  const MediaBrowserLibraryRefreshTarget({
    required this.id,
    required this.name,
    this.category = '',
  });

  final String id;
  final String name;
  final String category;
}

@immutable
class MediaBrowserLibraryRefreshProgress {
  const MediaBrowserLibraryRefreshProgress({
    required this.isRunning,
    this.failed = false,
    this.ratio,
  });

  final bool isRunning;
  final bool failed;

  /// 0.0–1.0；服务器无法提供可靠百分比时为 null。
  final double? ratio;
}

/// MediaBrowser（Emby/Jellyfin/飞牛影视）保留给 Feature 的扩展能力。
///
/// 这些方法返回服务器自有 DTO，供媒体浏览页面使用；请求仍由
/// Source Adapter 负责，页面和 Provider 不直接接触 `MediaBrowserApi`。
abstract interface class MediaBrowserMediaOperationsSource {
  /// 当前登录用户的 ID；未登录时为 null。
  Future<String?> userId();

  /// 校验当前登录用户及管理员权限。
  Future<MediaBrowserUser> currentUser();

  /// 管理端虚拟媒体库列表。
  Future<List<MediaBrowserLibrary>> virtualFolders();

  Future<void> addVirtualFolder({
    required String name,
    required String collectionType,
    required List<String> paths,
  });

  Future<void> removeVirtualFolder(String name);

  Future<void> renameVirtualFolder({
    required String name,
    required String newName,
  });

  Future<void> addMediaPath({
    required String libraryName,
    required String path,
  });

  Future<void> removeMediaPath({
    required String libraryName,
    required String path,
  });

  Future<void> updateVirtualFolderOptions({
    required String id,
    required bool enabled,
    Map<String, dynamic> options = const <String, dynamic>{},
  });

  /// 刷新全部媒体库；传入 [libraryId] 时只刷新指定媒体库。
  Future<void> refreshLibrary({String? libraryId});

  /// 查询指定媒体库的刷新状态；来源无法提供进度时返回已完成状态。
  Future<MediaBrowserLibraryRefreshProgress> libraryRefreshProgress(
    MediaBrowserLibraryRefreshTarget target,
  );

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

  /// 条目的更多类似；fnOS 等不支持该能力的来源返回空页。
  Future<MediaBrowserItemPage> similar(String itemId, {int limit = 12});

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

  /// 海报 / 背景图绝对地址。鉴权请求头由展示层按服务器类型附加；[tag]
  /// 是服务器侧图片版本号，参与拼接用于换图后打破缓存。
  Future<String> imageUrl(
    String itemId, {
    String imageType = 'Primary',
    int? maxWidth,
    String? tag,
  });
}
