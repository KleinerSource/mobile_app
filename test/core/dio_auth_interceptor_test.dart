import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/config/server_config.dart';

void main() {
  test('并发 401 只触发一次 refresh，并重试原请求', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    await repository.save(
      const AuthSession(
        accessToken: 'old-access',
        refreshToken: 'refresh-token',
        expiresIn: 3600,
      ),
    );
    final adapter = _RefreshAdapter();
    final dio = buildDio(
      const ServerConfig(baseUrl: 'http://media.example:8001'),
      sessionRepository: repository,
    )..httpClientAdapter = adapter;

    final responses = await Future.wait([
      dio.get<dynamic>('/protected-a'),
      dio.get<dynamic>('/protected-b'),
    ]);

    expect(responses, hasLength(2));
    expect(adapter.refreshCalls, 1);
    expect(adapter.authorizations, contains('Bearer old-access'));
    expect(adapter.authorizations, contains('Bearer new-access'));
    expect(await repository.accessToken(), 'new-access');
  });
}

class _RefreshAdapter implements HttpClientAdapter {
  int refreshCalls = 0;
  final authorizations = <String>[];
  final _firstFailures = <String>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization']?.toString();
    if (auth != null) authorizations.add(auth);
    if (options.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      return _jsonResponse({
        'success': true,
        'message': 'ok',
        'data': {
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'expires_in': 3600,
        },
      });
    }
    if (_firstFailures.add(options.path)) {
      return _jsonResponse({
        'success': false,
        'message': 'expired',
        'data': null,
      }, status: 401);
    }
    return _jsonResponse({'success': true, 'message': 'ok', 'data': {}});
  }

  ResponseBody _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
