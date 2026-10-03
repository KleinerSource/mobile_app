import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/error_codes.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_ranking.dart';
import 'package:omm/features/db_online/settings/db_online_backend_config.dart';

/// 影片排行榜（日/周/月榜）按期间与类型读取，一次性返回全量。
final dbOnlineRankingPageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineRankingPageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .rankingsPage(period: request.period, type: request.type);
    });

class DbOnlineRankingPageRequest {
  const DbOnlineRankingPageRequest({
    required this.serverId,
    required this.period,
    this.type = 0,
  });

  final String serverId;
  final String period;
  final int type;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineRankingPageRequest &&
      other.serverId == serverId &&
      other.period == period &&
      other.type == type;

  @override
  int get hashCode => Object.hash(serverId, period, type);
}

/// Top250 榜单按筛选读取一页数据。
final dbOnlineTop250PageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineTop250PageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref.watch(requiredApiClientProvider).dbOnline.top250Page(
        type: request.type,
        typeValue: request.typeValue,
        ignoreWatched: request.ignoreWatched,
        startRank: request.startRank,
        page: request.page,
        limit: request.limit,
      );
    });

class DbOnlineTop250PageRequest {
  const DbOnlineTop250PageRequest({
    required this.serverId,
    this.type = 'all',
    this.typeValue = '',
    this.ignoreWatched = false,
    this.startRank = 1,
    required this.page,
    required this.limit,
  });

  final String serverId;
  final String type;
  final String typeValue;
  final bool ignoreWatched;
  final int startRank;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineTop250PageRequest &&
      other.serverId == serverId &&
      other.type == type &&
      other.typeValue == typeValue &&
      other.ignoreWatched == ignoreWatched &&
      other.startRank == startRank &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
    serverId,
    type,
    typeValue,
    ignoreWatched,
    startRank,
    page,
    limit,
  );
}

/// 演员榜按类型读取，一次性返回全量。
final dbOnlineRankingActorsProvider = FutureProvider.autoDispose
    .family<DbOnlineRankingActorResult, DbOnlineRankingActorsRequest>((
      ref,
      request,
    ) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .ranking
          .rankingActors(type: request.type);
    });

class DbOnlineRankingActorsRequest {
  const DbOnlineRankingActorsRequest({required this.serverId, this.type = 0});

  final String serverId;
  final int type;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineRankingActorsRequest &&
      other.serverId == serverId &&
      other.type == type;

  @override
  int get hashCode => Object.hash(serverId, type);
}

/// Top250 需要服务端配置 JavDB Authorization；未配置时隐藏 Top250 榜单。
final dbOnlineTop250AvailableProvider = Provider<bool>((ref) {
  final config = ref.watch(dbOnlineBackendConfigProvider);
  return config.when(
    data: (value) {
      final api = value['javdb_api'];
      return api is Map &&
          api['authorization']?.toString().trim().isNotEmpty == true;
    },
    loading: () => false,
    error: (_, _) => false,
  );
});

/// 排行榜自动订阅配置的读取与保存。
final dbOnlineRankingAutoConfigProvider =
    AsyncNotifierProvider<
      DbOnlineRankingAutoConfigController,
      DbOnlineRankingAutoConfig
    >(DbOnlineRankingAutoConfigController.new);

class DbOnlineRankingAutoConfigController
    extends AsyncNotifier<DbOnlineRankingAutoConfig> {
  @override
  Future<DbOnlineRankingAutoConfig> build() {
    return ref.watch(requiredApiClientProvider).dbOnline.ranking.getAutoConfig();
  }

  Future<void> save(DbOnlineRankingAutoConfig config) async {
    final client = ref.read(requiredApiClientProvider);
    final saved = await client.dbOnline.ranking.updateAutoConfig(config);
    if (ref.mounted && identical(ref.read(requiredApiClientProvider), client)) {
      state = AsyncData(saved);
    }
  }
}

void _checkServerScope(Ref ref, String requestServerId) {
  final activeServerId =
      ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
  if (requestServerId != activeServerId) {
    throw const SourceException(
      AppErrorCode.operationFailed,
      code: AppErrorCode.operationFailed,
    );
  }
}
