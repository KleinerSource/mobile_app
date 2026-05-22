import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'libraries_api.g.dart';

@RestApi()
abstract class LibrariesApi {
  factory LibrariesApi(Dio dio, {String baseUrl}) = _LibrariesApi;

  @GET('/libraries')
  Future<Map<String, dynamic>> list(@Queries() Map<String, dynamic> q);

  @GET('/libraries/id/{id}')
  Future<Map<String, dynamic>> detail(@Path('id') int id);
}
