import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/dbo_config.dart';
import 'configs_repository.dart';

final configsRepositoryProvider = Provider<ConfigsRepository>((ref) {
  return ConfigsRepository(ref.watch(requiredApiClientProvider).configs);
});

final dboConfigProvider = FutureProvider<DboConfig>((ref) async {
  return ref.watch(configsRepositoryProvider).getDbo();
});

final videoExtensionsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(configsRepositoryProvider).getVideoExtensions();
});
