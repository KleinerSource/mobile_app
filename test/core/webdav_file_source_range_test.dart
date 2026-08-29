import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';
import 'package:omm/core/sources/files/webdav_file_source.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/features/files/file_playback_proxy.dart';

void main() {
  test('WebDAV 文件访问暴露可直接播放的 HTTP URL 和认证头', () async {
    final bytes = List<int>.generate(8, (index) => index);
    final fixture = await _WebDavFixture.start(bytes);
    final sourceId = SourceId.of('webdav-direct');
    final source = await WebDavFileSource.connect(
      id: sourceId.value,
      name: '测试 WebDAV',
      options: WebDavConnectionOptions(
        uri: fixture.baseUri.replace(path: '/dav/').toString(),
        port: fixture.server.port,
        user: 'alice',
        password: 'secret',
      ),
    );
    try {
      final access = await source.resolveAccess(
        FilePath(sourceId: sourceId, value: '/movie.mp4'),
      );
      expect(
        access.uri,
        fixture.baseUri.replace(path: '/dav/movie.mp4'),
      );
      expect(access.size, bytes.length);
      expect(access.mimeType, 'video/mp4');
      expect(access.headers['Authorization'], 'Basic YWxpY2U6c2VjcmV0');
    } finally {
      await source.dispose();
      await fixture.close();
    }
  });

  test('WebDAV Range 请求透传并校验 206 响应', () async {
    final bytes = List<int>.generate(32, (index) => index + 1);
    final fixture = await _WebDavFixture.start(bytes);
    final sourceId = SourceId.of('webdav-range');
    final source = await WebDavFileSource.connect(
      id: sourceId.value,
      name: '测试 WebDAV',
      options: WebDavConnectionOptions(
        uri: fixture.baseUri.toString(),
        port: fixture.server.port,
      ),
    );
    try {
      final path = FilePath(sourceId: sourceId, value: '/movie.mp4');
      final stream = await source.openRange(path, offset: 7, length: 9);
      expect(
        await stream.expand((chunk) => chunk).toList(),
        bytes.sublist(7, 16),
      );
      expect(fixture.ranges, ['bytes=7-15']);

      await expectLater(
        source.openRange(path, offset: bytes.length, length: 1),
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

  test('WebDAV 忽略 Range 时代理回退到临时文件', () async {
    final bytes = List<int>.generate(24, (index) => 255 - index);
    final fixture = await _WebDavFixture.start(bytes, ignoreRange: true);
    final sourceId = SourceId.of('webdav-fallback');
    final source = await WebDavFileSource.connect(
      id: sourceId.value,
      name: '测试 WebDAV',
      options: WebDavConnectionOptions(
        uri: fixture.baseUri.toString(),
        port: fixture.server.port,
      ),
    );
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(source),
      path: FilePath(sourceId: sourceId, value: '/movie.mp4'),
      size: bytes.length,
      mimeType: 'video/mp4',
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(proxy.uri);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=8-13');
      final response = await request.close();
      final body = <int>[];
      await for (final chunk in response) {
        body.addAll(chunk);
      }
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.contentLength, 6);
      expect(body, bytes.sublist(8, 14));
      expect(fixture.ranges, ['bytes=8-13']);
      expect(fixture.fullGets, 1);
    } finally {
      await proxy.close();
      client.close(force: true);
      await source.dispose();
      await fixture.close();
    }
  });
}

class _WebDavFixture {
  _WebDavFixture(this.server, this.bytes, {required this.ignoreRange});

  final HttpServer server;
  final List<int> bytes;
  final bool ignoreRange;
  final ranges = <String>[];
  var fullGets = 0;

  Uri get baseUri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.host,
    port: server.port,
    path: '/',
  );

  static Future<_WebDavFixture> start(
    List<int> bytes, {
    bool ignoreRange = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _WebDavFixture(server, bytes, ignoreRange: ignoreRange);
    server.listen(fixture._handle);
    return fixture;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }
    if (request.method == 'PROPFIND') {
      response.statusCode = 207;
      response.headers.contentType = ContentType('application', 'xml');
      response.write('''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/movie.mp4</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype/>
        <d:getcontentlength>${bytes.length}</d:getcontentlength>
        <d:getcontenttype>video/mp4</d:getcontenttype>
        <d:getetag>"fixture"</d:getetag>
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
        fullGets++;
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
      return;
    }
    response.statusCode = HttpStatus.methodNotAllowed;
    await response.close();
  }

  Future<void> close() => server.close(force: true);
}
