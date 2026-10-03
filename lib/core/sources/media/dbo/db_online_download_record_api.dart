import 'package:dio/dio.dart';

import '../../../api/envelope.dart';
import 'db_online_download_record.dart';

class DbOnlineDownloadRecordApi {
  DbOnlineDownloadRecordApi(this._dio);

  final Dio _dio;
  static const pageSize = 20;

  Future<DbOnlineDownloadRecordPage> list(
    DbOnlineDownloadRecordFilter filter, {
    int offset = 0,
  }) async {
    final response = await _dio.get<dynamic>(
      '/download-records',
      queryParameters: {
        'limit': pageSize,
        'offset': offset,
        ...filter.toQuery(),
      },
    );
    return unwrapStd(response.data, DbOnlineDownloadRecordPage.fromJson);
  }

  Future<List<DbOnlineRecordDownloader>> downloaders() async {
    final response = await _dio.get<dynamic>(
      '/downloaders',
      queryParameters: {'include_pan115_quota': true},
    );
    return unwrapStd(response.data, (data) {
      final items = data is Map ? data['downloaders'] : null;
      return items is List
          ? items
                .map(DbOnlineRecordDownloader.fromJson)
                .where((item) => item.name.isNotEmpty)
                .toList(growable: false)
          : <DbOnlineRecordDownloader>[];
    });
  }
}
