import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'genres_api.g.dart';

@RestApi()
abstract class GenresApi {
  factory GenresApi(Dio dio, {String baseUrl}) = _GenresApi;

  @GET('/genres')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);

  @GET('/genres/options')
  Future<dynamic> options(@Queries() Map<String, dynamic> q);

  @POST('/genres')
  Future<dynamic> create(@Body() Map<String, dynamic> body);

  @PATCH('/genres/{id}')
  Future<dynamic> update(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  /// 批量删除 · body { ids: [...], force: bool }
  @POST('/genres/batch-delete')
  Future<dynamic> batchDelete(@Body() Map<String, dynamic> body);
}
