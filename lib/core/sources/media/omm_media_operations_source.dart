import '../../models/media_streams.dart';
import '../../models/movie.dart';
import '../../models/playback.dart';
import '../../models/preview.dart';
import '../../models/resource_scan.dart';
import '../../models/subtitle_search.dart';
import '../../models/watch_record.dart';
import 'media_models.dart';

/// OMM 播放器专属的远程会话能力。
///
/// 播放器仍由 Feature 层负责渲染和引擎生命周期；这里只暴露播放决策、
/// 转码会话状态和字幕内容获取，协议 API 由 Source adapter 隔离。
abstract interface class OmmPlaybackOperationsSource {
  Future<PlaybackDecision> resolvePlaybackDecision(
    MediaRef movie,
    PlaybackClientCaps capabilities,
  );

  Future<TranscodeStatus> transcodeStatus(
    MediaRef movie, {
    String quality = 'auto',
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  });

  Stream<TranscodeStatus> transcodeEvents(
    MediaRef movie, {
    String quality = 'auto',
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  });

  Future<void> stopTranscode(MediaRef movie);

  Future<String> fetchSubtitleContent(String url);
}

/// OMM 后端的影片扩展操作。
///
/// 这些能力只属于 OMM 的本地媒体库，不进入 DBO 的通用媒体源契约。
/// 所有影片标识仍以 [MediaRef] 进入 Source 层，适配器负责校验并转换为
/// OMM 的整数 ID。
abstract interface class OmmMediaOperationsSource {
  Future<MediaPage<MediaSummary>> listFavorites(MediaQuery query);

  Future<bool> favoriteStatus(MediaRef movie);

  Future<List<String>> extraFanarts(MediaRef movie);

  /// 提交额外预览图下载任务，并返回统一调度任务 ID。
  Future<({String taskId, String? message})> downloadExtraFanarts(
    MediaRef movie,
  );

  Future<MediaInfoDetail?> mediaInfoDetail(MediaRef movie);

  Future<({bool value, String? message})> toggleFavorite(MediaRef movie);

  Future<String?> addFavoriteBatch(List<MediaRef> movies);

  Future<String?> removeFavoriteBatch(List<MediaRef> movies);

  Future<void> markWatched(MediaRef movie, bool completed);

  Future<WatchRecord?> watchRecord(MediaRef movie);

  Future<void> acknowledgeResources(MediaRef movie);

  Future<ResourceScanStartResult> startResourceScan({
    List<MediaRef>? movies,
    Map<String, dynamic>? filter,
    bool favoriteOnly = false,
  });

  Future<void> upsertWatchRecord(
    MediaRef movie, {
    required int positionSec,
    required int durationSec,
    bool? completed,
  });

  Future<({MovieDetail item, String? message})> updateMovie(
    MediaRef movie,
    Map<String, dynamic> body,
  );

  Future<String?> deleteMovie(MediaRef movie, {bool force = false});

  Future<String?> syncNfo(MediaRef movie);

  Future<String?> refreshFromNfo(MediaRef movie);

  Future<({String keyword, List<SubtitleSearchItem> items})> searchSubtitles(
    MediaRef movie,
  );

  Future<String> previewSubtitle(MediaRef movie, String url);

  Future<String?> downloadSubtitle(
    MediaRef movie, {
    required String url,
    required String ext,
    bool overwrite = false,
  });

  Future<Map<String, dynamic>> getDbonlineMetadata(MediaRef movie);

  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getResourcesBySource(MediaRef movie, String source);

  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getAllResources(MediaRef movie);

  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders();

  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(MediaRef movie);

  Future<({String message, String lastDownloadedAt})> pushDownload({
    required List<String> urls,
    required String downloader,
    required MediaRef movie,
    Map<String, dynamic>? videoInfo,
    List<Map<String, dynamic>> recordResources = const [],
    String savePath = '',
  });

  Future<String?> batchAddAssociations({
    required List<MediaRef> movies,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  });

  Future<String?> batchRemoveAssociations({
    required List<MediaRef> movies,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  });

  /// 水印标记三态：null（未设置）表示保持影片现有标记，由服务端按标签推导。
  Future<({String? message, int successCount, int failedCount})>
  batchWatermark({
    required List<MediaRef> movies,
    bool? subtitle,
    bool? exsub,
    bool? crack,
    String? resolution,
  });

  Future<({String? taskId, String? message})> mergeDuplicateFiles({
    required List<MediaRef> movies,
    required MediaRef targetMovie,
  });

  Future<Map<String, dynamic>> compareDuplicateNfo(List<MediaRef> movies);

  Future<String?> applyDuplicateNfo(Map<String, dynamic> payload);

  Future<String?> requestDownload({
    required List<MediaRef> movies,
    required Map<String, dynamic> requirements,
  });

  /// 水印标记三态：null（未设置）表示保持影片现有标记，由服务端按标签推导。
  Future<String?> applyPosterCrop(
    MediaRef movie, {
    required double cropOffset,
    bool? subtitle,
    bool? exsub,
    bool? crack,
    String? resolution,
    bool syncParts = false,
  });

  Future<List<int>> previewPosterCrop(
    MediaRef movie, {
    required double cropOffset,
    bool? subtitle,
    bool? exsub,
    bool? crack,
    String? resolution,
  });

  /// 为单部影片生成预览视频与 Sprite/VTT 资产。
  Future<PreviewStartResult> generatePreview(
    MediaRef movie, {
    bool overwrite = false,
  });

  /// 查询影片的预览资产状态；任务进度通过统一 WebSocket 任务中心推送。
  Future<PreviewStatus> previewStatus(MediaRef movie);

  /// 取消排队中或执行中的预览任务。
  Future<String?> cancelPreviewTask(String taskId);
}
