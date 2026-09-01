import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/playback/media_browser_lyrics.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/features/player/audio/audio_metadata.dart';
import 'package:omm/features/player/audio/audio_playback_service.dart';
import 'package:omm/features/player/audio/audio_player_page.dart';
import 'package:omm/features/player/audio/lrc_parser.dart';
import 'package:omm/features/player/common/player_queue.dart';

/// 打开 Emby/Jellyfin 音频队列播放。
///
/// 与视频链路一致：直连原始文件（static=true，token 走查询参数），
/// 切歌与退出时通过 Sessions/Playing 上报让服务器累计播放次数。
Future<void> openMediaBrowserAudioPlayback(
  BuildContext context,
  WidgetRef ref, {
  required List<MediaBrowserItem> tracks,
  int startIndex = 0,
}) async {
  final playable = tracks
      .where((track) => track.isAudio && track.id.trim().isNotEmpty)
      .toList(growable: false);
  if (playable.isEmpty || !context.mounted) return;
  if (ref.read(mediaBrowserConfigProvider) == null) return;
  try {
    final urls = await ref.read(mediaBrowserServerUrlsProvider.future);
    final repository = ref.read(mediaBrowserMediaRepositoryProvider);
    final session = MediaBrowserAudioQueueSession(
      tracks: playable,
      urls: urls,
      repository: repository,
    );
    final index = startIndex.clamp(0, playable.length - 1);
    final current = session.queue[index];
    session.startPlaybackReports();
    if (!context.mounted) return;
    await AudioPlayerPage.openDirect(
      context,
      title: current.title,
      directUrl: current.directUrl!,
      queue: session.queue,
      queueIndex: index,
      audioMetadataLoader: session.loadMetadata,
      onQueueDispose: session.dispose,
      // 搓碟（DJ 台）依赖本地 PCM，远程直链音源不支持，禁用搓碟手势。
      scratchEnabled: false,
      useRootNavigator: true,
    );
    await session.dispose();
    // 播放结束同步专辑页/搜索结果的播放次数与收藏状态。
    ref.invalidate(mediaBrowserAlbumTracksProvider);
    ref.invalidate(mediaBrowserItemDetailProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
    }
  }
}

/// 播放单个音频条目；有所属专辑时定位到整专辑队列。
Future<void> openMediaBrowserAudioItem(
  BuildContext context,
  WidgetRef ref, {
  required MediaBrowserItem item,
}) async {
  final albumId = item.albumId?.trim() ?? '';
  if (albumId.isEmpty) {
    await openMediaBrowserAudioPlayback(context, ref, tracks: [item]);
    return;
  }
  try {
    final repository = ref.read(mediaBrowserMediaRepositoryProvider);
    final tracks = await repository.albumTracks(albumId);
    final index = tracks.indexWhere(
      (track) => track.id == item.id.trim() && track.isAudio,
    );
    if (index >= 0) {
      if (!context.mounted) return;
      await openMediaBrowserAudioPlayback(
        context,
        ref,
        tracks: tracks,
        startIndex: index,
      );
      return;
    }
  } catch (_) {
    // 专辑曲目拉取失败时回退单曲播放。
  }
  if (!context.mounted) return;
  await openMediaBrowserAudioPlayback(context, ref, tracks: [item]);
}

/// 一次音频播放会话：队列、元数据、封面临时文件与播放上报的载体。
///
/// 页面退出（onQueueDispose）后释放全部资源；后台播放由
/// AudioPlaybackService 持有，但本项目音频页退出即停止播放，
/// 因此会话生命周期与页面一致。
class MediaBrowserAudioQueueSession {
  MediaBrowserAudioQueueSession({
    required this.tracks,
    required this.urls,
    required this.repository,
    Dio? artworkDownloader,
    audio_service.AudioHandler? playbackHandler,
  }) : _downloader =
           artworkDownloader ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _handler = playbackHandler;

  final List<MediaBrowserItem> tracks;
  final MediaBrowserServerUrls urls;
  final MediaBrowserMediaRepository repository;
  final Dio _downloader;
  final audio_service.AudioHandler? _handler;

  final Map<String, MediaBrowserItem> _trackByMediaId =
      <String, MediaBrowserItem>{};
  final Map<String, Future<String?>> _artworkByImageItemId =
      <String, Future<String?>>{};
  final List<File> _ownedFiles = <File>[];
  StreamSubscription<audio_service.MediaItem?>? _mediaItemSubscription;
  String? _reportedItemId;
  bool _disposed = false;
  Future<void>? _disposeFuture;

  late final List<PlayerQueueItem> queue = _buildQueue();

  List<PlayerQueueItem> _buildQueue() {
    final items = <PlayerQueueItem>[];
    for (final track in tracks) {
      final item = PlayerQueueItem(
        title: queueTitleForTrack(track),
        type: PlayerQueueItemType.audio,
        mediaId: mediaIdForTrack(track),
        directUrl: urls.audioStream(
          track.id,
          mediaSourceId: track.mediaSources.isEmpty
              ? null
              : track.mediaSources.first.id,
        ),
      );
      // 播放服务的 mediaItem.id 是 safeMediaId（不可逆摘要），统一以它
      // 建映射，切歌上报与元数据加载才能定位回服务器条目。
      _trackByMediaId[item.safeMediaId] = track;
      items.add(item);
    }
    return List<PlayerQueueItem>.unmodifiable(items);
  }

