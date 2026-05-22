import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/related_movie.dart';
import '../../../../core/ui/tokens.dart';
import '../../movies_providers.dart';

class RelatedMovieCard extends ConsumerWidget {
  const RelatedMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
  });

  final RelatedMovie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final uuid = movie.posterUuid ?? movie.thumbUuid ?? movie.fanartUuid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.poster),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.poster),
                child: uuid != null
                    ? CachedNetworkImage(
                        imageUrl: urlBuilder(uuid),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(color: c.surface),
                        errorWidget: (_, __, ___) =>
                            ColoredBox(color: c.surface),
                      )
                    : ColoredBox(color: c.surface),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}
