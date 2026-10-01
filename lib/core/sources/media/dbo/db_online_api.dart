import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_search.dart';
import 'package:omm/core/sources/media/dbo/db_online_subtitle.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription_api.dart';
import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/error_codes.dart';

class DbOnlineApi {
  DbOnlineApi(Dio dio)
    : _dio = dio,
      subscriptions = DbOnlineSubscriptionApi(dio);

  final Dio _dio;
  final DbOnlineSubscriptionApi subscriptions;

  /// 读取 DBO 后台配置。配置接口返回完整配置，但未鉴权时只包含公开字段。
  Future<Map<String, dynamic>> getBackendConfig() async {
    final response = await _dio.get<dynamic>('/config');
    return unwrapStd<Map<String, dynamic>>(response.data, (data) {
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    });
  }

  /// 局部更新 DBO 后台配置，body 只应包含正在编辑的顶层分区。
  Future<Map<String, dynamic>> updateBackendConfig(
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.put<dynamic>('/config', data: body);
    return unwrapStd<Map<String, dynamic>>(response.data, (data) {
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    });
  }

  /// 测试 DBO 后台配置中的外部服务连接。
  Future<Map<String, dynamic>> testBackendConnection(
    String name,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<dynamic>(
      '/${Uri.encodeComponent(name)}/test',
      data: body,
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return <String, dynamic>{};
  }

  Future<List<DbOnlineMovie>> recommend({int page = 1, int limit = 9}) {
    return _movies('/recommend', {'page': page, 'limit': limit});
  }

  Future<List<DbOnlineMovie>> latest({
    int page = 1,
    int limit = 9,
    String? sortBy,
    String? sort,
  }) async {
    return (await latestPage(
      page: page,
      limit: limit,
      sortBy: sortBy,
      sort: sort,
    )).movies;
  }

  /// 获取 dbonline 最新影片的一页。
  ///
  /// `sort` 是移动端新约定；`sort_by` 保留给当前 dbonline 后端，两个
  /// 参数同时发送可兼容已经发布的服务端和使用新参数名的服务端。
  /// 不按在线播放能力筛选影片；响应中的 `can_play` 仅供播放入口判断。
  Future<DbOnlineMoviePage> latestPage({
    int page = 1,
    int limit = 9,
    String? sortBy,
    String? sort,
  }) {
    final sortValue = (sort ?? sortBy ?? 'update').trim();
    return _moviesPage('/latest', {
      'page': page,
      'limit': limit,
      'type': 'all',
      'sort': sortValue,
      'sort_by': sortValue,
    });
  }

  /// 获取 dbonline 影片库的一页。
  ///
  /// `/subs/tags` 使用 `filter_by` 的第一段表示影片分类，第二段固定为
  /// `t`。不按在线播放能力筛选，`can_play` 仅供播放入口判断。
  Future<DbOnlineMoviePage> taggedMoviesPage({
    String filterBy = '0:t:::::',
    int page = 1,
    int limit = 24,
    String sortBy = 'update',
    String orderBy = 'desc',
  }) {
    final normalizedFilter = filterBy.trim();
    if (normalizedFilter.isEmpty) {
      throw ArgumentError.value(filterBy, 'filterBy', AppErrorCode.validationFailed);
    }
    final normalizedSort = sortBy.trim();
    if (normalizedSort != 'update' && normalizedSort != 'release') {
      throw ArgumentError.value(sortBy, 'sortBy', AppErrorCode.validationFailed);
    }
    final normalizedOrder = orderBy.trim();
    if (normalizedOrder != 'asc' && normalizedOrder != 'desc') {
      throw ArgumentError.value(orderBy, 'orderBy', AppErrorCode.validationFailed);
    }
    return _moviesPage('/subs/tags', {
      'filter_by': normalizedFilter,
      'page': page,
      'limit': limit,
      'sort_by': normalizedSort,
      'order_by': normalizedOrder,
    });
  }

  /// 按关键词获取 dbonline 搜索结果的一页。
  ///
  /// 搜索接口的电影类型必须显式传递，避免服务端默认值变化导致结果
  /// 混入其他实体类型。响应中的 `can_play` 仅供播放入口判断，不作为搜索
  /// 过滤条件。响应沿用首页列表的 `data.movies` 解析逻辑。
  Future<DbOnlineMoviePage> searchPage({
    required String query,
    int page = 1,
    int limit = 24,
  }) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(query, 'query', AppErrorCode.validationFailed);
    }
    return _moviesPage('/search', {
      'q': normalized,
      'type': 'movie',
      'page': page,
      'limit': limit,
      'movie_type': 'all',
      'movie_sort_by': 'relevance',
    });
  }

  /// 搜索 dbonline 演员。该接口返回一次性结果，不提供影片列表式分页。
  Future<DbOnlineActorSearchResult> searchActors({
    required String query,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(query, 'query', AppErrorCode.validationFailed);
    }
    final response = await _dio.get<dynamic>(
      '/search/actors',
      queryParameters: {'q': normalized},
    );
    return unwrapStd<DbOnlineActorSearchResult>(response.data, (data) {
      if (data is! Map) {
        return const DbOnlineActorSearchResult(
          actors: <DbOnlineActorSearchItem>[],
        );
      }
      final rawActors = data['actors'];
      final actors = rawActors is List
          ? rawActors
                .map(DbOnlineActorSearchItem.fromJson)
                .where((actor) => actor.id.isNotEmpty && actor.name.isNotEmpty)
                .toList(growable: false)
          : const <DbOnlineActorSearchItem>[];
      return DbOnlineActorSearchResult(
        actors: actors,
        total: _intValue(data['total']) ?? actors.length,
      );
    });
  }

  /// 搜索 dbonline 系列。系列搜索沿用通用搜索接口的实体响应格式。
  Future<DbOnlineSearchEntityPage> searchSeriesPage({
    required String query,
    int page = 1,
    int limit = 24,
  }) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(query, 'query', AppErrorCode.validationFailed);
    }
    return _searchEntitiesPage('/search', {
      'q': normalized,
      'type': 'series',
      'page': page,
      'limit': limit,
      'movie_type': 'all',
      'movie_sort_by': 'relevance',
    });
  }

  /// 按番号获取影片详情。dbonline 使用字符串番号作为稳定标识，不能
  /// 转换为 Oh My Media 的整数影片 ID。每次请求都会强制携带 refresh=true。
  Future<DbOnlineMovieDetail> detail(
    String code, {
    bool refresh = false,
    String? videoId,
  }) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', AppErrorCode.validationFailed);
    }
    final query = <String, dynamic>{
      'refresh': true,
      if (videoId?.trim().isNotEmpty == true) 'video_id': videoId!.trim(),
    };
    final response = await _dio.get<dynamic>(
      '/video/${Uri.encodeComponent(normalized)}',
      queryParameters: query.isEmpty ? null : query,
    );
    return unwrapStd<DbOnlineMovieDetail>(
      response.data,
      (data) =>
          DbOnlineMovieDetail.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  /// 通过 dbonline/JavDB 的 video_id 获取详情，适用于番号尚未写入本地
  /// 数据库的推荐结果。每次请求都会强制携带 refresh=true。
  Future<DbOnlineMovieDetail> detailByVideoId(
    String videoId, {
    bool refresh = false,
  }) async {
    final normalized = videoId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(videoId, 'videoId', AppErrorCode.validationFailed);
    }
    final response = await _dio.get<dynamic>(
      '/video/id/${Uri.encodeComponent(normalized)}',
      queryParameters: const {'refresh': true},
    );
    return unwrapStd<DbOnlineMovieDetail>(
      response.data,
      (data) =>
          DbOnlineMovieDetail.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<DbOnlineExternalResources> customResources(String code) =>
      _externalResources('custom', code);

  Future<DbOnlineExternalResources> nyaaResources(String code) =>
      _externalResources('nyaa', code);

  /// 查询番号下成功下载过的资源哈希和时间。
  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  downloadHistory(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', AppErrorCode.validationFailed);
    }
    final response = await _dio.get<dynamic>(
      '/video/${Uri.encodeComponent(normalized)}/download-history',
    );
    return unwrapStd<
      ({Map<String, String> magnets, Map<String, String> ed2ks})
    >(response.data, (data) {
      Map<String, String> normalize(Object? value) {
        if (value is! Map) return <String, String>{};
        final result = <String, String>{};
        for (final entry in value.entries) {
          final hash = entry.key.toString().trim().toUpperCase();
          if (hash.isNotEmpty) result[hash] = (entry.value ?? '').toString();
        }
        return result;
      }

      if (data is Map) {
        return (
          magnets: normalize(data['magnets']),
          ed2ks: normalize(data['ed2ks']),
        );
      }
      return (magnets: <String, String>{}, ed2ks: <String, String>{});
    });
  }

  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders() async {
    final response = await _dio.get<dynamic>('/downloaders');
    return unwrapStd<
      List<({String name, String displayName, bool? ed2kEnabled})>
    >(response.data, (data) {
      final items = data is Map && data['downloaders'] is List
          ? data['downloaders'] as List
          : data is List
          ? data
          : const [];
      return items
          .whereType<Map>()
          .map((item) {
            final json = Map<String, dynamic>.from(item);
            final name = (json['name'] ?? '').toString().trim();
            final displayName =
                (json['display_name'] ?? json['displayName'] ?? name)
                    .toString()
                    .trim();
            final ed2kEnabled = json['ed2k_enabled'] is bool
                ? json['ed2k_enabled'] as bool
                : null;
            return (
              name: name,
              displayName: displayName,
              ed2kEnabled: ed2kEnabled,
            );
          })
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<({String message, String downloader})> pushDownload({
    required List<String> urls,
    required String downloader,
    required Map<String, dynamic> videoInfo,
    required List<Map<String, dynamic>> recordResources,
  }) async {
    final response = await _dio.post<dynamic>(
      '/download',
      data: {
        'urls': urls,
        'downloader': downloader,
        'save_path': '',
        'video_info': videoInfo,
        'record_resources': recordResources,
      },
    );
    final data = unwrapStd<Map<String, dynamic>>(
      response.data,
      (value) => value is Map ? Map<String, dynamic>.from(value) : const {},
    );
    return (
      message: envelopeMessageOrNull(response.data) ?? '',
      downloader: (data['downloader'] ?? downloader).toString(),
    );
  }

  Future<DbOnlineExternalResources> _externalResources(
    String source,
    String code,
  ) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', AppErrorCode.validationFailed);
    }
    final response = await _dio.get<dynamic>(
      '/external-magnets/$source/${Uri.encodeComponent(normalized)}',
    );
    return unwrapStd<DbOnlineExternalResources>(
      response.data,
      DbOnlineExternalResources.fromJson,
    );
  }

  /// 获取 dbonline 在线播放剧集和清晰度。source_id 必须是详情接口返回
  /// 的正整数播放源 ID；video_id 可选，后端会按番号回查。
  Future<DbOnlinePlayEpisodes> onlinePlayEpisodes(
    String code, {
    required int sourceId,
    String? videoId,
  }) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', AppErrorCode.validationFailed);
    }
    if (sourceId <= 0) {
      throw ArgumentError.value(sourceId, 'sourceId', AppErrorCode.validationFailed);
    }
    final response = await _dio.get<dynamic>(
      '/video/${Uri.encodeComponent(normalized)}/online-play/episodes',
      queryParameters: {
        'source_id': sourceId,
        if (videoId?.trim().isNotEmpty == true) 'video_id': videoId!.trim(),
      },
    );
    return unwrapStd<DbOnlinePlayEpisodes>(
      response.data,
      (data) =>
          DbOnlinePlayEpisodes.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<List<DbOnlineSubtitleFile>> findSubtitles(String code) async {
    final response = await _dio.get<dynamic>(
      '/subtitle/find/${Uri.encodeComponent(code.trim())}',
    );
    return unwrapStd<List<DbOnlineSubtitleFile>>(response.data, (data) {
      if (data is! Map || data['files'] is! List) {
        return const <DbOnlineSubtitleFile>[];
      }
      return (data['files'] as List)
          .map(DbOnlineSubtitleFile.fromJson)
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<List<DbOnlineSubtitleCandidate>> searchExternalSubtitles(
    String code,
  ) async {
    final response = await _dio.get<dynamic>(
      '/subtitle/external/search/${Uri.encodeComponent(code.trim())}',
    );
    return unwrapStd<List<DbOnlineSubtitleCandidate>>(response.data, (data) {
      if (data is! Map || data['items'] is! List) {
        return const <DbOnlineSubtitleCandidate>[];
      }
      return (data['items'] as List)
          .map(DbOnlineSubtitleCandidate.fromJson)
          .where((item) => item.name.isNotEmpty && item.url.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<DbOnlineSubtitlePreview> previewLocalSubtitle(String id) async {
    final response = await _dio.get<dynamic>(
      '/subtitle/preview',
      queryParameters: {'id': id},
    );
    return unwrapStd<DbOnlineSubtitlePreview>(
      response.data,
      DbOnlineSubtitlePreview.fromJson,
    );
  }

  Future<DbOnlineSubtitlePreview> previewExternalSubtitle(String url) async {
    final response = await _dio.get<dynamic>(
      '/subtitle/external/preview',
      queryParameters: {'url': url},
    );
    return unwrapStd<DbOnlineSubtitlePreview>(
      response.data,
      DbOnlineSubtitlePreview.fromJson,
    );
  }

  Future<Uint8List> downloadLocalSubtitle(String id) async {
    final response = await _dio.get<List<int>>(
      '/subtitle/download',
      queryParameters: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  Future<Uint8List> downloadExternalSubtitle({
    required String url,
    required String name,
    required String extension,
  }) async {
    final response = await _dio.get<List<int>>(
      '/subtitle/external/download',
      queryParameters: {'url': url, 'name': name, 'ext': extension},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  Future<List<DbOnlineMovie>> _movies(
    String path,
    Map<String, dynamic> query,
  ) async {
    return (await _moviesPage(path, query)).movies;
  }

  Future<DbOnlineMoviePage> _moviesPage(
    String path,
    Map<String, dynamic> query,
  ) async {
    final response = await _dio.get<dynamic>(path, queryParameters: query);
    return unwrapStd<DbOnlineMoviePage>(response.data, (data) {
      if (data is! Map) {
        return DbOnlineMoviePage(
          movies: const <DbOnlineMovie>[],
          page: _intValue(query['page']) ?? 1,
          limit: _intValue(query['limit']) ?? 0,
          hasMore: false,
        );
      }
      final movies = data['movies'];
      final items = movies is List
          ? movies
                .whereType<Map>()
                .map(
                  (item) =>
                      DbOnlineMovie.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <DbOnlineMovie>[];
      final page = _intValue(query['page']) ?? 1;
      final limit = _intValue(query['limit']) ?? items.length;
      final total = _intValue(data['total']);
      final explicitHasMore = data['has_more'];
      final hasMore = explicitHasMore is bool
          ? explicitHasMore
          : total != null && total > page * limit
          ? true
          : items.length >= limit && limit > 0;
      return DbOnlineMoviePage(
        movies: items,
        page: page,
        limit: limit,
        total: total,
        hasMore: hasMore,
      );
    });
  }

  Future<DbOnlineSearchEntityPage> _searchEntitiesPage(
    String path,
    Map<String, dynamic> query,
  ) async {
    final response = await _dio.get<dynamic>(path, queryParameters: query);
    return unwrapStd<DbOnlineSearchEntityPage>(response.data, (data) {
      if (data is! Map) {
        return DbOnlineSearchEntityPage(
          items: const <DbOnlineSearchEntity>[],
          page: _intValue(query['page']) ?? 1,
          limit: _intValue(query['limit']) ?? 0,
          hasMore: false,
        );
      }
      final rawItems = data['items'];
      final items = rawItems is List
          ? rawItems
                .map(DbOnlineSearchEntity.fromJson)
                .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
                .toList(growable: false)
          : const <DbOnlineSearchEntity>[];
      final page = _intValue(query['page']) ?? 1;
      final limit = _intValue(query['limit']) ?? items.length;
      final total = _intValue(data['total']);
      final explicitHasMore = data['has_more'];
      final hasMore = explicitHasMore is bool
          ? explicitHasMore
          : total != null && total > page * limit
          ? true
          : items.length >= limit && limit > 0;
      return DbOnlineSearchEntityPage(
        items: items,
        page: page,
        limit: limit,
        total: total,
        hasMore: hasMore,
      );
    });
  }
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
