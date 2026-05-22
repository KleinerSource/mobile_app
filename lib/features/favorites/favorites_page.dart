import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../../shared/poster.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';
import '../settings/settings_page.dart';
import 'favorites_providers.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final favs = ref.watch(_favoritesListProvider);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR LIBRARY', style: AppText.eyebrow(context)),
                          const SizedBox(height: 3),
                          Text('Favorites', style: AppText.pageTitle(context)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.surface,
                          border: Border.all(color: c.cardBorder),
                        ),
                        child: Icon(Icons.settings, size: 18, color: c.text),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats strip
            favs.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (items) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: _StatsCard(items: items),
                ),
              ),
            ),

            // Lists (本地虚拟集合)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: Row(
                  children: [
                    Expanded(child: Text('Your lists', style: AppText.sectionTitle(context))),
                    Text(
                      '+ New list',
                      style: TextStyle(
                        color: c.accent,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                child: _ListsGrid(),
              ),
            ),

            // Up next - watchlist
            favs.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (items) {
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.cardBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.favorite_border, size: 32, color: c.muted),
                            const SizedBox(height: 10),
                            Text('还没有收藏的影片',
                                style: AppText.body(context)
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              '在影片详情页点击 ♡ 加入收藏',
                              style: AppText.meta(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UP NEXT', style: AppText.eyebrow(context)),
                          const SizedBox(height: 4),
                          Text('Watchlist', style: AppText.sectionTitle(context)),
                        ],
                      ),
                    ),
                    for (final m in items.take(8))
                      _WatchlistRow(movie: m, urlBuilder: urlBuilder),
                    const SizedBox(height: 120),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final _favoritesListProvider =
    FutureProvider<List<MovieListItem>>((ref) async {
  final repo = ref.watch(favoritesRepositoryProvider);
  final paged = await repo.list(
    const MovieFilter(sortBy: 'updated_at', sortOrder: 'desc'),
    limit: 50,
    offset: 0,
  );
  return paged.items;
});

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.items});
  final List<MovieListItem> items;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final watched = items.where((m) => m.watchRecord?.completed == true).length;
    final hours = items.fold<int>(0, (acc, m) {
      final r = m.watchRecord;
      if (r == null) return acc;
      final fraction = r.completed ? 1.0 : r.progressRatio;
      final mins = m.runtime != null ? (m.runtime! * fraction).round() : 0;
      return acc + mins;
    }) ~/
        60;

    Widget cell(String k, String v, {bool first = false}) {
      return Expanded(
        child: Container(
          decoration: first
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: c.divider)),
                ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                v,
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                k.toUpperCase(),
                style: TextStyle(
                  color: c.muted,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          cell('Saved', '${items.length}', first: true),
          cell('Watched', '$watched'),
          cell('Hours', '$hours'),
        ],
      ),
    );
  }
}

class _ListsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lists = [
      ('Watchlist', '—', AppHues.lavender, false),
      ('All-Time Best', '—', AppHues.coral, false),
      ('Weekend Picks', '—', AppHues.mint, false),
      ('After Hours', '—', AppHues.sky, true),
    ];
    return LayoutBuilder(builder: (ctx, cons) {
      const gap = 10.0;
      final w = (cons.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final l in lists)
            SizedBox(
              width: w,
              child: _ListCard(
                name: l.$1,
                sub: l.$2,
                hue: l.$3,
                pin: l.$4,
              ),
            ),
        ],
      );
    });
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.name,
    required this.sub,
    required this.hue,
    required this.pin,
  });
  final String name;
  final String sub;
  final int hue;
  final bool pin;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 5 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppHues.top(hue), AppHues.bottom(hue)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                width: 100,
                height: 100,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppHues.highlight(hue),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '◇',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (pin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'PIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sub,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchlistRow extends StatelessWidget {
  const _WatchlistRow({required this.movie, required this.urlBuilder});
  final MovieListItem movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movie.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Poster(
                url: movie.posterUuid != null ? urlBuilder(movie.posterUuid!) : null,
                title: movie.title,
                year: movie.year,
                radius: 8,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (movie.year != null) '${movie.year}',
                      if (movie.runtime != null && movie.runtime! > 0)
                        '${movie.runtime}m',
                    ].join(' · '),
                    style: AppText.meta(context),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B9D), Color(0xFF9F6BFF)],
                ),
              ),
              child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
