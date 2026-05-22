import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'system_api.g.dart';

@RestApi()
abstract class SystemApi {
  factory SystemApi(Dio dio, {String baseUrl}) = _SystemApi;

  @GET('/health')
  Future<dynamic> health();

  @GET('/version')
  Future<dynamic> version();

  @GET('/database/stats')
  Future<dynamic> stats();
}
