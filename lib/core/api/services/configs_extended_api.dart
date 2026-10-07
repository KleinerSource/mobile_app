import 'package:dio/dio.dart';

class ConfigsExtendedApi {
  ConfigsExtendedApi(this._dio);

  final Dio _dio;

  Future<Object?> avdb() => _get('/configs/avdb');

  Future<Object?> saveAvdb(Map<String, dynamic> body) =>
      _post('/configs/avdb', body);

  Future<Object?> ffmpeg() => _get('/configs/ffmpeg');

  Future<Object?> saveFfmpeg(Map<String, dynamic> body) =>
      _post('/configs/ffmpeg', body);

  Future<Object?> preview() => _get('/configs/preview');

  Future<Object?> savePreview(Map<String, dynamic> body) =>
      _post('/configs/preview', body);

  Future<Object?> _get(String path) async =>
      (await _dio.get<dynamic>(path)).data;

  Future<Object?> _post(String path, Map<String, dynamic> body) async =>
      (await _dio.post<dynamic>(path, data: body)).data;
}
