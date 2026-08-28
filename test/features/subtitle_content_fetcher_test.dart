import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return responder(options);
  }
}

OmmMediaSourceAdapter _sourceWith(ResponseBody Function() responder) {
  final dio = Dio(BaseOptions(responseType: ResponseType.plain));
  dio.httpClientAdapter = _FakeAdapter((_) async => responder());
  return OmmMediaSourceAdapter(ApiClient(dio));
}

void main() {
  test('成功下载时返回去空白后的字幕内容', () async {
    final source = _sourceWith(
      () => ResponseBody.fromString(
        'WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\n你好\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/vtt; charset=utf-8'],
        },
      ),
    );
    final content = await source.fetchSubtitleContent(
      'http://server/subtitles/1?format=vtt',
    );
    expect(content, startsWith('WEBVTT'));
    expect(content, contains('00:00:01.000 --> 00:00:02.000'));
  });

  test('接口返回 404 时抛出带后端文案的异常而不是影响调用方', () async {
    final source = _sourceWith(
      () => ResponseBody.fromString(
        '{"success":false,"message":"字幕不存在"}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        },
      ),
    );
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/99?format=vtt'),
      throwsA(
        isA<SourceException>()
            .having((e) => e.message, 'message', '字幕不存在')
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('错误响应体不是 JSON 时退回通用 HTTP 文案', () async {
    final source = _sourceWith(() => ResponseBody.fromString('Not Found', 404));
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/99?format=vtt'),
      throwsA(
        isA<SourceException>().having(
          (e) => e.message,
          'message',
          contains('404'),
        ),
      ),
    );
  });

  test('内容缺少时间轴行时视为无效字幕', () async {
    final source = _sourceWith(() => ResponseBody.fromString('WEBVTT\n', 200));
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/1?format=vtt'),
      throwsA(
        isA<SourceException>().having((e) => e.message, 'message', '字幕内容无效或为空'),
      ),
    );
  });

  test('连接失败映射为网络异常文案', () async {
    final dio = Dio(BaseOptions(responseType: ResponseType.plain));
    dio.httpClientAdapter = _FakeAdapter((_) async {
      throw DioException.connectionTimeout(
        requestOptions: RequestOptions(path: '/'),
        timeout: const Duration(seconds: 1),
      );
    });
    final source = OmmMediaSourceAdapter(ApiClient(dio));
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/1?format=vtt'),
      throwsA(
        isA<SourceException>().having(
          (e) => e.message,
          'message',
          '请求超时，请稍后重试',
        ),
      ),
    );
  });
}
