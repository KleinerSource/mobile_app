import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/tokens.dart';
import '../../../shared/error_view.dart';
import '../movies_providers.dart';
import 'movie_detail_content.dart';

class MovieDetailPage extends ConsumerWidget {
  const MovieDetailPage({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final asyncMovie = ref.watch(movieDetailProvider(movieId));
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        title: asyncMovie.maybeWhen(
          data: (m) => Text(
            m.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: asyncMovie.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(movieDetailProvider(movieId)),
        ),
        data: (movie) => MovieDetailContent(movie: movie),
      ),
    );
  }
}
