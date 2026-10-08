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

  test('同一来源切换服务器地址不会复用旧音乐文件', () async {
    final root = await Directory.systemTemp.createTemp('music-endpoint-');
    addTearDown(() => root.delete(recursive: true));
    final service = MusicCacheService(rootDirectory: root);
    const sourceId = SourceId('same-source');
    const path = FilePath(sourceId: sourceId, value: 'song.mp3');
    final firstSource = _MemoryFileSource(
      sourceId,
      files: {
        'song.mp3': [1, 2],
      },
      endpoint: 'smb://old/music',
    );
    final first = service.acquire(
      repository: FileSourceRepository(firstSource),
      path: path,
      size: 2,
      pathExtension: 'mp3',
    );
    final firstFile = await first.file;
    first.release();
    final nextSource = _MemoryFileSource(
      sourceId,
      files: {
        'song.mp3': [3, 4],
      },
      endpoint: 'smb://new/music',
    );
    final next = service.acquire(
      repository: FileSourceRepository(nextSource),
      path: path,
      size: 2,
      pathExtension: 'mp3',
    );
    final nextFile = await next.file;
    expect(nextFile.path, isNot(firstFile.path));
    expect(await nextFile.readAsBytes(), [3, 4]);
    next.release();
    expect(nextSource.downloadCount, 1);
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

  test('未知大小音乐的空缓存会重建，空响应不保留为有效缓存', () async {
    final root = await Directory.systemTemp.createTemp('empty-music-cache-');
    addTearDown(() => root.delete(recursive: true));
    final source = _MemoryFileSource(
      const SourceId('empty-source'),
      files: {
        'song.mp3': [1, 2],
      },
    );
    final service = MusicCacheService(rootDirectory: root);
    final repository = FileSourceRepository(source);
    const path = FilePath(
      sourceId: SourceId('empty-source'),
      value: 'song.mp3',
    );
    MusicCacheLease acquire() => service.acquire(
      repository: repository,
      path: path,
      pathExtension: 'mp3',
    );
    final first = acquire();
    final file = await first.file;
    first.release();
    await file.writeAsBytes([]);
    final rebuilt = acquire();
    expect(await (await rebuilt.file).readAsBytes(), [1, 2]);
    rebuilt.release();
    expect(source.downloadCount, 2);
    await file.delete();
    source.files['song.mp3'] = [];
    final empty = acquire();
    await expectLater(empty.file, throwsA(isA<StateError>()));
    empty.release();
    expect(await service.usage(), 0);
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
    // 一次手动清理后，正在播放的文件应在释放时自动删除。
    await service.usage();
    expect(await file.exists(), isFalse);
  });
}

class _MemoryFileSource implements FileSource, FileTransferCapability {
  _MemoryFileSource(
    this.sourceId, {
    required this.files,
    this.failAfterFirstChunk = false,
    this.endpoint,
  });

  final SourceId sourceId;
  final Map<String, List<int>> files;
  final bool failAfterFirstChunk;
  final String? endpoint;
  var downloadCount = 0;

  @override
  SourceDescriptor get descriptor => SourceDescriptor(
    id: sourceId,
    kind: SourceKind.smb,
    name: '测试音乐来源',
    endpoint: endpoint,
  );

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
