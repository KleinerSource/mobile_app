import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/server_config_provider.dart';
import '../../../../core/ui/tokens.dart';
import '../../movies_providers.dart';
import '../widgets/fanart_gallery.dart';

class ExtraFanartSection extends ConsumerWidget {
  const ExtraFanartSection({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final cfg = ref.watch(serverConfigProvider);
    final baseUrl = cfg?.baseUrl ?? '';
    final asyncList = ref.watch(extraFanartsProvider(movieId));
    return asyncList.maybeWhen(
      data: (paths) {
        if (paths.isEmpty) return const SizedBox.shrink();
        final urls = paths.map((p) => '$baseUrl$p').toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '预览图',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => FanartGallery(
                              urls: urls, initialIndex: i),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: CachedNetworkImage(
                          imageUrl: urls[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(color: c.surface),
                          errorWidget: (_, __, ___) =>
                              ColoredBox(color: c.surface),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
