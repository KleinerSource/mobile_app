import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record.dart';

final dbOnlineDownloadRecordApiProvider = Provider.autoDispose
    .family<DbOnlineDownloadRecordApi, String>((ref, serverId) {
      final client = ref.watch(requiredApiClientProvider);
      if (client.config?.activeServerId != serverId) {
        throw StateError('The active DB Online server changed.');
      }
      return client.dbOnline.downloadRecords;
    });

final dbOnlineRecordDownloadersProvider = FutureProvider.autoDispose
    .family<List<DbOnlineRecordDownloader>, String>(
      (ref, serverId) =>
          ref.watch(dbOnlineDownloadRecordApiProvider(serverId)).downloaders(),
    );
