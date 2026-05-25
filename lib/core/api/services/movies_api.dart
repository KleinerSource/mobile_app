import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'movies_api.g.dart';

@RestApi()
abstract class MoviesApi {
  factory MoviesApi(Dio dio, {String baseUrl}) = _MoviesApi;

  @GET('/movies')
  Future<dynamic> getMovies(@Queries() Map<String, dynamic> q);

  @GET('/movies/id/{id}')
  Future<dynamic> getMovieDetail(@Path('id') int id);

  @PUT('/movies/id/{id}/watch-record')
  Future<dynamic> upsertWatchRecord(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @GET('/movies/id/{id}/watch-record')
  Future<dynamic> getWatchRecord(@Path('id') int id);

  /// 额外剧照列表 (来自 master 后端能力)
  @GET('/movies/id/{id}/extrafanart')
  Future<dynamic> getExtraFanarts(@Path('id') int id);

  /// 媒体信息 (容器/视频流/音频流) (来自 master 后端能力)
  @GET('/movies/id/{id}/media-info')
  Future<dynamic> getMediaInfo(@Path('id') int id);

  // ===== 详情页操作 =====

  /// 编辑影片字段 · body: { title, plot, year, rating, ... }
  @PATCH('/movies/id/{id}')
  Future<dynamic> updateMovie(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  /// 删除影片 (含磁盘文件) · body: { movie_ids: [...], force: bool }
  @POST('/movies/delete')
  Future<dynamic> deleteMovies(@Body() Map<String, dynamic> body);

  // ===== NFO 同步/重载/状态 =====

  @POST('/movies/id/{id}/nfo/sync')
  Future<dynamic> syncNfo(@Path('id') int id);

  @POST('/movies/id/{id}/nfo/refresh')
  Future<dynamic> refreshFromNfo(@Path('id') int id);

  @GET('/movies/id/{id}/nfo/status')
  Future<dynamic> getNfoStatus(@Path('id') int id);

  // ===== 字幕 (迅雷) =====

  @GET('/movies/id/{id}/subtitles/thunder/search')
  Future<dynamic> searchThunderSubtitles(@Path('id') int id);

  @GET('/movies/id/{id}/subtitles/thunder/preview')
  Future<dynamic> previewThunderSubtitle(
    @Path('id') int id,
    @Queries() Map<String, dynamic> q,
  );

  @POST('/movies/id/{id}/subtitles/thunder/download')
  Future<dynamic> downloadThunderSubtitle(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  // ===== DBO 接口元数据/资源 =====

  /// 从 DB Online 接口刷新影片元数据 (需要 DBO 配置)
  @GET('/movies/id/{id}/dbonline/metadata')
  Future<dynamic> getDbonlineMetadata(@Path('id') int id);

  /// 获取磁力/ed2k 资源 · source = 'magnet' / 'ed2k' 等
  @GET('/movies/id/{id}/dbonline/resources/{source}')
  Future<dynamic> getResources(
    @Path('id') int id,
    @Path('source') String source,
  );

  /// 影片下载历史 · 返回 { magnets: {hash: time}, ed2ks: {hash: time} }
  @GET('/movies/id/{id}/dbonline/download-history')
  Future<dynamic> getDownloadHistory(@Path('id') int id);

  // ===== 批量操作 =====

  /// 批量添加关联 · body: { movie_ids, tag_ids?, genre_ids?, series_id? }
  @POST('/movies/batch/associations/add')
  Future<dynamic> batchAddAssociations(@Body() Map<String, dynamic> body);

  /// 批量移除关联 · body: { movie_ids, tag_ids?, genre_ids?, series_id? }
  @POST('/movies/batch/associations/remove')
  Future<dynamic> batchRemoveAssociations(@Body() Map<String, dynamic> body);

  /// 批量海报水印/裁剪 · body: { movie_ids, subtitle, exsub, crack, uhd }
  @POST('/movies/batch/watermark')
  Future<dynamic> batchWatermark(@Body() Map<String, dynamic> body);

  /// 批量合并重复番号 · body: { movie_ids, target_movie_id }
  @POST('/movies/batch/merge-duplicate-files')
  Future<dynamic> mergeDuplicateFiles(@Body() Map<String, dynamic> body);

  /// 比较重复番号 NFO · body: { movie_ids }
  @POST('/movies/batch/duplicate-nfo/compare')
  Future<dynamic> compareDuplicateNfo(@Body() Map<String, dynamic> body);

  /// 应用 NFO 同步选择 · body: scalar_selections + ...
  @POST('/movies/batch/duplicate-nfo/apply')
  Future<dynamic> applyDuplicateNfo(@Body() Map<String, dynamic> body);

  /// 提交下载请求 · body: { movie_ids, requirements: {...} }
  @POST('/movies/download')
  Future<dynamic> requestDownload(@Body() Map<String, dynamic> body);

  // ===== 海报裁剪 + 水印 =====

  /// 应用裁剪 + 水印 · body: { subtitle, exsub, crack, uhd, crop_offset }
  @POST('/movies/id/{id}/poster/watermark')
  Future<dynamic> updatePosterWatermark(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  /// 预览裁剪结果 (返回 JPEG bytes)
  @POST('/movies/id/{id}/poster/watermark/preview')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> previewPosterWatermark(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );
}
