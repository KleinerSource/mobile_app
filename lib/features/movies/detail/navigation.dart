import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main/main_shell_providers.dart';
import '../movie_filter.dart';
import '../movies_providers.dart';
import 'movie_detail_page.dart';

void applyFilterAndPop(
  BuildContext context,
  WidgetRef ref, {
  required MovieFilter filter,
}) {
  ref.read(movieFilterProvider.notifier).state = filter;
  ref.read(mainShellTabIndexProvider.notifier).state = 1;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

void filterBySeries(BuildContext context, WidgetRef ref, int seriesId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(seriesIds: [seriesId]));
}

void filterByTag(BuildContext context, WidgetRef ref, int tagId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(tagIds: [tagId]));
}

void filterByGenre(BuildContext context, WidgetRef ref, int genreId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(genreIds: [genreId]));
}

void filterByActor(BuildContext context, WidgetRef ref, int actorId) {
  applyFilterAndPop(context, ref,
      filter: MovieFilter(actorIds: [actorId]));
}

void navigateToMovie(BuildContext context, int movieId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
  );
}
