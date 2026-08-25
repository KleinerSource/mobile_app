import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/error_mapper.dart';

void main() {
  group('mapDioError', () {
    test('timeout 映射为友好文案', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      );
      final ex = mapDioError(e);
      expect(ex.message, '请求超时，请稍后重试');
      expect(ex.status, isNull);
    });

    test('无 response 映射为网络失败', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      final ex = mapDioError(e);
      expect(ex.message, '网络连接失败，请检查网络连接');
    });

    test('detail 为字符串', () {
      final ex = mapDioError(_resp(400, {'detail': '番号已存在'}));
      expect(ex.message, '番号已存在');
      expect(ex.status, 400);
    });

    test('detail 为对象 message', () {
      final ex = mapDioError(
        _resp(400, {
          'detail': {'message': '冲突'},
        }),
      );
      expect(ex.message, '冲突');
    });

    test('detail 为数组 → 用 ; 连接 msg/message', () {
      final ex = mapDioError(
        _resp(422, {
          'detail': [
            {'msg': 'a 不能为空'},
            {'message': 'b 不合法'},
            {'foo': 'bar'},
          ],
        }),
      );
      expect(ex.message, 'a 不能为空; b 不合法; 验证错误');
    });

    test('回落 message 字段', () {
      final ex = mapDioError(_resp(409, {'message': '已存在'}));
      expect(ex.message, '已存在');
    });

    test('二进制 JSON 错误仍解析业务 message 和 data', () {
      final ex = mapDioError(
        _resp(
          401,
          utf8.encode(
            jsonEncode({
              'success': false,
              'message': '令牌过期',
              'data': {'reason': 'expired'},
            }),
          ),
        ),
      );
      expect(ex.message, '令牌过期');
      expect(ex.data, {'reason': 'expired'});
    });

    test('完全无字段 → 用 HTTP 状态', () {
      final ex = mapDioError(_resp(500, {}, statusText: 'Internal'));
      expect(ex.message, 'HTTP 500: Internal');
    });

    test('异常文本不会暴露 query token 或 Bearer token', () {
      final ex = ApiException(
        'open https://media.example/stream.m3u8?token=access-secret '
        'Authorization: Bearer header-secret',
      );
      expect(ex.message, isNot(contains('access-secret')));
      expect(ex.message, isNot(contains('header-secret')));
      expect(ex.message, contains('token=***'));
      expect(ex.message, contains('Bearer ***'));
    });
  });
}

DioException _resp(int code, Object body, {String statusText = ''}) {
  final opts = RequestOptions(path: '/x');
  return DioException(
    requestOptions: opts,
    response: Response(
      requestOptions: opts,
      statusCode: code,
      statusMessage: statusText,
      data: body,
      headers: Headers.fromMap({
        'x-request-id': ['req-123'],
      }),
    ),
    type: DioExceptionType.badResponse,
  );
}
