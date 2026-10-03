import 'package:dio/dio.dart';

import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/error_codes.dart';
import 'package:omm/core/sources/media/dbo/db_online_ranking.dart';

/// DBO 排行榜的演员榜、一键订阅与自动订阅配置接口。
///
/// 影片榜（`/rankings`、`/top250`）在 [DbOnlineApi] 中，与其它影片列表
/// 共用分页解析；这里只放排行榜专属的非影片列表端点。
class DbOnlineRankingApi {
  DbOnlineRankingApi(this._dio);

  final Dio _dio;

  /// 演员榜。type：0=有码、1=无码、2=欧美，一次性返回全量。
  Future<DbOnlineRankingActorResult> rankingActors({int type = 0}) async {
    if (type < 0 || type > 2) {
      throw ArgumentError.value(type, 'type', AppErrorCode.validationFailed);
    }
    final response = await _dio.get<dynamic>(
      '/actors',
      queryParameters: {'type': type},
    );
    return unwrapStd<DbOnlineRankingActorResult>(
      response.data,
      DbOnlineRankingActorResult.fromJson,
    );
  }

  /// 按当前筛选把 Top250 整榜批量创建订阅。
  Future<DbOnlineTop250SubscribeResult> subscribeTop250({
    required String type,
    required String typeValue,
    required bool ignoreWatched,
    required int startRank,
  }) async {
    final response = await _dio.post<dynamic>(
      '/top250/subscribe',
      data: {
        'type': type,
        'type_value': typeValue,
        'ignore_watched': ignoreWatched,
        'start_rank': startRank,
      },
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return unwrapStd<DbOnlineTop250SubscribeResult>(
      response.data,
      DbOnlineTop250SubscribeResult.fromJson,
    );
  }

  /// 读取排行榜自动订阅配置。
  Future<DbOnlineRankingAutoConfig> getAutoConfig() async {
    final response = await _dio.get<dynamic>('/subs/ranking');
    return unwrapStd<DbOnlineRankingAutoConfig>(
      response.data,
      (data) => DbOnlineRankingAutoConfig.fromJson(
        data is Map ? data['config'] : null,
      ),
    );
  }

  /// 保存排行榜自动订阅配置。
  Future<DbOnlineRankingAutoConfig> updateAutoConfig(
    DbOnlineRankingAutoConfig config,
  ) async {
    final response = await _dio.put<dynamic>(
      '/subs/ranking',
      data: {'config': config.toJson()},
    );
    return unwrapStd<DbOnlineRankingAutoConfig>(
      response.data,
      (data) => DbOnlineRankingAutoConfig.fromJson(
        data is Map ? data['config'] : null,
      ),
    );
  }
}
