import 'package:dio/dio.dart';

import '../envelope.dart';

/// 影片详情页之外的批量、媒体刷新和字幕编辑接口。
class MoviesExtendedApi {
  MoviesExtendedApi(this._dio);

  final Dio _dio;

  Future<Object?> refreshMediaInfo(int movieId) async {
    final response = await _dio.post<dynamic>(
      '/movies/id/$movieId/media-info/refresh',
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> loadSubtitleForEdit(int movieId, int subtitleId) async {
    final response = await _dio.get<dynamic>(
      '/movies/id/$movieId/subtitle-editor/$subtitleId',
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> saveSubtitle(
    int movieId,
    int subtitleId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.put<dynamic>(
      '/movies/id/$movieId/subtitle-editor/$subtitleId',
      data: body,
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<void> deleteSubtitle(int movieId, int subtitleId) async {
    final response = await _dio.delete<dynamic>(
      '/movies/id/$movieId/subtitle-editor/$subtitleId',
    );
    unwrapStd<void>(response.data, (_) {});
  }

  Future<Object?> acknowledgeResources(
    int movieId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<dynamic>(
      '/movies/id/$movieId/dbonline/resources/acknowledge',
      data: body,
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> fetchDbonlineCover(int movieId) async {
    final response = await _dio.post<dynamic>(
      '/movies/id/$movieId/dbonline/cover',
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> downloadDbonlineExtrafanart(int movieId) async {
    final response = await _dio.post<dynamic>(
      '/movies/id/$movieId/dbonline/extrafanart',
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> batchNfoSync(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>(
      '/movies/batch/nfo-sync',
      data: body,
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> nfoSyncProgress(String taskId) async {
    final response = await _dio.get<dynamic>('/movies/nfo-sync/$taskId');
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<void> cancelNfoSync(String taskId) async {
    final response = await _dio.post<dynamic>(
      '/movies/nfo-sync/$taskId/cancel',
    );
    unwrapStd<void>(response.data, (_) {});
  }

  Future<Object?> batchExtraFanart(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>(
      '/movies/batch/dbonline/extrafanart',
      data: body,
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> extraFanartProgress(String taskId) async {
    final response = await _dio.get<dynamic>(
      '/movies/batch/dbonline/extrafanart/$taskId',
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<void> cancelExtraFanart(String taskId) async {
    final response = await _dio.post<dynamic>(
      '/movies/batch/dbonline/extrafanart/$taskId/cancel',
    );
    unwrapStd<void>(response.data, (_) {});
  }

  Future<Object?> batchResourceScan(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>(
      '/movies/batch/dbonline/resources/scan',
      data: body,
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Object?> resourceScanProgress(String taskId) async {
    final response = await _dio.get<dynamic>(
      '/movies/batch/dbonline/resources/scan/$taskId',
    );
    return unwrapStd<Object?>(response.data, (data) => data);
  }
}
