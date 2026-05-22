import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/models/resource.dart';
import '../../core/models/actor.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/filter_chip.dart';
import '../../shared/poster.dart';
import '../favorites/favorites_providers.dart';
import '../movies/movies_providers.dart';
import 'movie_detail_providers.dart';

class MovieDetailPage extends ConsumerWidget {
  const MovieDetailPage({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(movieDetailProvider(movieId));
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = appColors(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败', style: AppText.sectionTitle(context)),
                const SizedBox(height: 8),
                Text('$e', style: AppText.body(context), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (movie) => _DetailBody(
          movie: movie,
          urlBuilder: urlBuilder,
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final favStatus = ref.watch(favoriteStatusProvider);
    // 初始化收藏状态种子
    if (!favStatus.containsKey(movie.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(favoriteStatusProvider.notifier).seed(movie.id, movie.isFavorited);
      });
    }
    final isFavorited = favStatus[movie.id] ?? movie.isFavorited;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          pinned: true,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 18),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: isFavorited ? c.accent : null,
                ),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final value = await ref
                      .read(favoriteStatusProvider.notifier)
                      .toggle(movie.id);
                  messenger.showSnackBar(SnackBar(
                    content: Text(value ? '已加入收藏' : '已移除收藏'),
                    duration: const Duration(seconds: 1),
                  ));
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('操作失败: $e')),
                  );
                }
              },
            ),
            const SizedBox(width: 6),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroHeader(movie: movie, urlBuilder: urlBuilder),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: _TitleBlock(movie: movie),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: _ActionRow(),
          ),
        ),
        if (movie.plot != null && movie.plot!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: Text(
                movie.plot!,
                style: AppText.body(context).copyWith(height: 1.55),
              ),
            ),
          ),
        if (movie.actors.isNotEmpty)
          SliverToBoxAdapter(
            child: _CastSection(actors: movie.actors),
          ),
        if (movie.genres.isNotEmpty || movie.tags.isNotEmpty)
          SliverToBoxAdapter(
            child: _ChipsSection(genres: movie.genres, tags: movie.tags),
          ),
        SliverToBoxAdapter(
          child: _DetailsTable(movie: movie),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (movie.fanartUuid != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Poster(
              url: urlBuilder(movie.fanartUuid!),
              title: movie.title,
              year: movie.year,
              aspectRatio: 1,
              radius: 0,
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.bg.withValues(alpha: 0.0),
                c.bg.withValues(alpha: 0.4),
                c.bg,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 70),
            child: SizedBox(
              width: 200,
              child: Poster(
                url: movie.posterUuid != null
                    ? urlBuilder(movie.posterUuid!)
                    : null,
                title: movie.title,
                year: movie.year,
                radius: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final meta = <String>[];
    if (movie.year != null) meta.add('${movie.year}');
    if (movie.runtime != null && movie.runtime! > 0) meta.add('${movie.runtime} MIN');
    if (movie.country != null && movie.country!.isNotEmpty) meta.add(movie.country!.toUpperCase());
    if (movie.rating != null && movie.rating! > 0) {
      meta.add('★ ${movie.rating!.toStringAsFixed(1)}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          movie.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.text,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.84,
            height: 1.1,
          ),
        ),
        if (movie.originalTitle != null && movie.originalTitle != movie.title) ...[
          const SizedBox(height: 4),
          Text(
            movie.originalTitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontStyle: FontStyle.italic, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          meta.join(' · '),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.muted,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('播放功能尚未对接')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c.text,
              foregroundColor: c.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, size: 18),
                SizedBox(width: 6),
                Text('Play',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: c.text,
              side: BorderSide(color: c.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '+ List',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _CastSection extends StatelessWidget {
  const _CastSection({required this.actors});
  final List<ActorItem> actors;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Text('Cast', style: AppText.sectionTitle(context)),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: actors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final a = actors[i];
                final hue = AppHues.all[i % AppHues.all.length];
                return SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppHues.top(hue), AppHues.bottom(hue)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppHues.top(hue).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(a.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first.toString() +
            parts.last.characters.first.toString())
        .toUpperCase();
  }
}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection({required this.genres, required this.tags});
  final List<ResourceItem> genres;
  final List<ResourceItem> tags;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < genres.length; i++)
            HueChip(label: genres[i].name, hue: AppHues.all[i % AppHues.all.length]),
          for (var i = 0; i < tags.length; i++)
            HueChip(
              label: '# ${tags[i].name}',
              hue: AppHues.all[(i + 2) % AppHues.all.length],
            ),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final rows = <List<String>>[];
    if (movie.num != null && movie.num!.isNotEmpty) rows.add(['Number', movie.num!]);
    if (movie.country != null && movie.country!.isNotEmpty) {
      rows.add(['Country', movie.country!]);
    }
    if (movie.series != null) rows.add(['Series', movie.series!.name]);
    if (movie.filePath != null && movie.filePath!.isNotEmpty) {
      rows.add(['File', movie.filePath!]);
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(bottom: BorderSide(color: c.divider))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      rows[i][0].toUpperCase(),
                      style: TextStyle(
                        color: c.muted,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i][1],
                      style: TextStyle(
                        color: c.text,
                        fontFamily: rows[i][0] == 'File' ? 'monospace' : 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: rows[i][0] == 'File' ? 11.5 : 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
