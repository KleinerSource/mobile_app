/// OMM 媒体元数据与关联操作。
///
/// 返回值保留为协议无关的 [Object?]，由各 Feature 的领域门面解码为现有
/// 模型。网络客户端和端点只允许出现在 Source adapter 内部。
abstract interface class OmmMetadataOperationsSource {
  Future<Object?> listActors(Map<String, dynamic> query);

  Future<Object?> actorOptions(Map<String, dynamic> query);

  Future<List<int>> previewActorAvatar(Map<String, dynamic> body);

  Future<Object?> actorDetail(int id);

  Future<Object?> createActor(Map<String, dynamic> body);

  Future<Object?> updateActor(int id, Map<String, dynamic> body);

  Future<Object?> deleteActors(Map<String, dynamic> body);

  Future<Object?> resourceDetail(String type, int id);

  Future<Object?> resourceList(String type, Map<String, dynamic> query);

  Future<Object?> resourceOptions(String type, Map<String, dynamic> query);

  Future<Object?> resourceCreate(String type, Map<String, dynamic> body);

  Future<Object?> resourceUpdate(
    String type,
    int id,
    Map<String, dynamic> body,
  );

  Future<Object?> resourceDelete(String type, Map<String, dynamic> body);

  Future<Object?> resourceMerge(String type, Map<String, dynamic> body);

  Future<Object?> mappingList(String type, Map<String, dynamic> query);

  Future<Object?> mappingCreate(String type, Map<String, dynamic> body);

  Future<Object?> mappingUpdate(String type, int id, Map<String, dynamic> body);

  Future<Object?> mappingDelete(String type, Map<String, dynamic> body);

  Future<Object?> actorExternalSyncPreview(Map<String, dynamic> body);

  Future<Object?> mixedExternalSyncPreviewStart(Map<String, dynamic> body);

  Future<Object?> mixedExternalSyncPreviewSession(String taskId);

  Future<Object?> actorExternalSyncApply(Map<String, dynamic> body);
}
