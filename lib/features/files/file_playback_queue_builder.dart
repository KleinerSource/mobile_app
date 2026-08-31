import '../../core/platform/app_log_store.dart';
import '../../core/sources/common/source_exception.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_source_repository.dart';
import '../cache/music_cache.dart';
import '../player/common/player_queue.dart';
import 'file_playback_proxy.dart';

/// 把同目录媒体条目解析为播放器队列，并在构建失败时释放已创建的代理。
Future<List<PlayerQueueItem>> buildFilePlaybackQueue({
  required FileSourceRepository repository,
  required List<FileEntry> entries,
  required FileEntry current,
  required PlayerQueueItemType itemType,
  required bool useDirect,
  required List<FilePlaybackProxy> proxies,
  required String directUrlMissingMessage,
  MusicCacheService? musicCache,
}) async {
  final queue = <PlayerQueueItem>[];
  try {
    for (final entry in entries) {
      try {
        final formatHint = _pathExtension(entry.name);
        if (useDirect) {
          final access = await repository.resolveAccess(entry.path);
          final uri = access.uri;
          if (uri == null) {
            throw FileSourceException(
              directUrlMissingMessage,
              code: 'webdav_direct_url_missing',
            );
          }
          queue.add(
            PlayerQueueItem(
              title: entry.name,
              type: itemType,
              mediaId: entry.stableKey,
              directUrl: uri.toString(),
              directHeaders: access.headers,
              directFormatHint: formatHint,
              directPlaybackFileName: entry.name,
              directPreferFfmpegForHls: true,
            ),
          );
        } else {
          // 没有可供播放器直接访问的 URL，或音频需要先完整缓存时，
          // 为队列中的每个文件预留回环代理；资源由播放器页在整个队列
          // 结束后释放。
          final proxy = await FilePlaybackProxy.start(
            repository: repository,
            path: entry.path,
            size: entry.size,
            mimeType: entry.mimeType,
            pathExtension: formatHint,
            cacheBeforePlayback: itemType == PlayerQueueItemType.audio,
            musicCache: musicCache,
            modifiedAt: entry.modifiedAt,
          );
          proxies.add(proxy);
          queue.add(
            PlayerQueueItem(
              title: entry.name,
              type: itemType,
              mediaId: entry.stableKey,
              directUrl: proxy.uri.toString(),
              directFormatHint: formatHint,
              directPlaybackFileName: entry.name,
              directPreferFfmpegForHls: true,
            ),
          );
        }
      } catch (error, stackTrace) {
        if (entry.stableKey == current.stableKey) rethrow;
        appLog(
          '[FileBrowser] 跳过无法加入队列的视频: ${entry.name} '
          '$error\n$stackTrace',
        );
      }
    }
    return queue;
  } catch (_) {
    await closeFilePlaybackProxies(proxies);
    rethrow;
  }
}

Future<void> closeFilePlaybackProxies(
  Iterable<FilePlaybackProxy> proxies,
) async {
  for (final proxy in proxies) {
    try {
      await proxy.close();
    } catch (_) {}
  }
}

String? _pathExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1);
}
