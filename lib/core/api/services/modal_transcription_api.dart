import 'package:dio/dio.dart';

/// Modal 云端字幕转译配置接口。
///
/// 该接口与传统的 `/translation/*` AI 文本翻译接口是两套独立能力，
/// 因此单独保留 service，避免配置字段和任务语义混用。
class ModalTranscriptionApi {
  ModalTranscriptionApi(this._dio);

  final Dio _dio;

  Future<dynamic> getConfig() async {
    final response = await _dio.get<dynamic>('/modal-transcription/config');
    return response.data;
  }

  Future<dynamic> saveConfig(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>(
      '/modal-transcription/config',
      data: body,
    );
    return response.data;
  }
}
