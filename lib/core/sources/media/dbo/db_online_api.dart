import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_watched.dart';
import 'package:omm/core/sources/media/dbo/db_online_search.dart';
import 'package:omm/core/sources/media/dbo/db_online_ranking_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_subtitle.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/core/sources/media/dbo/db_online_following_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record_api.dart';
import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/error_codes.dart';

class DbOnlineApi {
  DbOnlineApi(Dio dio)
    : _dio = dio,
      subscriptions = DbOnlineSubscriptionApi(dio),
      following = DbOnlineFollowingApi(dio),
      downloadRecords = DbOnlineDownloadRecordApi(dio),
      ranking = DbOnlineRankingApi(dio);

  final Dio _dio;
  final DbOnlineSubscriptionApi subscriptions;
  final DbOnlineFollowingApi following;
  final DbOnlineDownloadRecordApi downloadRecords;
  final DbOnlineRankingApi ranking;

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

  Future<Map<String, dynamic>> pan115Directories(Map<String, dynamic> config) =>
      _downloaderConfigOptions('/pan115/directories', config);

  Future<Map<String, dynamic>> thunderSelectOptions(
    Map<String, dynamic> config,
  ) => _downloaderConfigOptions('/thunder/select-options', config);

  Future<Map<String, dynamic>> openListToolPaths(Map<String, dynamic> config) =>
      _downloaderConfigOptions('/openlist/tool-paths', config);

  Future<List<Map<String, dynamic>>> mediaServerLibraries(
    String name,
    Map<String, dynamic> config,
  ) async {
    final response = await _dio.post<dynamic>(
      '/${Uri.encodeComponent(name)}/libraries',
      data: config,
    );
    return unwrapStd<List<Map<String, dynamic>>>(
      response.data,
      (data) => data is List
          ? data.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : [],
    );
  }

  Future<Map<String, dynamic>> libraryTaskStats({bool subtitles = false}) =>
      _libraryTaskRequest(subtitles ? '/subtitle/stats' : '/library/cache/stats');

  Future<Map<String, dynamic>> libraryTaskProgress({bool subtitles = false}) =>
      _libraryTaskRequest(
        subtitles ? '/subtitle/progress' : '/library/cache/refresh/progress',
      );

  Future<Map<String, dynamic>> startLibraryTask({
    bool subtitles = false,
    String mode = 'incremental',
  }) => _libraryTaskRequest(
    subtitles ? '/subtitle/scan' : '/library/cache/refresh',
    post: true,
    query: subtitles ? {'mode': mode} : null,
  );

  Future<Map<String, dynamic>> _libraryTaskRequest(
    String path, {
    bool post = false,
    Map<String, dynamic>? query,
  }) async {
    final response = post
        ? await _dio.post<dynamic>(path, queryParameters: query)
        : await _dio.get<dynamic>(path);
    final raw = response.data;
    // 字幕管理接口沿用 code / msg，其余媒体库接口使用 success / error。
    final envelope =
        path.startsWith('/subtitle/') &&
            raw is Map &&
            !raw.containsKey('success') &&
            raw.containsKey('code')
        ? {
            ...raw,
            'success': raw['code'] == 0,
            if (raw['code'] != 0) 'error': raw['msg'],
          }
        : raw;
    return unwrapStd<Map<String, dynamic>>(
      envelope,
      (data) => data is Map ? Map<String, dynamic>.from(data) : {},
    );
  }

  Future<Map<String, dynamic>> pan115Account() async {
    final response = await _dio.get<dynamic>(
      '/pan115/tasks',
      queryParameters: {'filter': 'downloading', 'page': 1, 'page_size': 1},
    );
    return unwrapStd<Map<String, dynamic>>(response.data, (data) {
      final account = data is Map ? data['account'] : null;
      return account is Map ? Map<String, dynamic>.from(account) : {};
    });
  }

