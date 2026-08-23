import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'tags_api.g.dart';

@RestApi()
abstract class TagsApi {
  factory TagsApi(Dio dio, {String baseUrl}) = _TagsApi;

  @GET('/tags')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);

  @GET('/tags/options')
  Future<dynamic> options(@Queries() Map<String, dynamic> q);

  @POST('/tags')
  Future<dynamic> create(@Body() Map<String, dynamic> body);

  @PATCH('/tags/{id}')
  Future<dynamic> update(@Path('id') int id, @Body() Map<String, dynamic> body);

  @POST('/tags/delete')
  Future<dynamic> batchDelete(@Body() Map<String, dynamic> body);
}
