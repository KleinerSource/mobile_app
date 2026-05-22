import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';
import '../navigation.dart';
import '../widgets/actor_chip.dart';
import '../widgets/taxonomy_pill.dart';

class TaxonomySection extends ConsumerWidget {
  const TaxonomySection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final blocks = <Widget>[];

    if (movie.series != null) {
      blocks.add(_block(
        c: c,
        title: '系列',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TaxonomyPill(
              label: movie.series!.name,
              onTap: () => filterBySeries(context, ref, movie.series!.id),
            ),
          ],
        ),
      ));
    }
    if (movie.tags.isNotEmpty) {
      blocks.add(_block(
        c: c,
        title: '标签',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: movie.tags
              .map((t) => TaxonomyPill(
                    label: t.name,
                    onTap: () => filterByTag(context, ref, t.id),
                  ))
              .toList(),
        ),
      ));
    }
    if (movie.genres.isNotEmpty) {
      blocks.add(_block(
        c: c,
        title: '分类',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: movie.genres
              .map((g) => TaxonomyPill(
                    label: g.name,
                    onTap: () => filterByGenre(context, ref, g.id),
                  ))
              .toList(),
        ),
      ));
    }
    if (movie.actors.isNotEmpty) {
      blocks.add(_block(
        c: c,
        title: '演员',
        child: SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movie.actors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = movie.actors[i];
              return ActorChip(
                name: a.name,
                onTap: () => filterByActor(context, ref, a.id),
              );
            },
          ),
        ),
      ));
    }

    if (blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }

  Widget _block({required AppColors c, required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: AppSpacing.s),
          child,
        ],
      ),
    );
  }
}
