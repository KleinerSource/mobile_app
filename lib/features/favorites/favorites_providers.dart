import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import 'favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return FavoritesRepository(client.favorites);
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
