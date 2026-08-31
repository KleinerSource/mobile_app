import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/platform/app_log_store.dart';
import '../../../core/sources/files/file_entry.dart';
import '../../../core/sources/files/file_source_repository.dart';
import '../../cache/music_cache.dart';
import 'audio_metadata.dart';
import 'lrc_parser.dart';
import '../common/player_queue.dart';

class FileAudioMetadataSession {
  FileAudioMetadataSession({
    required FileSourceRepository repository,
    required Iterable<FileEntry> directoryEntries,
    Future<Iterable<FileEntry>> Function()? directoryEntriesLoader,
    MusicCacheService? musicCache,
  }) : _repository = repository,
       _directoryEntries = List<FileEntry>.unmodifiable(directoryEntries),
       _directoryEntriesLoader = directoryEntriesLoader,
       _musicCache = musicCache;

  final FileSourceRepository _repository;
  List<FileEntry> _directoryEntries;
  final Future<Iterable<FileEntry>> Function()? _directoryEntriesLoader;
  final MusicCacheService? _musicCache;
  final FileCancellationToken _cancellation = FileCancellationToken();
  Future<Iterable<FileEntry>>? _directoryEntriesFuture;
  final Map<String, Future<AudioTrackMetadata>> _cache = {};
  final Set<File> _ownedFiles = <File>{};
  final Set<MusicCacheLease> _musicCacheLeases = <MusicCacheLease>{};
  bool _disposed = false;

