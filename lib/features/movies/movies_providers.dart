import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/config/server_config_provider.dart';
import 'movie_filter.dart';
import 'movies_repository.dart';

final movieFilterProvider = StateProvider<MovieFilter>((_) => const MovieFilter());

final moviesRepositoryProvider = Provider<MoviesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return MoviesRepository(client.movies, client.favorites);
});

/// 海报/图片 URL 构造器。
final imageUrlBuilderProvider = Provider<String Function(String uuid)>((ref) {
  final cfg = ref.watch(serverConfigProvider);
  return (uuid) => '${cfg?.apiBase ?? ''}/images/$uuid';
});
