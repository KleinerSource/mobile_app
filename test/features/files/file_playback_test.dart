// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/files/file_playback_engine_test.dart
//   - test/features/files/file_playback_proxy_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_capabilities.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_operation.dart';
import 'package:omm/core/sources/files/file_source.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';
import 'package:omm/features/files/file_playback_engine.dart';
import 'package:omm/features/files/file_playback_proxy.dart';
import 'package:omm/features/player/common/playback_engine.dart';

// ==================== 原 test/features/files/file_playback_engine_test.dart ====================
void _main_0() {
  test('iOS SMB 默认使用 libmpv 读取回环代理', () {
    expect(
      filePlaybackEngineKind(sourceKind: SourceKind.smb, isIOS: true),
      PlaybackEngineKind.libmpv,
    );
  });

  test('iOS WebDAV 默认保留 KSPlayer 直连播放', () {
    expect(
      filePlaybackEngineKind(sourceKind: SourceKind.webDav, isIOS: true),
      PlaybackEngineKind.ksPlayer,
    );
  });

  test('iOS OpenList 与 WebDAV 一致默认保留 KSPlayer 直连播放', () {
    expect(
      filePlaybackEngineKind(sourceKind: SourceKind.openList, isIOS: true),
      PlaybackEngineKind.ksPlayer,
    );
  });

  test('调试模式手动选择优先于文件源默认内核', () {
    expect(
      filePlaybackEngineKind(
        sourceKind: SourceKind.smb,
        isIOS: true,
        requested: PlaybackEngineKind.ksPlayer,
      ),
      PlaybackEngineKind.ksPlayer,
    );
  });

  test('非 iOS 返回空以沿用播放设置和会话工厂默认值', () {
    expect(
      filePlaybackEngineKind(sourceKind: SourceKind.smb, isIOS: false),
      isNull,
    );
  });
}

