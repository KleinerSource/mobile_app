import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';

void main() {
  for (final legacy in [true, false]) {
    final protocol = legacy ? 'code/msg' : 'success/data';

    test('字幕查询解析 $protocol 空结果', () async {
      final api = _api(_envelope(legacy, {'files': [], 'items': null}));

      expect(await api.findSubtitles('ABC-001'), isEmpty);
      expect(await api.searchExternalSubtitles('ABC-001'), isEmpty);
    });

    test('字幕查询解析 $protocol 非空结果', () async {
      final api = _api(
        _envelope(legacy, {
          'files': [
            {'id': 'local-1', 'name': '本地.srt', 'extension': 'srt'},
          ],
          'items': [
            {'name': '迅雷.srt', 'url': 'https://example.test/sub.srt'},
          ],
        }),
      );

      expect((await api.findSubtitles('ABC-001')).single.name, '本地.srt');
      expect(
        (await api.searchExternalSubtitles('ABC-001')).single.name,
        '迅雷.srt',
      );
    });

    test('字幕预览解析 $protocol 内容', () async {
      final api = _api(_envelope(legacy, {'content': '测试字幕'}));

      expect((await api.previewLocalSubtitle('local-1')).content, '测试字幕');
      expect(
        (await api.previewExternalSubtitle(
          'https://example.test/sub.srt',
        )).content,
        '测试字幕',
      );
    });
  }

  final requests = <String, Future<Object> Function(DbOnlineApi)>{
    '本地查询': (api) => api.findSubtitles('ABC-001'),
    '迅雷查询': (api) => api.searchExternalSubtitles('ABC-001'),
    '本地预览': (api) => api.previewLocalSubtitle('local-1'),
    '迅雷预览': (api) =>
        api.previewExternalSubtitle('https://example.test/sub.srt'),
  };
  for (final entry in requests.entries) {
    test('${entry.key} 保留 code/msg 业务错误', () async {
      final api = _api({'code': -1, 'msg': '字幕功能未启用'});

      await expectLater(
        entry.value(api),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            '字幕功能未启用',
          ),
        ),
      );
    });
  }

  test('显式 success=false 不会被 code=0 覆盖', () async {
    final api = _api({'success': false, 'code': 0, 'error': '字幕服务不可用'});

    await expectLater(
      api.findSubtitles('ABC-001'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '字幕服务不可用',
        ),
      ),
    );
  });

  test('HTTP 请求失败不会被空结果兼容吞掉', () async {
    final api = _api({'code': -1, 'msg': '字幕服务不可用'}, status: 502);

    await expectLater(
      api.searchExternalSubtitles('ABC-001'),
      throwsA(isA<DioException>()),
    );
  });
}

Map<String, Object?> _envelope(bool legacy, Object? data) => {
  if (legacy) ...{'code': 0, 'msg': 'success'} else 'success': true,
  'data': data,
};

DbOnlineApi _api(Object? response, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
    ..httpClientAdapter = _SubtitleAdapter(response, status);
  addTearDown(dio.close);
  return DbOnlineApi(dio);
}

class _SubtitleAdapter implements HttpClientAdapter {
  _SubtitleAdapter(this.response, this.status);

  final Object? response;
  final int status;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(response),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}
