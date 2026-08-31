import 'dart:convert';
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
import 'package:omm/features/player/audio/file_audio_metadata_session.dart';
import 'package:omm/features/player/common/player_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('同名图片优先于 cover，LRC 只匹配同目录同名文件并在释放时清理', () async {
    final sourceId = SourceId.of('metadata-source');
    final source = _MemoryFileSource(
      sourceId,
      files: {
        'music/song.MP3': utf8.encode('not an audio file'),
        'music/song.PNG': [1, 2, 3],
        'music/cover.jpg': [4, 5, 6],
        'music/song.LRC': utf8.encode('[00:01.00]第一句'),
      },
    );
    final audio = _entry(sourceId, 'music/song.MP3');
    final entries = [
      audio,
      _entry(sourceId, 'music/song.PNG'),
      _entry(sourceId, 'music/cover.jpg'),
      _entry(sourceId, 'music/song.LRC'),
    ];
    final session = FileAudioMetadataSession(
      repository: FileSourceRepository(source),
      directoryEntries: entries,
    );

    final metadata = await session.load(
      PlayerQueueItem(
        title: audio.name,
        type: PlayerQueueItemType.audio,
        mediaId: audio.stableKey,
      ),
    );

    expect(metadata.artworkPath, isNotNull);
    final artwork = File(metadata.artworkPath!);
    expect(await artwork.readAsBytes(), [1, 2, 3]);
    expect(metadata.artworkMimeType, 'image/png');
    expect(metadata.lyrics?.cues.single.text, '第一句');

    await session.dispose();
    expect(await artwork.exists(), isFalse);
  });

  test('不支持的图片扩展名不会作为封面回退', () async {
    final sourceId = SourceId.of('unsupported-artwork-source');
    final source = _MemoryFileSource(
      sourceId,
      files: {
        'song.mp3': [0, 1, 2],
        'song.gif': [3, 4, 5],
      },
    );
    final audio = _entry(sourceId, 'song.mp3');
    final session = FileAudioMetadataSession(
      repository: FileSourceRepository(source),
      directoryEntries: [audio, _entry(sourceId, 'song.gif')],
    );

    final metadata = await session.load(
      PlayerQueueItem(
        title: audio.name,
        type: PlayerQueueItemType.audio,
        mediaId: audio.stableKey,
      ),
    );

    expect(metadata.artworkPath, isNull);
    await session.dispose();
  });

  test('内嵌元数据读取复用音乐缓存中的音频文件', () async {
    final root = await Directory.systemTemp.createTemp('omm-metadata-cache-');
    addTearDown(() => root.delete(recursive: true));
    final sourceId = SourceId.of('metadata-music-cache-source');
    final source = _MemoryFileSource(
      sourceId,
      files: {
        'song.mp3': [0, 1, 2],
      },
    );
    final audio = FileEntry(
      path: FilePath(sourceId: sourceId, value: 'song.mp3'),
      name: 'song.mp3',
      type: FileEntryType.file,
      size: 3,
    );
    final session = FileAudioMetadataSession(
      repository: FileSourceRepository(source),
      directoryEntries: [audio],
      musicCache: MusicCacheService(rootDirectory: root),
    );

    await session.load(
      PlayerQueueItem(
        title: audio.name,
        type: PlayerQueueItemType.audio,
        mediaId: audio.stableKey,
      ),
    );

    expect(source.downloadCount, 1);
    await session.dispose();
  });

  test('初始目录列表不完整时会补拉同目录歌词', () async {
    final sourceId = SourceId.of('metadata-directory-loader-source');
    final source = _MemoryFileSource(
      sourceId,
      files: {'music/song.LRC': utf8.encode('[00:01.00]补拉歌词')},
    );
    final audio = _entry(sourceId, 'music/song.mp3');
    var loadCount = 0;
    final session = FileAudioMetadataSession(
      repository: FileSourceRepository(source),
      directoryEntries: [audio],
      directoryEntriesLoader: () async {
        loadCount++;
        return [audio, _entry(sourceId, 'music/song.LRC')];
      },
    );

    final metadata = await session.load(
      PlayerQueueItem(
        title: audio.name,
        type: PlayerQueueItemType.audio,
        mediaId: audio.stableKey,
      ),
    );

    expect(loadCount, 1);
    expect(metadata.lyrics?.cues.single.text, '补拉歌词');
    await session.dispose();
  });
}

FileEntry _entry(SourceId sourceId, String path) {
  final name = path.split('/').last;
  return FileEntry(
    path: FilePath(sourceId: sourceId, value: path),
    name: name,
    type: FileEntryType.file,
  );
}

class _MemoryFileSource implements FileSource, FileTransferCapability {
  _MemoryFileSource(this.sourceId, {required this.files});

  final SourceId sourceId;
  final Map<String, List<int>> files;
  var downloadCount = 0;

  @override
  SourceDescriptor get descriptor =>
      SourceDescriptor(id: sourceId, kind: SourceKind.smb, name: '测试元数据来源');

  @override
  Set<FileCapability> get capabilities => const {FileCapability.transfer};

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  }) {
    downloadCount++;
    final bytes = files[path.value];
    if (bytes == null) return Stream<List<int>>.error(StateError('文件不存在'));
    return Stream<List<int>>.value(bytes);
  }

  @override
  Future<void> upload(FileUploadRequest request) async {}
}
