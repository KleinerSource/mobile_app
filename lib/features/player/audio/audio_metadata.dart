import 'package:flutter/foundation.dart';

import 'lrc_parser.dart';
import '../common/player_queue.dart';

@immutable
class AudioTrackMetadata {
  const AudioTrackMetadata({
    this.artworkPath,
    this.artworkMimeType,
    this.artist,
    this.album,
    this.lyrics,
  });

  final String? artworkPath;
  final String? artworkMimeType;
  final String? artist;
  final String? album;
  final LrcDocument? lyrics;
}

typedef AudioTrackMetadataLoader =
    Future<AudioTrackMetadata> Function(PlayerQueueItem item);

abstract interface class AudioMetadataSink {
  Future<void> updateCurrentMetadata(AudioTrackMetadata metadata);
}

/// 音频页面的异步元数据协调器。
///
/// 只负责按队列项缓存和取消过期加载，具体的页面状态与播放器更新由调用方
/// 处理，避免公共会话控制器依赖音频元数据模型。
class AudioMetadataCoordinator {
  AudioMetadataCoordinator({required this.loader});

  final AudioTrackMetadataLoader loader;
  final Map<String, Future<AudioTrackMetadata>> _cache =
      <String, Future<AudioTrackMetadata>>{};
  int _generation = 0;
  bool _disposed = false;

  Future<void> load(
    PlayerQueueItem item, {
    required void Function(AudioTrackMetadata metadata) onLoaded,
  }) async {
    if (_disposed) return;
    final generation = ++_generation;
    final future = _cache[item.safeMediaId] ??= loader(item);
    try {
      final metadata = await future;
      if (_disposed || generation != _generation) return;
      onLoaded(metadata);
    } catch (_) {
      // 元数据是增强信息，读取失败不应影响音频播放。
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    final pending = List<Future<AudioTrackMetadata>>.from(_cache.values);
    if (pending.isNotEmpty) await Future.wait(pending, eagerError: false);
    _cache.clear();
  }
}
