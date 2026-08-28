import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/sources/media/media_source_providers.dart';
import 'media_favorites_repository.dart';

final favoritesRepositoryProvider = Provider<MediaFavoritesRepository>((ref) {
  final source = ref.watch(ommMediaSourceProvider);
  if (source == null) {
    throw StateError('当前服务器不是 OMM，无法访问收藏夹');
  }
  return MediaFavoritesRepository(source.operations);
});

/// 全局收藏状态缓存 · key = movieId
class FavoriteStatusNotifier extends Notifier<Map<int, bool>> {
  @override
  Map<int, bool> build() => const {};

  void seed(int id, bool isFavorited) {
    if (state[id] == isFavorited) return;
    state = {...state, id: isFavorited};
  }

  Future<bool> toggle(int id) async {
    final repo = ref.read(favoritesRepositoryProvider);
    final newValue = await repo.toggle(id);
    state = {...state, id: newValue};
    return newValue;
  }

  bool? get(int id) => state[id];
}

final favoriteStatusProvider =
    NotifierProvider<FavoriteStatusNotifier, Map<int, bool>>(
      FavoriteStatusNotifier.new,
    );
