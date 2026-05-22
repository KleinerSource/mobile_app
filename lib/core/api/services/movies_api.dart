import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'movies_api.g.dart';

@RestApi()
abstract class MoviesApi {
  factory MoviesApi(Dio dio, {String baseUrl}) = _MoviesApi;

  @GET('/movies')
  Future<Map<String, dynamic>> getMovies(@Queries() Map<String, dynamic> q);

  @GET('/movies/id/{id}')
  Future<Map<String, dynamic>> getMovieDetail(@Path('id') int id);

  @PUT('/movies/id/{id}/watch-record')
  Future<Map<String, dynamic>> upsertWatchRecord(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @GET('/movies/id/{id}/watch-record')
  Future<Map<String, dynamic>> getWatchRecord(@Path('id') int id);

  /// 额外剧照列表 (来自 master 后端能力)
  @GET('/movies/id/{id}/extrafanart')
  Future<Map<String, dynamic>> getExtraFanarts(@Path('id') int id);

  /// 媒体信息 (容器/视频流/音频流) (来自 master 后端能力)
  @GET('/movies/id/{id}/media-info')
  Future<Map<String, dynamic>> getMediaInfo(@Path('id') int id);
}
