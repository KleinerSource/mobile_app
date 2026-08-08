import 'package:dio/dio.dart';

class ImagesApi {
  ImagesApi(this._dio);

  final Dio _dio;

  Future<Object?> list(Map<String, dynamic> q) async =>
      (await _dio.get<dynamic>('/images', queryParameters: q)).data;

  Future<Object?> info(String uuid) async =>
      (await _dio.get<dynamic>('/images/$uuid/info')).data;

  Future<List<int>> bytes(String uuid) async {
    final response = await _dio.get<List<int>>(
      '/images/$uuid',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const [];
  }
}
