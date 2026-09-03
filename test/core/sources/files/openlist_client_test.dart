// OpenList（AList v3 兼容）文件源测试。
// 文件管理走标准 WebDAV（PROPFIND/GET），REST API 仅用于强制刷新；
// fixture 同时模拟 /dav 的 WebDAV 响应与 /api 的信封响应。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/files/openlist_api.dart';
import 'package:omm/core/sources/sources.dart';

void main() {
  group('OpenListFileSource（WebDAV 管理 + REST 强制刷新）', () {
    test('登录后经 WebDAV 列目录，普通刷新不触发 REST API', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-list');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture),
      );
      try {
        final listing = await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/'),
        );
        expect(listing.currentPath.value, '/');
        expect(listing.entries.map((entry) => entry.name).toList(), [
          'movies',
          'movie.mkv',
        ]);
        final movie = listing.entries.singleWhere(
          (entry) => entry.name == 'movie.mkv',
        );
        expect(movie.size, fixture.fileBytes.length);
        expect(movie.attributes['etag'], '"sig1"');
        expect(fixture.loginBodies.single['username'], 'alice');
        expect(fixture.fsListRequests, isEmpty);
        expect(fixture.propfindPaths, isNotEmpty);
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('强制刷新先经 REST 通知服务端再走 WebDAV 列目录', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-refresh');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture),
      );
      try {
        final listing = await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/'),
          refresh: true,
        );
        expect(listing.entries, isNotEmpty);
        expect(fixture.fsListRequests.single['path'], '/');
        expect(fixture.fsListRequests.single['refresh'], true);
        expect(fixture.listAuthHeaders.single, startsWith('token-'));
        expect(fixture.propfindPaths, isNotEmpty);
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('根路径映射到实例内的 API 路径', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-root');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture, path: '/media'),
      );
      try {
        await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/'),
          refresh: true,
        );
        expect(fixture.fsListRequests.single['path'], '/media');

        await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/shows'),
          refresh: true,
        );
        expect(fixture.fsListRequests.last['path'], '/media/shows');
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('REST 刷新失败时降级为普通 WebDAV 列目录', () async {
      final fixture = await _OpenListFixture.start()
        ..failRefresh = true;
      final sourceId = SourceId.of('openlist-degrade');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture),
      );
      try {
        final listing = await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/'),
          refresh: true,
        );
        expect(listing.entries.map((entry) => entry.name), [
          'movies',
          'movie.mkv',
        ]);
        expect(fixture.fsListRequests.single['refresh'], true);
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('令牌过期时强制刷新自动重新登录', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-relogin');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture),
      );
      try {
        await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/'),
          refresh: true,
        );
        fixture.expireTokens();
        await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/'),
          refresh: true,
        );
        expect(fixture.loginCount, 2);
        expect(fixture.fsListRequests.length, 2);
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('游客模式不登录，刷新请求不带 Authorization', () async {
      final fixture = await _OpenListFixture.start(requireAuth: false);
      final sourceId = SourceId.of('openlist-guest');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: OpenListConnectionOptions(
          uri: fixture.davUri.toString(),
          port: fixture.server.port,
        ),
      );
      try {
        expect(fixture.loginCount, 0);
        final listing = await source.listDirectory(
          FilePath(sourceId: sourceId, value: '/'),
          refresh: true,
        );
        expect(listing.entries, isNotEmpty);
        expect(fixture.listAuthHeaders.single, isNull);
      } finally {
        await source.dispose();
        await fixture.close();
      }
    });

    test('密码错误时连接失败并给出业务错误', () async {
      final fixture = await _OpenListFixture.start()
        ..wrongPassword = true;
      try {
        await expectLater(
          OpenListFileSource.connect(
            id: 'openlist-bad',
            name: '测试 OpenList',
            options: _options(fixture),
          ),
          throwsA(
            isA<FileSourceException>().having(
              (error) => error.message,
              'message',
              allOf(contains('连接失败'), contains('wrong username or password')),
            ),
          ),
        );
      } finally {
        await fixture.close();
      }
    });

    test('Range 读取经 WebDAV 直链透传', () async {
      final fixture = await _OpenListFixture.start();
      final sourceId = SourceId.of('openlist-range');
      final source = await OpenListFileSource.connect(
        id: sourceId.value,
        name: '测试 OpenList',
        options: _options(fixture),
      );
      try {
        final stream = await source.openRange(
          FilePath(sourceId: sourceId, value: '/movie.mkv'),
          offset: 7,
          length: 9,
        );
        expect(
          await stream.expand((chunk) => chunk).toList(),
          fixture.fileBytes.sublist(7, 16),
        );
        expect(fixture.ranges, contains('bytes=7-15'));
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
    uri: fixture.davUri.toString(),
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
  var failRefresh = false;
  final loginBodies = <Map<String, dynamic>>[];
  final fsListRequests = <Map<String, dynamic>>[];
  final listAuthHeaders = <String?>[];
  final propfindPaths = <String>[];
  final ranges = <String>[];

  final fileBytes = List<int>.generate(64, (index) => index);

  Uri get baseUri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.host,
    port: server.port,
    path: '/',
  );

  Uri get davUri => baseUri.replace(path: '/dav');

  static Future<_OpenListFixture> start({bool requireAuth = true}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _OpenListFixture(server, requireAuth: requireAuth);
    server.listen((request) {
      fixture._handle(request);
    });
    return fixture;
  }

  void expireTokens() => validTokens.clear();

  bool _apiAuthorized(HttpRequest request) {
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

      if (request.method == 'POST' && path == '/api/fs/list') {
        if (!_apiAuthorized(request)) {
          await _writeEnvelope(response, 401, 'token is expired');
          return;
        }
        final body = await _readJsonBody(request);
        fsListRequests.add(body);
        listAuthHeaders.add(
          request.headers.value(HttpHeaders.authorizationHeader),
        );
        if (failRefresh) {
          await _writeEnvelope(response, 500, 'storage driver error');
          return;
        }
        await _writeEnvelope(
          response,
          200,
          'success',
          data: {
            'content': <Object?>[],
            'total': 0,
            'page': 1,
            'per_page': 1,
            'has_more': false,
          },
        );
        return;
      }

      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.ok;
        await response.close();
        return;
      }

      if (request.method == 'PROPFIND') {
        propfindPaths.add(path);
        response.statusCode = 207;
        response.headers.contentType = ContentType('application', 'xml');
        // webdav_client 假定首个 response 是集合自身并跳过，因此先输出
        // 请求目录，再输出子项（与真实服务器的 Depth:1 行为一致）。
        response.write('''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>$path</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/movies</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>movies</d:displayname>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/movie.mkv</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>movie.mkv</d:displayname>
        <d:resourcetype/>
        <d:getcontentlength>${fileBytes.length}</d:getcontentlength>
        <d:getetag>"sig1"</d:getetag>
        <d:getcontenttype>video/x-matroska</d:getcontenttype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>''');
        await response.close();
        return;
      }

      if (request.method == 'GET') {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        if (range == null) {
          response.statusCode = HttpStatus.ok;
          response.headers.contentLength = fileBytes.length;
          response.add(fileBytes);
          await response.close();
          return;
        }
        ranges.add(range);
        final match = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range);
        final start = int.tryParse(match?.group(1) ?? '');
        final end = int.tryParse(match?.group(2) ?? '');
        if (start == null ||
            end == null ||
            start < 0 ||
            start >= fileBytes.length ||
            end < start) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */${fileBytes.length}',
          );
          await response.close();
          return;
        }
        final boundedEnd = end.clamp(start, fileBytes.length - 1).toInt();
        response.statusCode = HttpStatus.partialContent;
        response.headers.contentLength = boundedEnd - start + 1;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$boundedEnd/${fileBytes.length}',
        );
        response.add(fileBytes.sublist(start, boundedEnd + 1));
        await response.close();
        return;
      }

      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
    } catch (_) {
      try {
        await response.close();
      } catch (_) {}
    }
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
