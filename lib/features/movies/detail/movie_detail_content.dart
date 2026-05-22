import 'package:flutter/material.dart';

import '../../../core/models/movie.dart';
import 'movie_detail_actions.dart';
import 'sections/extra_fanart_section.dart';
import 'sections/file_paths_section.dart';
import 'sections/hero_section.dart';
import 'sections/info_section.dart';
import 'sections/media_info_section.dart';
import 'sections/plot_section.dart';
import 'sections/related_movies_section.dart';
import 'sections/taxonomy_section.dart';

class MovieDetailContent extends StatelessWidget {
  const MovieDetailContent({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroSection(movie: movie),
        MovieDetailActions(movie: movie),
        InfoSection(movie: movie),
        PlotSection(movie: movie),
        TaxonomySection(movie: movie),
        RelatedMoviesSection(title: '分片', movies: movie.partMovies),
        ExtraFanartSection(movieId: movie.id),
        RelatedMoviesSection(title: '同演员其他影片', movies: movie.actorRelatedMovies),
        MediaInfoSection(movieId: movie.id),
        FilePathsSection(movie: movie),
        const SizedBox(height: 24),
      ],
    );
  }
}
