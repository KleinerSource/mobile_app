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
import 'package:omm/features/cache/music_cache.dart';

void main() {
  test('首次下载后再次获取命中独立音乐缓存', () async {
    final root = await Directory.systemTemp.createTemp('omm-music-cache-');
    addTearDown(() => root.delete(recursive: true));
    final source = _MemoryFileSource(
      SourceId.of('music-cache-source'),
      files: {
        'music/song.mp3': [1, 2, 3],
      },
    );
    final repository = FileSourceRepository(source);
    final service = MusicCacheService(rootDirectory: root);
    final path = FilePath(sourceId: source.sourceId, value: 'music/song.mp3');

    final first = service.acquire(
      repository: repository,
      path: path,
      size: 3,
      pathExtension: 'mp3',
    );
    final firstFile = await first.file;
    first.release();

    final second = service.acquire(
      repository: repository,
      path: path,
      size: 3,
      pathExtension: 'mp3',
    );
    expect((await second.file).path, firstFile.path);
    second.release();
    expect(source.downloadCount, 1);
    expect(await service.usage(), 3);
  });

  test('同一音乐的并发获取只下载一次', () async {
    final root = await Directory.systemTemp.createTemp('omm-music-cache-');
    addTearDown(() => root.delete(recursive: true));
    final source = _MemoryFileSource(
      SourceId.of('music-cache-concurrent-source'),
      files: {
        'song.flac': [4, 5, 6, 7],
      },
    );
    final repository = FileSourceRepository(source);
    final service = MusicCacheService(rootDirectory: root);
    final path = FilePath(sourceId: source.sourceId, value: 'song.flac');

    final first = service.acquire(
      repository: repository,
      path: path,
      size: 4,
      pathExtension: 'flac',
    );
    final second = service.acquire(
      repository: repository,
      path: path,
      size: 4,
      pathExtension: 'flac',
    );
    expect(await Future.wait([first.file, second.file]), hasLength(2));
    first.release();
    second.release();
    expect(source.downloadCount, 1);
  });

  test('下载失败会删除未完成的 part 文件', () async {
    final root = await Directory.systemTemp.createTemp('omm-music-cache-');
    addTearDown(() => root.delete(recursive: true));
    final source = _MemoryFileSource(
      SourceId.of('music-cache-failure-source'),
      files: {
        'song.mp3': [8, 9],
      },
      failAfterFirstChunk: true,
    );
    final service = MusicCacheService(rootDirectory: root);
    final repository = FileSourceRepository(source);
    final path = FilePath(sourceId: source.sourceId, value: 'song.mp3');
    final lease = service.acquire(
      repository: repository,
      path: path,
      pathExtension: 'mp3',
    );

    await expectLater(lease.file, throwsA(isA<StateError>()));
    lease.release();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}omm_music_cache',
    );
    expect(
      await directory
          .list()
          .where((entity) => entity.path.endsWith('.part'))
          .isEmpty,
      isTrue,
    );
  });

  test('清理时保护仍被使用的音乐缓存', () async {
    final root = await Directory.systemTemp.createTemp('omm-music-cache-');
    addTearDown(() => root.delete(recursive: true));
    final source = _MemoryFileSource(
      SourceId.of('music-cache-clear-source'),
      files: {
        'song.mp3': [10, 11],
      },
    );
    final service = MusicCacheService(rootDirectory: root);
    final repository = FileSourceRepository(source);
    final path = FilePath(sourceId: source.sourceId, value: 'song.mp3');
    final lease = service.acquire(
      repository: repository,
      path: path,
      size: 2,
      pathExtension: 'mp3',
    );
    final file = await lease.file;

    await service.clear();
    expect(await file.exists(), isTrue);
    lease.release();
    await service.clear();
    expect(await file.exists(), isFalse);
  });
}

class _MemoryFileSource implements FileSource, FileTransferCapability {
  _MemoryFileSource(
    this.sourceId, {
    required this.files,
    this.failAfterFirstChunk = false,
  });

  final SourceId sourceId;
  final Map<String, List<int>> files;
  final bool failAfterFirstChunk;
  var downloadCount = 0;

  @override
  SourceDescriptor get descriptor =>
      SourceDescriptor(id: sourceId, kind: SourceKind.smb, name: '测试音乐来源');

  @override
  Set<FileCapability> get capabilities => const {FileCapability.transfer};

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  }) async* {
    downloadCount++;
    final bytes = files[path.value];
    if (bytes == null) throw StateError('文件不存在');
    yield bytes.sublist(0, bytes.length > 1 ? 1 : bytes.length);
    if (failAfterFirstChunk) throw StateError('模拟下载失败');
    if (bytes.length > 1) yield bytes.sublist(1);
  }

  @override
  Future<void> upload(FileUploadRequest request) async {}
}
