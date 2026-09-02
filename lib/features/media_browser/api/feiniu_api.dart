import 'package:dio/dio.dart';

import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config.dart';

import 'feiniu_models.dart';

class FeiniuApi {
  FeiniuApi(this._dio);

  final Dio _dio;

  Future<FeiniuVersion> version() async {
    final response = await _dio.get<dynamic>(
      '/sys/version',
      options: Options(extra: const {'skipAuth': true, 'skipRetry': true}),
    );
    return _unwrap(response.data, (data) => FeiniuVersion.fromJson(_map(data)));
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<dynamic>(
      '/login',
      data: {
        'app_name': 'trimemedia-web',
        'username': username.trim(),
        'password': password,
      },
      options: Options(extra: const {'skipAuth': true, 'skipRetry': true}),
    );
    final data = _unwrap(response.data, (value) => _map(value));
    final token = _string(data['token'] ?? data['access_token']);
    if (token.isEmpty) throw ApiException('飞牛登录响应缺少访问令牌');
    return token;
  }

  Future<FeiniuUser> userInfo() async {
    final response = await _dio.get<dynamic>('/user/info');
    return _unwrap(response.data, (data) => FeiniuUser.fromJson(_map(data)));
  }

  Future<void> logout() async {
    final response = await _dio.post<dynamic>(
      '/logout',
      options: Options(extra: const {'skipRetry': true}),
    );
    _unwrap(response.data, (_) {});
  }

