import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/core/sources/media/dbo/db_online_following_api.dart';

/// 所有关注缓存以服务器 ID 隔离，防止切换后读取上一台服务器的数据。
final dbOnlineFollowingApiProvider = Provider.autoDispose
    .family<DbOnlineFollowingApi, String>((ref, serverId) {
      final client = ref.watch(requiredApiClientProvider);
      if (client.config?.activeServerId != serverId) {
        throw StateError('The active DB Online server changed.');
      }
      return client.dbOnline.following;
    });

final dbOnlineFollowingPresetsProvider = FutureProvider.autoDispose
    .family<List<DbOnlineFollowingPreset>, String>(
      (ref, serverId) =>
          ref.watch(dbOnlineFollowingApiProvider(serverId)).presets(),
    );

final dbOnlineFollowingStylesProvider = FutureProvider.autoDispose
    .family<List<DbOnlineFollowingStyle>, String>(
      (ref, serverId) =>
          ref.watch(dbOnlineFollowingApiProvider(serverId)).styles(),
    );

final dbOnlineFollowedUsersProvider = FutureProvider.autoDispose
    .family<List<DbOnlineFollowedUser>, String>(
      (ref, serverId) =>
          ref.watch(dbOnlineFollowingApiProvider(serverId)).users(),
    );

bool isDbOnlineFollowingServer(WidgetRef ref, String serverId) =>
    ref.read(mediaRuntimeConfigProvider)?.activeServerId == serverId;
