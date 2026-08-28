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
    );
    final client = HttpClient();
    try {
      final fullRequest = await client.getUrl(proxy.uri);
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
