import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/watch_record.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'movie_filter.dart';
import 'media_repository.dart';

final movieFilterProvider = StateProvider<MovieFilter>(
  (_) => const MovieFilter(),
);

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

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final source = ref.watch(ommMediaSourceProvider);
  if (source == null) {
    throw const SourceException('当前服务器不是 OMM，不能使用本地媒体库影片操作');
  }
  return MediaRepository(
    catalog: source,
    details: source,
    operations: source.operations,
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

final movieDetailProvider = FutureProvider.autoDispose.family<MovieDetail, int>(
  (ref, id) async {
    return ref.read(mediaRepositoryProvider).detail(id);
  },
);

/// 影片详情页使用完整观看记录，获取服务端保存的精确续播秒数。
final movieWatchRecordProvider = FutureProvider.autoDispose
    .family<WatchRecord?, int>((ref, id) async {
      return ref.read(mediaRepositoryProvider).watchRecord(id);
    });

final extraFanartsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, id) async {
      final rawUrls = await ref.read(mediaRepositoryProvider).extraFanarts(id);
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
    .family<MediaInfoDetail?, int>((ref, id) async {
      return ref.read(mediaRepositoryProvider).mediaInfoDetail(id);
    });
