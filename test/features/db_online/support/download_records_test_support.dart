import 'package:dio/dio.dart';

import 'following_test_support.dart';

class DownloadRecordsTestBackend extends FollowingTestBackend {
  List<Map<String, dynamic>> records = [downloadRecord(1)];
  List<Map<String, dynamic>> downloaders = [
    {
      'name': 'pan115',
      'display_name': '115 网盘',
      'ed2k_enabled': false,
      'available_quota': 123,
    },
  ];
  bool pushFailed = false;

  @override
  Object response(RequestOptions request) {
    if (request.path == '/downloaders') {
      return {
        'success': true,
        'data': {'downloaders': downloaders},
      };
    }
    if (request.path == '/download-records') {
      final query = request.queryParameters;
      final keyword = query['keyword']?.toString() ?? '';
      final status = query['success'];
      final matching = records.where((record) {
        return (keyword.isEmpty || record.toString().contains(keyword)) &&
            (status == null ||
                record['success'] == (status.toString() == 'true')) &&
            (query['downloader'] == null ||
                record['downloader'] == query['downloader']) &&
            (query['source_type'] == null ||
                record['source_type'] == query['source_type']);
      }).toList();
      final offset = query['offset'] as int? ?? 0;
      final limit = query['limit'] as int? ?? 20;
      final batch = matching.skip(offset).take(limit).toList();
      return downloadRecordPage(
        batch,
        total: records.length,
        filtered: matching.length,
        more: offset + batch.length < matching.length,
      );
    }
    if (request.path == '/download') {
      final body = request.data as Map;
      final resource = (body['record_resources'] as List).single as Map;
      final index = records.indexWhere(
        (record) => record['id'] == resource['record_id'],
      );
      if (index >= 0) {
        records[index] = {
          ...records[index],
          'success': !pushFailed,
          'error_message': pushFailed ? '重推测试失败' : '',
          'downloader': body['downloader'],
        };
      }
      if (pushFailed) return {'success': false, 'error': '重推测试失败'};
      final downloader = body['downloader'];
      for (final item in downloaders) {
        if (item['name'] == downloader && item['available_quota'] is int) {
          item['available_quota'] = (item['available_quota'] as int) - 1;
        }
      }
      return {
        'success': true,
        'data': {'downloader': downloader},
      };
    }
    return super.response(request);
  }
}

Map<String, dynamic> downloadRecord(
  int id, {
  bool success = true,
  String protocol = 'magnet',
  String sourceType = 'manual',
  String sourceLabel = '手动推送',
  List<String> types = const ['hd', 'sub', 'uncensored'],
}) => {
  'id': id,
  'video_id': 'video-$id',
  'video_code': 'DBO-$id',
  'video_title': '记录影片 $id',
  'release_date': '2026-09-01',
  'source_type': sourceType,
  'source_label': sourceLabel,
  'resource_url': protocol == 'ed2k'
      ? 'ed2k://|file|sample|1024|0123456789ABCDEF0123456789ABCDEF|/'
      : 'magnet:?xt=urn:btih:000000000000000000000000000000000000000$id',
  'resource_protocol': protocol,
  'resource_site': 'nyaa',
  'resource_name': '资源名称 $id',
  'resource_flags': 26,
  'resource_date': '2026-10-01',
  'resource_types': types,
  'downloader': 'pan115',
  'success': success,
  'error_message': success ? '' : '原推送失败',
  'downloaded_at': '2026-10-03T01:02:03Z',
};

Map<String, dynamic> downloadRecordPage(
  List<Map<String, dynamic>> records, {
  int? total,
  int? filtered,
  bool more = false,
}) => {
  'success': true,
  'data': {
    'records': records,
    'total_count': total ?? records.length,
    'filtered_count': filtered ?? records.length,
    'has_more': more,
  },
};
