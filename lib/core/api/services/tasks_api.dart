import 'package:dio/dio.dart';

/// 服务端统一任务调度接口。
class TasksApi {
  TasksApi(this._dio);

  final Dio _dio;

  Future<dynamic> listTypes() async {
    final response = await _dio.get<dynamic>('/task-types');
    return response.data;
  }

  Future<dynamic> submit(
    String taskType, [
    Map<String, dynamic> input = const <String, dynamic>{},
  ]) async {
    final response = await _dio.post<dynamic>(
      '/tasks',
      data: <String, dynamic>{'task_type': taskType, 'input': input},
    );
    return response.data;
  }

  Future<dynamic> list({String? taskType, String? status}) async {
    final query = <String, dynamic>{};
    if (taskType != null && taskType.trim().isNotEmpty) {
      query['task_type'] = taskType.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    final response = await _dio.get<dynamic>('/tasks', queryParameters: query);
    return response.data;
  }

  Future<dynamic> get(String taskId) async {
    final response = await _dio.get<dynamic>(
      '/tasks/${Uri.encodeComponent(taskId)}',
    );
    return response.data;
  }

  Future<dynamic> control(String taskId, String action) async {
    const supported = <String>{'cancel', 'pause', 'resume', 'retry'};
    if (!supported.contains(action)) {
      throw ArgumentError.value(action, 'action', '不支持的任务操作');
    }
    final response = await _dio.post<dynamic>(
      '/tasks/${Uri.encodeComponent(taskId)}/$action',
    );
    return response.data;
  }

  Future<dynamic> listRecords({
    int limit = 50,
    int offset = 0,
    String? status,
    String? taskType,
    bool recoveryOnly = false,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (taskType != null && taskType.trim().isNotEmpty) {
      query['task_type'] = taskType.trim();
    }
    if (recoveryOnly) query['recovery_only'] = true;
    final response = await _dio.get<dynamic>(
      '/task-records',
      queryParameters: query,
    );
    return response.data;
  }

  Future<dynamic> deleteRecord(String recordId) async {
    final response = await _dio.delete<dynamic>(
      '/task-records/${Uri.encodeComponent(recordId)}',
    );
    return response.data;
  }
}
