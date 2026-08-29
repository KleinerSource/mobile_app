// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/core/sources_test.dart
//   - test/core/webdav_file_source_range_test.dart
//   - test/core/sources/file_playback_progress_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/files/file_playback_progress.dart';
import 'package:omm/core/sources/sources.dart';
import 'package:omm/features/db_online/api/db_online_api.dart';
import 'package:omm/features/files/file_playback_proxy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/core/sources_test.dart ====================
void _main_0() {
  test('SourceId and MediaRef keep source scope in stable keys', () {
    const ommId = SourceId('omm');
    const dboId = SourceId('dbo');
    const first = MediaRef(sourceId: ommId, value: '42');
    const second = MediaRef(sourceId: dboId, value: '42');

    expect(first, isNot(second));
    expect(first.stableKey, 'omm:42');
    expect(second.stableKey, 'dbo:42');
    expect(SourceId.of(' OMM '), ommId);
  });

  test('media registry exposes only the registered capabilities', () {
    final source = _FakeMediaSource(
      capabilities: const {MediaCapability.catalog},
    );
    final registry = MediaSourceRegistry([source]);

    expect(registry.find(const SourceId('fake')), same(source));
    expect(registry.capability<CatalogSource>(const SourceId('fake')), source);
    expect(
      registry.capability<MovieDetailSource>(const SourceId('fake')),
      isNull,
    );
  });

  test(
    'OMM adapter maps integer movie ids to scoped media references',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
        ..httpClientAdapter = _JsonAdapter((path) {
          if (path == '/api/movies') {
            return {
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 42,
                    'title': 'OMM 影片',
                    'num': 'ABC-042',
                    'year': 2024,
                    'rating': 8.5,
                    'poster_uuid': 'poster-42',
                  },
                ],
                'total_count': 1,
                'limit': 24,
                'offset': 0,
              },
            };
          }
          if (path == '/api/movies/id/42') {
            return {
              'success': true,
              'data': {
                'id': 42,
                'title': 'OMM 详情',
                'num': 'ABC-042',
                'plot': '详情简介',
              },
            };
          }
          return {'success': true, 'data': <String, Object?>{}};
        });
      final source = OmmMediaSourceAdapter(ApiClient(dio));

      final page = await source.listMovies(const MediaQuery(limit: 24));

      expect(
        page.items.single.ref,
        const MediaRef(sourceId: SourceId('omm'), value: '42'),
      );
      expect(page.items.single.title, 'OMM 影片');
      expect(page.items.single.code, 'ABC-042');
      final detail = await source.getMovie(
        const MediaRef(sourceId: SourceId('omm'), value: '42'),
      );
      expect(detail.payload, isA<MovieDetail>());
      expect((detail.payload! as MovieDetail).plot, '详情简介');
      expect(source.supports(MediaCapability.libraryManagement), isTrue);
      expect(source.supports(MediaCapability.scanning), isTrue);
    },
  );

  test(
    'DBO adapter preserves string identifiers and DBO-only resources',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
        ..httpClientAdapter = _JsonAdapter((path) {
          if (path == '/api/recommend') {
            return {
              'success': true,
              'data': {
                'movies': [
                  {
                    'id': 'video-1',
                    'number': 'DBO-001',
                    'title': 'DBO 影片',
                    'can_play': true,
                  },
                ],
                'total': 1,
              },
            };
          }
          if (path == '/api/video/DBO-001') {
            return {
              'success': true,
              'data': {
                'code': 'DBO-001',
                'video_id': 'video-1',
                'title': 'DBO 影片',
                'can_play': true,
                'magnets': [
                  {'name': '资源 1', 'magnet': 'magnet:?xt=urn:btih:1'},
                ],
                'ed2ks': [
                  {'name': '资源 2', 'ed2k': 'ed2k://|file|sample|1|hash|/'},
                ],
              },
            };
          }
          return {'success': true, 'data': <String, Object?>{}};
        });
      final source = DboMediaSourceAdapter(DbOnlineApi(dio));

      final page = await source.listMovies(
        const MediaQuery(mode: MediaCatalogMode.recommended, limit: 9),
      );
      final detail = await source.getMovie(
        const MediaRef(
          sourceId: SourceId('dbo'),
          value: 'video-1',
          alternateValue: 'DBO-001',
        ),
      );
      final resources = await source.listResources(
        const MediaRef(
          sourceId: SourceId('dbo'),
          value: 'video-1',
          alternateValue: 'DBO-001',
        ),
      );

      expect(page.items.single.ref.stableKey, 'dbo:video-1:DBO-001');
      expect(detail.summary.ref.stableKey, 'dbo:video-1:DBO-001');
      expect(
        resources.map((item) => item.kind),
        containsAll(<MediaResourceKind>[
          MediaResourceKind.magnet,
          MediaResourceKind.ed2k,
        ]),
      );
      expect(source.supports(MediaCapability.libraryManagement), isFalse);
    },
  );

  test(
    'adapter maps API failures to SourceException and keeps status',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
        ..httpClientAdapter = _JsonAdapter((path) {
          if (path == '/api/movies') {
            return {'success': false, 'message': '服务端暂时不可用'};
          }
          return {'success': true, 'data': <String, Object?>{}};
        });
      final source = OmmMediaSourceAdapter(ApiClient(dio));

      final mapped = mapSourceError(
        ApiException('网关错误', status: 503),
        fallback: '请求失败',
      );
      expect(
        mapped,
        isA<SourceException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.message, 'message', '网关错误'),
      );
      await expectLater(
        source.listMovies(const MediaQuery()),
        throwsA(
          isA<SourceException>().having(
            (error) => error.message,
            'message',
            '服务端暂时不可用',
          ),
        ),
      );
    },
  );

  test('file path helpers keep SMB relative and WebDAV absolute semantics', () {
    expect(normalizeRelativeFilePath(r'\\Movies\\A.mkv'), 'Movies/A.mkv');
    expect(normalizeWebDavPath(r'Movies\\A.mkv'), '/Movies/A.mkv');
    expect(isRootFilePath(''), isTrue);
    expect(isRootFilePath('/'), isTrue);
    expect(isRootFilePath('///'), isTrue);
    expect(isRootFilePath('/Movies'), isFalse);
    expect(joinRelativeFilePath('Movies', 'A.mkv'), 'Movies/A.mkv');
    expect(joinWebDavPath('/Movies', 'A.mkv'), '/Movies/A.mkv');
    expect(
      buildBreadcrumbs(
        const FilePath(sourceId: SourceId('smb'), value: 'Movies/2024'),
        webDav: false,
      ).map((item) => item.value),
      ['', 'Movies', 'Movies/2024'],
    );
    expect(() => normalizeRelativeFilePath('../outside'), throwsArgumentError);
    expect(
      () => joinRelativeFilePath('Movies', '2024/A.mkv'),
      throwsArgumentError,
    );
  });

  test(
    'file source config separates secure credentials from preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final configRepository = FileSourceConfigRepository(prefs);
      final credentialsRepository = FileSourceCredentialsRepository(
        store: _MemoryTokenStore(),
      );
      const config = FileSourceConfig.smb(
        id: 'nas',
        name: '家庭 NAS',
        host: 'nas.local',
        port: 445,
        path: 'media/Movies',
        credentialRef: 'nas-account',
        serverId: 'server-nas',
      );

      await configRepository.save(config);
      await credentialsRepository.save(
        'nas-account',
        const FileSourceCredentials(
          user: 'alice',
          password: 'secret',
          domain: 'WORKGROUP',
        ),
      );

      final restored = configRepository.find('nas');
      final credentials = await credentialsRepository.read('nas-account');
      expect(restored, config);
      expect(restored!.toJson(), isNot(contains('password')));
      expect(restored.toJson(), containsPair('path', 'media/Movies'));
      expect(restored.toJson(), isNot(contains('share')));
      expect(credentials?.password, 'secret');
    },
  );

  test('SMB 路径拆分共享名和共享内相对路径', () {
    final paths = [
      parseSmbPath('media'),
      parseSmbPath('/media/Movies'),
      parseSmbPath(r'\media\Movies'),
      parseSmbPath(r'\\nas\media\Movies'),
      parseSmbPath('smb://nas/media/Movies'),
    ];
    expect(paths.first.share, 'media');
    expect(paths.first.relativePath, isEmpty);
    for (final path in paths.skip(1)) {
      expect(path.share, 'media');
      expect(path.relativePath, 'Movies');
    }
  });

  test('SMB 服务器根路径不要求共享名并保留根路径语义', () {
    final paths = [
      parseSmbPath('/'),
      parseSmbPath(r'\'),
      parseSmbPath(r'\\nas'),
      parseSmbPath('smb://nas'),
      parseSmbPath('smb://nas/'),
    ];

    for (final path in paths) {
      expect(path.isServerRoot, isTrue);
      expect(path.share, isEmpty);
      expect(path.relativePath, isEmpty);
      expect(path.normalizedPath, '/');
    }
  });

  test('文件来源缺少端口时使用协议默认端口且只接受 path', () {
    final smb = FileSourceConfig.fromJson(const {
      'id': 'smb',
      'name': 'SMB',
      'protocol': 'smb',
      'host': 'nas.local',
      'path': 'media',
      'credential_ref': 'smb-account',
      'server_id': 'server-smb',
      'enabled': true,
      'timeout_ms': 30000,
      'smb_workers': 2,
    });
    final webDav = FileSourceConfig.fromJson(const {
      'id': 'webdav',
      'name': 'WebDAV',
      'protocol': 'webdav',
      'host': 'dav.example',
      'path': 'media',
      'uri': 'https://dav.example/media',
      'credential_ref': 'webdav-account',
      'server_id': 'server-webdav',
      'enabled': true,
      'timeout_ms': 30000,
      'smb_workers': 2,
    });
    final directWebDav = FileSourceConfig.webDav(
      id: 'direct-webdav',
      name: 'WebDAV',
      host: 'dav.example',
      path: 'media',
      uri: 'https://dav.example/media',
      credentialRef: 'direct-webdav-account',
      serverId: 'server-webdav',
    );

    expect(smb.port, 445);
    expect(webDav.port, 443);
    expect(directWebDav.port, 443);
    expect(
      () => FileSourceConfig.fromJson(const {
        'id': 'legacy',
        'name': '旧字段',
        'protocol': 'smb',
        'host': 'nas.local',
        'share': 'media',
        'credential_ref': 'legacy-account',
        'server_id': 'server-legacy',
        'enabled': true,
        'timeout_ms': 30000,
        'smb_workers': 2,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('OpenList 文件来源配置序列化往返并按协议默认端口', () {
    final openList = FileSourceConfig.fromJson(const {
      'id': 'openlist',
      'name': 'OpenList',
      'protocol': 'openlist',
      'host': 'alist.example',
      'path': '/',
      'uri': 'https://alist.example',
      'credential_ref': 'openlist-account',
      'server_id': 'server-openlist',
      'enabled': true,
      'timeout_ms': 30000,
      'smb_workers': 2,
    });
    final directOpenList = FileSourceConfig.openList(
      id: 'direct-openlist',
      name: 'OpenList',
      host: 'alist.example',
      path: '/media',
      uri: 'http://alist.example',
      credentialRef: 'direct-openlist-account',
      serverId: 'server-openlist',
    );

    expect(openList.port, 443);
    expect(directOpenList.port, 5244);
    expect(openList.protocol, FileSourceProtocol.openList);
    expect(FileSourceConfig.fromJson(directOpenList.toJson()), directOpenList);
    expect(
      FileSourceConfig.openList(
        id: 'bad-openlist',
        name: 'OpenList',
        host: 'alist.example',
        path: '/',
        uri: 'ftp://alist.example',
        credentialRef: 'bad-account',
        serverId: 'server-bad',
      ).isValid,
      isFalse,
    );
  });

  test(
    'file source repository ignores every legacy file source shape',
    () async {
      SharedPreferences.setMockInitialValues({
        'file_sources.v1': jsonEncode([
          {
            'id': 'legacy-smb',
            'name': '旧 SMB',
            'protocol': 'smb',
            'host': 'nas.local',
            'share': 'media',
            'credential_ref': 'legacy-smb-account',
            'server_id': 'server-legacy',
            'enabled': true,
            'timeout_ms': 30000,
            'smb_workers': 2,
          },
          {
            'id': 'legacy-webdav',
            'name': '旧 WebDAV',
            'protocol': 'webdav',
            'uri': 'https://dav.example/media',
            'credential_ref': 'legacy-webdav-account',
            'server_id': 'server-legacy',
            'enabled': true,
            'timeout_ms': 30000,
            'smb_workers': 2,
          },
          {
            'id': 'legacy-web-dav-alias',
            'name': '旧协议别名',
            'protocol': 'web_dav',
            'host': 'dav.example',
            'port': 443,
            'share': 'media',
            'uri': 'https://dav.example/media',
            'credential_ref': 'legacy-alias-account',
            'server_id': 'server-legacy',
            'enabled': true,
            'timeout_ms': 30000,
            'smb_workers': 2,
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      expect(FileSourceConfigRepository(prefs).loadAll(), isEmpty);
    },
  );

  test(
    'file source registry disposes protocol clients and rejects missing capability',
    () async {
      final source = _FakeFileSource();
      final registry = FileSourceRegistry([source]);

      expect(
        () => registry.requireCapability<FileMutationCapability>(
          const SourceId('fake-files'),
        ),
        throwsA(isA<UnsupportedSourceCapabilityException>()),
      );
      await registry.dispose();
      expect(source.disposed, isTrue);
    },
  );

  test(
    'media source provider selects the adapter from the active server project',
    () {
      final ommConfig = _serverConfig('omm-server', 'oh-my-media');
      final dboConfig = _serverConfig('dbo-server', 'db_online');
      final ommContainer = ProviderContainer(
        overrides: [
          requiredApiClientProvider.overrideWithValue(
            ApiClient(Dio(), config: ommConfig),
          ),
        ],
      );
      final dboContainer = ProviderContainer(
        overrides: [
          requiredApiClientProvider.overrideWithValue(
            ApiClient(Dio(), config: dboConfig),
          ),
        ],
      );
      addTearDown(ommContainer.dispose);
      addTearDown(dboContainer.dispose);

      expect(
        ommContainer
            .read(mediaSourceRegistryProvider)
            .find(const SourceId('omm')),
        isA<OmmMediaSourceAdapter>(),
      );
      expect(
        dboContainer
            .read(mediaSourceRegistryProvider)
            .find(const SourceId('dbo')),
        isA<DboMediaSourceAdapter>(),
      );
      expect(
        dboContainer
            .read(mediaSourceRegistryProvider)
            .find(const SourceId('omm')),
        isNull,
      );
    },
  );

  test('generic media provider request keys include server scope', () {
    const movie = MediaRef(sourceId: SourceId('omm'), value: '1');
    const query = MediaQuery();
    expect(
      const MediaCatalogRequest(
        serverId: 'server-a',
        sourceId: SourceId('omm'),
        query: query,
      ),
      isNot(
        const MediaCatalogRequest(
          serverId: 'server-b',
          sourceId: SourceId('omm'),
          query: query,
        ),
      ),
    );
    expect(
      const MediaMovieDetailRequest(serverId: 'server-a', movie: movie),
      isNot(const MediaMovieDetailRequest(serverId: 'server-b', movie: movie)),
    );
  });
}

ServerConfig _serverConfig(String id, String projectName) {
  final server = ServerProfile(
    id: id,
    name: id,
    projectName: projectName,
    lines: [ServerLine(id: 'primary', name: '主线路', baseUrl: 'http://$id')],
  );
  return ServerConfig(
    baseUrl: 'http://$id',
    lines: server.lines,
    servers: [server],
    activeServerId: id,
  );
}

class _FakeMediaSource implements MediaSource, CatalogSource {
  _FakeMediaSource({required this.capabilities});

  @override
  final Set<MediaCapability> capabilities;

  @override
  final descriptor = const SourceDescriptor(
    id: SourceId('fake'),
    kind: SourceKind.omm,
    name: 'Fake',
  );

  @override
  bool supports(MediaCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<MediaPage<MediaSummary>> listMovies(MediaQuery query) async =>
      const MediaPage(
        items: <MediaSummary>[],
        page: 1,
        limit: 0,
        hasMore: false,
      );

  @override
  Future<MediaPage<MediaSummary>> searchMovies(MediaQuery query) async =>
      const MediaPage(
        items: <MediaSummary>[],
        page: 1,
        limit: 0,
        hasMore: false,
      );
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.responseFor);

  final Object? Function(String path) responseFor;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseFor(options.uri.path)),
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

class _FakeFileSource
    implements FileSource, FileBrowseCapability, SourceLifecycle {
  bool disposed = false;

  @override
  final descriptor = const SourceDescriptor(
    id: SourceId('fake-files'),
    kind: SourceKind.smb,
    name: 'Fake files',
  );

  @override
  final capabilities = const <FileCapability>{FileCapability.browse};

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Future<DirectoryListing> listDirectory(
    FilePath path, {
    bool refresh = false,
  }) async => const DirectoryListing(
        currentPath: FilePath(sourceId: SourceId('fake-files'), value: ''),
        entries: <FileEntry>[],
      );

  @override
  Future<FileEntry> stat(FilePath path) => throw UnimplementedError();

  @override
  Future<bool> exists(FilePath path) => throw UnimplementedError();

  @override
  Future<FileEntry> validatePath(FilePath path) => throw UnimplementedError();

  @override
  Future<void> dispose() async => disposed = true;
}

// ==================== 原 test/core/webdav_file_source_range_test.dart ====================
void _main_1() {
  test('WebDAV 文件访问暴露可直接播放的 HTTP URL 和认证头', () async {
    final bytes = List<int>.generate(8, (index) => index);
    final fixture = await _WebDavFixture.start(bytes);
    final sourceId = SourceId.of('webdav-direct');
    final source = await WebDavFileSource.connect(
      id: sourceId.value,
      name: '测试 WebDAV',
      options: WebDavConnectionOptions(
        uri: fixture.baseUri.replace(path: '/dav/').toString(),
        port: fixture.server.port,
        user: 'alice',
        password: 'secret',
      ),
    );
    try {
      final access = await source.resolveAccess(
        FilePath(sourceId: sourceId, value: '/movie.mp4'),
      );
      expect(
        access.uri,
        fixture.baseUri.replace(path: '/dav/movie.mp4'),
      );
      expect(access.size, bytes.length);
      expect(access.mimeType, 'video/mp4');
      expect(access.headers['Authorization'], 'Basic YWxpY2U6c2VjcmV0');
    } finally {
      await source.dispose();
      await fixture.close();
    }
  });

  test('WebDAV Range 请求透传并校验 206 响应', () async {
    final bytes = List<int>.generate(32, (index) => index + 1);
    final fixture = await _WebDavFixture.start(bytes);
    final sourceId = SourceId.of('webdav-range');
    final source = await WebDavFileSource.connect(
      id: sourceId.value,
      name: '测试 WebDAV',
      options: WebDavConnectionOptions(
        uri: fixture.baseUri.toString(),
        port: fixture.server.port,
      ),
    );
    try {
      final path = FilePath(sourceId: sourceId, value: '/movie.mp4');
      final stream = await source.openRange(path, offset: 7, length: 9);
      expect(
        await stream.expand((chunk) => chunk).toList(),
        bytes.sublist(7, 16),
      );
      expect(fixture.ranges, ['bytes=7-15']);

      await expectLater(
        source.openRange(path, offset: bytes.length, length: 1),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('区间超出文件范围'),
          ),
        ),
      );
    } finally {
      await source.dispose();
      await fixture.close();
    }
  });

  test('WebDAV 忽略 Range 时代理回退到临时文件', () async {
    final bytes = List<int>.generate(24, (index) => 255 - index);
    final fixture = await _WebDavFixture.start(bytes, ignoreRange: true);
    final sourceId = SourceId.of('webdav-fallback');
    final source = await WebDavFileSource.connect(
      id: sourceId.value,
      name: '测试 WebDAV',
      options: WebDavConnectionOptions(
        uri: fixture.baseUri.toString(),
        port: fixture.server.port,
      ),
    );
    final proxy = await FilePlaybackProxy.start(
      repository: FileSourceRepository(source),
      path: FilePath(sourceId: sourceId, value: '/movie.mp4'),
      size: bytes.length,
      mimeType: 'video/mp4',
      pathExtension: 'mp4',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(proxy.uri);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=8-13');
      final response = await request.close();
      final body = <int>[];
      await for (final chunk in response) {
        body.addAll(chunk);
      }
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.contentLength, 6);
      expect(body, bytes.sublist(8, 14));
      expect(fixture.ranges, ['bytes=8-13']);
      expect(fixture.fullGets, 1);
    } finally {
      await proxy.close();
      client.close(force: true);
      await source.dispose();
      await fixture.close();
    }
  });
}

class _WebDavFixture {
  _WebDavFixture(this.server, this.bytes, {required this.ignoreRange});

  final HttpServer server;
  final List<int> bytes;
  final bool ignoreRange;
  final ranges = <String>[];
  var fullGets = 0;

  Uri get baseUri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.host,
    port: server.port,
    path: '/',
  );

  static Future<_WebDavFixture> start(
    List<int> bytes, {
    bool ignoreRange = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _WebDavFixture(server, bytes, ignoreRange: ignoreRange);
    server.listen(fixture._handle);
    return fixture;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }
    if (request.method == 'PROPFIND') {
      response.statusCode = 207;
      response.headers.contentType = ContentType('application', 'xml');
      response.write('''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/movie.mp4</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype/>
        <d:getcontentlength>${bytes.length}</d:getcontentlength>
        <d:getcontenttype>video/mp4</d:getcontenttype>
        <d:getetag>"fixture"</d:getetag>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>''');
      await response.close();
      return;
    }
    if (request.method == 'GET') {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range == null) {
        fullGets++;
        response.statusCode = HttpStatus.ok;
        response.headers.contentLength = bytes.length;
        response.add(bytes);
        await response.close();
        return;
      }
      ranges.add(range);
      if (ignoreRange) {
        response.statusCode = HttpStatus.ok;
        response.headers.contentLength = bytes.length;
        response.add(bytes);
        await response.close();
        return;
      }
      final match = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range);
      final start = int.tryParse(match?.group(1) ?? '');
      final end = int.tryParse(match?.group(2) ?? '');
      if (start == null ||
          end == null ||
          start < 0 ||
          start >= bytes.length ||
          end < start) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${bytes.length}',
        );
        await response.close();
        return;
      }
      final boundedEnd = end.clamp(start, bytes.length - 1).toInt();
      response.statusCode = HttpStatus.partialContent;
      response.headers.contentLength = boundedEnd - start + 1;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$boundedEnd/${bytes.length}',
      );
      response.add(bytes.sublist(start, boundedEnd + 1));
      await response.close();
      return;
    }
    response.statusCode = HttpStatus.methodNotAllowed;
    await response.close();
  }

  Future<void> close() => server.close(force: true);
}

// ==================== 原 test/core/sources/file_playback_progress_test.dart ====================
void _main_2() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('按文件名保存并读取续播位置，忽略目录和服务器', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 42,
      durationSec: 300,
    );

    final progress = repository.load('aaa.mp4');
    expect(progress?.positionSec, 42);
    expect(progress?.durationSec, 300);
    expect(progress?.percentage, 14);
    expect(repository.load('different-server/aaa.mp4')?.percentage, 14);
    expect(repository.load(r'other-directory\aaa.mp4')?.percentage, 14);
    expect(repository.load('bbb.mp4'), isNull);
  });

  test('播放到末尾附近会清除续播位置', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 285,
      durationSec: 300,
    );

    expect(repository.load('aaa.mp4'), isNull);
  });

  test('播放进度小于5%时不保存续播记录，并清除已有记录', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 42,
      durationSec: 300,
    );
    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 14,
      durationSec: 300,
    );

    expect(repository.load('aaa.mp4'), isNull);
  });

  test('播放进度达到5%时才保存续播记录', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 15,
      durationSec: 300,
    );

    expect(repository.load('aaa.mp4')?.positionSec, 15);
  });

  test('已有的低于5%续播记录不会被恢复', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);
    final key =
        'file.playback.position.${base64Url.encode(utf8.encode('aaa.mp4'))}';
    await prefs.setString(
      key,
      jsonEncode({'position_sec': 14, 'duration_sec': 300}),
    );

    expect(repository.load('aaa.mp4'), isNull);
  });
}

void main() {
  group('sources', _main_0);
  group('webdav_file_source_range', _main_1);
  group('file_playback_progress', _main_2);
}