// ==================== 原 test/features/files/file_playback_proxy_test.dart ====================
void _main_1() {
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

  test('M3U8 播放代理保留扩展名并返回 HLS MIME', () async {
    final sourceId = SourceId.of('m3u8-source');
    final bytes = List<int>.generate(6, (index) => index + 1);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(
        _DownloadOnlyFileSource(sourceId, bytes),
      ),
      path: FilePath(sourceId: sourceId, value: '直播.M3U8'),
      size: bytes.length,
      pathExtension: 'M3U8',
    );
    final client = HttpClient();
    try {
      expect(proxy.uri.path, endsWith('.m3u8'));
      final request = await client.getUrl(proxy.uri);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        response.headers.contentType?.mimeType,
        'application/vnd.apple.mpegurl',
      );
      expect(await _read(response), bytes);
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('音频播放代理支持 MIME、HEAD、完整读取和 Range 读取', () async {
    final sourceId = SourceId.of('audio-source');
    final bytes = List<int>.generate(24, (index) => index + 10);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(_RangeStreamFileSource(sourceId, bytes)),
      path: FilePath(sourceId: sourceId, value: '音乐.FLAC'),
      size: bytes.length,
      mimeType: 'audio/flac',
      pathExtension: 'flac',
    );
    final client = HttpClient();
    try {
      final headRequest = await client.openUrl('HEAD', proxy.uri);
      final headResponse = await headRequest.close();
      expect(headResponse.statusCode, HttpStatus.ok);
      expect(headResponse.contentLength, bytes.length);
      expect(headResponse.headers.contentType?.mimeType, 'audio/flac');
      expect(headResponse.headers.value('accept-ranges'), 'bytes');
      expect(await _read(headResponse), isEmpty);

      final fullRequest = await client.getUrl(proxy.uri);
      final fullResponse = await fullRequest.close();
      expect(fullResponse.statusCode, HttpStatus.ok);
      expect(await _read(fullResponse), bytes);

      final rangeRequest = await client.getUrl(proxy.uri);
      rangeRequest.headers.set('range', 'bytes=4-9');
      final rangeResponse = await rangeRequest.close();
      expect(rangeResponse.statusCode, HttpStatus.partialContent);
      expect(rangeResponse.contentLength, 6);
      expect(rangeResponse.headers.contentType?.mimeType, 'audio/flac');
      expect(await _read(rangeResponse), bytes.sublist(4, 10));
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
      final cases = <({String header, int start, int length})>[
        (header: 'Bytes=0-3', start: 0, length: 4),
        (header: 'bytes=10-15', start: 10, length: 6),
        (header: 'bytes=20-', start: 20, length: 12),
        (header: 'bytes=-5', start: 27, length: 5),
      ];
      for (final item in cases) {
        final request = await client.getUrl(proxy.uri);
        request.headers.set('range', item.header);
        final response = await request.close();
        final body = await _read(response);
        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.contentLength, item.length);
        expect(body, bytes.sublist(item.start, item.start + item.length));
      }
      expect(source.ranges, [(0, 4), (10, 6), (20, 12), (27, 5)]);
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('播放代理 GET 优先使用下载流，不依赖 stat/resolveAccess', () async {
    final sourceId = SourceId.of('download-only-source');
    final bytes = List<int>.generate(6, (index) => index + 30);
    final source = _DownloadOnlyFileSource(sourceId, bytes);
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
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(await _read(response), bytes);
      expect(source.resolveAccessCalls, 0);
      expect(source.downloadCalls, 1);
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('文件播放器代理的 HEAD 返回大小、MIME 和 Range 能力', () async {
    final sourceId = SourceId.of('head-source');
    final bytes = List<int>.generate(16, (index) => index);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(_RangeStreamFileSource(sourceId, bytes)),
      path: FilePath(sourceId: sourceId, value: '影片.mp4'),
      size: bytes.length,
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.openUrl('HEAD', proxy.uri);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, bytes.length);
      expect(response.headers.contentType?.mimeType, 'video/x-matroska');
      expect(response.headers.value('accept-ranges'), 'bytes');
      expect(await _read(response), isEmpty);
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

      final malformed = await client.getUrl(proxy.uri);
      malformed.headers.set('range', 'items=0-1');
      final malformedResponse = await malformed.close();
      expect(
        malformedResponse.statusCode,
        HttpStatus.requestedRangeNotSatisfiable,
      );
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('文件大小未知且元数据探测不到时落盘再响应 Range', () async {
    final sourceId = SourceId.of('unknown-size-source');
    final bytes = List<int>.generate(10, (index) => index + 10);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(_UnknownSizeFileSource(sourceId, bytes)),
      path: FilePath(sourceId: sourceId, value: '影片.mp4'),
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(proxy.uri);
      request.headers.set('range', 'bytes=4-6');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers.value('content-range'), 'bytes 4-6/10');
      expect(await _read(response), bytes.sublist(4, 7));
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('文件大小未知时优先探测元数据，避免整文件落盘', () async {
    final sourceId = SourceId.of('stat-range-source');
    final bytes = List<int>.generate(20, (index) => index + 40);
    final source = _StatOnlyRangeFileSource(sourceId, bytes);
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(source),
      path: FilePath(sourceId: sourceId, value: '影片.mp4'),
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(proxy.uri);
      request.headers.set('range', 'bytes=3-7');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers.value('content-range'), 'bytes 3-7/20');
      expect(await _read(response), bytes.sublist(3, 8));
      expect(source.ranges, [(3, 5)]);
      expect(source.openStreamCalls, 0);
    } finally {
      await proxy.close();
      client.close(force: true);
    }
  });

  test('文件播放器代理将上游解析错误转换为可识别的 HTTP 错误', () async {
    final sourceId = SourceId.of('error-source');
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(_FailingFileSource(sourceId)),
      path: FilePath(sourceId: sourceId, value: '影片.mp4'),
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(proxy.uri);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.notFound);
      expect(await _read(response), utf8.encode('视频流读取失败'));
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

class _DownloadOnlyFileSource
    implements FileSource, FileTransferCapability, FileAccessCapability {
  _DownloadOnlyFileSource(this.sourceId, this.bytes);

  final SourceId sourceId;
  final List<int> bytes;
  var resolveAccessCalls = 0;
  var downloadCalls = 0;

  @override
  SourceDescriptor get descriptor =>
      SourceDescriptor(id: sourceId, kind: SourceKind.smb, name: '仅下载来源');

  @override
  Set<FileCapability> get capabilities => const {
    FileCapability.transfer,
    FileCapability.access,
  };

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  }) {
    downloadCalls++;
    return Stream<List<int>>.value(bytes);
  }

  @override
  Future<void> upload(FileUploadRequest request) async {}

  @override
  Future<FileAccess> resolveAccess(FilePath path) {
    resolveAccessCalls++;
    return Future<FileAccess>.error(StateError('不应调用 stat'));
  }
}

class _FailingFileSource implements FileSource, FileAccessCapability {
  _FailingFileSource(this.sourceId);

  final SourceId sourceId;

  @override
  SourceDescriptor get descriptor =>
      SourceDescriptor(id: sourceId, kind: SourceKind.webDav, name: '错误来源');

  @override
  Set<FileCapability> get capabilities => const {FileCapability.access};

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Future<FileAccess> resolveAccess(FilePath path) => Future<FileAccess>.error(
    const FileSourceException('上游文件不存在', statusCode: 404),
  );
}

class _UnknownSizeFileSource extends _StreamFileSource {
  _UnknownSizeFileSource(super.sourceId, super.bytes);

  @override
  Future<FileAccess> resolveAccess(FilePath path) async => FileAccess(
    mimeType: 'video/mp4',
    openStream: () => Stream<List<int>>.value(bytes),
  );
}

class _StatOnlyRangeFileSource extends _StreamFileSource
    implements FileRangeAccessCapability {
  _StatOnlyRangeFileSource(super.sourceId, super.bytes);

  final ranges = <(int, int)>[];
  var openStreamCalls = 0;

  @override
  Future<FileAccess> resolveAccess(FilePath path) async => FileAccess(
    size: bytes.length,
    mimeType: 'video/mp4',
    openStream: () {
      openStreamCalls++;
      return Stream<List<int>>.value(bytes);
    },
  );

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

void main() {
  group('file_playback_engine', _main_0);
  group('file_playback_proxy', _main_1);
}
