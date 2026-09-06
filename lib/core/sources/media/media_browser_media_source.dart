import 'media_browser_media_operations_source.dart';
import 'media_source.dart';

/// MediaBrowser（Emby/Jellyfin/飞牛影视）的完整媒体 Source 能力集合。
///
/// 通用能力用于跨来源目录/详情/播放访问；两家都是外部媒体服务器，媒体
/// 库管理与扫描由服务器自身完成，因此不实现对应能力。专属能力（媒体库
/// 浏览、剧集结构、收藏/已看、播放会话上报）保留给媒体浏览页面。
abstract interface class MediaBrowserMediaSource
    implements
        MediaSource,
        CatalogSource,
        MovieDetailSource,
        PlaybackSource,
        MediaBrowserMediaOperationsSource {}

/// MediaBrowser 服务端提供的筛选元数据。
///
/// 目前只有 Emby/Jellyfin 的 `/Genres` 接口使用该能力；其他媒体源可以
/// 不实现，页面会回退到已加载条目的类型字段。
abstract interface class MediaBrowserGenresSource {
  Future<List<String>> genres();
}
