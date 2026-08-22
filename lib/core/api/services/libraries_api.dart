import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'libraries_api.g.dart';

@RestApi()
abstract class LibrariesApi {
  factory LibrariesApi(Dio dio, {String baseUrl}) = _LibrariesApi;

  // ===== 媒体库 CRUD =====

  @GET('/libraries')
  Future<dynamic> list(@Queries() Map<String, dynamic> q);

  @GET('/libraries/id/{id}')
  Future<dynamic> detail(@Path('id') int id);

  @POST('/libraries')
  Future<dynamic> create(@Body() Map<String, dynamic> body);

  @PATCH('/libraries/id/{id}')
  Future<dynamic> update(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  /// 删除媒体库（统一删除入口，单项删除即提交长度为 1 的数组） · body: { libraries_ids: [int] }
  @POST('/libraries/delete')
  Future<dynamic> delete(@Body() Map<String, dynamic> body);

  // ===== 扫描 =====

  /// 触发扫描 · body: { incremental: bool }
  @POST('/libraries/id/{id}/scan')
  Future<dynamic> scan(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @GET('/libraries/id/{id}/scan/active')
  Future<dynamic> activeScans(@Path('id') int id);

  @GET('/libraries/id/{id}/scan/tasks/{taskId}')
  Future<dynamic> scanProgress(
    @Path('id') int id,
    @Path('taskId') String taskId,
  );

  @POST('/libraries/id/{id}/scan/tasks/{taskId}/pause')
  Future<dynamic> pauseScan(
    @Path('id') int id,
    @Path('taskId') String taskId,
  );

  @POST('/libraries/id/{id}/scan/tasks/{taskId}/resume')
  Future<dynamic> resumeScan(
    @Path('id') int id,
    @Path('taskId') String taskId,
  );

  @POST('/libraries/id/{id}/scan/tasks/{taskId}/cancel')
  Future<dynamic> cancelScan(
    @Path('id') int id,
    @Path('taskId') String taskId,
  );

  // ===== 目录 (嵌套在媒体库下) =====

  @GET('/libraries/id/{id}/directories')
  Future<dynamic> listDirectories(@Path('id') int id);

  @POST('/libraries/id/{id}/directories')
  Future<dynamic> createDirectory(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/libraries/id/{id}/directories/{dirId}')
  Future<dynamic> updateDirectory(
    @Path('id') int id,
    @Path('dirId') int dirId,
    @Body() Map<String, dynamic> body,
  );

  /// 删除目录（统一删除入口，单项删除即提交长度为 1 的数组） · body: { directories_ids: [int] }
  @POST('/libraries/id/{id}/directories/delete')
  Future<dynamic> deleteDirectory(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  // ===== Tools (路径浏览 + 验证) =====

  @POST('/tools/browse')
  Future<dynamic> browsePath(@Body() Map<String, dynamic> body);

  @POST('/tools/paths/validate')
  Future<dynamic> validatePath(@Body() Map<String, dynamic> body);
}
