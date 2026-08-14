import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'mappings_api.g.dart';

@RestApi()
abstract class MappingsApi {
  factory MappingsApi(Dio dio, {String baseUrl}) = _MappingsApi;

  /// 列出普通映射 · type ∈ {tags, genres, series}
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

  // ===== 同步演员关联 =====

  /// 预览数据源返回的别名、简介和头像 · body: { actor_name, source? }
  @POST('/mappings/actors/external-sync/preview')
  Future<dynamic> actorExternalSyncPreview(@Body() Map<String, dynamic> body);

  /// 启动混合渠道渐进预览会话 · body: { actor_name } → { task_id }
  /// 渠道在后台并行采集，每完成一个即增量合并，先到的渠道数据可先渲染
  @POST('/mappings/actors/external-sync/preview/mixed')
  Future<dynamic> mixedExternalSyncPreviewStart(@Body() Map<String, dynamic> body);

  /// 获取混合渠道预览会话进度 · { status: running|complete|failed, pending_sources, preview, error? }
  @GET('/mappings/actors/external-sync/preview/mixed/{taskId}')
  Future<dynamic> mixedExternalSyncPreviewSession(@Path('taskId') String taskId);

  /// 应用同步演员关联结果 · body: { mapped_value, original_values, biography?, avatar_url?, avatar_overwrite? }
  @POST('/mappings/actors/external-sync/apply')
  Future<dynamic> actorExternalSyncApply(@Body() Map<String, dynamic> body);

  /// 批量同步演员关联 · body: { actor_names, source? } → { task_id, total_count }
  @POST('/mappings/actors/external-sync/batch')
  Future<dynamic> actorExternalSyncBatch(@Body() Map<String, dynamic> body);

  /// 批量任务进度
  @GET('/mappings/actors/external-sync/batch/{taskId}')
  Future<dynamic> actorExternalSyncBatchStatus(@Path('taskId') String taskId);

  /// 取消批量任务
  @POST('/mappings/actors/external-sync/batch/{taskId}/cancel')
  Future<dynamic> actorExternalSyncBatchCancel(@Path('taskId') String taskId);
}
