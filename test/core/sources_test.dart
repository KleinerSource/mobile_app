import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/api/db_online_api.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/sources.dart';

void main() {
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
  Future<DirectoryListing> listDirectory(FilePath path) async =>
      const DirectoryListing(
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
