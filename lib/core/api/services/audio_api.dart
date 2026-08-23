import 'package:dio/dio.dart';

/// 音频资产及云端字幕转译任务接口。
///
/// 音频提取的实时进度由任务 WebSocket 推送，这里只负责任务查询和操作。
///
/// 字幕转译信息内嵌在音频资产行上（一个资产只保留一条转译信息，随资产删除）：
/// - [listTranscriptions] 返回的是资产表投影出的转译视图，行内 `id` 即音频资产 ID；
/// - 取消/重试接口的 id 传音频资产 ID（与 WS scheduler_status 的 taskId 同源）。
class AudioApi {
  AudioApi(this._dio);

  final Dio _dio;

  /// 音频资产列表：支持按影片名/文件名搜索，返回分页资产与转译统计。
  Future<dynamic> listAssets({
    int limit = 50,
    int offset = 0,
    String? search,
    String? format,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    final term = search?.trim() ?? '';
    if (term.isNotEmpty) query['search'] = term;
    final fmt = format?.trim().toLowerCase() ?? '';
    if (fmt.isNotEmpty) query['format'] = fmt;
    final response = await _dio.get<dynamic>('/audios', queryParameters: query);
    return response.data;
  }

  /// 统一删除入口：单项删除即提交长度为 1 的 ids 数组。
  Future<dynamic> deleteAssets(List<int> ids) async {
    final response = await _dio.post<dynamic>(
      '/audios/delete',
      data: {'ids': ids},
    );
    return response.data;
  }

  /// 把音频资产加入字幕转译队列，返回受理与被拒明细。
  Future<dynamic> enqueueTranscriptions(
    List<int> assetIds, {
    bool overwrite = false,
  }) async {
    final response = await _dio.post<dynamic>(
      '/audios/transcriptions',
      data: {'audio_asset_ids': assetIds, 'overwrite': overwrite},
    );
    return response.data;
  }

  /// 转译队列视图（从音频资产表投影）：仅返回转译状态非空的资产，
  /// 每个资产至多一条记录，按入队时间倒序。
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

  /// [assetId] 为音频资产 ID。
  Future<dynamic> cancelSubtitleTranscription(String assetId) async {
    final response = await _dio.post<dynamic>(
      '/audios/transcriptions/${Uri.encodeComponent(assetId)}/cancel',
    );
    return response.data;
  }

  /// [assetId] 为音频资产 ID。
  Future<dynamic> retrySubtitleTranscription(
    String assetId, {
    bool? overwrite,
  }) async {
    final response = await _dio.post<dynamic>(
      '/audios/transcriptions/${Uri.encodeComponent(assetId)}/retry',
      data: overwrite == null ? <String, dynamic>{} : {'overwrite': overwrite},
    );
    return response.data;
  }
}
