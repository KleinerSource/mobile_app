import 'package:dio/dio.dart';

import '../../models/db_online_movie.dart';
import '../envelope.dart';

class DbOnlineApi {
  DbOnlineApi(this._dio);

  final Dio _dio;

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
  /// 默认仅返回支持在线播放的影片。
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
      'filter_by': 'can_play',
    });
  }

  /// 按关键词获取 dbonline 搜索结果的一页。
  ///
  /// 搜索接口的电影类型必须显式传递，避免服务端默认值变化导致结果
  /// 混入其他实体类型。默认只搜索支持在线播放的影片；DBO/JavDB 使用
  /// `can_play` 表示在线播。响应沿用首页列表的 `data.movies` 解析逻辑。
  Future<DbOnlineMoviePage> searchPage({
    required String query,
    int page = 1,
    int limit = 24,
  }) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(query, 'query', '搜索关键词不能为空');
    }
    return _moviesPage('/search', {
      'q': normalized,
      'type': 'movie',
      'page': page,
      'limit': limit,
      'movie_type': 'all',
      'movie_sort_by': 'relevance',
      'movie_filter_by': 'can_play',
    });
  }

  /// 按番号获取影片详情。dbonline 使用字符串番号作为稳定标识，不能
  /// 转换为 Oh-My-Media 的整数影片 ID。每次请求都会强制携带 refresh=true。
  Future<DbOnlineMovieDetail> detail(
    String code, {
    bool refresh = false,
    String? videoId,
  }) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', '番号不能为空');
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
      throw ArgumentError.value(videoId, 'videoId', '影片 ID 不能为空');
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

  /// 获取 dbonline 在线播放剧集和清晰度。source_id 必须是详情接口返回
  /// 的正整数播放源 ID；video_id 可选，后端会按番号回查。
  Future<DbOnlinePlayEpisodes> onlinePlayEpisodes(
    String code, {
    required int sourceId,
    String? videoId,
  }) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', '番号不能为空');
    }
    if (sourceId <= 0) {
      throw ArgumentError.value(sourceId, 'sourceId', '播放源 ID 必须为正整数');
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
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
