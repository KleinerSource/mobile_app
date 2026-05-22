import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'genres_api.g.dart';

@RestApi()
abstract class GenresApi {
  factory GenresApi(Dio dio, {String baseUrl}) = _GenresApi;

  @GET('/genres')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);
}
