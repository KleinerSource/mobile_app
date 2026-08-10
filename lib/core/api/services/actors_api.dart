import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'actors_api.g.dart';

@RestApi()
abstract class ActorsApi {
  factory ActorsApi(Dio dio, {String baseUrl}) = _ActorsApi;

  @GET('/actors')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);

  @GET('/actors/options')
  Future<dynamic> options(@Queries() Map<String, dynamic> q);
}
