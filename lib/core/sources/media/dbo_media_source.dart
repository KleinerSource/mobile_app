import 'dbo_media_operations_source.dart';
import 'media_source.dart';

/// DBO 的完整媒体 Source 能力集合。
///
/// 通用能力用于跨来源目录/详情/播放/资源访问，专属能力用于 DBO 页面
/// 仍需使用的在线搜索和 DTO 细节。
abstract interface class DboMediaSource
    implements
        MediaSource,
        CatalogSource,
        MovieDetailSource,
        PlaybackSource,
        ResourceSource,
        DboMediaOperationsSource {}
