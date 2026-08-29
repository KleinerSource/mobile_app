// OpenList（AList v3 兼容）文件源的协议层与能力层测试。
// 通过进程内 HttpServer 模拟 OpenList REST API（信封 {code, message, data}）。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/files/openlist_api.dart';
import 'package:omm/core/sources/sources.dart';

void main() {
  group('OpenListClient 协议层', () {
    test('登录后携带裸 token 调用 fs API', () async {
      final fixture = await _OpenListFixture.start();
      final client = OpenListClient(_options(fixture));
      try {
        final entries = await client.listDirectory('/media');
        expect(entries.map((entry) => entry.name), [
          'movies',
          'movie.mkv',
          '.hidden',
        ]);
        expect(fixture.loginBodies.single['username'], 'alice');
        expect(fixture.loginBodies.single['password'], 'secret');
        expect(fixture.listAuthHeaders.single, startsWith('token-'));
        expect(fixture.listRequests.single['path'], '/media');
        expect(fixture.listRequests.single['per_page'], 500);
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('信封 401（令牌过期）自动重新登录并重试一次', () async {
      final fixture = await _OpenListFixture.start();
      final client = OpenListClient(_options(fixture));
      try {
        await client.listDirectory('/media');
        fixture.expireTokens();
        final entries = await client.listDirectory('/media');
        expect(entries, isNotEmpty);
        expect(fixture.loginCount, 2);
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('密码错误时抛出业务错误', () async {
      final fixture = await _OpenListFixture.start()
        ..wrongPassword = true;
      final client = OpenListClient(_options(fixture));
      try {
        await expectLater(
          client.listDirectory('/media'),
          throwsA(
            isA<OpenListException>()
                .having((error) => error.message, 'message', contains('登录失败'))
                .having(
                  (error) => error.message,
                  'message',
                  contains('wrong username or password'),
                ),
          ),
        );
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('分页循环合并全部条目，refresh 只在第一页携带', () async {
      final fixture = await _OpenListFixture.start()
        ..directoryEntries = List.generate(
          501,
          (index) => <String, dynamic>{
            'name': 'file-$index.bin',
            'is_dir': false,
            'size': index,
            'modified': '2026-01-02T03:04:05Z',
            'sign': '',
          },
        );
      final client = OpenListClient(_options(fixture));
      try {
        final entries = await client.listDirectory('/media', refresh: true);
        expect(entries.length, 501);
        expect(entries.last.name, 'file-500.bin');
        expect(fixture.listRequests.length, 2);
        expect(fixture.listRequests.first['refresh'], true);
        expect(fixture.listRequests.first['page'], 1);
        expect(fixture.listRequests.last['refresh'], false);
        expect(fixture.listRequests.last['page'], 2);
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('游客模式不登录，直链依赖 sign 而非 Authorization', () async {
      final fixture = await _OpenListFixture.start(requireAuth: false);
      final client = OpenListClient(
        OpenListConnectionOptions(
          uri: fixture.baseUri.toString(),
          port: fixture.server.port,
        ),
      );
      try {
        expect(fixture.loginCount, 0);
        final entries = await client.listDirectory('/media');
        expect(entries, isNotEmpty);

        final access = await client.resolveDirectAccess('/media/movie.mkv');
        expect(access.uri.path, '/d/media/movie.mkv');
        expect(access.uri.queryParameters['sign'], 'sig1');
        expect(access.headers.containsKey('Authorization'), isFalse);

        final response = await client.openStream('/media/movie.mkv');
        expect(response.statusCode, 200);
        final bytes = await response.data!.stream
            .expand((chunk) => chunk)
            .toList();
        expect(bytes, fixture.fileBytes);
        expect(fixture.downloadAuthHeaders.last, isNull);
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('raw_url 为第三方直链时不携带 Authorization', () async {
      final fixture = await _OpenListFixture.start();
      fixture.statOverrides['/media/cloud.bin'] = <String, dynamic>{
        'name': 'cloud.bin',
        'is_dir': false,
        'size': 128,
        'sign': '',
        'raw_url': 'http://127.0.0.1:1/cloud.bin',
        'header': {'Referer': 'https://cdn.example'},
      };
      final client = OpenListClient(_options(fixture));
      try {
        final access = await client.resolveDirectAccess('/media/cloud.bin');
        expect(access.uri.host, '127.0.0.1');
        expect(access.uri.port, 1);
        expect(access.headers['Referer'], 'https://cdn.example');
        expect(access.headers.containsKey('Authorization'), isFalse);
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('上传 PUT 携带 URL 编码的 File-Path 头与字节流', () async {
      final fixture = await _OpenListFixture.start();
      final client = OpenListClient(_options(fixture));
      try {
        var reported = 0;
        await client.upload(
          '/media/上传.bin',
          Stream<List<int>>.value(utf8.encode('hello')),
          5,
          onProgress: (received, total) => reported = received,
        );
        final upload = fixture.uploadRequests.single;
        expect(Uri.decodeComponent(upload.path), '/media/上传.bin');
        expect(upload.bytes, utf8.encode('hello'));
        expect(reported, 5);
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('下载与区间请求代发 fs/get 要求的 User-Agent', () async {
      final fixture = await _OpenListFixture.start();
      fixture.statOverrides['/media/movie.mkv'] = <String, dynamic>{
        'name': 'movie.mkv',
        'is_dir': false,
        'size': 64,
        'modified': '2026-01-02T03:04:05Z',
        'sign': 'sig1',
        'raw_url': '',
        'header': {'User-Agent': 'pan-client/1.0'},
      };
      final client = OpenListClient(_options(fixture));
      try {
        final response = await client.openStream('/media/movie.mkv');
        expect(response.statusCode, 200);
        await response.data!.stream.drain<void>();
        expect(fixture.downloadUserAgents.last, 'pan-client/1.0');

        final ranged = await client.openStream(
          '/media/movie.mkv',
          rangeStart: 8,
          rangeEnd: 16,
        );
        expect(ranged.statusCode, HttpStatus.partialContent);
        await ranged.data!.stream.drain<void>();
        expect(fixture.downloadUserAgents.last, 'pan-client/1.0');
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });

    test('对象不存在时抛出可识别的 404 业务错误', () async {
      final fixture = await _OpenListFixture.start();
      final client = OpenListClient(_options(fixture));
      try {
        await expectLater(
          client.get('/media/missing.bin'),
          throwsA(
            isA<OpenListException>().having(
              (error) => error.isNotFound,
              'isNotFound',
              isTrue,
            ),
          ),
        );
      } finally {
        await client.dispose();
        await fixture.close();
      }
    });
  });

  group('OpenListFileSource 能力层', () {
    test('connect 校验根路径必须是目录', () async {
      final fixture = await _OpenListFixture.start();
      try {
        final source = await OpenListFileSource.connect(
          id: 'openlist-1',
          name: '测试 OpenList',
          options: _options(fixture, path: '/media'),
        );
        await source.dispose();

        await expectLater(
          OpenListFileSource.connect(
            id: 'openlist-2',
            name: '测试 OpenList',
            options: _options(fixture, path: '/media/movie.mkv'),
          ),
          throwsA(
            isA<FileSourceException>().having(
              (error) => error.message,
              'message',
              contains('根路径必须是目录'),
            ),
          ),
        );
      } finally {
        await fixture.close();
      }
    });

    test('listDirectory 映射条目、etag 与隐藏标记，并透传 refresh', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-list');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture, path: '/'),
      );
      try {
        final listing = await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/media'),
        );
        expect(listing.currentPath.value, '/media');
        expect(listing.parentPath?.value, '/');
        expect(
          listing.entries.map((entry) => entry.name).toList(),
          ['movies', 'movie.mkv', '.hidden'],
        );
        final movie = listing.entries.singleWhere(
          (entry) => entry.name == 'movie.mkv',
        );
        expect(movie.size, fixture.fileBytes.length);
        expect(movie.attributes['etag'], 'sig1');
        expect(
          listing.entries
              .singleWhere((entry) => entry.name == '.hidden')
              .isHidden,
          isTrue,
        );

        await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/media'),
          refresh: true,
        );
        expect(fixture.listRequests.last['refresh'], true);
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('resolveAccess 返回同源 /d/ 直连地址与认证头', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-access');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture, path: '/'),
      );
      try {
        final access = await source.resolveAccess(
          FilePath(sourceId: sourceId, value: '/media/movie.mkv'),
        );
        expect(access.uri, isNotNull);
        expect(access.uri!.path, '/d/media/movie.mkv');
        expect(access.uri!.queryParameters['sign'], 'sig1');
        expect(access.headers['Authorization'], startsWith('token-'));
        expect(access.size, fixture.fileBytes.length);
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('openRange 透传 Range 并校验 206 响应', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-range');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture, path: '/'),
      );
      try {
        final path = FilePath(sourceId: sourceId, value: '/media/movie.mkv');
        final stream = await source.openRange(path, offset: 7, length: 9);
        expect(
          await stream.expand((chunk) => chunk).toList(),
          fixture.fileBytes.sublist(7, 16),
        );
        expect(fixture.ranges, contains('bytes=7-15'));

        await expectLater(
          source.openRange(path, offset: fixture.fileBytes.length, length: 1),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('区间超出文件范围'),
            ),
          ),
        );
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('服务忽略 Range 时抛出 UnsupportedError 供代理回退', () async {
      final fixture = await _OpenListFixture.start()..ignoreRange = true;
      final sourceId = SourceId.of('openlist-no-range');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture, path: '/'),
      );
      try {
        await expectLater(
          source.openRange(
            FilePath(sourceId: sourceId, value: '/media/movie.mkv'),
            offset: 4,
            length: 6,
          ),
          throwsA(isA<UnsupportedError>()),
        );
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('upload 非覆盖模式下目标已存在时抛出 already_exists', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-upload');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture, path: '/'),
      );
      try {
        await expectLater(
          source.upload(
            FileUploadRequest(
              destination: FilePath(
                sourceId: sourceId,
                value: '/media/movie.mkv',
              ),
              data: Stream<List<int>>.value(const [1, 2, 3]),
              length: 3,
            ),
          ),
          throwsA(
            isA<FileSourceException>().having(
              (error) => error.code,
              'code',
              'already_exists',
            ),
          ),
        );
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('变更操作映射到对应的 API 请求体', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-mutation');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture, path: '/'),
      );
      try {
        await source.createDirectory(
          FilePath(sourceId: sourceId, value: '/media'),
          'newdir',
        );
        await source.rename(
          FilePath(sourceId: sourceId, value: '/media/movie.mkv'),
          'renamed.mkv',
        );
        await source.move(
          FilePath(sourceId: sourceId, value: '/media/movie.mkv'),
          FilePath(sourceId: sourceId, value: '/movies2/movie.mkv'),
        );
        await source.delete(
          FilePath(sourceId: sourceId, value: '/media/movie.mkv'),
        );

        final mutations = {
          for (final (api, body) in fixture.mutationRequests)
            api: body,
        };
        expect(mutations['/api/fs/mkdir'], {
          'path': '/media/newdir',
        });
        expect(mutations['/api/fs/rename'], {
          'path': '/media/movie.mkv',
          'name': 'renamed.mkv',
        });
        expect(mutations['/api/fs/move'], {
          'src_dir': '/media',
          'dst_dir': '/movies2',
          'names': ['movie.mkv'],
        });
        expect(mutations['/api/fs/remove'], {
          'dir': '/media',
          'names': ['movie.mkv'],
        });
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });
  });
}

OpenListConnectionOptions _options(
  _OpenListFixture fixture, {
  String path = '/',
}) {
  return OpenListConnectionOptions(
    uri: fixture.baseUri.toString(),
    port: fixture.server.port,
    path: path,
    user: 'alice',
    password: 'secret',
  );
}

class _OpenListFixture {
  _OpenListFixture(this.server, {required this.requireAuth});

  final HttpServer server;
  final bool requireAuth;

  final validTokens = <String>{};
  var loginCount = 0;
  var wrongPassword = false;
  final loginBodies = <Map<String, dynamic>>[];
  final listRequests = <Map<String, dynamic>>[];
  final listAuthHeaders = <String?>[];
  final getRequests = <Map<String, dynamic>>[];
  final mutationRequests = <(String, Map<String, dynamic>)>[];
  final uploadRequests = <({String path, List<int> bytes})>[];
  final ranges = <String>[];
  final downloadAuthHeaders = <String?>[];
  final downloadUserAgents = <String?>[];

  List<Map<String, dynamic>> directoryEntries = [
    {'name': 'movies', 'is_dir': true, 'size': 0, 'modified': '2026-01-02T03:04:05Z', 'sign': ''},
    {
      'name': 'movie.mkv',
      'is_dir': false,
      'size': 64,
      'modified': '2026-01-02T03:04:05Z',
      'sign': 'sig1',
    },
    {'name': '.hidden', 'is_dir': false, 'size': 1, 'modified': '2026-01-02T03:04:05Z', 'sign': ''},
  ];
  List<int> fileBytes = List<int>.generate(64, (index) => index);
  final statOverrides = <String, Map<String, dynamic>>{};
  bool ignoreRange = false;

  Uri get baseUri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.host,
    port: server.port,
    path: '/',
  );

  static Future<_OpenListFixture> start({bool requireAuth = true}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _OpenListFixture(server, requireAuth: requireAuth);
    server.listen((request) {
      fixture._handle(request);
    });
    return fixture;
  }

  void expireTokens() => validTokens.clear();

  bool _authorized(HttpRequest request) {
    final token = request.headers.value(HttpHeaders.authorizationHeader);
    if (token == null) return !requireAuth;
    return validTokens.contains(token);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;
    try {
      if (request.method == 'POST' && path == '/api/auth/login') {
        final body = await _readJsonBody(request);
        loginBodies.add(body);
        loginCount += 1;
        if (wrongPassword ||
            body['username'] != 'alice' ||
            body['password'] != 'secret') {
          await _writeEnvelope(response, 400, 'wrong username or password');
          return;
        }
        final token = 'token-$loginCount';
        validTokens.add(token);
        await _writeEnvelope(response, 200, 'success', data: {'token': token});
        return;
      }

      if (request.method == 'PUT' && path == '/api/fs/put') {
        if (requireAuth && !_authorized(request)) {
          await _writeEnvelope(response, 401, 'token is expired');
          return;
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in request) {
          builder.add(chunk);
        }
        uploadRequests.add((
          path: request.headers.value('file-path') ?? '',
          bytes: builder.takeBytes(),
        ));
        await _writeEnvelope(response, 200, 'success');
        return;
      }

      if (request.method == 'POST' && path.startsWith('/api/fs/')) {
        if (!_authorized(request)) {
          await _writeEnvelope(response, 401, 'token is expired');
          return;
        }
        final body = await _readJsonBody(request);
        if (path == '/api/fs/list') {
          listRequests.add(body);
          listAuthHeaders.add(
            request.headers.value(HttpHeaders.authorizationHeader),
          );
          await _handleList(body, response);
          return;
        }
        if (path == '/api/fs/get') {
          getRequests.add(body);
          await _handleGet(body, response);
          return;
        }
        mutationRequests.add((path, body));
        await _writeEnvelope(response, 200, 'success');
        return;
      }

      if (request.method == 'GET' && path.startsWith('/d/')) {
        downloadAuthHeaders.add(
          request.headers.value(HttpHeaders.authorizationHeader),
        );
        downloadUserAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
        if (!_authorized(request) &&
            request.uri.queryParameters['sign'] != 'sig1') {
          response.statusCode = HttpStatus.unauthorized;
          await response.close();
          return;
        }
        await _serveBytes(request, response, fileBytes);
        return;
      }

      if (request.method == 'GET' && path.startsWith('/raw/')) {
        await _serveBytes(request, response, fileBytes, allowRange: false);
        return;
      }

      response.statusCode = HttpStatus.notFound;
      await response.close();
    } catch (_) {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleList(
    Map<String, dynamic> body,
    HttpResponse response,
  ) async {
    final page = (body['page'] as num?)?.toInt() ?? 1;
    final perPage = (body['per_page'] as num?)?.toInt() ?? 0;
    final total = directoryEntries.length;
    final start = (page - 1) * perPage;
    final hasMore = start + perPage < total;
    final content = start >= total
        ? null
        : directoryEntries.sublist(
            start,
            (start + perPage).clamp(0, total),
          );
    await _writeEnvelope(response, 200, 'success', data: {
      'content': content,
      'total': total,
      'page': page,
      'per_page': perPage,
      'has_more': hasMore,
      'readme': '',
      'header': '',
      'write': true,
      'provider': 'Local',
    });
  }

  Future<void> _handleGet(
    Map<String, dynamic> body,
    HttpResponse response,
  ) async {
    final path = body['path']?.toString() ?? '';
    final override = statOverrides[path];
    if (override != null) {
      await _writeEnvelope(response, 200, 'success', data: override);
      return;
    }
    if (path == '/' || path == '/media') {
      await _writeEnvelope(response, 200, 'success', data: {
        'name': path == '/' ? '/' : 'media',
        'is_dir': true,
        'size': 0,
        'modified': '2026-01-02T03:04:05Z',
        'sign': '',
        'raw_url': '',
        'header': '',
        'provider': 'Local',
      });
      return;
    }
    if (path == '/media/movie.mkv') {
      await _writeEnvelope(response, 200, 'success', data: {
        'name': 'movie.mkv',
        'is_dir': false,
        'size': fileBytes.length,
        'modified': '2026-01-02T03:04:05Z',
        'sign': 'sig1',
        'raw_url': '',
        'header': '',
        'provider': 'Local',
      });
      return;
    }
    await _writeEnvelope(
      response,
      500,
      'failed get object info: object not found',
    );
  }

  Future<void> _serveBytes(
    HttpRequest request,
    HttpResponse response,
    List<int> bytes, {
    bool allowRange = true,
  }) async {
    final range = allowRange
        ? request.headers.value(HttpHeaders.rangeHeader)
        : null;
    if (range == null) {
      response.statusCode = HttpStatus.ok;
      response.headers.contentLength = bytes.length;
      response.add(bytes);
      await response.close();
      return;
    }
    ranges.add(range);
    if (ignoreRange) {
      response.statusCode = HttpStatus.ok;
      response.headers.contentLength = bytes.length;
      response.add(bytes);
      await response.close();
      return;
    }
    final match = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range);
    final start = int.tryParse(match?.group(1) ?? '');
    final end = int.tryParse(match?.group(2) ?? '');
    if (start == null ||
        end == null ||
        start < 0 ||
        start >= bytes.length ||
        end < start) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */${bytes.length}',
      );
      await response.close();
      return;
    }
    final boundedEnd = end.clamp(start, bytes.length - 1).toInt();
    response.statusCode = HttpStatus.partialContent;
    response.headers.contentLength = boundedEnd - start + 1;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$boundedEnd/${bytes.length}',
    );
    response.add(bytes.sublist(start, boundedEnd + 1));
    await response.close();
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  Future<void> _writeEnvelope(
    HttpResponse response,
    int code,
    String message, {
    Object? data,
  }) async {
    response.headers.contentType = ContentType.json;
    response.write(
      jsonEncode({
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      }),
    );
    await response.close();
  }

  Future<void> close() => server.close(force: true);
}
