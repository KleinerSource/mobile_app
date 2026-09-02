import 'package:dio/dio.dart';

import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config.dart';

import 'feiniu_models.dart';

class FeiniuApi {
  FeiniuApi(this._dio);

  final Dio _dio;

  /// 最近一次登录响应中的会话 Cookie，供 AuthController 持久化。
  String? _lastLoginCookie;

  String? get lastLoginCookie => _lastLoginCookie;

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
    // 避免上一次登录残留的 Cookie 被误用于本次登录。
    _lastLoginCookie = null;
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
    _lastLoginCookie = _cookieHeader(response.headers);
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
      final raw = data is Map
          ? data['list'] ?? data['items'] ?? data['databases']
          : data;
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
    List<String>? typeTags,
  }) async {
    final pageSize = limit < 1 ? 1 : limit;
    final page = startIndex < 1 ? 1 : startIndex ~/ pageSize + 1;
    final body = <String, dynamic>{
      'ancestor_guid': parentGuid,
      'tags': {
        'type':
            typeTags ??
            (excludeFolder
                ? const ['Movie', 'TV']
                : const ['Movie', 'TV', 'Directory']),
      },
      'sort_column': sortColumn,
      'sort_type': sortType,
      if (searchTerm?.trim().isNotEmpty == true) 'search': searchTerm!.trim(),
      'page': page,
      'page_size': pageSize,
      'exclude_grouped_video': 1,
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
    return _unwrap(response.data, (data) {
      final map = _map(data);
      final item = map['item'];
      if (item is! Map) return FeiniuItem.fromJson(map);
      return FeiniuItem.fromJson({...map, ...Map<String, dynamic>.from(item)});
    });
  }

  Future<List<FeiniuPerson>> personList(String guid) async {
    final response = await _dio.post<dynamic>(
      '/person/list/${Uri.encodeComponent(guid)}',
      data: const {'page': 1, 'page_size': 200},
    );
    return _unwrap(response.data, (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : const {};
      final raw =
          map['list'] ??
          map['items'] ??
          map['persons'] ??
          map['people'] ??
          (data is List ? data : null);
      if (raw is! List) return const <FeiniuPerson>[];
      return raw
          .whereType<Map>()
          .map((item) => FeiniuPerson.fromJson(Map<String, dynamic>.from(item)))
          .where((person) => person.id.isNotEmpty || person.name.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<Map<String, String>> genreMap({String language = 'zh-CN'}) async {
    final response = await _dio.get<dynamic>(
      '/tag/genres',
      queryParameters: {'lan': language},
    );
    return _unwrap(response.data, _genreMap);
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

  Future<List<FeiniuItem>> seasonList(String guid) async {
    final response = await _dio.get<dynamic>(
      '/season/list/${Uri.encodeComponent(guid)}',
    );
    return _unwrap(
      response.data,
      (data) => _items(data, keys: const ['list', 'items', 'seasons']),
    );
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

  /// 外置字幕内容地址。飞牛流信息中的 [extra_file] 只是 0/1 标记，
  /// 实际字幕内容通过字幕 GUID 从该接口读取。
  static String subtitleUrl(String baseUrl, String subtitleGuid) {
    final base = Uri.parse(
      ServerConfig.normalizeForProject(baseUrl, ServerProject.feiniu),
    );
    return base
        .replace(
          path:
              '${base.path}/api/v1/subtitle/dl/${Uri.encodeComponent(subtitleGuid)}',
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

  static String resolveAssetUrl(String baseUrl, String? rawUrl, {int? width}) {
    final value = rawUrl?.trim() ?? '';
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    if (uri.hasScheme) {
      if (width == null || width <= 0 || uri.queryParameters.containsKey('w')) {
        return value;
      }
      return uri
          .replace(queryParameters: {...uri.queryParameters, 'w': '$width'})
          .toString();
    }

    final base = Uri.parse(
      ServerConfig.normalizeForProject(baseUrl, ServerProject.feiniu),
    );
    final rawPath = uri.path;
    final lowerPath = rawPath.toLowerCase();
    String? path;
    if (lowerPath == '/api/v1' || lowerPath.startsWith('/api/v1/')) {
      path = '/v$rawPath';
    } else if (lowerPath == '/v/api/v1' || lowerPath.startsWith('/v/api/v1/')) {
      path = rawPath;
    } else if (lowerPath == '/sys/img' || lowerPath.startsWith('/sys/img/')) {
      path = '${base.path}/api/v1$rawPath';
    } else if (lowerPath == '/sys/rimg' || lowerPath.startsWith('/sys/rimg/')) {
      path = '${base.path}/api/v1$rawPath';
    } else if (lowerPath == '/sys/progressthumb' ||
        lowerPath.startsWith('/sys/progressthumb/')) {
      path = '${base.path}/api/v1$rawPath';
    } else if (lowerPath == '/img' || lowerPath.startsWith('/img/')) {
      path = '${base.path}/api/v1$rawPath';
    } else if (lowerPath == '/mediadb' || lowerPath.startsWith('/mediadb/')) {
      path = '${base.path}/api/v1/sys/img$rawPath';
    } else if (lowerPath == 'sys/img' || lowerPath.startsWith('sys/img/')) {
      path = '${base.path}/api/v1/$rawPath';
    } else if (lowerPath == 'sys/rimg' || lowerPath.startsWith('sys/rimg/')) {
      path = '${base.path}/api/v1/$rawPath';
    } else if (lowerPath == 'mediadb' || lowerPath.startsWith('mediadb/')) {
      path = '${base.path}/api/v1/sys/img/$rawPath';
    } else if (lowerPath == 'img' || lowerPath.startsWith('img/')) {
      path = '${base.path}/api/v1/$rawPath';
    } else if (RegExp(
      r'^/[0-9a-fA-F]{2}/[0-9a-fA-F]{2}/[^/]+$',
    ).hasMatch(rawPath)) {
      // item/person 接口返回的是图片服务去掉了 /sys/img 的分片路径，
      // 例如 /55/02/<hash>.webp。
      path = '${base.path}/api/v1/sys/img$rawPath';
    } else {
      // 飞牛网页端对所有未带完整资源前缀的图片路径都使用 sys/img，
      // 包括没有前导斜线的 55/02/<hash>.webp。
      path =
          '${base.path}/api/v1/sys/img/${rawPath.replaceFirst(RegExp(r'^/+'), '')}';
    }
    var query = uri.hasQuery ? uri.query : '';
    if (width != null && width > 0 && !uri.queryParameters.containsKey('w')) {
      query = query.isEmpty ? 'w=$width' : '$query&w=$width';
    }
    return base
        .replace(
          path: path,
          query: query.isEmpty ? null : query,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
        .toString();
  }

  static Map<String, String> mediaHeaders(String? token, [String? cookie]) => {
    if (_nonEmpty(token)) 'Authorization': token!.trim(),
    if (_nonEmpty(cookie)) 'Cookie': cookie!.trim(),
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

  List<FeiniuItem> _items(
    Object? data, {
    List<String> keys = const ['list', 'items'],
  }) {
    Object? raw = data;
    if (data is Map) {
      raw = null;
      for (final key in keys) {
        if (data[key] != null) {
          raw = data[key];
          break;
        }
      }
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => FeiniuItem.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.guid.isNotEmpty)
        .toList(growable: false);
  }
}

Map<String, String> _genreMap(Object? data) {
  if (data is List) {
    final result = <String, String>{};
    for (final value in data) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      final id = _string(
        map['id'] ?? map['tag_id'] ?? map['genre_id'] ?? map['value'],
      );
      final name = _string(
        map['name'] ??
            map['title'] ??
            map['label'] ??
            map['tag_name'] ??
            map['genre_name'] ??
            map['text'] ??
            map['value'],
      );
      if (id.isNotEmpty && name.isNotEmpty) result[id] = name;
    }
    return result;
  }
  if (data is! Map) return const <String, String>{};
  final map = Map<String, dynamic>.from(data);
  for (final key in const ['list', 'items', 'genres', 'tags']) {
    if (map[key] != null) return _genreMap(map[key]);
  }
  final result = <String, String>{};
  for (final entry in map.entries) {
    final id = entry.key.trim();
    final value = entry.value;
    final name = value is Map
        ? _string(
            value['name'] ??
                value['title'] ??
                value['label'] ??
                value['tag_name'] ??
                value['genre_name'] ??
                value['value'],
          )
        : _string(value);
    if (id.isNotEmpty && name.isNotEmpty) result[id] = name;
  }
  return result;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _string(Object? value) => value?.toString().trim() ?? '';

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

bool _nonEmpty(String? value) => value?.trim().isNotEmpty == true;

String? _cookieHeader(Headers headers) {
  final values = headers['set-cookie'];
  if (values == null || values.isEmpty) return null;
  final cookies = <String>[];
  for (final value in values) {
    final cookie = value.split(';').first.trim();
    if (cookie.isEmpty || cookie.startsWith('=')) continue;
    if (!cookies.contains(cookie)) cookies.add(cookie);
  }
  return cookies.isEmpty ? null : cookies.join('; ');
}
