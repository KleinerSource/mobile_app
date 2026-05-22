import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../movies/movies_providers.dart';

final movieDetailProvider =
    FutureProvider.family<MovieDetail, int>((ref, id) async {
  return ref.watch(moviesRepositoryProvider).detail(id);
});
