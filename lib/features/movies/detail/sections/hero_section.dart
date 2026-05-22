import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';
import '../../movies_providers.dart';

class HeroSection extends ConsumerWidget {
  const HeroSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final fanart = movie.fanartUuid;
    final poster = movie.posterUuid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fanart != null)
                CachedNetworkImage(
                  imageUrl: urlBuilder(fanart),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(color: c.surface),
                  errorWidget: (_, __, ___) => ColoredBox(color: c.surface),
                )
              else
                ColoredBox(color: c.surface),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.bg.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.poster),
                    child: poster != null
                        ? CachedNetworkImage(
                            imageUrl: urlBuilder(poster),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => ColoredBox(color: c.surface),
                            errorWidget: (_, __, ___) =>
                                ColoredBox(color: c.surface),
                          )
                        : ColoredBox(color: c.surface),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (movie.num != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              movie.num!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: c.text,
                              ),
                            ),
                          ),
                        if (movie.year != null)
                          Text(
                            '${movie.year}',
                            style: TextStyle(
                                fontSize: 13, color: c.textMuted),
                          ),
                        if (movie.runtime != null)
                          Text(
                            '${movie.runtime} 分钟',
                            style: TextStyle(
                                fontSize: 13, color: c.textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
