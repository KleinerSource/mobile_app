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

  @GET('/movies/id/{id}/extrafanart')
  Future<dynamic> getExtraFanarts(@Path('id') int id);

  @GET('/movies/id/{id}/media-info')
  Future<dynamic> getMediaInfo(@Path('id') int id);
}
