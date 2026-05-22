import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'directories_api.g.dart';

@RestApi()
abstract class DirectoriesApi {
  factory DirectoriesApi(Dio dio, {String baseUrl}) = _DirectoriesApi;

  @GET('/directories')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);
}
