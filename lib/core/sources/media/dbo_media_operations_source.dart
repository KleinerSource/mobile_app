import 'dart:typed_data';

import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_search.dart';
import 'package:omm/core/sources/media/dbo/db_online_subtitle.dart';

/// DBO 保留给 Feature 的在线目录扩展能力。
///
/// 这些方法返回 DBO 自有 DTO，供 DBO 专属页面使用；请求仍由 Source
/// Adapter 负责，页面和 Provider 不直接接触 `DbOnlineApi`。
abstract interface class DboMediaOperationsSource {
  Future<DbOnlineMovieDetail> getMovieByCode(
    String code, {
    String? videoId,
    bool refresh = true,
  });

  Future<DbOnlineMovieDetail> getMovieByVideoId(
    String videoId, {
    bool refresh = true,
  });

  Future<DbOnlinePlayEpisodes> getPlayEpisodes({
    required String code,
    required int sourceId,
    String? videoId,
  });

  Future<DbOnlineExternalResources> getCustomResources(String code);

  Future<DbOnlineExternalResources> getNyaaResources(String code);

  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(String code);

  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders();

  Future<({String message, String downloader})> pushDownload({
    required List<String> urls,
    required String downloader,
    required Map<String, dynamic> videoInfo,
    required List<Map<String, dynamic>> recordResources,
  });

  Future<DbOnlineActorSearchResult> searchActors({required String query});

  /// 按实体类型搜索（series/maker/director/list）。
  Future<DbOnlineSearchEntityPage> searchEntitiesPage({
    required String type,
    required String query,
    int page = 1,
    int limit = 24,
  });

  Future<List<DbOnlineSubtitleFile>> findSubtitles(String code);

  Future<List<DbOnlineSubtitleCandidate>> searchExternalSubtitles(String code);

  Future<DbOnlineSubtitlePreview> previewLocalSubtitle(String id);

  Future<DbOnlineSubtitlePreview> previewExternalSubtitle(String url);

  Future<Uint8List> downloadLocalSubtitle(String id);

  Future<Uint8List> downloadExternalSubtitle({
    required String url,
    required String name,
    required String extension,
  });
}
