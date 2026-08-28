import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/models/ffmpeg_config.dart';
import 'configs_repository.dart';

final configsRepositoryProvider = Provider<ConfigsRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return ConfigsRepository(client.configs, client.configsExtended);
});

final dboConfigProvider = FutureProvider<DboConfig>((ref) async {
  return ref.watch(configsRepositoryProvider).getDbo();
});

final videoExtensionsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(configsRepositoryProvider).getVideoExtensions();
});

final avdbConfigProvider = FutureProvider<AvdbConfig>((ref) async {
  return ref.watch(configsRepositoryProvider).getAvdb();
});

final ffmpegConfigProvider = FutureProvider<FfmpegConfig>((ref) async {
  return ref.watch(configsRepositoryProvider).getFfmpeg();
});