  /// 开始按当前曲目上报播放会话。
  ///
  /// 播放服务在队列打开后会发布首个 mediaItem，之后每次切歌再发布，
  /// 这里统一监听：上一曲报 Stopped（读当前进度），新曲报 Playing。
  void startPlaybackReports() {
    final handler = _handler ?? _serviceHandlerOrNull();
    if (handler == null) return;
    _mediaItemSubscription = handler.mediaItem
        .distinct((a, b) => a?.id == b?.id)
        .listen(
          _onMediaItemChanged,
          onError: (Object _) {},
          cancelOnError: false,
        );
  }

  void _onMediaItemChanged(audio_service.MediaItem? item) {
    if (_disposed) return;
    final previous = _reportedItemId;
    final next = item == null ? null : _trackByMediaId[item.id];
    if (next?.id == previous) return;
    if (previous != null) {
      unawaited(
        repository
            .reportPlaybackStopped(
              itemId: previous,
              positionTicks: secondsToMediaBrowserTicks(
                _currentReportPosition().inSeconds,
              ),
            )
            .catchError((_) {}),
      );
    }
    if (next == null) {
      _reportedItemId = null;
      return;
    }
    _reportedItemId = next.id;
    unawaited(
      repository
          .reportPlaybackStart(itemId: next.id, positionTicks: 0)
          .catchError((_) {}),
    );
  }

  Duration _currentReportPosition() {
    final handler = _handler ?? _serviceHandlerOrNull();
    final state = handler?.playbackState.valueOrNull;
    if (state == null) return Duration.zero;
    var position = state.position;
    if (state.playing) {
      final elapsed = DateTime.now().difference(state.updateTime);
      if (elapsed > Duration.zero) position += elapsed;
    }
    return position;
  }

  audio_service.AudioHandler? _serviceHandlerOrNull() {
    try {
      return AudioPlaybackService.handler;
    } catch (_) {
      // 服务未初始化（如测试环境）时跳过上报。
      return null;
    }
  }

  /// 音频页的异步元数据加载器：艺术家 / 专辑 / 服务器歌词 / 封面。
  Future<AudioTrackMetadata> loadMetadata(PlayerQueueItem item) async {
    if (_disposed) return const AudioTrackMetadata();
    final track = _trackByMediaId[item.safeMediaId];
    if (track == null) return const AudioTrackMetadata();

    final artwork = await _artworkFor(track);
    LrcDocument? lyrics;
    try {
      lyrics = parseMediaBrowserLyrics(await repository.fetchLyrics(track.id));
    } catch (_) {
      // 歌词是增强信息，失败静默回退。
    }
    if (_disposed) return const AudioTrackMetadata();
    return AudioTrackMetadata(
      artworkPath: artwork,
      artworkMimeType: artwork == null ? null : 'image/jpeg',
      artist: track.displayArtist,
      album: track.album,
      lyrics: lyrics,
    );
  }

  Future<String?> _artworkFor(MediaBrowserItem track) {
    // 曲目自带封面优先，否则用专辑封面（同专辑曲目共享一次下载）。
    final imageItemId = track.primaryImageTag != null
        ? track.id
        : track.albumId?.trim();
    if (imageItemId == null || imageItemId.isEmpty) {
      return Future<String?>.value(null);
    }
    return _artworkByImageItemId.putIfAbsent(
      imageItemId,
      () => _downloadArtwork(imageItemId),
    );
  }

  Future<String?> _downloadArtwork(String imageItemId) async {
    try {
      final directory = await _artworkDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'mb_audio_${_digest(imageItemId)}.jpg',
      );
      if (!await file.exists()) {
        await _downloader.download(
          urls.poster(imageItemId, maxWidth: 600),
          file.path,
        );
        if (_disposed) {
          await _deleteQuietly(file);
          return null;
        }
      }
      _ownedFiles.add(file);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _mediaItemSubscription?.cancel();
    _mediaItemSubscription = null;
    final reported = _reportedItemId;
    _reportedItemId = null;
    if (reported != null) {
      try {
        await repository.reportPlaybackStopped(
          itemId: reported,
          positionTicks: secondsToMediaBrowserTicks(
            _currentReportPosition().inSeconds,
          ),
        );
      } catch (_) {
        // 退出上报失败只影响服务端统计，不影响本地。
      }
    }
    for (final file in _ownedFiles.toList()) {
      await _deleteQuietly(file);
    }
    _ownedFiles.clear();
    _artworkByImageItemId.clear();
  }

  Future<Directory> _artworkDirectory() async {
    Directory root;
    try {
      root = await getTemporaryDirectory();
    } catch (_) {
      // 测试环境可能未注册 path_provider，回退系统临时目录。
      root = Directory.systemTemp;
    }
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}omm_mb_audio_art',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}

/// 曲目在播放队列中的稳定 mediaId；safeMediaId 只保留不可逆摘要，
/// 通知栏与锁屏不会出现 token。
String mediaIdForTrack(MediaBrowserItem track) =>
    'mediabrowser:${track.id.trim()}';

/// 通知栏标题：专辑内播放时带曲号前缀，便于识别顺序。
String queueTitleForTrack(MediaBrowserItem track) {
  final number = track.indexNumber;
  if (number == null || number <= 0) return track.name;
  return '${number.toString().padLeft(2, '0')} ${track.name}';
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

String _digest(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 24);
