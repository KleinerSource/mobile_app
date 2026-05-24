import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppL10n.of(context).searchTitle.toUpperCase(),
                      style: AppText.eyebrow(context)),
                  const SizedBox(height: 3),
                  Text(AppL10n.of(context).searchFind,
                      style: AppText.pageTitle(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, size: 18, color: c.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: AppL10n.of(context).searchHintAll,
                          hintStyle:
                              TextStyle(color: c.muted, fontWeight: FontWeight.w500),
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: InputBorder.none,
                        ),
                        style:
                            TextStyle(color: c.text, fontWeight: FontWeight.w500),
                        onChanged: _onChanged,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: c.muted),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _EmptyHint()
                  : _SearchResults(query: _query),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: c.muted2),
          const SizedBox(height: 12),
          Text(AppL10n.of(context).searchEmpty,
              style: AppText.body(context)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(AppL10n.of(context).searchHint2,
              style: AppText.meta(context)),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final results = ref.watch(_searchProvider(query));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AppL10n.of(context).searchFailed(e.toString()),
              style: AppText.body(context)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                AppL10n.of(context).searchNoResult,
                style: AppText.body(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) => MovieCard(
            movie: items[i],
            posterUrlBuilder: urlBuilder,
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => MovieDetailPage(movieId: items[i].id),
              ),
            ),
          ),
        );
      },
    );
  }
}

final _searchProvider =
    FutureProvider.family<List<MovieListItem>, String>((ref, q) async {
  if (q.isEmpty) return const [];
  final repo = ref.watch(moviesRepositoryProvider);
  final page = await repo.list(
    MovieFilter(search: q, sortBy: 'created_at', sortOrder: 'desc'),
    limit: 60,
    offset: 0,
  );
  return page.items;
});
