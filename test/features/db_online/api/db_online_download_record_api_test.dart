import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record.dart';
import 'package:omm/core/api/api_exception.dart';

import '../support/download_records_test_support.dart';

void main() {
  test('固定每批20条，筛选参数包含false和逗号连接类型', () async {
    final backend = DownloadRecordsTestBackend();
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    final api = DbOnlineApi(dio).downloadRecords;
    await api.list(
      const DbOnlineDownloadRecordFilter(
        startDate: '2026-09-01',
        endDate: '2026-10-03',
        keyword: ' DBO ',
        resourceTypes: ['hd', 'sub', 'uncensored'],
        downloader: 'pan115',
        sourceType: 'actor_subscription',
        status: 'false',
      ),
      offset: 37,
    );
    expect(backend.to('/download-records').single.queryParameters, {
      'limit': 20,
      'offset': 37,
      'start_date': '2026-09-01',
      'end_date': '2026-10-03',
      'keyword': 'DBO',
      'resource_types': 'hd,sub,uncensored',
      'downloader': 'pan115',
      'source_type': 'actor_subscription',
      'success': false,
    });
    expect(
      backend.to('/download-records').single.queryParameters,
      isNot(contains('filter_by')),
    );
  });

  test('默认当天，清空筛选字段不发送空值，复制资源条件不可变', () {
    final defaults = DbOnlineDownloadRecordFilter.today(
      DateTime(2026, 10, 3, 9),
    );
    expect(defaults.toQuery(), {
      'start_date': '2026-10-03',
      'end_date': '2026-10-03',
    });
    final types = ['hd'];
    final changed = defaults.copyWith(
      resourceTypes: types,
      status: 'false',
      keyword: '  资源  ',
    );
    types.add('sub');
    expect(changed.resourceTypes, ['hd']);
    expect(changed.toQuery()['keyword'], '资源');
    expect(
      changed.copyWith(status: '', keyword: '', resourceTypes: []).toQuery(),
      defaults.toQuery(),
    );
  });

  test('记录保留字符串影片ID、封面、状态、分页和全部原始重推字段', () async {
    final backend = DownloadRecordsTestBackend();
    backend.records = [
      {
        ...downloadRecord(17, success: false),
        'video_id': '0000017',
        'thumb_url': '/thumb.jpg',
        'cover_url': '/cover.jpg',
      },
    ];
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    final api = DbOnlineApi(dio);
    final page = await api.downloadRecords.list(
      const DbOnlineDownloadRecordFilter(),
    );
    final record = page.records.single;
    expect(record.id, 17);
    expect(record.videoId, '0000017');
    expect(record.thumbUrl, '/thumb.jpg');
    expect(record.coverUrl, '/cover.jpg');
    expect(record.success, false);
    expect(page.totalCount, 1);
    expect(page.filteredCount, 1);
    expect(page.hasMore, false);
    await api.pushDownload(
      urls: [record.resourceUrl],
      downloader: 'pan115',
      videoInfo: record.videoInfo,
      recordResources: [record.recordResource],
    );
    expect(backend.to('/download').single.data, {
      'urls': [record.resourceUrl],
      'downloader': 'pan115',
      'save_path': '',
      'video_info': {
        'video_id': '0000017',
        'code': 'DBO-17',
        'title': '记录影片 17',
        'date': '2026-09-01',
      },
      'record_resources': [
        {
          'record_id': 17,
          'url': record.resourceUrl,
          'name': '资源名称 17',
          'source_type': 'manual',
          'source_label': '手动推送',
          'resource_protocol': 'magnet',
          'resource_site': 'nyaa',
          'resource_flags': 26,
          'resource_date': '2026-10-01',
          'video_id': '0000017',
          'video_code': 'DBO-17',
          'video_title': '记录影片 17',
        },
      ],
    });
    expect(backend.records, hasLength(1));
    expect(backend.records.single['success'], true);
  });

  test('下载器门面读取115配额且保留旧下载器契约', () async {
    final backend = DownloadRecordsTestBackend();
    backend.downloaders.add({
      'name': 'cd2',
      'display_name': 'CloudDrive2',
      'ed2k_enabled': true,
    });
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    final api = DbOnlineApi(dio);
    final downloaders = await api.downloadRecords.downloaders();
    expect(backend.to('/downloaders').single.queryParameters, {
      'include_pan115_quota': true,
    });
    expect(downloaders.first.availableQuota, 123);
    expect(downloaders.first.option.ed2kEnabled, false);
    expect(downloaders.last.ed2kEnabled, true);
    expect(downloaders.last.availableQuota, isNull);
    expect((await api.getDownloaders()).first.name, 'pan115');
    expect(backend.to('/downloaders').last.queryParameters, isEmpty);
  });

  test('统一错误信封抛出，记录查询失败不会伪装为空列表', () async {
    final backend = DownloadRecordsTestBackend();
    backend.respond = (request) => request.path == '/download-records'
        ? {'success': false, 'error': '数据库读取失败'}
        : null;
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    expect(
      DbOnlineApi(
        dio,
      ).downloadRecords.list(const DbOnlineDownloadRecordFilter()),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '数据库读取失败',
        ),
      ),
    );
  });

  test('关注来源解析风格名称但重推保留原始ID', () {
    final record = DbOnlineDownloadRecord.fromJson(
      downloadRecord(
        1,
        sourceType: 'series_subscription',
        sourceLabel: '关注订阅 (1, 2, 99)',
      ),
    );
    expect(
      record.resolveSourceLabel({'1': '风格一', '2': '风格二'}),
      '关注订阅 (风格一 / 风格二 / 99)',
    );
    expect(record.resolveSourceLabel({}), '关注订阅 (1, 2, 99)');
    expect(record.recordResource['source_label'], '关注订阅 (1, 2, 99)');
  });
}
