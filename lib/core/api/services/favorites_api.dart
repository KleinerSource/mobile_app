import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'favorites_api.g.dart';

@RestApi()
abstract class FavoritesApi {
  factory FavoritesApi(Dio dio, {String baseUrl}) = _FavoritesApi;

  @PUT('/favorites/{movieId}/toggle')
  Future<dynamic> toggle(@Path('movieId') int movieId);
}
