import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_capabilities.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_source.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';
import 'package:omm/features/files/file_playback_proxy.dart';

void main() {
  test('文件播放器代理按流转发文件并支持 Range', () async {
    final sourceId = SourceId.of('proxy-source');
    final bytes = List<int>.generate(12, (index) => index + 1);
    final source = _StreamFileSource(sourceId, bytes);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(source),
      path: FilePath(sourceId: sourceId, value: '影片.mkv'),
      size: bytes.length,
      mimeType: 'video/x-matroska',
      pathExtension: 'mkv',
    );
    final client = HttpClient();
    try {
      final fullRequest = await client.getUrl(proxy.uri);
      expect(proxy.uri.path, endsWith('.mkv'));
      final fullResponse = await fullRequest.close();
      final fullBody = await _read(fullResponse);
      expect(fullResponse.statusCode, HttpStatus.ok);
      expect(fullResponse.contentLength, bytes.length);
      expect(fullBody, bytes);

      final rangeRequest = await client.getUrl(proxy.uri);
      rangeRequest.headers.set('range', 'bytes=2-5');
      final rangeResponse = await rangeRequest.close();
      final rangeBody = await _read(rangeResponse);
      expect(rangeResponse.statusCode, HttpStatus.partialContent);
      expect(rangeResponse.contentLength, 4);
      expect(rangeBody, bytes.sublist(2, 6));
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('文件播放器代理把 Range 转发给随机读取来源', () async {
    final sourceId = SourceId.of('range-source');
    final bytes = List<int>.generate(32, (index) => index + 1);
    final source = _RangeStreamFileSource(sourceId, bytes);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(source),
      path: FilePath(sourceId: sourceId, value: '影片.mp4'),
      size: bytes.length,
      mimeType: 'video/mp4',
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(proxy.uri);
      request.headers.set('range', 'bytes=10-15');
      final response = await request.close();
      final body = await _read(response);
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.contentLength, 6);
      expect(body, bytes.sublist(10, 16));
      expect(source.ranges, [(10, 6)]);
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('文件播放器代理拒绝越界 Range', () async {
    final sourceId = SourceId.of('invalid-range-source');
    final bytes = List<int>.generate(8, (index) => index);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(_StreamFileSource(sourceId, bytes)),
      path: FilePath(sourceId: sourceId, value: '影片.mp4'),
      size: bytes.length,
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(proxy.uri);
      request.headers.set('range', 'bytes=8-');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(response.headers.value('content-range'), 'bytes */8');
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });
}

Future<List<int>> _read(HttpClientResponse response) async {
  final bytes = <int>[];
  await for (final chunk in response) {
    bytes.addAll(chunk);
  }
  return bytes;
}

class _StreamFileSource implements FileSource, FileAccessCapability {
  _StreamFileSource(this.sourceId, this.bytes);

  final SourceId sourceId;
  final List<int> bytes;

  @override
  SourceDescriptor get descriptor =>
      SourceDescriptor(id: sourceId, kind: SourceKind.smb, name: '测试文件来源');

  @override
  Set<FileCapability> get capabilities => const {FileCapability.access};

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Future<FileAccess> resolveAccess(FilePath path) async => FileAccess(
    size: bytes.length,
    mimeType: 'video/x-matroska',
    openStream: () => Stream<List<int>>.value(bytes),
  );
}

class _RangeStreamFileSource extends _StreamFileSource
    implements FileRangeAccessCapability {
  _RangeStreamFileSource(super.sourceId, super.bytes);

  final ranges = <(int, int)>[];

  @override
  Future<Stream<List<int>>> openRange(
    FilePath path, {
    required int offset,
    required int length,
    FileTransferOptions options = const FileTransferOptions(),
  }) async {
    ranges.add((offset, length));
    return Stream<List<int>>.value(bytes.sublist(offset, offset + length));
  }
}
