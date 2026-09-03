import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/feiniu_media_source_adapter.dart';
import 'package:omm/core/sources/media/media_browser_media_operations_source.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/features/media_browser/api/feiniu_api.dart';

void main() {
  test('飞牛适配器分页并生成带鉴权头的播放描述', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
      ..httpClientAdapter = _FeiniuSourceAdapter();
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(dio),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );

    final page = await source.listMovies(const MediaQuery(limit: 1));
    final descriptor = await source.resolvePlayback(
      const MediaRef(sourceId: SourceId('feiniu'), value: 'item-1'),
      const PlaybackRequest(),
    );

    expect(page.items.single.title, '示例影片');
    expect(page.total, 1);
    expect(
      descriptor.uri.toString(),
      'http://test/v/api/v1/media/range/media-1',
    );
    expect(descriptor.headers, {
      'Authorization': 'token-1',
      'X-Trim-Client': 'web',
      'X-Trim-Client-Version': '616',
    });
    expect(descriptor.mimeType, 'video/x-matroska');
  });
  test('飞牛媒体库与详情映射封面、背景、简介和人员', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
      ..httpClientAdapter = _FeiniuMetadataAdapter();
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(dio),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );

    final views = await source.views();
    final item = await source.getItem('item-1');

    expect(views.single.primaryImageTag, '/mediadb/library-1/poster.jpg');
    expect(item.primaryImageTag, '/mediadb/item-1/poster.jpg');
    expect(item.backdropImageTags, ['/mediadb/item-1/backdrop.jpg']);
    expect(item.productionYear, 2025);
    expect(item.originalTitle, 'Example Movie');
    expect(item.overview, '影片简介');
    expect(item.genres, ['科幻', '动作']);
    expect(item.people.map((person) => person.name), ['导演一', '演员一']);
    expect(item.people.first.type, 'Director');
    expect(item.people.last.role, '主角');
    expect(item.people.last.profilePath, '/person/p2.webp');
  });

  test('飞牛适配器通过原生季列表返回完整季条目', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final adapter = _FeiniuSeasonAdapter();
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(
        Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
          ..httpClientAdapter = adapter,
      ),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );

    final seasons = await source.seasons('series-1');

    expect(adapter.paths, ['/v/api/v1/season/list/series-1']);
    expect(seasons, hasLength(1));
    expect(seasons.single.id, 'season-1');
    expect(seasons.single.type, 'Season');
    expect(seasons.single.name, '第一季');
    expect(seasons.single.indexNumber, 1);
    expect(seasons.single.parentIndexNumber, isNull);
    expect(seasons.single.primaryImageTag, '/55/02/season.webp');
    expect(seasons.single.childCount, 8);
  });

  test('飞牛详情补全类型、文件与媒体流，并按 GUID 选择字幕', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final adapter = _FeiniuRichMetadataAdapter();
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(
        Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
          ..httpClientAdapter = adapter,
      ),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );

    final item = await source.getItem('item-rich');
    final mediaSource = item.mediaSources.single;
    expect(adapter.paths, contains('/v/api/v1/person/list/item-rich'));
    expect(item.genres, ['悬疑', '冒险']);
    expect(item.people.single.profilePath, '/person/p1.jpg');
    expect(mediaSource.path, '/movies/example.mkv');
    expect(mediaSource.sizeInBytes, 4096);
    expect(mediaSource.mediaStreams, hasLength(5));
    expect(mediaSource.mediaStreams.first.width, 1920);
    expect(mediaSource.mediaStreams.first.bitRate, 6424829);
    expect(mediaSource.mediaStreams[1].channelLayout, '5.1');
    expect(mediaSource.mediaStreams.last.format, 'ass');

    final descriptor = await source.resolvePlayback(
      const MediaRef(sourceId: SourceId('feiniu'), value: 'item-rich'),
      const PlaybackRequest(audioStreamIndex: 1, subtitleTrackId: 'sub-1'),
    );
    expect(descriptor.audioTracks[1].id, 'audio-1');
    expect(
      descriptor.subtitleTracks.singleWhere((track) => track.id == 'sub-1').id,
      'sub-1',
    );
    expect(adapter.playInfoBody['audio_guid'], 'audio-1');
    expect(adapter.playInfoBody['subtitle_guid'], 'sub-1');
    expect(descriptor.mimeType, 'video/x-matroska');

    final externalDescriptor = await source.resolvePlayback(
      const MediaRef(sourceId: SourceId('feiniu'), value: 'item-rich'),
      const PlaybackRequest(subtitleTrackId: 'sub-external'),
    );
    expect(
      externalDescriptor.subtitleTracks
          .singleWhere((track) => track.id == 'sub-external')
          .url,
      'http://test/v/api/v1/subtitle/dl/sub-external',
    );
    expect(adapter.playInfoBody['subtitle_guid'], 'sub-external');
  });

  test('飞牛多文件映射为多个片源并按 mediaGuid 播放第二源', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final adapter = _FeiniuMultiFileAdapter();
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(
        Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
          ..httpClientAdapter = adapter,
      ),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );

    final item = await source.getItem('item-multi');
    expect(item.mediaSources.map((source) => source.id), [
      'media-1',
      'media-2',
    ]);
    expect(item.mediaSources[0].name, 'first.mkv');
    expect(item.mediaSources[1].path, '/movies/second.mp4');
    expect(item.mediaSources[1].container, 'mp4');
    expect(item.mediaSources[1].sizeInBytes, 2048);
    expect(item.partCount, 2);
    expect(item.videoParts.map((part) => part.itemId), [
      'item-multi',
      'item-multi',
    ]);
    expect(item.videoParts.map((part) => part.mediaSourceId), [
      'media-1',
      'media-2',
    ]);
    expect(item.videoParts[1].name, 'second.mp4');

    final descriptor = await source.resolvePlayback(
      const MediaRef(sourceId: SourceId('feiniu'), value: 'item-multi'),
      const PlaybackRequest(mediaSourceId: 'media-2'),
    );

    expect(adapter.playInfoBody['media_guid'], 'media-2');
    expect(
      descriptor.uri.toString(),
      'http://test/v/api/v1/media/range/media-2',
    );
    expect(descriptor.mimeType, 'video/mp4');

    await expectLater(
      source.resolvePlayback(
        const MediaRef(sourceId: SourceId('feiniu'), value: 'item-multi'),
        const PlaybackRequest(mediaSourceId: 'missing'),
      ),
      throwsA(isA<SourceException>()),
    );
  });

  test('飞牛适配器支持媒体库管理并按 GUID 更新', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final adapter = _FeiniuLibraryAdapter();
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(
        Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
          ..httpClientAdapter = adapter,
      ),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );

    final user = await source.currentUser();
    final libraries = await source.virtualFolders();
    await source.addVirtualFolder(
      name: '剧集库',
      collectionType: 'tvshows',
      paths: ['/media/tv'],
    );
    await source.renameVirtualFolder(name: '电影库', newName: '影片库');
    await source.addMediaPath(libraryName: '电影库', path: '/media/4k');
    await source.removeMediaPath(libraryName: '电影库', path: '/media/movies');
    await source.updateVirtualFolderOptions(
      id: 'mdb-1',
      enabled: false,
      options: const {'lan': 'zh-CN'},
    );
    await source.removeVirtualFolder('电影库');
    await source.refreshLibrary();

    expect(user.isAdmin, isTrue);
    expect(libraries.single.collectionType, 'movies');
    expect(libraries.single.paths, ['/media/movies', '/media/4k']);
    expect(libraries.single.enabled, isTrue);
    expect(adapter.requests, contains('PUT /v/api/v1/mdb/create'));
    expect(adapter.requests, contains('POST /v/api/v1/mdb/mdb-1'));
    expect(adapter.requests, contains('DELETE /v/api/v1/mdb/mdb-1'));
    expect(adapter.requests, contains('POST /v/api/v1/mdb/scan/mdb-1'));
    expect(
      adapter.bodies.whereType<Map>().any(
        (body) => body['mdb_guid'] == 'mdb-1',
      ),
      isFalse,
    );
    expect(
      adapter.bodies.whereType<Map>().any(
        (body) =>
            body['name'] == '影片库' &&
            body['dir_list'] is List &&
            (body['dir_list'] as List).contains('/media/movies'),
      ),
      isTrue,
    );
  });

  test('飞牛媒体库刷新聚合任务进度并处理零总数和任务结束', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final adapter = _FeiniuRefreshAdapter([
      [
        {
          'guid': 'task-1',
          'ancestor': 'mdb-1',
          'status': 2,
          'total_count': 352,
          'finished_count': 342,
        },
        {
          'guid': 'mdb-1',
          'ancestor': 'mdb-1',
          'status': 3,
          'total_count': 648,
          'finished_count': 618,
        },
        {
          'guid': 'other',
          'ancestor': 'other',
          'status': 2,
          'total_count': 100,
          'finished_count': 99,
        },
      ],
      [
        {
          'guid': 'mdb-1',
          'ancestor': 'mdb-1',
          'status': 2,
          'total_count': 0,
          'finished_count': 0,
        },
      ],
      const [],
    ]);
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(
        Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
          ..httpClientAdapter = adapter,
      ),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );
    const target = MediaBrowserLibraryRefreshTarget(
      id: 'mdb-1',
      name: '本地动漫',
      category: 'TV',
    );

    await source.refreshLibrary(libraryId: 'mdb-1');
    final aggregated = await source.libraryRefreshProgress(target);
    final unknown = await source.libraryRefreshProgress(target);
    final completed = await source.libraryRefreshProgress(target);

    expect(adapter.requests.first, 'POST /v/api/v1/mdb/scan/mdb-1');
    expect(adapter.bodies.first, isNull);
    expect(aggregated.isRunning, isTrue);
    expect(aggregated.ratio, closeTo(960 / 1000, 0.0001));
    expect(unknown.isRunning, isTrue);
    expect(unknown.ratio, isNull);
    expect(completed.isRunning, isFalse);
    expect(completed.failed, isFalse);
    expect(
      adapter.taskRequestBodies,
      everyElement({
        'guid': 'mdb-1',
        'ancestor': 'mdb-1',
        'ancestor_name': '本地动漫',
        'ancestor_category': 'TV',
      }),
    );
  });
}

