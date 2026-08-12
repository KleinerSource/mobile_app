import 'package:dio/dio.dart';

class ConfigsExtendedApi {
  ConfigsExtendedApi(this._dio);

  final Dio _dio;

  Future<Object?> create(Map<String, dynamic> body) => _post('/configs', body);

  Future<Object?> avdb() => _get('/configs/avdb');

  Future<Object?> saveAvdb(Map<String, dynamic> body) =>
      _post('/configs/avdb', body);

  Future<Object?> ffmpeg() => _get('/configs/ffmpeg');

  Future<Object?> saveFfmpeg(Map<String, dynamic> body) =>
      _post('/configs/ffmpeg', body);

  Future<Object?> getByKey(String key) => _get('/configs/key/$key');

  Future<Object?> updateByKey(String key, Map<String, dynamic> body) =>
      _patch('/configs/key/$key', body);

  Future<void> deleteByKey(String key) async {
    await _dio.delete<dynamic>('/configs/key/$key');
  }

  Future<Object?> _get(String path) async => (await _dio.get<dynamic>(path)).data;

  Future<Object?> _post(String path, Map<String, dynamic> body) async =>
      (await _dio.post<dynamic>(path, data: body)).data;

  Future<Object?> _patch(String path, Map<String, dynamic> body) async =>
      (await _dio.patch<dynamic>(path, data: body)).data;
}
