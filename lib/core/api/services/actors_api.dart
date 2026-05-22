import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'actors_api.g.dart';

@RestApi()
abstract class ActorsApi {
  factory ActorsApi(Dio dio, {String baseUrl}) = _ActorsApi;

  @GET('/actors')
  Future<Map<String, dynamic>> list(@Queries() Map<String, dynamic> q);
}
