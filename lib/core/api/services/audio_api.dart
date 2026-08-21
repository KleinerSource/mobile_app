import 'package:dio/dio.dart';

/// 音频资产及云端字幕转译任务接口。
///
/// 音频提取的实时进度由任务 WebSocket 推送，这里只负责任务查询和操作。
class AudioApi {
  AudioApi(this._dio);

  final Dio _dio;

  Future<dynamic> listTranscriptions({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    final response = await _dio.get<dynamic>(
      '/audios/transcriptions',
      queryParameters: query,
    );
    return response.data;
  }

  Future<dynamic> extractAudio({
    required int movieId,
    String format = 'mp3',
    int bitrateKbps = 192,
  }) async {
    final response = await _dio.post<dynamic>(
      '/audios/extract',
      data: {
        'movie_id': movieId,
        'format': format,
        'bitrate_kbps': bitrateKbps,
      },
    );
    return response.data;
  }

  Future<dynamic> cancelAudioExtraction(String taskId) async {
    final response = await _dio.post<dynamic>(
      '/audios/extract/${Uri.encodeComponent(taskId)}/cancel',
    );
    return response.data;
  }

  Future<dynamic> cancelSubtitleTranscription(String taskId) async {
    final response = await _dio.post<dynamic>(
      '/audios/transcriptions/${Uri.encodeComponent(taskId)}/cancel',
    );
    return response.data;
  }

  Future<dynamic> retrySubtitleTranscription(
    String taskId, {
    bool? overwrite,
  }) async {
    final response = await _dio.post<dynamic>(
      '/audios/transcriptions/${Uri.encodeComponent(taskId)}/retry',
      data: overwrite == null ? <String, dynamic>{} : {'overwrite': overwrite},
    );
    return response.data;
  }
}
