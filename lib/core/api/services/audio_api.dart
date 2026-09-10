import 'package:dio/dio.dart';

/// 音频资产及字幕转译业务投影接口。
///
/// 任务提交和控制统一由 `TasksApi` 负责；这里仅保留资产读写和投影查询。
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
}
