import 'package:dio/dio.dart';

/// 服务端统一任务历史接口。
class TasksApi {
  TasksApi(this._dio);

  final Dio _dio;

  Future<dynamic> list({
    int limit = 50,
    int offset = 0,
    String? status,
    String? taskName,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (taskName != null && taskName.trim().isNotEmpty) {
      query['task_name'] = taskName.trim();
    }
    final response = await _dio.get<dynamic>('/tasks', queryParameters: query);
    return response.data;
  }

  Future<dynamic> delete(String recordId) async {
    final response = await _dio.delete<dynamic>(
      '/tasks/${Uri.encodeComponent(recordId)}',
    );
    return response.data;
  }
}
