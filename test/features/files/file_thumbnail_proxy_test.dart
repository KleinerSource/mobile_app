import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_capabilities.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_operation.dart';
import 'package:omm/core/sources/files/file_source.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';
import 'package:omm/core/sources/files/webdav_file_source.dart';
import 'package:omm/features/files/file_playback_proxy.dart';
import 'package:webdav_client/webdav_client.dart' as dav;

const _id = SourceId('nas');
const _path = FilePath(sourceId: _id, value: '/目录/电影.mp4');

Future<FilePlaybackProxy> _proxy(
  FileSource source, {
  int? size = 20,
  int budget = 64 * 1024 * 1024,
}) => FilePlaybackProxy.start(
  repository: FileSourceRepository(source),
  path: _path,
  size: size,
  thumbnailPolicy: FileThumbnailReadPolicy(maxBytes: budget),
);

Future<List<int>> _read(HttpClient client, Uri uri, {String? range}) async {
  final request = await client.getUrl(uri);
  if (range != null) request.headers.set('range', range);
  final response = await request.close();
  if (response.statusCode >= 400) throw HttpException('${response.statusCode}');
  return response.fold<List<int>>([], (all, bytes) => all..addAll(bytes));
}

void main() {
  test('普通GET和随机定位都只通过openRange，HEAD不读取视频字节', () async {
    final source = _RangeSource();
    final proxy = await _proxy(source);
    final client = HttpClient();
    try {
      final head = await (await client.headUrl(proxy.uri)).close();
      expect(head.contentLength, 20);
      await head.drain<void>();
      expect(source.ranges, isEmpty);
      expect(await _read(client, proxy.uri), List.generate(20, (i) => i));
      expect(await _read(client, proxy.uri, range: 'bytes=10-14'), [
        10,
        11,
        12,
        13,
        14,
      ]);
      expect(source.ranges, [(0, 20), (10, 5)]);
      expect(source.downloads, 0);
    } finally {
      client.close(force: true);
      await proxy.close();
    }
  });

  test('未知大小和不支持区间读取均不完整下载', () async {
    for (final unknown in [false, true]) {
      final source = _RangeSource()..unsupported = true;
      final proxy = await _proxy(source, size: unknown ? null : 20);
      final client = HttpClient();
      try {
        await expectLater(_read(client, proxy.uri), throwsA(isA<Exception>()));
        expect(source.downloads, 0);
      } finally {
        client.close(force: true);
        await proxy.close();
      }
    }
  });

  test('多条请求共享读取额度，超限终止且不下载整文件', () async {
    final source = _RangeSource();
    final proxy = await _proxy(source, budget: 10);
    final client = HttpClient();
    try {
      expect(await _read(client, proxy.uri, range: 'bytes=0-5'), [
        0,
        1,
        2,
        3,
        4,
        5,
      ]);
      await expectLater(
        _read(client, proxy.uri, range: 'bytes=6-15'),
        throwsA(isA<Exception>()),
      );
      expect(source.ranges.fold<int>(0, (sum, range) => sum + range.$2), 10);
      expect(source.downloads, 0);
    } finally {
      client.close(force: true);
      await proxy.close();
    }
  });

  test('关闭代理取消正在读取的任务，不关闭文件来源', () async {
    final source = _RangeSource()..block = true;
    final proxy = await _proxy(source);
    final client = HttpClient();
    final response = _read(client, proxy.uri);
    final expectClosed = expectLater(response, throwsA(isA<Exception>()));
    await source.started.future;
    await proxy.close();
    await expectClosed;
    expect(source.token!.isCancelled, isTrue);
    expect(source.downloads, 0);
    client.close(force: true);
  });

  for (final ignoreRange in [false, true]) {
    test('真实WebDAV鉴权与Range响应：忽略Range=$ignoreRange', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String?>[];
      final auth = <String?>[];
      server.listen((request) async {
        requests.add(request.headers.value('range'));
        auth.add(request.headers.value('authorization'));
        if (auth.last == null) {
          request.response.statusCode = 401;
          request.response.headers.set(
            'www-authenticate',
            'Basic realm="test"',
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = ignoreRange ? 200 : 206;
        request.response.headers.set('content-range', 'bytes 5-9/20');
        request.response.contentLength = ignoreRange ? 20 : 5;
        request.response.add(
          ignoreRange ? List.generate(20, (i) => i) : [5, 6, 7, 8, 9],
        );
        await request.response.close();
      });
      final url = 'http://${server.address.host}:${server.port}';
      final clientDav = dav.newClient(url, user: 'alice', password: 'secret');
      final source = WebDavFileSource(
        client: clientDav,
        sourceId: _id,
        descriptor: const SourceDescriptor(
          id: _id,
          kind: SourceKind.webDav,
          name: 'test',
        ),
        connection: WebDavConnectionOptions(
          uri: url,
          port: server.port,
          user: 'alice',
          password: 'secret',
        ),
      );
      final proxy = await _proxy(source);
      final client = HttpClient();
      try {
        if (ignoreRange) {
          await expectLater(
            _read(client, proxy.uri, range: 'bytes=5-9'),
            throwsA(isA<Exception>()),
          );
        } else {
          expect(await _read(client, proxy.uri, range: 'bytes=5-9'), [
            5,
            6,
            7,
            8,
            9,
          ]);
        }
        expect(requests, ['bytes=5-9', 'bytes=5-9']);
        expect(auth.last, startsWith('Basic '));
      } finally {
        client.close(force: true);
        await proxy.close();
        await source.dispose();
        await server.close(force: true);
      }
    });
  }
}

class _RangeSource
    implements FileSource, FileRangeAccessCapability, FileTransferCapability {
  bool unsupported = false;
  bool block = false;
  int downloads = 0;
  FileCancellationToken? token;
  final started = Completer<void>();
  final ranges = <(int, int)>[];
  @override
  SourceDescriptor get descriptor =>
      const SourceDescriptor(id: _id, kind: SourceKind.smb, name: 'SMB');
  @override
  Set<FileCapability> get capabilities => {FileCapability.transfer};
  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);
  @override
  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  }) {
    downloads++;
    return Stream.value(List.generate(20, (i) => i));
  }

  @override
  Future<void> upload(FileUploadRequest request) async {}
  @override
  Future<Stream<List<int>>> openRange(
    FilePath path, {
    required int offset,
    required int length,
    FileTransferOptions options = const FileTransferOptions(),
  }) async {
    if (unsupported) throw UnsupportedError('Range');
    ranges.add((offset, length));
    token = options.cancellation;
    if (!started.isCompleted) started.complete();
    if (block) {
      await token!.whenCancelled;
      throw StateError('cancelled');
    }
    return Stream.value(List.generate(length, (i) => offset + i));
  }
}
