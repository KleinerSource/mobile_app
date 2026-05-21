import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'movies_api.g.dart';

@RestApi()
abstract class MoviesApi {
  factory MoviesApi(Dio dio, {String baseUrl}) = _MoviesApi;

  @GET('/movies')
  Future<Map<String, dynamic>> getMovies(@Queries() Map<String, dynamic> q);

  @GET('/movies/{id}')
  Future<Map<String, dynamic>> getMovieDetail(@Path('id') int id);

  @PUT('/movies/{id}/watch-record')
  Future<Map<String, dynamic>> upsertWatchRecord(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @GET('/movies/{id}/watch-record')
  Future<Map<String, dynamic>> getWatchRecord(@Path('id') int id);
}