class _FeiniuMetadataAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.uri.path) {
      '/v/api/v1/mediadb/list' => {
        'list': [
          {
            'guid': 'library-1',
            'name': '本地电影',
            'category': 'movies',
            'poster': '/mediadb/library-1/poster.jpg',
          },
        ],
      },
      '/v/api/v1/item/item-1' => {
        'guid': 'item-1',
        'title': '示例影片',
        'type': 'Movie',
        'poster': '/mediadb/item-1/poster.jpg',
        'backdrops': ['/mediadb/item-1/backdrop.jpg'],
        'release_date': '2025-11-26',
        'original_title': 'Example Movie',
        'overview': '影片简介',
        'genres': ['科幻', '动作'],
      },
      '/v/api/v1/person/list/item-1' => {
        'list': [
          {
            'person_guid': 'p1',
            'name': '导演一',
            'job': 'Director',
            'profile_path': '/person/p1.webp',
          },
          {
            'person_guid': 'p2',
            'name': '演员一',
            'job': 'Actor',
            'character': '主角',
            'profile_path': '/person/p2.webp',
          },
        ],
      },
      _ => <String, Object?>{},
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _FeiniuSourceAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final data = switch (path) {
      '/v/api/v1/item/list' => {
        'list': [
          {
            'guid': 'item-1',
            'title': '示例影片',
            'type': 'Movie',
            'poster': '/mediadb/item-1/poster.jpg',
            'backdrops': ['/mediadb/item-1/backdrop.jpg'],
            'can_play': true,
            'media_guid': 'media-1',
            'file_name': 'movie.mkv',
          },
        ],
        'total': 1,
      },
      '/v/api/v1/item/item-1' => {
        'guid': 'item-1',
        'title': '示例影片',
        'type': 'Movie',
        'poster': '/mediadb/item-1/poster.jpg',
        'backdrops': ['/mediadb/item-1/backdrop.jpg'],
        'release_date': '2025-11-26',
        'original_title': 'Example Movie',
        'overview': '影片简介',
        'genres': ['科幻', '动作'],
        'can_play': true,
        'media_guid': 'media-1',
        'file_name': 'movie.mkv',
      },
      '/v/api/v1/stream/list/item-1' => {
        'video_streams': [
          {'guid': 'video-1', 'title': 'H.265'},
        ],
        'audio_streams': [
          {'guid': 'audio-1', 'title': '国语', 'index': 0, 'is_default': true},
        ],
        'subtitle_streams': <Map<String, Object?>>[],
      },
      '/v/api/v1/play/info' => {
        'item_guid': 'item-1',
        'media_guid': 'media-1',
        'video_guid': 'video-1',
        'audio_guid': 'audio-1',
      },
      _ => <String, Object?>{},
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _FeiniuSeasonAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final data = options.uri.path == '/v/api/v1/season/list/series-1'
        ? {
            'list': [
              {
                'guid': 'season-1',
                'name': '第一季',
                'type': 'Season',
                'parent_guid': 'series-1',
                'season_number': 1,
                'number_of_episodes': 8,
                'poster': '/55/02/season.webp',
              },
            ],
          }
        : <String, Object?>{};
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _FeiniuRichMetadataAdapter implements HttpClientAdapter {
  final paths = <String>[];
  Map<String, dynamic> playInfoBody = const {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    paths.add(path);
    if (path == '/v/api/v1/play/info') {
      playInfoBody = Map<String, dynamic>.from(options.data as Map);
    }
    final data = switch (path) {
      '/v/api/v1/item/item-rich' => {
        'guid': 'item-rich',
        'title': '完整影片',
        'type': 'Movie',
        'genres': [13, 2],
        'media_guid': 'media-rich',
        'poster': '/mediadb/item-rich/poster.jpg',
        'can_play': true,
      },
      '/v/api/v1/person/list/item-rich' => {
        'list': [
          {
            'person_guid': 'p1',
            'name': '演员一',
            'job': 'Actor',
            'role': '主角',
            'profile_path': '/person/p1.jpg',
          },
        ],
      },
      '/v/api/v1/tag/genres' => [
        {'id': 13, 'value': '悬疑'},
        {'id': 2, 'value': '冒险'},
      ],
      '/v/api/v1/stream/list/item-rich' => {
        'file_stream': {
          'guid': 'file-1',
          'media_guid': 'media-rich',
          'path': '/movies/example.mkv',
          'size': 4096,
          'wrapper': 'mkv',
        },
        'video_stream': {
          'guid': 'video-1',
          'codec_name': 'h264',
          'width': 1920,
          'height': 804,
          'bps': 6424829,
          'bit_depth': 8,
          'profile': 'High',
          'r_frame_rate': '24 fps',
        },
        'audio_streams': [
          {
            'guid': 'audio-0',
            'title': '国语',
            'codec_name': 'ac3',
            'index': 0,
            'channels': 6,
            'channel_layout': '5.1',
            'sample_rate': '48000',
            'is_default': true,
          },
          {
            'guid': 'audio-1',
            'title': 'English',
            'codec_name': 'aac',
            'index': 1,
            'channels': 2,
          },
        ],
        'subtitle_streams': [
          {
            'guid': 'sub-1',
            'title': '简体中文',
            'codec_name': 'subrip',
            'format': 'srt',
            'language': 'chi',
            'index': 2,
          },
          {
            'guid': 'sub-external',
            'title': '外挂字幕',
            'codec_name': 'ass',
            'format': 'ass',
            'language': 'chi',
            'index': 3,
            'is_external': 1,
            'extra_file': 1,
          },
        ],
      },
      '/v/api/v1/play/info' => {
        'item_guid': 'item-rich',
        'media_guid': 'media-rich',
      },
      _ => <String, Object?>{},
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _FeiniuMultiFileAdapter implements HttpClientAdapter {
  Map<String, dynamic> playInfoBody = const {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final data = switch (path) {
      '/v/api/v1/item/item-multi' => {
        'guid': 'item-multi',
        'title': '多片源电影',
        'type': 'Movie',
        'can_play': true,
        'media_guid': 'media-1',
      },
      '/v/api/v1/stream/list/item-multi' => {
        'files': [
          {
            'media_guid': 'media-2',
            'file_name': 'second.mp4',
            'path': '/movies/second.mp4',
            'size': 2048,
            'container': 'mp4',
          },
          {
            'media_guid': 'media-1',
            'file_name': 'first.mkv',
            'path': '/movies/first.mkv',
            'size': 4096,
            'container': 'mkv',
          },
          {
            'media_guid': 'media-2',
            'file_name': 'duplicate.mp4',
            'path': '/movies/duplicate.mp4',
          },
        ],
        'video_stream': {'guid': 'video-1', 'codec_name': 'h264'},
      },
      '/v/api/v1/play/info' => _playInfo(options),
      _ => <String, Object?>{},
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, dynamic> _playInfo(RequestOptions options) {
    playInfoBody = Map<String, dynamic>.from(options.data as Map);
    return {
      'item_guid': 'item-multi',
      'media_guid': playInfoBody['media_guid'],
    };
  }
}

class _FeiniuLibraryAdapter implements HttpClientAdapter {
  final requests = <String>[];
  final bodies = <Object?>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri.path}');
    bodies.add(options.data);
    final data = switch (options.uri.path) {
      '/v/api/v1/user/info' => {'id': 'admin-1', 'name': '管理员', 'is_admin': 1},
      '/v/api/v1/mdb/list' => {
        'list': [
          {
            'guid': 'mdb-1',
            'name': '电影库',
            'category': 'Movie',
            'dir_list': ['/media/movies', '/media/4k'],
            'lan': 'zh-CN',
            'include_adult': false,
            'skip_filesize': 0,
            'auto_progress_thumb': 1,
            'prefer_local_nfo': 1,
            'subtitle_lan': 'zh-CN',
            'auto_scrap_subtitle': 1,
          },
        ],
      },
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _FeiniuRefreshAdapter implements HttpClientAdapter {
  _FeiniuRefreshAdapter(this.taskResponses);

  final List<List<Map<String, dynamic>>> taskResponses;
  final requests = <String>[];
  final bodies = <Object?>[];
  final taskRequestBodies = <Map<String, dynamic>>[];
  var _taskCall = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri.path}');
    bodies.add(options.data);
    final path = options.uri.path;
    if (path == '/v/api/v1/task/running') {
      taskRequestBodies.add(Map<String, dynamic>.from(options.data as Map));
      final index = _taskCall++;
      final tasks = index < taskResponses.length
          ? taskResponses[index]
          : const <Map<String, dynamic>>[];
      return ResponseBody.fromString(
        jsonEncode({'code': 0, 'data': tasks}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': true}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
