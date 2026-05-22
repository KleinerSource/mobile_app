import 'package:flutter/material.dart';

import '../../../../core/models/related_movie.dart';
import '../../../../core/ui/tokens.dart';
import '../navigation.dart';
import '../widgets/related_movie_card.dart';

class RelatedMoviesSection extends StatelessWidget {
  const RelatedMoviesSection({
    super.key,
    required this.title,
    required this.movies,
  });

  final String title;
  final List<RelatedMovie> movies;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = movies[i];
                return RelatedMovieCard(
                  movie: m,
                  onTap: () => navigateToMovie(context, m.id),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}
