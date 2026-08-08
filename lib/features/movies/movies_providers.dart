import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/url_resolver.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/media_info.dart';
import '../../core/models/movie.dart';
import 'movie_filter.dart';
import 'movies_repository.dart';

final movieFilterProvider = StateProvider<MovieFilter>((_) => const MovieFilter());

final moviesRepositoryProvider = Provider<MoviesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return MoviesRepository(client.movies, client.favorites, client.system);
});

/// 海报/图片 URL 构造器。
final imageUrlBuilderProvider = Provider<String Function(String uuid)>((ref) {
  final cfg = ref.watch(serverConfigProvider);
  return (uuid) => cfg == null ? '' : resolveApiUrl(cfg, '/images/$uuid');
});

final movieDetailProvider = FutureProvider.autoDispose
    .family<MovieDetail, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).detail(id);
});

final extraFanartsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).extraFanarts(id);
});

final mediaInfoProvider = FutureProvider.autoDispose
    .family<MediaInfo?, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).mediaInfo(id);
});
