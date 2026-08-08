import 'package:dio/dio.dart';

class MappingsExtendedApi {
  MappingsExtendedApi(this._dio);

  final Dio _dio;

  Future<Object?> cacheInfo() => _get('/mappings/cache/info');

  Future<Object?> refreshCache() => _post('/mappings/cache/refresh');

  Future<Object?> invalidateCache() => _post('/mappings/cache/invalidate');

  Future<Object?> _get(String path) async => (await _dio.get<dynamic>(path)).data;

  Future<Object?> _post(String path) async => (await _dio.post<dynamic>(path)).data;
}
