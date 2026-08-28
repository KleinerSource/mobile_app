import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/sources/media/omm_media_operations_adapter.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';

void main() {
  test('资源编辑请求携带自动映射开关', () async {
    final adapter = _ResourceAdapter();
    final repository = ResourcesRepository(
      OmmMediaOperationsAdapter(ApiClient(_dio(adapter))),
    );

    await repository.update(ResourceKind.tag, 7, name: '睡觉', autoMapping: true);
    await repository.update(ResourceKind.series, 8, name: '系列 B');

    expect(adapter.paths, <String>['/api/tags/7', '/api/series/8']);
    expect(adapter.requestBodies[0].containsKey('description'), isFalse);
    expect(adapter.requestBodies[1].containsKey('description'), isFalse);
    expect(adapter.requestBodies[0]['auto_mapping'], isTrue);
    expect(adapter.requestBodies[1]['auto_mapping'], isFalse);
  });
}

Dio _dio(_ResourceAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = adapter;
}

class _ResourceAdapter implements HttpClientAdapter {
  final paths = <String>[];
  final requestBodies = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    if (options.data is Map) {
      requestBodies.add(Map<String, dynamic>.from(options.data as Map));
    }

    final id = options.uri.path.split('/').last;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'ok',
        'data': {
          'id': int.parse(id),
          'name': options.data['name'],
          'movie_count': 0,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
