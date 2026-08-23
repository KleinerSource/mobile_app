import 'package:dio/dio.dart';

/// 标签、分类、系列和演员的详情、重命名、合并及影片预览接口。
class CatalogExtendedApi {
  CatalogExtendedApi(this._dio);

  final Dio _dio;

  Future<Object?> detail(String type, int id) => _get('/$type/$id');

  Future<Object?> create(String type, Map<String, dynamic> body) =>
      _post('/$type', body);

  Future<Object?> update(String type, int id, Map<String, dynamic> body) =>
      _patch('/$type/$id', body);

  Future<Object?> batchDelete(String type, Map<String, dynamic> body) =>
      _post('/$type/delete', body);

  Future<Object?> checkRename(String type, Map<String, dynamic> body) =>
      _post('/$type/rename/check', body);

  Future<Object?> checkMerge(String type, Map<String, dynamic> body) =>
      _post('/$type/merge/check', body);

  Future<Object?> merge(String type, Map<String, dynamic> body) =>
      _post('/$type/merge', body);

  Future<Object?> moviesPreview(
    String type,
    int id, {
    Map<String, dynamic>? q,
  }) => _get('/$type/$id/movies/preview', queryParameters: q);

  Future<Object?> listActors(Map<String, dynamic> q) =>
      _get('/actors', queryParameters: q);

  Future<Object?> createActor(Map<String, dynamic> body) =>
      _post('/actors', body);

  Future<Object?> updateActor(int id, Map<String, dynamic> body) =>
      _patch('/actors/$id', body);

  Future<Object?> deleteActors(Map<String, dynamic> body) =>
      _post('/actors/delete', body);

  Future<Object?> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async =>
      (await _dio.get<dynamic>(path, queryParameters: queryParameters)).data;

  Future<Object?> _post(String path, Map<String, dynamic> body) async =>
      (await _dio.post<dynamic>(path, data: body)).data;

  Future<Object?> _patch(String path, Map<String, dynamic> body) async =>
      (await _dio.patch<dynamic>(path, data: body)).data;
}
