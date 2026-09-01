import 'jellyfin_media_operations_source.dart';
import 'media_source.dart';

/// Jellyfin 的完整媒体 Source 能力集合。
///
/// 通用能力用于跨来源目录/详情/播放访问；Jellyfin 是外部媒体服务器，
/// 媒体库管理与扫描由服务器自身完成，因此不实现对应能力。专属能力
/// （媒体库浏览、剧集结构、收藏/已看、播放会话上报）保留给 Jellyfin 页面。
abstract interface class JellyfinMediaSource
    implements
        MediaSource,
        CatalogSource,
        MovieDetailSource,
        PlaybackSource,
        JellyfinMediaOperationsSource {}
