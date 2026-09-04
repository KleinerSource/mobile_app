import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/models/ffmpeg_config.dart';
import 'package:omm/core/models/preview_config.dart';
import 'package:omm/core/sources/common/source_exception.dart';
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

final previewConfigProvider = FutureProvider<PreviewConfig>((ref) async {
  if (ref.watch(serverConfigProvider)?.isOmm != true) {
    throw const UnsupportedSourceCapabilityException('previewGeneration');
  }
  return ref.watch(configsRepositoryProvider).getPreview();
});