  Future<List<FeiniuMediaDb>> mediaDbList() async {
    final response = await _dio.get<dynamic>('/mediadb/list');
    return _unwrap(response.data, (data) {
      final raw = data is Map ? data['list'] ?? data['items'] : data;
      if (raw is! List) return const <FeiniuMediaDb>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => FeiniuMediaDb.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.guid.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<int> mediaDbSum() async {
    final response = await _dio.get<dynamic>('/mediadb/sum');
    return _unwrap(response.data, (data) {
      if (data is num) return data.toInt();
      if (data is Map) {
        return _int(data['sum'] ?? data['total'] ?? data['count']);
      }
      return 0;
    });
  }

  Future<FeiniuItemPage> itemList({
    String parentGuid = '',
    bool excludeFolder = true,
    String sortColumn = 'sort_title',
    String sortType = 'ASC',
    String? searchTerm,
    int startIndex = 0,
    int limit = 24,
  }) async {
    final body = <String, dynamic>{
      'parent_guid': parentGuid,
      'exclude_folder': excludeFolder ? 1 : 0,
      'sort_column': sortColumn,
      'sort_type': sortType,
      if (searchTerm?.trim().isNotEmpty == true) 'search': searchTerm!.trim(),
      'start_index': startIndex,
      'limit': limit,
    };
    final response = await _dio.post<dynamic>('/item/list', data: body);
    return _unwrap(
      response.data,
      (data) =>
          FeiniuItemPage.fromData(data, startIndex: startIndex, limit: limit),
    );
  }

  Future<FeiniuItem> item(String guid) async {
    final response = await _dio.get<dynamic>(
      '/item/${Uri.encodeComponent(guid)}',
    );
    return _unwrap(response.data, (data) => FeiniuItem.fromJson(_map(data)));
  }

  Future<List<FeiniuItem>> favoriteList({
    int startIndex = 0,
    int limit = 100,
  }) async {
    final response = await _dio.post<dynamic>(
      '/favorite/list',
      data: {'start_index': startIndex, 'limit': limit},
    );
    return _unwrap(response.data, (data) => _items(data));
  }

  Future<FeiniuItemPage> playList({int startIndex = 0, int limit = 24}) async {
    final response = await _dio.post<dynamic>(
      '/play/list',
      data: {'start_index': startIndex, 'limit': limit},
    );
    return _unwrap(
      response.data,
      (data) =>
          FeiniuItemPage.fromData(data, startIndex: startIndex, limit: limit),
    );
  }

  Future<List<FeiniuItem>> episodeList(String guid) async {
    final response = await _dio.get<dynamic>(
      '/episode/list/${Uri.encodeComponent(guid)}',
    );
    return _unwrap(response.data, (data) => _items(data));
  }

  Future<FeiniuStreamList> streamList(String guid) async {
    final response = await _dio.get<dynamic>(
      '/stream/list/${Uri.encodeComponent(guid)}',
    );
    return _unwrap(response.data, (data) => FeiniuStreamList.fromData(data));
  }

  Future<FeiniuPlayInfo> playInfo({
    required String itemGuid,
    String? mediaGuid,
    String? videoGuid,
    String? audioGuid,
    String? subtitleGuid,
  }) async {
    final response = await _dio.post<dynamic>(
      '/play/info',
      data: {
        'item_guid': itemGuid,
        if (_nonEmpty(mediaGuid)) 'media_guid': mediaGuid,
        if (_nonEmpty(videoGuid)) 'video_guid': videoGuid,
        if (_nonEmpty(audioGuid)) 'audio_guid': audioGuid,
        if (_nonEmpty(subtitleGuid)) 'subtitle_guid': subtitleGuid,
      },
      options: Options(extra: const {'skipRetry': true}),
    );
    return _unwrap(response.data, (data) => FeiniuPlayInfo.fromData(data));
  }

  Future<void> markWatched(String guid, bool watched) async {
    final response = watched
        ? await _dio.post<dynamic>('/item/watched', data: {'item_guid': guid})
        : await _dio.delete<dynamic>(
            '/item/watched',
            data: {'item_guid': guid},
          );
    _unwrap(response.data, (_) {});
  }

  Future<void> markFavorite(String guid, bool favorite) async {
    final response = favorite
        ? await _dio.put<dynamic>('/item/favorite', data: {'item_guid': guid})
        : await _dio.delete<dynamic>(
            '/item/favorite',
            data: {'item_guid': guid},
          );
    _unwrap(response.data, (_) {});
  }

  Future<void> recordPlay(FeiniuPlayRecord record) async {
    final response = await _dio.post<dynamic>(
      '/play/record',
      data: record.toJson(),
    );
    _unwrap(response.data, (_) {});
  }

  Future<void> stopPlay({required String itemGuid, String? mediaGuid}) async {
    final response = await _dio.delete<dynamic>(
      '/play/record',
      data: {
        'item_guid': itemGuid,
        if (_nonEmpty(mediaGuid)) 'media_guid': mediaGuid,
      },
      options: Options(extra: const {'skipRetry': true}),
    );
    _unwrap(response.data, (_) {});
  }

  static String mediaRangeUrl(String baseUrl, String mediaGuid) {
    final base = Uri.parse(
      ServerConfig.normalizeForProject(baseUrl, ServerProject.feiniu),
    );
    return base
        .replace(
          path:
              '${base.path}/api/v1/media/range/${Uri.encodeComponent(mediaGuid)}',
        )
        .toString();
  }

  static String resolveUrl(String baseUrl, String rawUrl) {
    final value = rawUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    if (uri.hasScheme) return value;
    final base = Uri.parse(
      ServerConfig.normalizeForProject(baseUrl, ServerProject.feiniu),
    );
    if (value.startsWith('/')) {
      var path = value;
      if (path.toLowerCase() == '/api/v1' ||
          path.toLowerCase().startsWith('/api/v1/')) {
        path = '/v$path';
      }
      return base.replace(path: path).toString();
    }
    return base.replace(path: '${base.path}/').resolve(value).toString();
  }

  static String resolveAssetUrl(String baseUrl, String? rawUrl) {
    final value = rawUrl?.trim() ?? '';
    if (value.isEmpty) return '';
    return resolveUrl(baseUrl, value);
  }

  static Map<String, String> mediaHeaders(String? token) => {
    if (_nonEmpty(token)) 'Authorization': token!.trim(),
    'X-Trim-Client': 'web',
    'X-Trim-Client-Version': '616',
  };

  T _unwrap<T>(Object? raw, T Function(Object? data) parser) {
    if (raw is! Map) throw ApiException('飞牛响应格式无效');
    final map = Map<String, dynamic>.from(raw);
    final code = _int(map['code']);
    if (code != 0) {
      throw ApiException(
        _string(map['msg']).isEmpty ? '飞牛请求失败（$code）' : _string(map['msg']),
        data: map['data'],
      );
    }
    return parser(map['data']);
  }

  List<FeiniuItem> _items(Object? data) {
    final raw = data is Map ? data['list'] ?? data['items'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => FeiniuItem.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.guid.isNotEmpty)
        .toList(growable: false);
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _string(Object? value) => value?.toString().trim() ?? '';

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

bool _nonEmpty(String? value) => value?.trim().isNotEmpty == true;