  Future<Map<String, dynamic>> _downloaderConfigOptions(
    String path,
    Map<String, dynamic> config,
  ) async {
    final response = await _dio.post<dynamic>(path, data: config);
    return unwrapStd<Map<String, dynamic>>(
      response.data,
      (data) => data is Map ? Map<String, dynamic>.from(data) : {},
    );
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
  /// `t`，第三段 basic 为资源条件字母（m/c/s/p，p=可播放仅服务端
  /// `javdb_api.can_play` 开启时生效）。
  Future<DbOnlineMoviePage> taggedMoviesPage({
    String filterBy = dbOnlineFollowingDefaultFilterBy,
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

  /// 在线账户的已看清单使用额外一层 JavDB API data 信封。
  Future<DbOnlineMoviePage> watchedMoviesPage({
    DbOnlineWatchedFilter filter = const DbOnlineWatchedFilter(),
    int page = 1,
  }) async {
    final response = await _dio.get<dynamic>(
      '/subs/watched',
      queryParameters: {
        ...filter.toJson(),
        'page': page,
        'limit': DbOnlineWatchedFilter.pageSize,
      },
    );
    return unwrapStd<DbOnlineMoviePage>(response.data, (data) {
      final payload = data is Map ? data['data'] : null;
      final raw = payload is Map ? payload['movies'] : null;
      final movies = raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (item) =>
                      DbOnlineMovie.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <DbOnlineMovie>[];
      return DbOnlineMoviePage(
        movies: movies,
        page: page,
        limit: DbOnlineWatchedFilter.pageSize,
        hasMore: movies.length >= DbOnlineWatchedFilter.pageSize,
      );
    });
  }

  Future<int> recheckWatchedVideos({
    required DbOnlineWatchedFilter filter,
    required DbOnlineRecheckRequirements requirements,
  }) async {
    final response = await _dio.post<dynamic>(
      '/videos/recheck',
      data: {
        'scope': 'watched',
        'filters': filter.toJson(),
        'requirements': requirements.toJson(),
      },
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return unwrapStd<int>(
      response.data,
      (data) => data is Map ? _intValue(data['total']) ?? 0 : 0,
    );
  }

  /// 获取本地影片库的一页，与网页版影片库共享筛选与排序参数。
  Future<DbOnlineMoviePage> videoLibraryPage({
    int page = 1,
    int pageSize = 24,
    String sort = 'created',
    String order = 'desc',
    String resourceFilter = '',
    String userScore = '',
    String minScore = '',
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      'sort': sort,
      'order': order,
      if (resourceFilter.isNotEmpty) 'filter': resourceFilter,
      if (userScore.isNotEmpty) 'user_score': userScore,
      if (minScore.isNotEmpty) 'min_score': minScore,
    };
    final response = await _dio.get<dynamic>('/videos', queryParameters: query);
    return unwrapStd<DbOnlineMoviePage>(response.data, (data) {
      if (data is! Map) {
        return DbOnlineMoviePage(
          movies: const <DbOnlineMovie>[],
          page: page,
          limit: pageSize,
          hasMore: false,
        );
      }
      final rawVideos = data['videos'];
      final videos = rawVideos is List
          ? rawVideos
                .whereType<Map>()
                .map(
                  (item) =>
                      DbOnlineMovie.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <DbOnlineMovie>[];
      final currentPage = _intValue(data['page']) ?? page;
      final currentPageSize =
          _intValue(data['page_size'] ?? data['pageSize']) ?? pageSize;
      final total = _intValue(data['total']);
      final totalPages = _intValue(data['total_pages']);
      return DbOnlineMoviePage(
        movies: videos,
        page: currentPage,
        limit: currentPageSize,
        total: total,
        hasMore: totalPages != null
            ? currentPage < totalPages
            : videos.length >= currentPageSize && currentPageSize > 0,
      );
    });
  }

  /// 按关键词获取 dbonline 搜索结果的一页。
  ///
  /// 搜索接口的电影类型必须显式传递，避免服务端默认值变化导致结果
  /// 混入其他实体类型。`movieType`：all/0有码/1无码/2欧美/3FC2/4动漫；
  /// `movieSortBy`：relevance/release/update/score；`movieFilterBy` 是
  /// magnets/subtitle/single 按此顺序拼接的多选串，空等价于 all。
  /// 响应沿用首页列表的 `data.movies` 解析逻辑。
  Future<DbOnlineMoviePage> searchPage({
    required String query,
    int page = 1,
    int limit = 24,
    String movieType = 'all',
    String movieSortBy = 'relevance',
    String movieFilterBy = 'all',
  }) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(query, 'query', AppErrorCode.validationFailed);
    }
    final normalizedType = movieType.trim();
    if (!_searchMovieTypes.contains(normalizedType)) {
      throw ArgumentError.value(
        movieType,
        'movieType',
        AppErrorCode.validationFailed,
      );
    }
    final normalizedSort = movieSortBy.trim();
    if (!_searchMovieSortBys.contains(normalizedSort)) {
      throw ArgumentError.value(
        movieSortBy,
        'movieSortBy',
        AppErrorCode.validationFailed,
      );
    }
    final normalizedFilter = movieFilterBy.trim();
    return _moviesPage('/search', {
      'q': normalized,
      'type': 'movie',
      'page': page,
      'limit': limit,
      'movie_type': normalizedType,
      'movie_sort_by': normalizedSort,
      'movie_filter_by': normalizedFilter.isEmpty ? 'all' : normalizedFilter,
    });
  }

  static const _searchMovieTypes = {'all', '0', '1', '2', '3', '4'};
  static const _searchMovieSortBys = {'relevance', 'release', 'update', 'score'};

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

  /// 搜索 dbonline 实体（系列、片商、导演、清单）。
  ///
  /// 与网页端一致走通用搜索接口，`type` 使用服务端实体白名单，响应为
  /// `data.items` 的实体列表格式。
  Future<DbOnlineSearchEntityPage> searchEntitiesPage({
    required String type,
    required String query,
    int page = 1,
    int limit = 24,
  }) {
    final normalizedType = type.trim();
    if (!_searchEntityTypes.contains(normalizedType)) {
      throw ArgumentError.value(type, 'type', AppErrorCode.validationFailed);
    }
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(query, 'query', AppErrorCode.validationFailed);
    }
    return _searchEntitiesPage('/search', {
      'q': normalized,
      'type': normalizedType,
      'page': page,
      'limit': limit,
      'movie_type': 'all',
      'movie_sort_by': 'relevance',
    });
  }

  static const _searchEntityTypes = {'series', 'maker', 'director', 'list'};

  /// 实体（演员/系列/片商/导演/清单）的影片列表，与网页端实体落地页
  /// 共用同一组端点：`/{actors|series|makers|directors|lists}/{id}/movies`。
  ///
  /// `sortBy`：release/update/score；`filter` 是 m/c/s/p（有磁链/字幕/
  /// 单人/可播放）按此顺序拼接的多选串；`year` 仅演员生效（2011 至当前
  /// 年份）。
  Future<DbOnlineMoviePage> entityMoviesPage({
    required String kind,
    required String id,
    int page = 1,
    int limit = 24,
    String sortBy = 'release',
    String filter = '',
    String year = '',
  }) {
    final segment = _entityMovieSegments[kind.trim()];
    if (segment == null) {
      throw ArgumentError.value(kind, 'kind', AppErrorCode.validationFailed);
    }
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', AppErrorCode.validationFailed);
    }
    final normalizedSort = sortBy.trim();
    if (!_entityMovieSortBys.contains(normalizedSort)) {
      throw ArgumentError.value(sortBy, 'sortBy', AppErrorCode.validationFailed);
    }
    final isActor = kind.trim() == 'actor';
    final normalizedFilter = filter.trim();
    final normalizedYear = isActor ? year.trim() : '';
    return _moviesPage('/$segment/${Uri.encodeComponent(normalizedId)}/movies', {
      'page': page,
      'limit': limit,
      'sort_by': normalizedSort,
      if (!isActor) 'order_by': 'desc',
      if (normalizedFilter.isNotEmpty) 'filter': normalizedFilter,
      if (normalizedYear.isNotEmpty) 'year': normalizedYear,
    });
  }

  static const _entityMovieSegments = {
    'actor': 'actors',
    'series': 'series',
    'maker': 'makers',
    'director': 'directors',
    'list': 'lists',
  };
  static const _entityMovieSortBys = {'release', 'update', 'score'};

  /// 按类别筛选影片，与网页端 `/filter` 落地页共用 `/videos/filter` 端点。
  ///
  /// `categoryId` 为类别 external_id，优先于 [category] 名称；两者皆空时
  /// 视为非法请求。响应是 `data.videos` 的一次性全量列表，无分页参数。
  Future<List<DbOnlineMovie>> categoryFilterVideos({
    String categoryId = '',
    String category = '',
  }) async {
    final normalizedId = categoryId.trim();
    final normalizedName = category.trim();
    if (normalizedId.isEmpty && normalizedName.isEmpty) {
      throw ArgumentError.value(
        categoryId,
        'categoryId',
        AppErrorCode.validationFailed,
      );
    }
    final response = await _dio.get<dynamic>(
      '/videos/filter',
      queryParameters: {
        if (normalizedId.isNotEmpty) 'category_id': normalizedId,
        if (normalizedId.isEmpty) 'category': normalizedName,
      },
    );
    return unwrapStd<List<DbOnlineMovie>>(response.data, (data) {
      final rawVideos = data is Map ? data['videos'] : null;
      return rawVideos is List
          ? rawVideos
                .whereType<Map>()
                .map(
                  (item) =>
                      DbOnlineMovie.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <DbOnlineMovie>[];
    });
  }

  /// 影片排行榜（日/周/月榜），一次性返回全量结果。
  ///
  /// `period`：daily/weekly/monthly；`type`：0=有码、1=无码、2=欧美、
  /// 3=FC2。响应沿用 `data.movies` 解析，名次由列表顺序决定。
  Future<DbOnlineMoviePage> rankingsPage({
    required String period,
    int type = 0,
  }) {
    final normalizedPeriod = period.trim();
    if (!_rankingPeriods.contains(normalizedPeriod)) {
      throw ArgumentError.value(period, 'period', AppErrorCode.validationFailed);
    }
    if (type < 0 || type > 3) {
      throw ArgumentError.value(type, 'type', AppErrorCode.validationFailed);
    }
    return _moviesPage('/rankings', {'period': normalizedPeriod, 'type': type});
  }

  /// Top250 榜单的一页。`type` 为 all/video_type/year，`typeValue` 在
  /// video_type 下取 '0'-'3'、year 下取年份；`startRank` 仅允许
  /// 1/51/101/151/201，与网页端一致。
  Future<DbOnlineMoviePage> top250Page({
    String type = 'all',
    String typeValue = '',
    bool ignoreWatched = false,
    int startRank = 1,
    int page = 1,
    int limit = 25,
  }) {
    final normalizedType = type.trim();
    if (!_top250Types.contains(normalizedType)) {
      throw ArgumentError.value(type, 'type', AppErrorCode.validationFailed);
    }
    if (!_top250StartRanks.contains(startRank)) {
      throw ArgumentError.value(
        startRank,
        'startRank',
        AppErrorCode.validationFailed,
      );
    }
    if (page < 1) {
      throw ArgumentError.value(page, 'page', AppErrorCode.validationFailed);
    }
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', AppErrorCode.validationFailed);
    }
    return _moviesPage('/top250', {
      'type': normalizedType,
      'type_value': typeValue.trim(),
      'ignore_watched': ignoreWatched ? 'true' : 'false',
      'start_rank': startRank,
      'page': page,
      'limit': limit,
    });
  }

  static const _rankingPeriods = {'daily', 'weekly', 'monthly'};
  static const _top250Types = {'all', 'video_type', 'year'};
  static const _top250StartRanks = {1, 51, 101, 151, 201};

  /// 按番号获取影片详情。dbonline 使用字符串番号作为稳定标识，不能
  /// 转换为 Oh My Media 的整数影片 ID。refresh 控制是否强制访问在线 API。
  Future<DbOnlineMovieDetail> detail(
    String code, {
    bool refresh = true,
    String? videoId,
  }) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', AppErrorCode.validationFailed);
    }
    final query = <String, dynamic>{
      'refresh': refresh,
      if (videoId?.trim().isNotEmpty == true) 'video_id': videoId!.trim(),
    };
    final response = await _dio.get<dynamic>(
      '/video/${Uri.encodeComponent(normalized)}',
      queryParameters: query.isEmpty ? null : query,
    );
    return _movieDetailFromResponse(response.data);
  }

  /// 通过 dbonline/JavDB 的 video_id 获取详情，适用于番号尚未写入本地
  /// 数据库的推荐结果。refresh 控制是否强制访问在线 API。
  Future<DbOnlineMovieDetail> detailByVideoId(
    String videoId, {
    bool refresh = true,
  }) async {
    final normalized = videoId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(videoId, 'videoId', AppErrorCode.validationFailed);
    }
    final response = await _dio.get<dynamic>(
      '/video/id/${Uri.encodeComponent(normalized)}',
      queryParameters: {'refresh': refresh},
    );
    return _movieDetailFromResponse(response.data);
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

  DbOnlineMovieDetail _movieDetailFromResponse(Object? raw) {
    final source = raw is Map ? raw['source']?.toString() : null;
    return unwrapStd<DbOnlineMovieDetail>(raw, (data) {
      return DbOnlineMovieDetail.fromJson(
        Map<String, dynamic>.from(data as Map),
        source: source,
      );
    });
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