  /// 清理上一次进程异常退出后遗留的元数据临时文件。
  static Future<void> cleanupStaleCache({
    Duration maxAge = const Duration(hours: 12),
  }) async {
    try {
      final root = await _temporaryDirectory();
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}omm_audio_metadata',
      );
      if (!await directory.exists()) return;
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in directory.list()) {
        if (entity is! File ||
            !entity.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('omm_audio_')) {
          continue;
        }
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (error) {
          appLog('[AudioMetadata] 过期缓存清理失败: ${entity.path} $error');
        }
      }
    } catch (error, stackTrace) {
      appLog('[AudioMetadata] 过期缓存目录清理失败: $error\n$stackTrace');
    }
  }

  Future<AudioTrackMetadata> load(PlayerQueueItem item) {
    if (_disposed) {
      return Future.error(StateError('音频元数据会话已释放'));
    }
    final key = item.mediaId?.trim() ?? item.safeMediaId;
    return _cache.putIfAbsent(key, () => _loadItem(item));
  }

  Future<AudioTrackMetadata> _loadItem(PlayerQueueItem item) async {
    var entry = _findEntry(item);
    if (entry == null) return const AudioTrackMetadata();
    await _ensureDirectoryEntries();
    entry = _findEntry(item) ?? entry;

    String? artworkPath;
    String? artworkMimeType;
    String? artist;
    String? album;
    LrcDocument? lyrics;

    try {
      final embedded = await _readEmbeddedMetadata(entry);
      if (embedded != null) {
        artist = embedded.artist;
        album = embedded.album;
        if (embedded.pictureBytes != null &&
            embedded.pictureBytes!.isNotEmpty) {
          final file = await _writeOwnedFile(
            entry,
            embedded.pictureBytes!,
            suffix: _extensionForMime(embedded.pictureMimeType),
          );
          artworkPath = file.path;
          artworkMimeType = embedded.pictureMimeType;
        }
      }
    } catch (error, stackTrace) {
      appLog('[AudioMetadata] 内嵌元数据读取失败: ${entry.name} $error\n$stackTrace');
    }

    if (artworkPath == null) {
      final artworkEntry = _findArtworkEntry(entry);
      if (artworkEntry != null) {
        try {
          final file = await _copyRemoteFile(artworkEntry, prefix: 'art');
          artworkPath = file.path;
          artworkMimeType =
              artworkEntry.mimeType ?? _mimeForExtension(artworkEntry.name);
        } catch (error, stackTrace) {
          appLog(
            '[AudioMetadata] 回退封面读取失败: ${artworkEntry.name} $error\n$stackTrace',
          );
        }
      }
    }

    final lrcEntry = _findLrcEntry(entry);
    if (lrcEntry != null) {
      try {
        final bytes = await _readRemoteBytes(
          lrcEntry,
          maxBytes: 2 * 1024 * 1024,
        );
        lyrics = parseLrc(utf8.decode(bytes, allowMalformed: false));
      } catch (error, stackTrace) {
        appLog(
          '[AudioMetadata] LRC 读取失败: ${lrcEntry.name} $error\n$stackTrace',
        );
      }
    }

    return AudioTrackMetadata(
      artworkPath: artworkPath,
      artworkMimeType: artworkMimeType,
      artist: artist,
      album: album,
      lyrics: lyrics,
    );
  }

  Future<void> _ensureDirectoryEntries() async {
    final loader = _directoryEntriesLoader;
    if (loader == null) return;
    final current = _directoryEntriesFuture;
    if (current != null) {
      await current;
      return;
    }

    late final Future<Iterable<FileEntry>> next;
    next = loader();
    _directoryEntriesFuture = next;
    try {
      final loaded = await next;
      final merged = <String, FileEntry>{
        for (final entry in _directoryEntries) entry.stableKey: entry,
        for (final entry in loaded) entry.stableKey: entry,
      };
      _directoryEntries = List<FileEntry>.unmodifiable(merged.values);
    } catch (_) {
      if (identical(_directoryEntriesFuture, next)) {
        _directoryEntriesFuture = null;
      }
      rethrow;
    }
  }

  FileEntry? _findEntry(PlayerQueueItem item) {
    final key = item.mediaId?.trim();
    if (key == null || key.isEmpty) return null;
    for (final entry in _directoryEntries) {
      if (entry.stableKey == key) return entry;
    }
    return null;
  }

  FileEntry? _findLrcEntry(FileEntry audio) {
    final target = '${_stem(audio.name).toLowerCase()}.lrc';
    for (final entry in _directoryEntries) {
      if (entry.isFile && entry.name.toLowerCase() == target) return entry;
    }
    return null;
  }

  FileEntry? _findArtworkEntry(FileEntry audio) {
    final stem = _stem(audio.name).toLowerCase();
    final candidates = _directoryEntries.where((entry) {
      if (!entry.isFile) return false;
      final extension = _extension(entry.name);
      return const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);
    });

    for (final entry in candidates) {
      if (_stem(entry.name).toLowerCase() == stem) return entry;
    }
    for (final base in const ['cover', 'folder']) {
      for (final entry in candidates) {
        if (_stem(entry.name).toLowerCase() == base) return entry;
      }
    }
    return null;
  }

  Future<_EmbeddedMetadata?> _readEmbeddedMetadata(FileEntry entry) async {
    final musicCache = _musicCache;
    if (musicCache != null) {
      final lease = musicCache.acquire(
        repository: _repository,
        path: entry.path,
        size: entry.size,
        modifiedAt: entry.modifiedAt,
        pathExtension: _extension(entry.name),
      );
      _musicCacheLeases.add(lease);
      try {
        final cachedAudio = await lease.file;
        final parsed = await Isolate.run(
          () => _parseMetadataFile(cachedAudio.path),
        );
        final pictureBytes = parsed['pictureBytes'];
        return _EmbeddedMetadata(
          artist: parsed['artist']?.toString(),
          album: parsed['album']?.toString(),
          pictureBytes: pictureBytes is Uint8List ? pictureBytes : null,
          pictureMimeType: parsed['pictureMimeType']?.toString(),
        );
      } finally {
        _musicCacheLeases.remove(lease);
        lease.release();
      }
    }

    final tempAudio = await _copyRemoteFile(entry, prefix: 'audio');
    try {
      final parsed = await Isolate.run(
        () => _parseMetadataFile(tempAudio.path),
      );
      final pictureBytes = parsed['pictureBytes'];
      return _EmbeddedMetadata(
        artist: parsed['artist']?.toString(),
        album: parsed['album']?.toString(),
        pictureBytes: pictureBytes is Uint8List ? pictureBytes : null,
        pictureMimeType: parsed['pictureMimeType']?.toString(),
      );
    } finally {
      await _deleteQuietly(tempAudio);
      _ownedFiles.remove(tempAudio);
    }
  }

  Future<File> _copyRemoteFile(
    FileEntry entry, {
    required String prefix,
  }) async {
    final directory = await _metadataDirectory();
    final file = File(
      '${directory.path}/omm_audio_${prefix}_${_digest(entry.stableKey)}.${_extension(entry.name)}',
    );
    _ownedFiles.add(file);
    final sink = file.openWrite();
    try {
      await for (final chunk in _repository.download(
        entry.path,
        options: FileTransferOptions(cancellation: _cancellation),
      )) {
        sink.add(chunk);
      }
      await sink.close();
      return file;
    } catch (_) {
      await sink.close();
      await _deleteQuietly(file);
      _ownedFiles.remove(file);
      rethrow;
    }
  }

  Future<File> _writeOwnedFile(
    FileEntry source,
    Uint8List bytes, {
    required String suffix,
  }) async {
    final directory = await _metadataDirectory();
    final file = File(
      '${directory.path}/omm_audio_art_${_digest(source.stableKey)}.$suffix',
    );
    await file.writeAsBytes(bytes, flush: true);
    _ownedFiles.add(file);
    return file;
  }

  Future<Uint8List> _readRemoteBytes(
    FileEntry entry, {
    required int maxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in _repository.download(
      entry.path,
      options: FileTransferOptions(cancellation: _cancellation),
    )) {
      length += chunk.length;
      if (length > maxBytes) throw StateError('文件超过元数据读取限制');
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<Directory> _metadataDirectory() async {
    final root = await _temporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}omm_audio_metadata',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancellation.cancel('播放器已关闭');
    for (final lease in _musicCacheLeases.toList()) {
      lease.release();
    }
    final pending = List<Future<AudioTrackMetadata>>.from(_cache.values);
    if (pending.isNotEmpty) await Future.wait(pending, eagerError: false);
    for (final file in _ownedFiles.toList()) {
      await _deleteQuietly(file);
    }
    _ownedFiles.clear();
    _cache.clear();
  }
}

