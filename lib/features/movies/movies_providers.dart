import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/url_resolver.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/media_info.dart';
import '../../core/models/movie.dart';
import 'movie_filter.dart';
import 'movies_repository.dart';

final movieFilterProvider = StateProvider<MovieFilter>((_) => const MovieFilter());

/// 图片服务通常使用稳定 UUID 作为路径；同一个 UUID 的封面被服务器替换
/// 后，CachedNetworkImage 仍会命中旧文件。下拉刷新时递增此版本，让图片
/// URL 产生新的缓存键，同时保留服务器原有的图片路径。
final imageCacheRevisionProvider = StateProvider<int>((_) => 0);

void refreshImageCache(WidgetRef ref) {
  ref.read(imageCacheRevisionProvider.notifier).state++;
}

String imageUrlWithCacheRevision(String url, int revision) {
  if (revision <= 0) return url;
  final uri = Uri.parse(url);
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          '_mdc_image_revision': '$revision',
        },
      )
      .toString();
}

final moviesRepositoryProvider = Provider<MoviesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return MoviesRepository(
    client.movies,
    client.favorites,
    client.system,
    extendedApi: client.moviesExtended,
  );
});

/// 海报/图片 URL 构造器。
final imageUrlBuilderProvider = Provider<String Function(String uuid)>((ref) {
  final cfg = ref.watch(serverConfigProvider);
  final revision = ref.watch(imageCacheRevisionProvider);
  return (uuid) {
    if (cfg == null) return '';
    final url = resolveApiUrl(cfg, '/images/$uuid');
    return imageUrlWithCacheRevision(url, revision);
  };
});

final movieDetailProvider = FutureProvider.autoDispose
    .family<MovieDetail, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).detail(id);
});

final extraFanartsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, id) async {
  final rawUrls = await ref.read(moviesRepositoryProvider).extraFanarts(id);
  final config = ref.read(serverConfigProvider);
  if (config == null) return rawUrls;

  final token = await ref.read(authSessionRepositoryProvider).accessToken();
  final revision = ref.watch(imageCacheRevisionProvider);
  return rawUrls
      .map((url) => resolveProtectedUrl(config, url, token))
      .map((url) => imageUrlWithCacheRevision(url, revision))
      .toList(growable: false);
});

final mediaInfoProvider = FutureProvider.autoDispose
    .family<MediaInfo?, int>((ref, id) async {
  return ref.read(moviesRepositoryProvider).mediaInfo(id);
});
