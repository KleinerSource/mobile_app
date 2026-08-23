import 'package:dio/dio.dart';

class LibrariesExtendedApi {
  LibrariesExtendedApi(this._dio);

  final Dio _dio;

  Future<Object?> stats() => _get('/libraries/stats');

  Future<Object?> batchDelete(Map<String, dynamic> body) =>
      _post('/libraries/delete', body);

  Future<Object?> batchScan(Map<String, dynamic> body) =>
      _post('/libraries/scan', body);

  Future<Object?> regenerateAllCovers() =>
      _post('/libraries/covers/regenerate');

  Future<Object?> regenerateCover(int libraryId) =>
      _post('/libraries/covers/regenerate/$libraryId');

  Future<Object?> batchDeleteDirectories(
    int libraryId,
    Map<String, dynamic> body,
  ) => _post('/libraries/id/$libraryId/directories/delete', body);

  Future<Object?> directoryDetail(int libraryId, int directoryId) =>
      _get('/libraries/id/$libraryId/directories/$directoryId');

  Future<Object?> _get(String path) async =>
      (await _dio.get<dynamic>(path)).data;

  Future<Object?> _post(String path, [Map<String, dynamic>? body]) async =>
      (await _dio.post<dynamic>(path, data: body)).data;
}
