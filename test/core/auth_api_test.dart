import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/auth_api.dart';

void main() {
  test('鉴权 API 正确解包 Response.data 并覆盖完整会话路径', () async {
    final adapter = _AuthAdapter();
    final api = AuthApi(_dio(adapter));

    final status = await api.status();
    final session = await api.login(password: 'password', totpCode: '123456');
    final refreshed = await api.refresh('refresh-token');
    final verified = await api.verify();
    await api.logout();

    expect(status.enabled, isTrue);
    expect(session.accessToken, 'access-token');
    expect(refreshed.refreshToken, 'refresh-token');
    expect(verified, isTrue);
    expect(adapter.paths, <String>[
      '/api/auth/status',
      '/api/auth/login',
      '/api/auth/refresh',
      '/api/auth/verify',
      '/api/auth/logout',
    ]);
    expect(adapter.refreshAuthorization, 'Bearer refresh-token');
  });
}

Dio _dio(_AuthAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = adapter;
}

class _AuthAdapter implements HttpClientAdapter {
  final paths = <String>[];
  String? refreshAuthorization;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    if (options.uri.path.endsWith('/auth/refresh')) {
      refreshAuthorization = options.headers['Authorization']?.toString();
    }

    final data = switch (options.uri.path) {
      '/api/auth/status' => {
          'enabled': true,
          'configured': true,
          'authenticated': false,
          'password_login_disabled': false,
          'refresh_token_expire_days': 7,
          'max_failed_attempts': 5,
          'lock_minutes': 30,
          'totp_configured': true,
          'webauthn_configured': false,
        },
      '/api/auth/verify' => {'valid': true},
      _ => null,
    };
    final session = {
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'expires_in': 3600,
    };
    final body = {
      'success': true,
      'message': 'ok',
      'data': options.uri.path.endsWith('/auth/login') ||
              options.uri.path.endsWith('/auth/refresh')
          ? session
          : data,
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}
