import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

/// 演员 / 导演详情页 · 大头像 + 作品集 (用 actor_ids filter 反查)
class PersonDetailPage extends ConsumerWidget {
  const PersonDetailPage({
    super.key,
    required this.actorId,
    required this.name,
    this.actorType,
    this.biography,
  });

  final int actorId;
  final String name;
  final String? actorType;
  final String? biography;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first.toString() +
            parts.last.characters.first.toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) * 31) % 360;

    final movies = ref.watch(_actorMoviesProvider(actorId));

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppHues.top(hue), AppHues.bottom(hue)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppHues.top(hue).withValues(alpha: 0.4),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(name, style: AppText.pageTitle(context)),
                        if (actorType != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            actorType!.toUpperCase(),
                            style: TextStyle(
                              color: c.muted,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (biography?.trim().isNotEmpty == true)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: Text(biography!.trim(), style: AppText.body(context)),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: Text('Filmography', style: AppText.sectionTitle(context)),
              ),
            ),
            movies.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('加载失败: $e', style: AppText.body(context)),
                ),
              ),
              data: (items) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => MovieCard(
                      movie: items[i],
                      posterUrlBuilder: urlBuilder,
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }
}

final _actorMoviesProvider =
    FutureProvider.family<List<MovieListItem>, int>((ref, actorId) async {
  final repo = ref.watch(moviesRepositoryProvider);
  final filter = MovieFilter(actorIds: [actorId], sortBy: 'year', sortOrder: 'desc');
  final page = await repo.list(filter, limit: 60, offset: 0);
  return page.items;
});
