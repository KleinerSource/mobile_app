import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'mappings_api.g.dart';

@RestApi()
abstract class MappingsApi {
  factory MappingsApi(Dio dio, {String baseUrl}) = _MappingsApi;

  /// 列出某类型 mappings · type ∈ {tags, genres, series, actors}
  @GET('/mappings/type/{type}')
  Future<dynamic> list(
    @Path('type') String type,
    @Queries() Map<String, dynamic> q,
  );

  @POST('/mappings/type/{type}')
  Future<dynamic> create(
    @Path('type') String type,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/mappings/type/{type}/{id}')
  Future<dynamic> update(
    @Path('type') String type,
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  /// 删除 · body: { mappings_ids: [...] }
  @DELETE('/mappings/type/{type}')
  Future<dynamic> delete(
    @Path('type') String type,
    @Body() Map<String, dynamic> body,
  );

  /// 批量导入 (json)
  @POST('/mappings/type/{type}/batch')
  Future<dynamic> import(
    @Path('type') String type,
    @Body() Map<String, dynamic> body,
  );

  @GET('/mappings/type/{type}/export')
  Future<dynamic> export(@Path('type') String type);

  @POST('/mappings/actors/sync')
  Future<dynamic> syncActors();
}
