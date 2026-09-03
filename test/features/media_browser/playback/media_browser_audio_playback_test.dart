import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/playback/media_browser_audio_playback.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/features/player/common/player_queue.dart';

/// 只实现播放会话用到的 Source 方法，其余通过 noSuchMethod 拒绝。
class _FakeMediaBrowserSource implements MediaBrowserMediaSource {
  Object? lyrics;
  Object? lyricsError;
  final lyricsRequests = <String>[];
  final playbackStarts = <String>[];
  final playbackStops = <String>[];

  @override
  Future<Object?> fetchLyrics(String itemId) async {
    lyricsRequests.add(itemId);
    if (lyricsError != null) throw lyricsError!;
    return lyrics;
  }

  @override
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) async {
    playbackStarts.add(itemId);
  }

  @override
  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) async {
    playbackStops.add(itemId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 返回固定字节的 HTTP adapter，模拟封面下载。
class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);

  final List<int> bytes;
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri}');
    return ResponseBody(
      Stream<Uint8List>.value(Uint8List.fromList(bytes)),
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
  }
}

MediaBrowserItem _track(
  String id, {
  String? name,
  int? indexNumber,
  String? albumId,
  String? primaryImageTag,
}) => MediaBrowserItem(
  id: id,
  name: name ?? '曲目$id',
  type: 'Audio',
  albumId: albumId,
  album: albumId == null ? null : '测试专辑',
  albumArtist: '测试艺术家',
  indexNumber: indexNumber,
  primaryImageTag: primaryImageTag,
);

MediaBrowserServerUrls _urls() => MediaBrowserServerUrls(
  config: MediaBrowserConfig.emby,
  baseUrl: 'http://test',
  token: 'secret-token',
);

void main() {
  test('队列构建：曲号标题、音频直链、mediaId 不含 token', () {
    final source = _FakeMediaBrowserSource();
    final session = MediaBrowserAudioQueueSession(
      tracks: [
        _track('t1', indexNumber: 1),
        _track('t2', indexNumber: 3),
        _track('t3'), // 无曲号
      ],
      urls: _urls(),
      repository: MediaBrowserMediaRepository(source),
    );

    final queue = session.queue;
    expect(queue.length, 3);
    expect(
      queue.every((item) => item.type == PlayerQueueItemType.audio),
      isTrue,
    );
    expect(queue[0].title, '01 曲目t1');
    expect(queue[1].title, '03 曲目t2');
    expect(queue[2].title, '曲目t3');
    expect(
      queue[0].directUrl,
      'http://test/emby/Audio/t1/stream?static=true&api_key=secret-token',
    );
    // mediaId 是条目 ID，safeMediaId 是不可逆摘要，通知栏不暴露 token。
    expect(queue[0].mediaId, 'mediabrowser:t1');
    expect(queue[0].safeMediaId, startsWith('file:'));
    expect(queue[0].safeMediaId, isNot(contains('secret-token')));
  });

  test('元数据加载：艺术家 / 专辑 / 服务器歌词；无封面时为 null', () async {
    final source = _FakeMediaBrowserSource()
      ..lyrics = <String, dynamic>{
        'Lyrics': [
          {'Text': '第一行', 'Start': 10000000},
        ],
      };
    final session = MediaBrowserAudioQueueSession(
      tracks: [_track('t1', albumId: 'album-1')],
      urls: _urls(),
      repository: MediaBrowserMediaRepository(source),
    );

    final metadata = await session.loadMetadata(session.queue.single);

    expect(metadata.artist, '测试艺术家');
    expect(metadata.album, '测试专辑');
    expect(metadata.lyrics?.cues.single.text, '第一行');
    expect(metadata.artworkPath, isNull);
    expect(source.lyricsRequests, ['t1']);
  });

  test('元数据加载：歌词接口失败时静默回退', () async {
    final source = _FakeMediaBrowserSource()..lyricsError = Exception('服务器无歌词');
    final session = MediaBrowserAudioQueueSession(
      tracks: [_track('t1')],
      urls: _urls(),
      repository: MediaBrowserMediaRepository(source),
    );

    final metadata = await session.loadMetadata(session.queue.single);

    expect(metadata.lyrics, isNull);
    expect(metadata.artist, '测试艺术家');
  });

  test('封面下载到临时文件并在 dispose 时清理', () async {
    final adapter = _BytesAdapter(Uint8List.fromList('fake-jpeg'.codeUnits));
    final session = MediaBrowserAudioQueueSession(
      tracks: [
        _track('t1', albumId: 'album-1'),
        _track('t2', albumId: 'album-1'),
      ],
      urls: _urls(),
      repository: MediaBrowserMediaRepository(_FakeMediaBrowserSource()),
      artworkDownloader: Dio()..httpClientAdapter = adapter,
    );

    final first = await session.loadMetadata(session.queue[0]);
    final second = await session.loadMetadata(session.queue[1]);

    // 同专辑曲目共享一次封面下载。
    expect(first.artworkPath, isNotNull);
    expect(second.artworkPath, first.artworkPath);
    expect(adapter.requests.single, contains('Items/album-1/Images/Primary'));
    expect(adapter.requests.single, contains('api_key=secret-token'));
    final file = File(first.artworkPath!);
    expect(await file.exists(), isTrue);

    await session.dispose();

    expect(await file.exists(), isFalse);
  });

  test('切歌与退出按曲目上报播放会话', () async {
    final source = _FakeMediaBrowserSource();
    final handler = audio_service.BaseAudioHandler();
    final session = MediaBrowserAudioQueueSession(
      tracks: [_track('t1'), _track('t2')],
      urls: _urls(),
      repository: MediaBrowserMediaRepository(source),
      playbackHandler: handler,
    );
    final queue = session.queue;
    session.startPlaybackReports();

    // 队列打开：服务发布首个 mediaItem（id 为 safeMediaId 摘要）。
    handler.mediaItem.add(
      audio_service.MediaItem(id: queue[0].safeMediaId, title: queue[0].title),
    );
    await Future<void>.delayed(Duration.zero);
    expect(source.playbackStarts, ['t1']);

    // 切歌：上一曲报 Stopped，新曲报 Playing。
    handler.mediaItem.add(
      audio_service.MediaItem(id: queue[1].safeMediaId, title: queue[1].title),
    );
    await Future<void>.delayed(Duration.zero);
    expect(source.playbackStops, ['t1']);
    expect(source.playbackStarts, ['t1', 't2']);

    // 退出：当前曲补报 Stopped。
    await session.dispose();
    expect(source.playbackStops, ['t1', 't2']);

    // dispose 幂等，不重复上报。
    await session.dispose();
    expect(source.playbackStops.length, 2);
  });
}
