import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/dio_factory.dart';
import 'package:md_center/core/config/server_config.dart';

void main() {
  test('baseUrl 拼接 /api', () {
    final dio = buildDio(const ServerConfig(baseUrl: 'http://h:8001'));
    expect(dio.options.baseUrl, 'http://h:8001/api');
    expect(dio.options.connectTimeout, const Duration(seconds: 15));
  });

  test('错误拦截器把 success:false 转为 ApiException', () async {
    final dio = buildDio(const ServerConfig(baseUrl: 'http://h:8001'));
    final adapter = _StubAdapter({
      'success': false,
      'message': '业务失败',
      'data': null,
    });
    dio.httpClientAdapter = adapter;
    try {
      await dio.get<dynamic>('/x');
      fail('期望抛错');
    } catch (e) {
      final ex = toApiException(e);
      expect(ex.message, '业务失败');
    }
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final Map<String, dynamic> body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final encoded =
        '{"success":${body['success']},"message":"${body['message']}","data":${body['data']}}';
    return ResponseBody.fromString(encoded, 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}
