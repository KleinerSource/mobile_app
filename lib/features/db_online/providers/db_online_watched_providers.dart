import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_watched.dart';

final dbOnlineWatchedPageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineWatchedQuery>((ref, query) {
      final client = ref.watch(requiredApiClientProvider);
      if (client.config?.activeServerId != query.serverId) {
        throw const ServerConnectionClosedException();
      }
      return client.dbOnline.watchedMoviesPage(
        filter: query.filter,
        page: query.page,
      );
    });