Future<Directory> _temporaryDirectory() async {
  try {
    return await getTemporaryDirectory();
  } catch (_) {
    // Headless tests may not register path_provider. Directory.systemTemp is
    // also a safe fallback if the platform temporary-directory lookup fails.
    return Directory.systemTemp;
  }
}

Map<String, Object?> _parseMetadataFile(String path) {
  final metadata = readMetadata(File(path), getImage: true);
  Picture? picture;
  for (final candidate in metadata.pictures) {
    if (candidate.pictureType == PictureType.coverFront) {
      picture = candidate;
      break;
    }
    picture ??= candidate;
  }
  return <String, Object?>{
    'artist': metadata.artist,
    'album': metadata.album,
    'pictureBytes': picture?.bytes,
    'pictureMimeType': picture?.mimetype,
  };
}

class _EmbeddedMetadata {
  const _EmbeddedMetadata({
    this.artist,
    this.album,
    this.pictureBytes,
    this.pictureMimeType,
  });

  final String? artist;
  final String? album;
  final Uint8List? pictureBytes;
  final String? pictureMimeType;
}

String _stem(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 || dot == name.length - 1
      ? 'bin'
      : name.substring(dot + 1).toLowerCase();
}

String _extensionForMime(String? mime) {
  switch (mime?.toLowerCase()) {
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    default:
      return 'jpg';
  }
}

String? _mimeForExtension(String name) {
  switch (_extension(name)) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

String _digest(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 24);

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
