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
    required String sortBy,
  }) {
    return _movies('/latest', {
      'page': page,
      'limit': limit,
      'type': 'all',
      'sort_by': sortBy,
      'filter_by': 'magnets',
    });
  }

  /// 按番号获取影片详情。dbonline 使用字符串番号作为稳定标识，不能
  /// 转换为 Oh-My-Media 的整数影片 ID。
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
      if (refresh) 'refresh': true,
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
  /// 数据库的推荐结果。
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
      queryParameters: refresh ? const {'refresh': true} : null,
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
    final response = await _dio.get<dynamic>(path, queryParameters: query);
    return unwrapStd<List<DbOnlineMovie>>(response.data, (data) {
      if (data is! Map) return const <DbOnlineMovie>[];
      final movies = data['movies'];
      if (movies is! List) return const <DbOnlineMovie>[];
      return movies
          .whereType<Map>()
          .map(
            (item) => DbOnlineMovie.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    });
  }
}
